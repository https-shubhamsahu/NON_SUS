-- Saved + Go. The borrowed computer never receives a Google token.
-- It joins a private Realtime topic only while a row for that session is
-- live. The 128-bit sid is stored as a hash; knowing the topic name is the
-- capability, and this row is what makes it expire.
--
-- Realtime caches channel authorization for an open connection, so ending a
-- row stops new joins immediately and stops the two already-connected
-- clients only once they leave. The clients leave on `end`.

CREATE TABLE IF NOT EXISTS public.go_sessions (
    sid_hash       TEXT PRIMARY KEY,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at     TIMESTAMPTZ NOT NULL,
    owner_user_id  UUID REFERENCES auth.users(id),
    state          TEXT NOT NULL DEFAULT 'open'
                   CONSTRAINT go_sessions_state_chk CHECK (state IN ('open', 'live', 'ended'))
);

ALTER TABLE public.go_sessions ENABLE ROW LEVEL SECURITY;
-- No policies. Clients never read or write this table. The functions below
-- are the only door, and the realtime policy calls go_topic_live().

CREATE TABLE IF NOT EXISTS public.go_session_open_counters (
    ip_hash      TEXT PRIMARY KEY,
    window_start TIMESTAMPTZ NOT NULL DEFAULT now(),
    open_count   INTEGER NOT NULL DEFAULT 0
);

ALTER TABLE public.go_session_open_counters ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.check_and_increment_go_open_rate(
  p_ip_hash text,
  p_limit int,
  p_window_minutes int
)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_row public.go_session_open_counters;
BEGIN
  SELECT * INTO v_row FROM public.go_session_open_counters WHERE ip_hash = p_ip_hash FOR UPDATE;
  IF NOT FOUND THEN
    INSERT INTO public.go_session_open_counters (ip_hash, open_count) VALUES (p_ip_hash, 1);
    RETURN true;
  END IF;
  IF v_row.window_start < now() - make_interval(mins => p_window_minutes) THEN
    UPDATE public.go_session_open_counters
       SET window_start = now(), open_count = 1
     WHERE ip_hash = p_ip_hash;
    RETURN true;
  END IF;
  IF v_row.open_count >= p_limit THEN
    RETURN false;
  END IF;
  UPDATE public.go_session_open_counters SET open_count = open_count + 1 WHERE ip_hash = p_ip_hash;
  RETURN true;
END;
$$;

