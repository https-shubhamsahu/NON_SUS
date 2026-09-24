-- Drop: a NO SUS address anyone can send a file to, without an account.
--
-- The door is closed by default. The owner opens it for a while (and can
-- set a door code). A visitor's browser seals the file key, file name,
-- sender name, and note to the owner's device keys (device_keys, see
-- 20260924100000). The server stores ciphertext, its size, timing, and an
-- HMAC of the sender's IP (for rate limits and blocks). It never gets the
-- file key.
--
-- What the server could still do: serve the visitor a key it controls
-- (the key-directory problem device_keys already names). The door check
-- code on both sides is how a person notices that.
--
-- Clients never insert drops. The visitor goes through the drop-* edge
-- functions (service role); the owner reads with RLS and acts with the
-- RPCs below.

-- ===========================================================================
-- 1. Feature flag gate (same rule as go_enabled_for)
-- ===========================================================================
CREATE OR REPLACE FUNCTION public.drop_enabled_for(uid uuid)
RETURNS boolean
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  f public.feature_flags%ROWTYPE;
  s int := 0;
  t text;
  i int;
BEGIN
  IF uid IS NULL THEN RETURN false; END IF;
  SELECT * INTO f FROM public.feature_flags WHERE flag_key = 'nosus_drop_enabled';
  IF NOT FOUND OR NOT f.is_active THEN RETURN false; END IF;
  IF uid = ANY (f.targeted_user_ids) THEN RETURN true; END IF;
  IF f.rollout_percentage >= 100 THEN RETURN true; END IF;
  IF f.rollout_percentage <= 0 THEN RETURN false; END IF;
  t := uid::text;
  FOR i IN 1..char_length(t) LOOP
    s := s + ascii(substr(t, i, 1));
  END LOOP;
  RETURN (s % 100) < f.rollout_percentage;
END;
$$;

