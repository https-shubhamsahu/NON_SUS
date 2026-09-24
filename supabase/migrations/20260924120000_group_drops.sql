-- Group drops: an end-to-end encrypted chat feed inside a study group.
--
-- What the relay (this database + the group-drops bucket) holds:
--   * group_key_envelopes: the 32-byte group key sealed to each member
--     device's public key (device_keys). Only that device can open it.
--   * group_messages.body: AES-256-GCM ciphertext under the group key.
--   * group-drops objects: file ciphertext under a per-file key that only
--     travels inside an encrypted message body.
-- What the relay can still see: who is in the group, which device keys it
-- serves, who sent a message and when, message and file sizes. It also
-- serves the device keys members seal to, so it could swap one (a key
-- directory attack). Safety codes in the app are the check for that.
--
-- Retention: messages are purged after remote_configs.group_drops_retention_days
-- (30) and files after group_drops_file_retention_days (7), by pg_cron.

-- ===========================================================================
-- 1. Kill switch + config
-- ===========================================================================
INSERT INTO public.feature_flags (flag_key, description, is_active, rollout_percentage)
VALUES (
  'nosus_group_drops_enabled',
  'Group drops: end-to-end encrypted chat tab in groups. is_active false also stops new messages and uploads server-side.',
  true,
  0
)
ON CONFLICT (flag_key) DO NOTHING;

INSERT INTO public.remote_configs (config_key, config_value, description) VALUES
  ('group_drops_retention_days', '30'::jsonb, 'Group drops: days before the relay deletes a message.'),
  ('group_drops_file_retention_days', '7'::jsonb, 'Group drops: days before the relay deletes an attachment.'),
  ('group_drops_file_max_bytes', '26214400'::jsonb, 'Group drops: largest attachment before encryption (25 MB).')
ON CONFLICT (config_key) DO NOTHING;

CREATE OR REPLACE FUNCTION public.group_drops_relay_enabled()
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT COALESCE((
    SELECT is_active FROM public.feature_flags WHERE flag_key = 'nosus_group_drops_enabled'
  ), false);
$$;

REVOKE ALL ON FUNCTION public.group_drops_relay_enabled() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.group_drops_relay_enabled() TO authenticated;

-- ===========================================================================
-- 2. Key epochs
-- ===========================================================================
-- A new epoch means a new group key. Started when the first member opens the
-- chat, and again whenever someone is removed, banned, leaves, or revokes a
-- device, so the new key is only wrapped for who is left.
CREATE TABLE IF NOT EXISTS public.group_key_epochs (
    group_id   TEXT NOT NULL REFERENCES public.study_groups(id) ON DELETE CASCADE,
    epoch      INTEGER NOT NULL CONSTRAINT group_key_epochs_epoch_chk CHECK (epoch >= 1),
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (group_id, epoch)
);

ALTER TABLE public.group_key_epochs ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.group_key_epochs FROM anon, authenticated;
GRANT SELECT ON TABLE public.group_key_epochs TO authenticated;

DROP POLICY IF EXISTS group_key_epochs_member_select ON public.group_key_epochs;
CREATE POLICY group_key_epochs_member_select ON public.group_key_epochs
    FOR SELECT TO authenticated
    USING (public.is_group_member(group_id));

-- Writes only through start_group_key_epoch().

