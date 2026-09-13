-- Pairing links must not make Burn keys readable to the service role/database.
-- Legacy redemption rows keep their original key_hex/iv_hex values and claim
-- path. New rows carry only a client-side encrypted envelope.

ALTER TABLE public.burn_redemption_codes
  ADD COLUMN IF NOT EXISTS key_material_ciphertext TEXT,
  ADD COLUMN IF NOT EXISTS key_material_iv_hex TEXT;

ALTER TABLE public.burn_redemption_codes
  ALTER COLUMN key_hex DROP NOT NULL,
  ALTER COLUMN iv_hex DROP NOT NULL;
