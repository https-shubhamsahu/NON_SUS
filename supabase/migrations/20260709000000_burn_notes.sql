-- Migration: 20260709000000_burn_notes.sql
-- Zero-knowledge burn-on-read secrets exchange table

CREATE TABLE IF NOT EXISTS public.burn_notes (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ciphertext   TEXT NOT NULL,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at   TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '7 days')
);

-- RLS
ALTER TABLE public.burn_notes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can insert burn notes" ON public.burn_notes
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Anyone can read burn notes" ON public.burn_notes
  FOR SELECT USING (true);

CREATE POLICY "Anyone can delete burn notes" ON public.burn_notes
  FOR DELETE USING (true);

-- RPC for atomic read-and-delete (burn on read)
CREATE OR REPLACE FUNCTION read_and_burn_note(note_id UUID)
RETURNS TEXT AS $$
DECLARE
  retrieved_ciphertext TEXT;
BEGIN
  SELECT ciphertext INTO retrieved_ciphertext FROM public.burn_notes WHERE id = note_id;
  DELETE FROM public.burn_notes WHERE id = note_id;
  RETURN retrieved_ciphertext;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