REVOKE ALL ON FUNCTION public.drop_enabled_for(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.drop_enabled_for(uuid) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public._drop_cfg(p_key text, p_default bigint)
RETURNS bigint
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT COALESCE(
    (SELECT (config_value::text)::bigint FROM public.remote_configs WHERE config_key = p_key),
    p_default
  );
$$;

REVOKE ALL ON FUNCTION public._drop_cfg(text, bigint) FROM PUBLIC, anon, authenticated;

-- ===========================================================================
-- 2. Address handles
-- ===========================================================================
-- 4–20 chars, lowercase letters, digits, single hyphens, no leading or
-- trailing hyphen. "--" is refused so a handle can never be a punycode
-- label (xn--) on <handle>.nosus.foo. Kept in step with
-- homepage/src/lib/dropApi.ts, lib/features/address/drop/drop_manifest.dart
-- and infra/cloudflare/address-worker/src/index.ts.
CREATE OR REPLACE FUNCTION public.address_handle_valid(p_handle text)
RETURNS boolean
LANGUAGE sql IMMUTABLE SET search_path = public AS $$
  SELECT p_handle IS NOT NULL
     AND p_handle ~ '^[a-z0-9](?:[a-z0-9-]{2,18}[a-z0-9])$'
     AND position('--' IN p_handle) = 0
     AND p_handle NOT IN (
       'app', 'www', 'api', 'go', 'to', 'admin', 'support', 'help', 'mail',
       'nosus', 'no-sus', 'root', 'static', 'assets', 'burn', 'redeem', 'join',
       'status', 'blog', 'docs', 'login', 'signup', 'settings'
     );
$$;

GRANT EXECUTE ON FUNCTION public.address_handle_valid(text) TO anon, authenticated, service_role;

CREATE TABLE IF NOT EXISTS public.address_handles (
    handle     TEXT PRIMARY KEY
               CONSTRAINT address_handles_handle_chk CHECK (public.address_handle_valid(handle)),
    user_id    UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.address_handles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS address_handles_owner_select ON public.address_handles;
CREATE POLICY address_handles_owner_select ON public.address_handles
    FOR SELECT TO authenticated
    USING (user_id = (SELECT auth.uid()));

REVOKE ALL ON TABLE public.address_handles FROM anon;
REVOKE INSERT, UPDATE, DELETE ON TABLE public.address_handles FROM authenticated;

-- A released handle stays with its last owner for 30 days, so an address
-- someone already shared cannot be picked up by a stranger the next day.
CREATE TABLE IF NOT EXISTS public.address_handle_releases (
    handle      TEXT PRIMARY KEY,
    user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    released_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS address_handle_releases_user_idx
    ON public.address_handle_releases (user_id, released_at);

ALTER TABLE public.address_handle_releases ENABLE ROW LEVEL SECURITY;
-- No policies. Only the functions below touch it.
REVOKE ALL ON TABLE public.address_handle_releases FROM anon, authenticated;

CREATE OR REPLACE FUNCTION public._release_address_handle(p_uid uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.address_handle_releases (handle, user_id, released_at)
  SELECT handle, user_id, now() FROM public.address_handles WHERE user_id = p_uid
  ON CONFLICT (handle) DO UPDATE
     SET user_id = EXCLUDED.user_id, released_at = EXCLUDED.released_at;
  DELETE FROM public.address_handles WHERE user_id = p_uid;
END;
$$;

REVOKE ALL ON FUNCTION public._release_address_handle(uuid) FROM PUBLIC, anon, authenticated;

-- One handle per account. Claiming a new one releases the old one.
CREATE OR REPLACE FUNCTION public.claim_address_handle(p_handle text)
RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_uid    uuid := auth.uid();
  v_handle text := lower(btrim(COALESCE(p_handle, '')));
  v_owner  uuid;
BEGIN
  IF v_uid IS NULL OR NOT public.drop_enabled_for(v_uid) THEN
    RAISE EXCEPTION 'not enabled' USING ERRCODE = '42501';
  END IF;
  IF NOT public.address_handle_valid(v_handle) THEN
    RAISE EXCEPTION 'bad handle' USING ERRCODE = '22023';
  END IF;

  SELECT user_id INTO v_owner FROM public.address_handles WHERE handle = v_handle;
  IF v_owner = v_uid THEN
    RETURN v_handle;
  END IF;
  IF v_owner IS NOT NULL OR EXISTS (
    SELECT 1 FROM public.address_handle_releases r
     WHERE r.handle = v_handle
       AND r.user_id <> v_uid
       AND r.released_at > now() - interval '30 days'
  ) THEN
    RAISE EXCEPTION 'taken' USING ERRCODE = '23505';
  END IF;

  -- Each change parks the old handle for 30 days; cap it so one account
  -- cannot park a whole namespace.
  IF (SELECT count(*) FROM public.address_handle_releases
       WHERE user_id = v_uid AND released_at > now() - interval '30 days') >= 5 THEN
    RAISE EXCEPTION 'too many changes' USING ERRCODE = 'P0001';
  END IF;

  PERFORM public._release_address_handle(v_uid);
  BEGIN
    INSERT INTO public.address_handles (handle, user_id) VALUES (v_handle, v_uid);
  EXCEPTION WHEN unique_violation THEN
    RAISE EXCEPTION 'taken' USING ERRCODE = '23505';
  END;
  DELETE FROM public.address_handle_releases WHERE handle = v_handle;
  RETURN v_handle;
END;
$$;

REVOKE ALL ON FUNCTION public.claim_address_handle(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.claim_address_handle(text) TO authenticated;

CREATE OR REPLACE FUNCTION public.release_address_handle()
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not signed in' USING ERRCODE = '42501';
  END IF;
  PERFORM public._release_address_handle(v_uid);
  UPDATE public.drop_doors
     SET open_until = NULL, code_salt = NULL, code_hash = NULL, failed_codes = 0, updated_at = now()
   WHERE user_id = v_uid;
END;
$$;

-- ===========================================================================
-- 3. Doors
-- ===========================================================================
CREATE TABLE IF NOT EXISTS public.drop_doors (
    user_id      UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    open_until   TIMESTAMPTZ,
    -- sha256(salt || ':' || code), hex. Four to eight digits is guessable
    -- offline, so this column is only ever readable by its owner, and wrong
    -- guesses online close the door (failed_codes).
    code_salt    TEXT,
    code_hash    TEXT,
    failed_codes INTEGER NOT NULL DEFAULT 0,
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.drop_doors ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS drop_doors_owner_select ON public.drop_doors;
CREATE POLICY drop_doors_owner_select ON public.drop_doors
    FOR SELECT TO authenticated
    USING (user_id = (SELECT auth.uid()));

REVOKE ALL ON TABLE public.drop_doors FROM anon;
REVOKE INSERT, UPDATE, DELETE ON TABLE public.drop_doors FROM authenticated;

-- release_address_handle references drop_doors; grant after it exists.
REVOKE ALL ON FUNCTION public.release_address_handle() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.release_address_handle() TO authenticated;

-- 0 (or null) closes. Opening needs a handle and at least one live device
-- key, because a door with nowhere to seal to would take files nobody can
-- open. Returns when the door closes, or null when closed.
CREATE OR REPLACE FUNCTION public.set_drop_door(p_open_minutes int, p_code text DEFAULT NULL)
RETURNS timestamptz
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_uid   uuid := auth.uid();
  v_code  text := NULLIF(btrim(COALESCE(p_code, '')), '');
  v_salt  text;
  v_hash  text;
  v_until timestamptz;
BEGIN
  IF v_uid IS NULL OR NOT public.drop_enabled_for(v_uid) THEN
    RAISE EXCEPTION 'not enabled' USING ERRCODE = '42501';
  END IF;

  IF p_open_minutes IS NULL OR p_open_minutes <= 0 THEN
    INSERT INTO public.drop_doors (user_id, open_until, code_salt, code_hash, failed_codes, updated_at)
    VALUES (v_uid, NULL, NULL, NULL, 0, now())
    ON CONFLICT (user_id) DO UPDATE
       SET open_until = NULL, code_salt = NULL, code_hash = NULL, failed_codes = 0, updated_at = now();
    RETURN NULL;
  END IF;

  IF p_open_minutes > 1440 THEN
    RAISE EXCEPTION 'too long' USING ERRCODE = '22023';
  END IF;
  IF v_code IS NOT NULL AND v_code !~ '^[0-9]{4,8}$' THEN
    RAISE EXCEPTION 'bad code' USING ERRCODE = '22023';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.address_handles WHERE user_id = v_uid) THEN
    RAISE EXCEPTION 'no address' USING ERRCODE = 'P0001';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.device_keys WHERE user_id = v_uid AND revoked_at IS NULL) THEN
    RAISE EXCEPTION 'no device key' USING ERRCODE = 'P0001';
  END IF;

  IF v_code IS NOT NULL THEN
    v_salt := encode(extensions.gen_random_bytes(16), 'hex');
    v_hash := encode(extensions.digest(v_salt || ':' || v_code, 'sha256'), 'hex');
  END IF;
  v_until := now() + make_interval(mins => p_open_minutes);

  INSERT INTO public.drop_doors (user_id, open_until, code_salt, code_hash, failed_codes, updated_at)
  VALUES (v_uid, v_until, v_salt, v_hash, 0, now())
  ON CONFLICT (user_id) DO UPDATE
     SET open_until = EXCLUDED.open_until,
         code_salt = EXCLUDED.code_salt,
         code_hash = EXCLUDED.code_hash,
         failed_codes = 0,
         updated_at = now();
  RETURN v_until;
END;
$$;

REVOKE ALL ON FUNCTION public.set_drop_door(int, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_drop_door(int, text) TO authenticated;

-- ===========================================================================
-- 4. Drops
-- ===========================================================================
-- Private bucket. No storage.objects policies: uploads use a signed upload
-- URL from drop-init, downloads a signed URL from drop-fetch, deletes the
-- cleanup-drops sweep. Object path is the drop id and nothing else, so the
-- visitor never learns the owner's user id.
INSERT INTO storage.buckets (id, name, public, file_size_limit)
VALUES ('drops', 'drops', false, 52428800)
ON CONFLICT (id) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.drops (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    state         TEXT NOT NULL DEFAULT 'uploading'
                  CONSTRAINT drops_state_chk
                  CHECK (state IN ('uploading', 'pending', 'accepted', 'declined', 'expired')),
    size_bytes    BIGINT NOT NULL
                  CONSTRAINT drops_size_chk CHECK (size_bytes > 0 AND size_bytes <= 52428800),
    storage_path  TEXT NOT NULL,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at    TIMESTAMPTZ NOT NULL DEFAULT now() + interval '24 hours'
);

CREATE INDEX IF NOT EXISTS drops_owner_state_idx ON public.drops (owner_user_id, state);
CREATE INDEX IF NOT EXISTS drops_cleanup_idx ON public.drops (state, expires_at);

ALTER TABLE public.drops ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS drops_owner_select ON public.drops;
CREATE POLICY drops_owner_select ON public.drops
    FOR SELECT TO authenticated
    USING (owner_user_id = (SELECT auth.uid()) AND state IN ('pending', 'accepted'));

REVOKE ALL ON TABLE public.drops FROM anon;
REVOKE INSERT, UPDATE, DELETE ON TABLE public.drops FROM authenticated;

-- The sender's IP hash lives apart from drops so the owner (who can read
-- drops) never gets a stable identifier for a sender. It is used for
-- blocks and nothing else, and goes when the drop goes.
CREATE TABLE IF NOT EXISTS public.drop_senders (
    drop_id UUID PRIMARY KEY REFERENCES public.drops(id) ON DELETE CASCADE,
    ip_hash TEXT NOT NULL
);

ALTER TABLE public.drop_senders ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.drop_senders FROM anon, authenticated;

-- One sealed manifest per owner device. box = b64url(sealBox(device key,
-- context 'drop:<drop id>', JSON manifest)). The manifest carries the file
-- key, file name, type, size, sender name and note.
CREATE TABLE IF NOT EXISTS public.drop_envelopes (
    drop_id       UUID NOT NULL REFERENCES public.drops(id) ON DELETE CASCADE,
    device_key_id UUID NOT NULL REFERENCES public.device_keys(id) ON DELETE CASCADE,
    box           TEXT NOT NULL
                  CONSTRAINT drop_envelopes_box_chk CHECK (box ~ '^[A-Za-z0-9_-]{128,8192}$'),
    PRIMARY KEY (drop_id, device_key_id)
);

CREATE INDEX IF NOT EXISTS drop_envelopes_device_idx ON public.drop_envelopes (device_key_id);

ALTER TABLE public.drop_envelopes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS drop_envelopes_owner_select ON public.drop_envelopes;
CREATE POLICY drop_envelopes_owner_select ON public.drop_envelopes
    FOR SELECT TO authenticated
    USING (EXISTS (
      SELECT 1 FROM public.drops d
       WHERE d.id = drop_envelopes.drop_id
         AND d.owner_user_id = (SELECT auth.uid())
         AND d.state IN ('pending', 'accepted')
    ));

REVOKE ALL ON TABLE public.drop_envelopes FROM anon;
REVOKE INSERT, UPDATE, DELETE ON TABLE public.drop_envelopes FROM authenticated;

CREATE TABLE IF NOT EXISTS public.drop_blocks (
    owner_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    ip_hash       TEXT NOT NULL,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (owner_user_id, ip_hash)
);

ALTER TABLE public.drop_blocks ENABLE ROW LEVEL SECURITY;
-- No policies: the owner never sees the hashes. They can count and clear
-- them through the functions below.
REVOKE ALL ON TABLE public.drop_blocks FROM anon, authenticated;

-- Per-IP-hash counters, one row per (hash, kind). kind 'door' counts
-- lookups, 'send' counts drop-init calls (wrong door codes included).
CREATE TABLE IF NOT EXISTS public.drop_rate_counters (
    ip_hash      TEXT NOT NULL,
    kind         TEXT NOT NULL CONSTRAINT drop_rate_counters_kind_chk CHECK (kind IN ('door', 'send')),
    window_start TIMESTAMPTZ NOT NULL DEFAULT now(),
    hit_count    INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (ip_hash, kind)
);

ALTER TABLE public.drop_rate_counters ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.drop_rate_counters FROM anon, authenticated;

CREATE OR REPLACE FUNCTION public.check_and_increment_drop_rate(
  p_ip_hash text,
  p_kind text,
  p_limit int,
  p_window_minutes int
)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_row public.drop_rate_counters;
BEGIN
  SELECT * INTO v_row FROM public.drop_rate_counters
   WHERE ip_hash = p_ip_hash AND kind = p_kind FOR UPDATE;
  IF NOT FOUND THEN
    INSERT INTO public.drop_rate_counters (ip_hash, kind, hit_count) VALUES (p_ip_hash, p_kind, 1)
    ON CONFLICT (ip_hash, kind) DO UPDATE SET hit_count = public.drop_rate_counters.hit_count + 1;
    RETURN true;
  END IF;
  IF v_row.window_start < now() - make_interval(mins => p_window_minutes) THEN
    UPDATE public.drop_rate_counters
       SET window_start = now(), hit_count = 1
     WHERE ip_hash = p_ip_hash AND kind = p_kind;
    RETURN true;
  END IF;
  IF v_row.hit_count >= p_limit THEN
    RETURN false;
  END IF;
  UPDATE public.drop_rate_counters SET hit_count = hit_count + 1
   WHERE ip_hash = p_ip_hash AND kind = p_kind;
  RETURN true;
END;
$$;

REVOKE ALL ON FUNCTION public.check_and_increment_drop_rate(text, text, int, int) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.check_and_increment_drop_rate(text, text, int, int) TO service_role;

-- ===========================================================================
-- 5. Visitor side (service role only, called by the drop-* functions)
-- ===========================================================================
-- An unknown handle, a closed door, an owner outside the rollout, and an
-- owner with no device keys all look the same: closed. Never returns the
-- owner's id, email, or name.
CREATE OR REPLACE FUNCTION public.drop_door_public(p_handle text)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_owner   uuid;
  v_door    public.drop_doors%ROWTYPE;
  v_devices jsonb;
  v_closed  jsonb := jsonb_build_object('open', false, 'needsCode', false, 'devices', '[]'::jsonb);
BEGIN
  SELECT user_id INTO v_owner FROM public.address_handles WHERE handle = lower(btrim(COALESCE(p_handle, '')));
  IF v_owner IS NULL OR NOT public.drop_enabled_for(v_owner) THEN
    RETURN v_closed;
  END IF;
  SELECT * INTO v_door FROM public.drop_doors WHERE user_id = v_owner;
  IF NOT FOUND OR v_door.open_until IS NULL OR v_door.open_until <= now() THEN
    RETURN v_closed;
  END IF;
  SELECT COALESCE(jsonb_agg(jsonb_build_object('id', dk.id, 'publicKey', dk.public_key) ORDER BY dk.created_at), '[]'::jsonb)
    INTO v_devices
    FROM public.device_keys dk
   WHERE dk.user_id = v_owner AND dk.revoked_at IS NULL;
  IF jsonb_array_length(v_devices) = 0 THEN
    RETURN v_closed;
  END IF;
  RETURN jsonb_build_object('open', true, 'needsCode', v_door.code_hash IS NOT NULL, 'devices', v_devices);
END;
$$;

REVOKE ALL ON FUNCTION public.drop_door_public(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.drop_door_public(text) TO service_role;

-- Everything drop-init needs, in one transaction: rate limit, door, code,
-- block list, size cap, pending cap, then the 'uploading' row.
-- status: ok | rate | closed | code | size | full
CREATE OR REPLACE FUNCTION public.drop_begin(
  p_handle  text,
  p_code    text,
  p_ip_hash text,
  p_size    bigint
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_owner   uuid;
  v_door    public.drop_doors%ROWTYPE;
  v_code    text := NULLIF(btrim(COALESCE(p_code, '')), '');
  v_max     bigint := public._drop_cfg('drop_max_bytes', 26214400);
  v_rate    bigint := public._drop_cfg('drop_rate_per_hour', 10);
  v_pending bigint := public._drop_cfg('drop_pending_max', 20);
  v_ttl     bigint := public._drop_cfg('drop_ttl_hours', 24);
  v_id      uuid;
  v_devices jsonb;
BEGIN
  IF p_ip_hash IS NULL OR length(p_ip_hash) < 16 THEN
    RETURN jsonb_build_object('status', 'closed');
  END IF;
  -- Counted before anything else so wrong codes and closed doors cost
  -- the caller quota too.
  IF NOT public.check_and_increment_drop_rate(p_ip_hash, 'send', v_rate::int, 60) THEN
    RETURN jsonb_build_object('status', 'rate');
  END IF;

  SELECT user_id INTO v_owner FROM public.address_handles WHERE handle = lower(btrim(COALESCE(p_handle, '')));
  IF v_owner IS NULL OR NOT public.drop_enabled_for(v_owner) THEN
    RETURN jsonb_build_object('status', 'closed');
  END IF;

  SELECT * INTO v_door FROM public.drop_doors WHERE user_id = v_owner FOR UPDATE;
  IF NOT FOUND OR v_door.open_until IS NULL OR v_door.open_until <= now() THEN
    RETURN jsonb_build_object('status', 'closed');
  END IF;

  IF v_door.code_hash IS NOT NULL AND (
       v_code IS NULL
       OR encode(extensions.digest(v_door.code_salt || ':' || v_code, 'sha256'), 'hex') <> v_door.code_hash
     ) THEN
    -- 20 wrong codes in one opening close the door. The owner can reopen.
    UPDATE public.drop_doors
       SET failed_codes = failed_codes + 1,
           open_until = CASE WHEN failed_codes + 1 >= 20 THEN now() ELSE open_until END,
           updated_at = now()
     WHERE user_id = v_owner;
    RETURN jsonb_build_object('status', 'code');
  END IF;

  -- A blocked sender sees an ordinary closed door.
  IF EXISTS (SELECT 1 FROM public.drop_blocks WHERE owner_user_id = v_owner AND ip_hash = p_ip_hash) THEN
    RETURN jsonb_build_object('status', 'closed');
  END IF;

  -- p_size is ciphertext: plain + 12-byte nonce + 16-byte tag.
  IF p_size IS NULL OR p_size <= 28 OR p_size > v_max + 28 THEN
    RETURN jsonb_build_object('status', 'size', 'max', v_max);
  END IF;

  IF (SELECT count(*) FROM public.drops
       WHERE owner_user_id = v_owner
         AND state IN ('uploading', 'pending')
         AND expires_at > now()) >= v_pending THEN
    RETURN jsonb_build_object('status', 'full');
  END IF;

  SELECT COALESCE(jsonb_agg(jsonb_build_object('id', dk.id, 'publicKey', dk.public_key) ORDER BY dk.created_at), '[]'::jsonb)
    INTO v_devices
    FROM public.device_keys dk
   WHERE dk.user_id = v_owner AND dk.revoked_at IS NULL;
  IF jsonb_array_length(v_devices) = 0 THEN
    RETURN jsonb_build_object('status', 'closed');
  END IF;

  v_id := gen_random_uuid();
  INSERT INTO public.drops (id, owner_user_id, state, size_bytes, storage_path, expires_at)
  VALUES (v_id, v_owner, 'uploading', p_size, v_id::text, now() + make_interval(hours => v_ttl::int));
  INSERT INTO public.drop_senders (drop_id, ip_hash) VALUES (v_id, p_ip_hash);

  RETURN jsonb_build_object('status', 'ok', 'dropId', v_id, 'path', v_id::text, 'devices', v_devices);
END;
$$;

REVOKE ALL ON FUNCTION public.drop_begin(text, text, text, bigint) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.drop_begin(text, text, text, bigint) TO service_role;

-- Called by drop-confirm after it has checked the stored object's real
-- size. Envelopes must be for the owner's live device keys.
-- status: ok | gone | size | envelopes
CREATE OR REPLACE FUNCTION public.drop_finish(
  p_drop_id   uuid,
  p_real_size bigint,
  p_envelopes jsonb
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_drop public.drops%ROWTYPE;
  v_env  jsonb;
  v_n    int;
BEGIN
  SELECT * INTO v_drop FROM public.drops WHERE id = p_drop_id FOR UPDATE;
  IF NOT FOUND OR v_drop.state <> 'uploading' OR v_drop.expires_at <= now() THEN
    RETURN jsonb_build_object('status', 'gone');
  END IF;
  IF p_real_size IS NULL OR p_real_size <> v_drop.size_bytes THEN
    RETURN jsonb_build_object('status', 'size');
  END IF;
  IF p_envelopes IS NULL OR jsonb_typeof(p_envelopes) <> 'array' THEN
    RETURN jsonb_build_object('status', 'envelopes');
  END IF;
  v_n := jsonb_array_length(p_envelopes);
  IF v_n < 1 OR v_n > 10 THEN
    RETURN jsonb_build_object('status', 'envelopes');
  END IF;

  FOR v_env IN SELECT * FROM jsonb_array_elements(p_envelopes) LOOP
    IF COALESCE(jsonb_typeof(v_env->'deviceKeyId'), '') <> 'string'
       OR COALESCE(jsonb_typeof(v_env->'box'), '') <> 'string'
       OR (v_env->>'deviceKeyId') !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
       OR (v_env->>'box') !~ '^[A-Za-z0-9_-]{128,8192}$'
       OR NOT EXISTS (
         SELECT 1 FROM public.device_keys dk
          WHERE dk.id = (v_env->>'deviceKeyId')::uuid
            AND dk.user_id = v_drop.owner_user_id
            AND dk.revoked_at IS NULL
       ) THEN
      RETURN jsonb_build_object('status', 'envelopes');
    END IF;
  END LOOP;

  INSERT INTO public.drop_envelopes (drop_id, device_key_id, box)
  SELECT p_drop_id, (e->>'deviceKeyId')::uuid, e->>'box'
    FROM jsonb_array_elements(p_envelopes) e
  ON CONFLICT (drop_id, device_key_id) DO NOTHING;

  UPDATE public.drops SET state = 'pending' WHERE id = p_drop_id;
  RETURN jsonb_build_object('status', 'ok');
END;
$$;

REVOKE ALL ON FUNCTION public.drop_finish(uuid, bigint, jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.drop_finish(uuid, bigint, jsonb) TO service_role;

-- ===========================================================================
-- 6. Owner side
-- ===========================================================================
-- Accepting keeps the encrypted copy for one more hour so the phone can
-- download it into Drive; the sweep removes it after that.
CREATE OR REPLACE FUNCTION public.accept_drop(p_drop_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not signed in' USING ERRCODE = '42501';
  END IF;
  UPDATE public.drops
     SET state = 'accepted',
         expires_at = LEAST(expires_at, now() + interval '1 hour')
   WHERE id = p_drop_id
     AND owner_user_id = auth.uid()
     AND state IN ('pending', 'accepted')
     AND expires_at > now();
  IF NOT FOUND THEN
    RAISE EXCEPTION 'drop unavailable' USING ERRCODE = 'P0001';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.accept_drop(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.accept_drop(uuid) TO authenticated;

-- Declining drops the sealed manifests right away. The ciphertext object
-- goes on the next cleanup-drops sweep.
CREATE OR REPLACE FUNCTION public.decline_drop(p_drop_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not signed in' USING ERRCODE = '42501';
  END IF;
  UPDATE public.drops
     SET state = 'declined', expires_at = now()
   WHERE id = p_drop_id
     AND owner_user_id = auth.uid()
     AND state IN ('uploading', 'pending', 'accepted');
  DELETE FROM public.drop_envelopes e
   USING public.drops d
   WHERE e.drop_id = d.id AND d.id = p_drop_id AND d.owner_user_id = auth.uid();
END;
$$;

REVOKE ALL ON FUNCTION public.decline_drop(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.decline_drop(uuid) TO authenticated;

-- Blocks the network the drop came from (by IP hash) and declines it.
-- IPs are shared and change, so this is a speed bump, not an identity.
CREATE OR REPLACE FUNCTION public.block_drop_sender(p_drop_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_hash text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not signed in' USING ERRCODE = '42501';
  END IF;
  SELECT s.ip_hash INTO v_hash
    FROM public.drop_senders s
    JOIN public.drops d ON d.id = s.drop_id
   WHERE d.id = p_drop_id AND d.owner_user_id = auth.uid();
  IF v_hash IS NOT NULL THEN
    INSERT INTO public.drop_blocks (owner_user_id, ip_hash)
    VALUES (auth.uid(), v_hash)
    ON CONFLICT (owner_user_id, ip_hash) DO NOTHING;
  END IF;
  PERFORM public.decline_drop(p_drop_id);
END;
$$;

REVOKE ALL ON FUNCTION public.block_drop_sender(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.block_drop_sender(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.count_drop_blocks()
RETURNS int
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT count(*)::int FROM public.drop_blocks WHERE owner_user_id = auth.uid();
$$;

REVOKE ALL ON FUNCTION public.count_drop_blocks() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.count_drop_blocks() TO authenticated;

CREATE OR REPLACE FUNCTION public.clear_drop_blocks()
RETURNS void
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  DELETE FROM public.drop_blocks WHERE owner_user_id = auth.uid();
$$;

REVOKE ALL ON FUNCTION public.clear_drop_blocks() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.clear_drop_blocks() TO authenticated;

-- ===========================================================================
-- 7. Realtime (the phone's Inbox listens to its own drops)
-- ===========================================================================
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    BEGIN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.drops;
    EXCEPTION WHEN duplicate_object THEN
      NULL;
    END;
  END IF;
END $$;

-- ===========================================================================
-- 8. Flag and config
-- ===========================================================================
INSERT INTO public.feature_flags (flag_key, description, is_active, rollout_percentage)
VALUES (
  'nosus_drop_enabled',
  'NO SUS address and Drop inbox. Off for everyone except targeted testers until rollout is raised.',
  true,
  0
)
ON CONFLICT (flag_key) DO NOTHING;

INSERT INTO public.remote_configs (config_key, config_value, description) VALUES
  ('drop_max_bytes', '26214400'::jsonb, 'Largest file a visitor can drop (plain bytes).'),
  ('drop_rate_per_hour', '10'::jsonb, 'Drop attempts per network per hour, wrong door codes included.'),
  ('drop_door_rate_per_hour', '120'::jsonb, 'Address lookups per network per hour.'),
  ('drop_pending_max', '20'::jsonb, 'Most drops waiting in one inbox before the door says it is full.'),
  ('drop_ttl_hours', '24'::jsonb, 'How long an unanswered drop is kept before it is deleted.'),
  ('address_subdomain_live', 'false'::jsonb, 'Set true once <handle>.nosus.foo is served by the address worker.')
ON CONFLICT (config_key) DO NOTHING;

-- ===========================================================================
-- 9. Cleanup
-- ===========================================================================
-- Counters and parked handles by SQL; storage objects need the Storage
-- API, so cleanup-drops does those (same cron -> pg_net -> edge function
-- bridge as cleanup-burn-files, and the same vault secret).
SELECT cron.schedule(
  'drop-rate-sweep',
  '0 * * * *',
  $$
  DELETE FROM public.drop_rate_counters WHERE window_start < now() - interval '24 hours';
  DELETE FROM public.address_handle_releases WHERE released_at < now() - interval '30 days';
  $$
);

SELECT cron.schedule(
  'drops-cleanup-sweep',
  '*/10 * * * *',
  $$
  SELECT net.http_post(
    url := 'https://rxfnazmusofikwaggntb.supabase.co/functions/v1/cleanup-drops',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'burn_files_cron_secret')
    ),
    body := '{}'::jsonb
  );
  $$
);