REVOKE ALL ON FUNCTION public.check_and_increment_go_open_rate(text, int, int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.check_and_increment_go_open_rate(text, int, int) TO service_role;

-- Same rule as FeatureFlag.isEnabledFor: targeted users win, then 0 / 100,
-- then a sum of the uuid's character codes. UUID text is ASCII, so ascii()
-- matches Dart's code units.
CREATE OR REPLACE FUNCTION public.go_enabled_for(uid uuid)
RETURNS boolean
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  f public.feature_flags%ROWTYPE;
  s int := 0;
  t text;
  i int;
BEGIN
  IF uid IS NULL THEN RETURN false; END IF;
  SELECT * INTO f FROM public.feature_flags WHERE flag_key = 'nosus_address_enabled';
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

REVOKE ALL ON FUNCTION public.go_enabled_for(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.go_enabled_for(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.go_relay_enabled()
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT COALESCE((
    SELECT is_active FROM public.feature_flags WHERE flag_key = 'nosus_address_enabled'
  ), false);
$$;

REVOKE ALL ON FUNCTION public.go_relay_enabled() FROM PUBLIC;

CREATE OR REPLACE FUNCTION public.go_topic_live(p_topic text)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.go_relay_enabled()
     AND split_part(p_topic, ':', 1) = 'go'
     AND EXISTS (
       SELECT 1 FROM public.go_sessions s
        WHERE s.sid_hash = encode(extensions.digest(split_part(p_topic, ':', 2), 'sha256'), 'hex')
          AND s.expires_at > now()
          AND s.state <> 'ended'
     );
$$;

REVOKE ALL ON FUNCTION public.go_topic_live(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.go_topic_live(text) TO anon, authenticated;

CREATE OR REPLACE FUNCTION public._go_minutes(p_minutes int)
RETURNS int
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_max int;
BEGIN
  SELECT COALESCE((config_value::text)::int, 60) INTO v_max
    FROM public.remote_configs WHERE config_key = 'go_session_max_min';
  v_max := COALESCE(v_max, 60);
  RETURN LEAST(GREATEST(COALESCE(p_minutes, 15), 1), v_max);
END;
$$;

REVOKE ALL ON FUNCTION public._go_minutes(int) FROM PUBLIC;

CREATE OR REPLACE FUNCTION public.go_session_claim(p_sid text, p_minutes int)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_min int;
BEGIN
  IF auth.uid() IS NULL OR NOT public.go_enabled_for(auth.uid()) THEN
    RAISE EXCEPTION 'not enabled' USING ERRCODE = '42501';
  END IF;
  IF p_sid IS NULL OR length(p_sid) < 22 OR length(p_sid) > 32 THEN
    RAISE EXCEPTION 'bad sid' USING ERRCODE = '22023';
  END IF;
  v_min := public._go_minutes(p_minutes);
  UPDATE public.go_sessions
     SET owner_user_id = auth.uid(),
         state = 'live',
         expires_at = now() + make_interval(mins => v_min)
   WHERE sid_hash = encode(extensions.digest(p_sid, 'sha256'), 'hex')
     AND state = 'open'
     AND owner_user_id IS NULL
     AND expires_at > now();
  IF NOT FOUND THEN
    RAISE EXCEPTION 'session unavailable' USING ERRCODE = 'P0001';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.go_session_claim(text, int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.go_session_claim(text, int) TO authenticated;

CREATE OR REPLACE FUNCTION public.go_session_extend(p_sid text, p_minutes int)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_min int;
  v_max int;
BEGIN
  IF auth.uid() IS NULL OR NOT public.go_enabled_for(auth.uid()) THEN
    RAISE EXCEPTION 'not enabled' USING ERRCODE = '42501';
  END IF;
  v_min := public._go_minutes(p_minutes);
  SELECT COALESCE((config_value::text)::int, 60) INTO v_max
    FROM public.remote_configs WHERE config_key = 'go_session_max_min';
  v_max := COALESCE(v_max, 60);
  UPDATE public.go_sessions
     SET expires_at = LEAST(
       now() + make_interval(mins => v_min),
       created_at + make_interval(mins => v_max)
     )
   WHERE sid_hash = encode(extensions.digest(p_sid, 'sha256'), 'hex')
     AND owner_user_id = auth.uid()
     AND state = 'live'
     AND expires_at > now();
  IF NOT FOUND THEN
    RAISE EXCEPTION 'session unavailable' USING ERRCODE = 'P0001';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.go_session_extend(text, int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.go_session_extend(text, int) TO authenticated;

CREATE OR REPLACE FUNCTION public.go_session_end(p_sid text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not enabled' USING ERRCODE = '42501';
  END IF;
  UPDATE public.go_sessions
     SET state = 'ended', expires_at = now()
   WHERE sid_hash = encode(extensions.digest(p_sid, 'sha256'), 'hex')
     AND owner_user_id = auth.uid()
     AND state <> 'ended';
END;
$$;

REVOKE ALL ON FUNCTION public.go_session_end(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.go_session_end(text) TO authenticated;

INSERT INTO public.feature_flags (flag_key, description, is_active, rollout_percentage)
VALUES (
  'nosus_address_enabled',
  'Saved chat and borrowed-computer Go. Off for everyone except targeted testers until rollout is raised.',
  true,
  0
)
ON CONFLICT (flag_key) DO NOTHING;

INSERT INTO public.remote_configs (config_key, config_value, description) VALUES
  ('go_qr_ttl_s', '120'::jsonb, 'How long a QR keeps its session id before the desk rotates it.'),
  ('go_session_default_min', '15'::jsonb, 'Default borrowed-computer session length.'),
  ('go_session_max_min', '60'::jsonb, 'Longest a phone can extend a borrowed-computer session.'),
  ('go_idle_min', '10'::jsonb, 'End the desk session after this many minutes without input.'),
  ('go_file_max_bytes', '26214400'::jsonb, 'Largest single file a Go session will transfer.'),
  ('go_session_max_bytes', '209715200'::jsonb, 'Largest total transfer in one Go session.'),
  ('go_open_rate_per_hour', '30'::jsonb, 'How many Go sessions one network can open per window.')
ON CONFLICT (config_key) DO NOTHING;

-- Private broadcast. Anon is the desk; authenticated is the phone.
DROP POLICY IF EXISTS go_broadcast_select ON realtime.messages;
CREATE POLICY go_broadcast_select
  ON realtime.messages
  FOR SELECT
  TO anon, authenticated
  USING (
    realtime.topic() LIKE 'go:%'
    AND public.go_topic_live(realtime.topic())
  );

DROP POLICY IF EXISTS go_broadcast_insert ON realtime.messages;
CREATE POLICY go_broadcast_insert
  ON realtime.messages
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (
    realtime.topic() LIKE 'go:%'
    AND public.go_topic_live(realtime.topic())
  );
