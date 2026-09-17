-- Recovered 2026-09-18 from the production migration history: this was applied
-- to the live project on 2026-09-15 07:56 (the same deploy as the
-- document-intelligence / document-insights edge functions) but the file never
-- reached main, which blocked `supabase db push`. Content is verbatim.
--
-- Per-account hourly budgets for the optional services. Server-only: the table
-- and the function are granted to service_role only, so an edge function
-- consumes a budget and clients cannot read or call it.

CREATE TABLE IF NOT EXISTS public.optional_service_usage (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  service text NOT NULL CHECK (service IN ('document-intelligence', 'play-integrity')),
  window_start timestamptz NOT NULL,
  requests integer NOT NULL CHECK (requests > 0),
  PRIMARY KEY (user_id, service)
);
ALTER TABLE public.optional_service_usage ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.optional_service_usage FROM PUBLIC, anon, authenticated;
GRANT ALL ON public.optional_service_usage TO service_role;

-- Server-only, atomic per-account hourly budgets. No content or tokens stored.
CREATE OR REPLACE FUNCTION public.consume_optional_service_budget(p_user_id uuid, p_service text)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  used integer;
  budget integer;
BEGIN
  IF p_service NOT IN ('document-intelligence', 'play-integrity') THEN
    RAISE EXCEPTION 'Unknown service';
  END IF;
  budget := CASE WHEN p_service = 'document-intelligence' THEN 20 ELSE 10 END;
  INSERT INTO public.optional_service_usage AS usage(user_id, service, window_start, requests)
  VALUES (p_user_id, p_service, date_trunc('hour', now()), 1)
  ON CONFLICT (user_id, service) DO UPDATE
    SET window_start = EXCLUDED.window_start,
        requests = CASE WHEN usage.window_start = EXCLUDED.window_start
          THEN usage.requests + 1 ELSE 1 END
    WHERE usage.window_start <> EXCLUDED.window_start OR usage.requests < budget
  RETURNING requests INTO used;
  RETURN used IS NOT NULL;
END;
$$;
REVOKE ALL ON FUNCTION public.consume_optional_service_budget(uuid, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.consume_optional_service_budget(uuid, text) TO service_role;