-- ===========================================================================
-- 3. Key envelopes
-- ===========================================================================
-- box = sealBox(device public key, context 'group-key:<group_id>:<epoch>',
-- plain = 32-byte group key). Always 126 bytes = 168 b64url characters.
CREATE TABLE IF NOT EXISTS public.group_key_envelopes (
    group_id      TEXT NOT NULL,
    epoch         INTEGER NOT NULL,
    device_key_id UUID NOT NULL REFERENCES public.device_keys(id) ON DELETE CASCADE,
    box           TEXT NOT NULL
                  CONSTRAINT group_key_envelopes_box_chk CHECK (box ~ '^[A-Za-z0-9_-]{168}$'),
    created_by    UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (group_id, epoch, device_key_id),
    FOREIGN KEY (group_id, epoch)
      REFERENCES public.group_key_epochs(group_id, epoch) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS group_key_envelopes_device_idx
    ON public.group_key_envelopes (device_key_id);

ALTER TABLE public.group_key_envelopes ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.group_key_envelopes FROM anon, authenticated;
GRANT SELECT, DELETE ON TABLE public.group_key_envelopes TO authenticated;

-- A device reads only its own envelopes, and only while its owner is a member.
DROP POLICY IF EXISTS group_key_envelopes_own_select ON public.group_key_envelopes;
CREATE POLICY group_key_envelopes_own_select ON public.group_key_envelopes
    FOR SELECT TO authenticated
    USING (
      public.is_group_member(group_id)
      AND EXISTS (
        SELECT 1 FROM public.device_keys dk
         WHERE dk.id = device_key_id AND dk.user_id = (SELECT auth.uid())
      )
    );

-- A device may drop its own envelope when it does not open (a member wrapped
-- garbage for it). Another member then wraps the key again.
DROP POLICY IF EXISTS group_key_envelopes_own_delete ON public.group_key_envelopes;
CREATE POLICY group_key_envelopes_own_delete ON public.group_key_envelopes
    FOR DELETE TO authenticated
    USING (
      EXISTS (
        SELECT 1 FROM public.device_keys dk
         WHERE dk.id = device_key_id AND dk.user_id = (SELECT auth.uid())
      )
    );

-- Inserts only through put_group_key_envelopes().

-- ===========================================================================
-- 4. Messages
-- ===========================================================================
-- id is generated on the client because it is inside the AAD:
--   aad = utf8('nosus-group/1:<group_id>:<epoch>:<id>')
-- body = b64url(nonce(12) ‖ AES-256-GCM(json) ‖ tag(16)).
CREATE TABLE IF NOT EXISTS public.group_messages (
    id              UUID PRIMARY KEY,
    group_id        TEXT NOT NULL,
    epoch           INTEGER NOT NULL,
    sender_user_id  UUID NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
    kind            TEXT NOT NULL
                    CONSTRAINT group_messages_kind_chk CHECK (kind IN ('text', 'file')),
    body            TEXT NOT NULL
                    CONSTRAINT group_messages_body_chk
                    CHECK (body ~ '^[A-Za-z0-9_-]+$' AND char_length(body) BETWEEN 38 AND 32768),
    attachment_path TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    FOREIGN KEY (group_id, epoch)
      REFERENCES public.group_key_epochs(group_id, epoch) ON DELETE CASCADE,
    CONSTRAINT group_messages_attachment_chk CHECK (
      (kind = 'text' AND attachment_path IS NULL)
      OR (kind = 'file' AND attachment_path = group_id || '/' || id::text)
    )
);

CREATE INDEX IF NOT EXISTS group_messages_group_created_idx
    ON public.group_messages (group_id, created_at DESC);
CREATE INDEX IF NOT EXISTS group_messages_created_idx
    ON public.group_messages (created_at);

ALTER TABLE public.group_messages ENABLE ROW LEVEL SECURITY;

-- sender_user_id and created_at always come from their defaults.
REVOKE ALL ON TABLE public.group_messages FROM anon, authenticated;
GRANT SELECT, DELETE ON TABLE public.group_messages TO authenticated;
GRANT INSERT (id, group_id, epoch, kind, body, attachment_path)
    ON TABLE public.group_messages TO authenticated;

CREATE OR REPLACE FUNCTION public.group_key_current_epoch(p_group_id text)
RETURNS integer
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT max(e.epoch)
    FROM public.group_key_epochs e
   WHERE e.group_id = p_group_id
     AND public.is_group_member(p_group_id);
$$;

REVOKE ALL ON FUNCTION public.group_key_current_epoch(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.group_key_current_epoch(text) TO authenticated;

DROP POLICY IF EXISTS group_messages_member_select ON public.group_messages;
CREATE POLICY group_messages_member_select ON public.group_messages
    FOR SELECT TO authenticated
    USING (public.is_group_member(group_id));

-- Sender is self, sender is a member, and the message is under the current
-- key. A message under an old epoch would be readable by whoever was removed.
DROP POLICY IF EXISTS group_messages_member_insert ON public.group_messages;
CREATE POLICY group_messages_member_insert ON public.group_messages
    FOR INSERT TO authenticated
    WITH CHECK (
      sender_user_id = (SELECT auth.uid())
      AND public.group_drops_relay_enabled()
      AND public.is_group_member(group_id)
      AND epoch = public.group_key_current_epoch(group_id)
    );

-- No UPDATE policy: a message cannot be edited on the relay.
DROP POLICY IF EXISTS group_messages_sender_delete ON public.group_messages;
CREATE POLICY group_messages_sender_delete ON public.group_messages
    FOR DELETE TO authenticated
    USING (sender_user_id = (SELECT auth.uid()));

-- Realtime. RLS filters inserts to members. Delete events carry only the
-- primary key (a random uuid) and are not RLS-filtered by Realtime.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    BEGIN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.group_messages;
    EXCEPTION WHEN duplicate_object THEN
      NULL;
    END;
    -- A waiting device learns its envelope arrived without polling.
    BEGIN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.group_key_envelopes;
    EXCEPTION WHEN duplicate_object THEN
      NULL;
    END;
  END IF;
END $$;

-- ===========================================================================
-- 5. Key RPCs
-- ===========================================================================
CREATE OR REPLACE FUNCTION public.start_group_key_epoch(
  p_group_id text,
  p_expected_current integer DEFAULT NULL
)
RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_uid  uuid := auth.uid();
  v_cur  integer;
  v_next integer;
BEGIN
  IF v_uid IS NULL OR NOT public.is_group_member(p_group_id) THEN
    RAISE EXCEPTION 'not a member' USING ERRCODE = '42501';
  END IF;
  IF NOT public.group_drops_relay_enabled() THEN
    RAISE EXCEPTION 'group drops are off' USING ERRCODE = '42501';
  END IF;
  -- One epoch at a time per group.
  PERFORM pg_advisory_xact_lock(hashtextextended('group_key_epoch:' || p_group_id, 0));
  SELECT COALESCE(max(epoch), 0) INTO v_cur
    FROM public.group_key_epochs WHERE group_id = p_group_id;
  -- Compare-and-set: two members opening an empty chat at once must not
  -- both start a key. The loser reads the winner's epoch instead.
  IF p_expected_current IS NOT NULL AND v_cur <> p_expected_current THEN
    RETURN NULL;
  END IF;
  IF (SELECT count(*) FROM public.group_key_epochs
       WHERE group_id = p_group_id AND created_at > now() - interval '1 day') >= 50 THEN
    RAISE EXCEPTION 'too many key changes today' USING ERRCODE = 'P0001';
  END IF;
  v_next := v_cur + 1;
  INSERT INTO public.group_key_epochs (group_id, epoch, created_by)
  VALUES (p_group_id, v_next, v_uid);
  RETURN v_next;
END;
$$;

REVOKE ALL ON FUNCTION public.start_group_key_epoch(text, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.start_group_key_epoch(text, integer) TO authenticated;

-- p_envelopes = [{"device_key_id": uuid, "box": b64url}, ...]. Only the
-- current epoch, only live devices of current members. Existing envelopes
-- are never overwritten. Returns how many were stored.
CREATE OR REPLACE FUNCTION public.put_group_key_envelopes(
  p_group_id text,
  p_epoch integer,
  p_envelopes jsonb
)
RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_uid   uuid := auth.uid();
  v_cur   integer;
  v_count integer;
BEGIN
  IF v_uid IS NULL OR NOT public.is_group_member(p_group_id) THEN
    RAISE EXCEPTION 'not a member' USING ERRCODE = '42501';
  END IF;
  IF p_envelopes IS NULL OR jsonb_typeof(p_envelopes) <> 'array'
     OR jsonb_array_length(p_envelopes) > 500 THEN
    RAISE EXCEPTION 'bad envelopes' USING ERRCODE = '22023';
  END IF;
  SELECT max(epoch) INTO v_cur FROM public.group_key_epochs WHERE group_id = p_group_id;
  IF v_cur IS NULL OR p_epoch IS DISTINCT FROM v_cur THEN
    RAISE EXCEPTION 'stale epoch' USING ERRCODE = 'P0001';
  END IF;

  INSERT INTO public.group_key_envelopes (group_id, epoch, device_key_id, box, created_by)
  SELECT p_group_id, p_epoch, dk.id, e.value->>'box', v_uid
    FROM jsonb_array_elements(p_envelopes) e
    JOIN public.device_keys dk
      ON dk.id = (e.value->>'device_key_id')::uuid
     AND dk.revoked_at IS NULL
    JOIN public.study_group_members m
      ON m.group_id = p_group_id AND m.user_id = dk.user_id
  ON CONFLICT (group_id, epoch, device_key_id) DO NOTHING;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

REVOKE ALL ON FUNCTION public.put_group_key_envelopes(text, integer, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.put_group_key_envelopes(text, integer, jsonb) TO authenticated;

-- Live member devices with no envelope at p_epoch: new members, new devices.
-- A member who holds the key wraps it for these ("healing").
CREATE OR REPLACE FUNCTION public.group_key_devices_missing(p_group_id text, p_epoch integer)
RETURNS TABLE (device_key_id uuid, user_id uuid, public_key text, kind text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT dk.id, dk.user_id, dk.public_key, dk.kind
    FROM public.device_keys dk
    JOIN public.study_group_members m
      ON m.user_id = dk.user_id AND m.group_id = p_group_id
   WHERE dk.revoked_at IS NULL
     AND public.is_group_member(p_group_id)
     AND NOT EXISTS (
       SELECT 1 FROM public.group_key_envelopes env
        WHERE env.group_id = p_group_id
          AND env.epoch = p_epoch
          AND env.device_key_id = dk.id
     );
$$;

REVOKE ALL ON FUNCTION public.group_key_devices_missing(text, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.group_key_devices_missing(text, integer) TO authenticated;

-- True when the current key is held by a device that should no longer have
-- it: its owner left or was removed, or the device key was revoked. The
-- next member to open the chat starts a new epoch. This is the backstop for
-- leaving (which no admin sees) and for a rotation that failed client-side.
CREATE OR REPLACE FUNCTION public.group_key_needs_rotation(p_group_id text)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.is_group_member(p_group_id) AND EXISTS (
    SELECT 1
      FROM public.group_key_envelopes env
      JOIN public.device_keys dk ON dk.id = env.device_key_id
     WHERE env.group_id = p_group_id
       AND env.epoch = (SELECT max(epoch) FROM public.group_key_epochs WHERE group_id = p_group_id)
       AND (
         dk.revoked_at IS NOT NULL
         OR NOT EXISTS (
           SELECT 1 FROM public.study_group_members m
            WHERE m.group_id = p_group_id AND m.user_id = dk.user_id
         )
       )
  );
$$;

REVOKE ALL ON FUNCTION public.group_key_needs_rotation(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.group_key_needs_rotation(text) TO authenticated;

-- ===========================================================================
-- 6. Attachments bucket
-- ===========================================================================
-- Objects are ciphertext only, so the one allowed type is octet-stream.
-- Limit = 25 MB plaintext + 1 KB for the 28-byte seal overhead.
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('group-drops', 'group-drops', false, 26215424, ARRAY['application/octet-stream'])
ON CONFLICT (id) DO UPDATE
SET public = false,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Path is exactly <group_id>/<message uuid>.
DROP POLICY IF EXISTS "group-drops: member upload" ON storage.objects;
CREATE POLICY "group-drops: member upload" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (
      bucket_id = 'group-drops'
      AND public.group_drops_relay_enabled()
      AND array_length(storage.foldername(name), 1) = 1
      AND name ~ '^[^/]+/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      AND public.is_group_member((storage.foldername(name))[1])
    );

DROP POLICY IF EXISTS "group-drops: member download" ON storage.objects;
CREATE POLICY "group-drops: member download" ON storage.objects
    FOR SELECT TO authenticated
    USING (
      bucket_id = 'group-drops'
      AND public.is_group_member((storage.foldername(name))[1])
    );

DROP POLICY IF EXISTS "group-drops: uploader delete" ON storage.objects;
CREATE POLICY "group-drops: uploader delete" ON storage.objects
    FOR DELETE TO authenticated
    USING (
      bucket_id = 'group-drops'
      AND owner_id::text = (SELECT auth.uid())::text
    );

-- No UPDATE policy: an uploaded attachment is never replaced.

-- ===========================================================================
-- 7. Retention
-- ===========================================================================
CREATE OR REPLACE FUNCTION public.purge_group_drops()
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_days integer;
BEGIN
  SELECT (config_value::text)::integer INTO v_days
    FROM public.remote_configs WHERE config_key = 'group_drops_retention_days';
  v_days := GREATEST(COALESCE(v_days, 30), 1);

  DELETE FROM public.group_messages
   WHERE created_at < now() - make_interval(days => v_days);

  -- Old keys nobody needs: not current, no messages left under them.
  DELETE FROM public.group_key_epochs e
   WHERE e.created_at < now() - make_interval(days => v_days)
     AND e.epoch < (SELECT max(x.epoch) FROM public.group_key_epochs x WHERE x.group_id = e.group_id)
     AND NOT EXISTS (
       SELECT 1 FROM public.group_messages msg
        WHERE msg.group_id = e.group_id AND msg.epoch = e.epoch
     );
END;
$$;

REVOKE ALL ON FUNCTION public.purge_group_drops() FROM PUBLIC, anon, authenticated;

-- Attachment names past the file retention window, for cleanup-group-drops.
CREATE OR REPLACE FUNCTION public.group_drops_expired_objects(p_limit integer DEFAULT 1000)
RETURNS TABLE (name text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_days integer;
BEGIN
  SELECT (config_value::text)::integer INTO v_days
    FROM public.remote_configs WHERE config_key = 'group_drops_file_retention_days';
  v_days := GREATEST(COALESCE(v_days, 7), 1);
  RETURN QUERY
    SELECT o.name::text
      FROM storage.objects o
     WHERE o.bucket_id = 'group-drops'
       AND o.created_at < now() - make_interval(days => v_days)
     ORDER BY o.created_at
     LIMIT LEAST(GREATEST(COALESCE(p_limit, 1000), 1), 5000);
END;
$$;

REVOKE ALL ON FUNCTION public.group_drops_expired_objects(integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.group_drops_expired_objects(integer) TO service_role;

-- cron.schedule upserts by job name, so re-running is safe.
SELECT cron.schedule(
  'group-drops-message-purge',
  '17 * * * *',
  $$SELECT public.purge_group_drops()$$
);

-- Storage objects need the Storage API to delete, so cron calls the edge
-- function (same cron -> pg_net -> function bridge as burn-files-cleanup-sweep,
-- and the same vault secret, so no new secret is needed).
SELECT cron.schedule(
  'group-drops-files-cleanup',
  '23 * * * *',
  $$
  SELECT net.http_post(
    url := 'https://rxfnazmusofikwaggntb.supabase.co/functions/v1/cleanup-group-drops',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'burn_files_cron_secret')
    ),
    body := '{}'::jsonb
  );
  $$
);
