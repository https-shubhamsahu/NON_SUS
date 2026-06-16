-- NO SUS — Remaining Tables + RLS (idempotent)
-- Runs AFTER 20260611000000_phase_1_schema.sql (creates profiles, study_groups, study_group_members)
-- Runs BEFORE 20260613000000_storage_setup.sql (creates secure-files bucket + storage RLS)
-- =============================================================================
-- This migration:
--   1. Augments profiles with display_name + avatar columns
--   2. Adds joined_at to study_group_members
--   3. Creates secure_files, audit_logs, focus_logs, user_notes
--   4. Enables RLS + correct member-scoped policies on every new table
--   5. Registers tables with supabase_realtime publication
--   6. Drops legacy encryption key columns (must NEVER be in the DB)
-- =============================================================================

-- ─── EXTENSION ────────────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ─── 1. AUGMENT PROFILES ──────────────────────────────────────────────────────
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS display_name text,
  ADD COLUMN IF NOT EXISTS avatar_color_start text DEFAULT 'FF0072FF',
  ADD COLUMN IF NOT EXISTS avatar_color_end text DEFAULT 'FF00F2FE';

-- ─── 2. AUGMENT STUDY_GROUP_MEMBERS ───────────────────────────────────────────
ALTER TABLE public.study_group_members
  ADD COLUMN IF NOT EXISTS joined_at timestamptz NOT NULL DEFAULT now();

-- ─── 3. SECURE FILES ──────────────────────────────────────────────────────────
-- NOTE: encryption_key_base64 and encryption_iv_base64 are intentionally omitted.
-- Keys must NEVER be stored in the database — only in device-local SecureKeyStore.
CREATE TABLE IF NOT EXISTS public.secure_files (
  id                    text        PRIMARY KEY,
  group_id              text        REFERENCES public.study_groups(id) ON DELETE CASCADE,
  name                  text        NOT NULL,
  type                  text        NOT NULL DEFAULT 'pdf',
  uploaded_by_name      text        NOT NULL DEFAULT 'Anonymous',
  uploaded_by_initials  text        NOT NULL DEFAULT 'AN',
  size_bytes            integer     NOT NULL DEFAULT 0,
  is_watermarked        boolean     DEFAULT true,
  is_pinned             boolean     DEFAULT false,
  security_status       text        DEFAULT 'secured',
  uploaded_at           timestamptz NOT NULL DEFAULT now(),
  -- Only one of storage_path or gdrive_file_id should be populated:
  storage_path          text,                    -- Supabase Storage object name
  gdrive_file_id        text,                    -- Google Drive file ID (proxied)
  -- Encryption metadata (key ID, not the key itself)
  key_id                text                      -- Logical key identifier for rotation
);

ALTER TABLE public.secure_files ENABLE ROW LEVEL SECURITY;

-- Select: only group members can view file metadata.
CREATE POLICY "files: group member select"
  ON public.secure_files FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.study_group_members m
      WHERE m.group_id = secure_files.group_id AND m.user_id = auth.uid()
    )
  );

-- Insert: any group member can upload files.
CREATE POLICY "files: group member insert"
  ON public.secure_files FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.study_group_members m
      WHERE m.group_id = secure_files.group_id AND m.user_id = auth.uid()
    )
  );

-- Update: any group member can update (pin/unpin/rename).
CREATE POLICY "files: group member update"
  ON public.secure_files FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.study_group_members m
      WHERE m.group_id = secure_files.group_id AND m.user_id = auth.uid()
    )
  );

-- Delete: only group admins can delete files.
CREATE POLICY "files: admin delete"
  ON public.secure_files FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.study_group_members m
      WHERE m.group_id = secure_files.group_id AND m.user_id = auth.uid() AND m.is_admin = true
    )
  );

-- ─── 4. AUDIT LOGS ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.audit_logs (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  event      text        NOT NULL,
  status     text        NOT NULL DEFAULT 'INFO',
  user_id    uuid        REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- Any authenticated user can insert audit events.
CREATE POLICY "audit: authenticated insert"
  ON public.audit_logs FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

-- Any authenticated user can read the shared security ledger.
CREATE POLICY "audit: authenticated select"
  ON public.audit_logs FOR SELECT
  USING (auth.role() = 'authenticated');

-- No one can update or delete audit logs (immutable ledger).

-- ─── 5. FOCUS LOGS ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.focus_logs (
  id            uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       uuid    NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  date          date    NOT NULL,
  focus_minutes integer NOT NULL DEFAULT 0,
  UNIQUE (user_id, date)
);

ALTER TABLE public.focus_logs ENABLE ROW LEVEL SECURITY;

-- Users can only see and manage their own focus logs.
CREATE POLICY "focus: self all"
  ON public.focus_logs FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- ─── 6. USER NOTES ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.user_notes (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid        NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  note_text   text        NOT NULL DEFAULT '',
  updated_at  timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.user_notes ENABLE ROW LEVEL SECURITY;

-- Users can only see and manage their own note.
CREATE POLICY "notes: self all"
  ON public.user_notes FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- ─── 7. REALTIME PUBLICATION ──────────────────────────────────────────────────
-- Idempotently register each table with the realtime publication.
DO $pub$
DECLARE
  tbl text;
BEGIN
  FOREACH tbl IN ARRAY ARRAY['study_groups', 'study_group_members', 'secure_files', 'audit_logs', 'focus_logs', 'user_notes']
  LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication p
      JOIN pg_publication_rel pr ON pr.prpubid = p.oid
      JOIN pg_class c ON c.oid = pr.prrelid
      WHERE p.pubname = 'supabase_realtime' AND c.relname = tbl
    ) THEN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', tbl);
    END IF;
  END LOOP;
END $pub$;

-- ─── 8. LEGACY CLEANUP ────────────────────────────────────────────────────────
-- Drop encryption key columns if they somehow exist from a previous schema.
-- Keys must NEVER be stored in the database.
ALTER TABLE public.secure_files DROP COLUMN IF EXISTS encryption_key_base64;
ALTER TABLE public.secure_files DROP COLUMN IF EXISTS encryption_iv_base64;
