-- Keep internal Go-session helpers out of the Data API. PostgreSQL grants
-- EXECUTE to PUBLIC for new functions by default; revoking from PUBLIC alone
-- did not remove the inherited anon/authenticated grants on the hosted
-- project. These helpers are called only by SECURITY DEFINER bodies or Edge
-- Functions using service_role.
REVOKE ALL ON FUNCTION public._go_minutes(integer) FROM anon, authenticated;
REVOKE ALL ON FUNCTION public.check_and_increment_go_open_rate(text, integer, integer)
  FROM anon, authenticated;
REVOKE ALL ON FUNCTION public.go_enabled_for(uuid) FROM anon, authenticated;
REVOKE ALL ON FUNCTION public.go_relay_enabled() FROM anon, authenticated;

-- The phone calls these three RPCs directly after sign-in. They must remain
-- executable by authenticated users, but a borrowed computer or anonymous
-- browser must never be able to claim, extend, or terminate a session.
REVOKE ALL ON FUNCTION public.go_session_claim(text, integer) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.go_session_claim(text, integer) TO authenticated;

REVOKE ALL ON FUNCTION public.go_session_extend(text, integer) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.go_session_extend(text, integer) TO authenticated;

REVOKE ALL ON FUNCTION public.go_session_end(text) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.go_session_end(text) TO authenticated;

-- go_topic_live intentionally remains executable by anon and authenticated:
-- the Realtime RLS policy evaluates it as the connecting role. read_and_burn_note
-- and get_invite_details likewise remain public product entry points.
