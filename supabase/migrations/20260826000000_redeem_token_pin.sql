-- Two-digit pairing pin + unguessable access token for redemption.
-- Legacy 8-character codes (pin_hash IS NULL) keep working via
-- claim_redemption_code. New codes store HMAC(token) in code_hash and
-- HMAC(pin) in pin_hash. The pin is NOT a lookup key.

ALTER TABLE public.burn_redemption_codes
  ADD COLUMN IF NOT EXISTS pin_hash TEXT;

CREATE OR REPLACE FUNCTION public.claim_redemption_token(
  p_token_hash text,
  p_pin_hash text
)
RETURNS public.burn_redemption_codes
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_row public.burn_redemption_codes;
BEGIN
  UPDATE public.burn_redemption_codes
     SET consumed_at = now()
   WHERE code_hash = p_token_hash
     AND pin_hash = p_pin_hash
     AND pin_hash IS NOT NULL
     AND consumed_at IS NULL
     AND expires_at > now()
  RETURNING * INTO v_row;

  RETURN v_row;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.claim_redemption_token(text, text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.claim_redemption_token(text, text) TO service_role;
