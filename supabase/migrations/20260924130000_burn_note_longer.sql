-- Burn Notes: raise the note limit from 10,000 to 50,000 characters.
--
-- Ciphertext is base64 of AES-CTR with PKCS7 padding. The editors count
-- UTF-16 code units; one unit is at most 3 UTF-8 bytes, so 50,000 units is
-- at most 150,016 bytes → 200,024 base64 characters. 204,800 (200 KiB)
-- leaves headroom and is still a hard cap on row size.

ALTER TABLE public.burn_notes
  DROP CONSTRAINT IF EXISTS burn_notes_ciphertext_size;

ALTER TABLE public.burn_notes
  ADD CONSTRAINT burn_notes_ciphertext_size
  CHECK (length(ciphertext) <= 204800);
