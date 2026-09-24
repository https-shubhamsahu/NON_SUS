-- Device keys: one P-256 ECDH public key per signed-in device.
-- Drop (visitors seal files to the owner's devices) and Group drops (the
-- group key is wrapped per member device) both seal to these keys.
-- The private half stays on the device: Android Keystore on API 31+
-- (kind 'keystore'), a Keystore-wrapped software key below that
-- ('software'), browser storage on the web app ('web').
--
-- The server stores public keys only. It could still swap a key it serves
-- (a key-directory attack); safety codes in the app are the check for that.

CREATE TABLE IF NOT EXISTS public.device_keys (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    device_id    TEXT NOT NULL
                 CONSTRAINT device_keys_device_id_chk CHECK (device_id ~ '^[A-Za-z0-9_-]{8,64}$'),
    public_key   TEXT NOT NULL
                 CONSTRAINT device_keys_public_key_chk CHECK (public_key ~ '^[A-Za-z0-9_-]{87}$'),
    kind         TEXT NOT NULL
                 CONSTRAINT device_keys_kind_chk CHECK (kind IN ('keystore', 'software', 'web')),
    label        TEXT CONSTRAINT device_keys_label_chk CHECK (label IS NULL OR char_length(label) <= 60),
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    revoked_at   TIMESTAMPTZ,
    UNIQUE (user_id, device_id)
);

CREATE INDEX IF NOT EXISTS device_keys_user_live_idx
    ON public.device_keys (user_id) WHERE revoked_at IS NULL;

ALTER TABLE public.device_keys ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS device_keys_owner_select ON public.device_keys;
CREATE POLICY device_keys_owner_select ON public.device_keys
    FOR SELECT TO authenticated
    USING (user_id = auth.uid());

-- Writes go through register_device_key / revoke_device_key only.

CREATE OR REPLACE FUNCTION public.register_device_key(
  p_device_id  text,
  p_public_key text,
  p_kind       text,
  p_label      text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_id  uuid;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not signed in' USING ERRCODE = '42501';
  END IF;
  -- Cap live devices per account so one account cannot flood group
  -- envelopes or Drop fan-out.
  IF (SELECT count(*) FROM public.device_keys
       WHERE user_id = v_uid AND revoked_at IS NULL AND device_id <> p_device_id) >= 10 THEN
    RAISE EXCEPTION 'too many devices' USING ERRCODE = 'P0001';
  END IF;
  INSERT INTO public.device_keys (user_id, device_id, public_key, kind, label)
  VALUES (v_uid, p_device_id, p_public_key, p_kind, p_label)
  ON CONFLICT (user_id, device_id) DO UPDATE
     SET public_key   = EXCLUDED.public_key,
         kind         = EXCLUDED.kind,
         label        = COALESCE(EXCLUDED.label, public.device_keys.label),
         last_seen_at = now(),
         -- A new key on the same device id is a reinstall: live again.
         revoked_at   = CASE WHEN public.device_keys.public_key = EXCLUDED.public_key
                             THEN public.device_keys.revoked_at ELSE NULL END
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.register_device_key(text, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.register_device_key(text, text, text, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.revoke_device_key(p_device_key_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  UPDATE public.device_keys
     SET revoked_at = now()
   WHERE id = p_device_key_id AND user_id = auth.uid() AND revoked_at IS NULL;
END;
$$;

REVOKE ALL ON FUNCTION public.revoke_device_key(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.revoke_device_key(uuid) TO authenticated;

-- Live device keys of everyone in a group, for members of that group only.
CREATE OR REPLACE FUNCTION public.group_member_device_keys(p_group_id text)
RETURNS TABLE (device_key_id uuid, user_id uuid, public_key text, kind text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT dk.id, dk.user_id, dk.public_key, dk.kind
    FROM public.device_keys dk
    JOIN public.study_group_members m
      ON m.user_id = dk.user_id AND m.group_id = p_group_id
   WHERE dk.revoked_at IS NULL
     AND EXISTS (
       SELECT 1 FROM public.study_group_members me
        WHERE me.group_id = p_group_id AND me.user_id = auth.uid()
     );
$$;

REVOKE ALL ON FUNCTION public.group_member_device_keys(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.group_member_device_keys(text) TO authenticated;
