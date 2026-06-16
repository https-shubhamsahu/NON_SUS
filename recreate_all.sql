-- =============================================================================
-- NO SUS — Complete Database Re-creation Script
-- WARNING: Running this script will DELETE all existing database tables,
-- metadata, files, and users. It starts with a completely clean slate.
-- Run this script inside: Supabase Dashboard → SQL Editor → New Query → Run
-- =============================================================================

-- 1. Drop existing triggers, functions, and tables
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users CASCADE;
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;

DROP TABLE IF EXISTS public.user_notes CASCADE;
DROP TABLE IF EXISTS public.focus_logs CASCADE;
DROP TABLE IF EXISTS public.audit_logs CASCADE;
DROP TABLE IF EXISTS public.secure_files CASCADE;
DROP TABLE IF EXISTS public.study_group_members CASCADE;
DROP TABLE IF EXISTS public.study_groups CASCADE;
DROP TABLE IF EXISTS public.profiles CASCADE;

-- 2. Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 3. Create PROFILES table
CREATE TABLE public.profiles (
  id                  uuid        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email               text,
  display_name        text,
  avatar_color_start  text        DEFAULT 'FF0072FF',
  avatar_color_end    text        DEFAULT 'FF00F2FE',
  onboarding_completed BOOLEAN    NOT NULL DEFAULT false,
  updated_at          timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Allow all policy for development MVP mode
CREATE POLICY "Allow all" ON public.profiles FOR ALL USING (true) WITH CHECK (true);

-- 4. Create STUDY GROUPS table
CREATE TABLE public.study_groups (
  id                    text        PRIMARY KEY,
  name                  text        NOT NULL,
  description           text        DEFAULT '',
  security_level        text        NOT NULL DEFAULT 'encrypted',
  is_watermark_enabled  boolean     DEFAULT true,
  invite_code           text,
  file_count            integer     DEFAULT 0,
  last_activity         timestamptz DEFAULT now(),
  created_at            timestamptz NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.study_groups ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all" ON public.study_groups FOR ALL USING (true) WITH CHECK (true);

-- Register with Realtime
DO $pub$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication p
    JOIN pg_publication_rel pr ON pr.prpubid = p.oid
    JOIN pg_class c ON c.oid = pr.prrelid
    WHERE p.pubname = 'supabase_realtime' AND c.relname = 'study_groups'
  ) THEN
    EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.study_groups';
  END IF;
END $pub$;

CREATE TABLE public.study_group_members (
  group_id  text    NOT NULL REFERENCES public.study_groups(id) ON DELETE CASCADE,
  user_id   uuid    NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  is_admin  boolean NOT NULL DEFAULT false,
  joined_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (group_id, user_id)
);

-- Enable RLS
ALTER TABLE public.study_group_members ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all" ON public.study_group_members FOR ALL USING (true) WITH CHECK (true);

-- Register with Realtime
DO $pub$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication p
    JOIN pg_publication_rel pr ON pr.prpubid = p.oid
    JOIN pg_class c ON c.oid = pr.prrelid
    WHERE p.pubname = 'supabase_realtime' AND c.relname = 'study_group_members'
  ) THEN
    EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.study_group_members';
  END IF;
END $pub$;

-- 6. Create SECURE FILES table
CREATE TABLE public.secure_files (
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
  encryption_key_base64 text,
  encryption_iv_base64  text,
  uploaded_at           timestamptz NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.secure_files ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all" ON public.secure_files FOR ALL USING (true) WITH CHECK (true);

-- Register with Realtime
DO $pub$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication p
    JOIN pg_publication_rel pr ON pr.prpubid = p.oid
    JOIN pg_class c ON c.oid = pr.prrelid
    WHERE p.pubname = 'supabase_realtime' AND c.relname = 'secure_files'
  ) THEN
    EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.secure_files';
  END IF;
END $pub$;

-- 7. Create AUDIT LOGS table
CREATE TABLE public.audit_logs (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  event      text        NOT NULL,
  status     text        NOT NULL DEFAULT 'INFO',
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all" ON public.audit_logs FOR ALL USING (true) WITH CHECK (true);

-- Register with Realtime
DO $pub$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication p
    JOIN pg_publication_rel pr ON pr.prpubid = p.oid
    JOIN pg_class c ON c.oid = pr.prrelid
    WHERE p.pubname = 'supabase_realtime' AND c.relname = 'audit_logs'
  ) THEN
    EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.audit_logs';
  END IF;
END $pub$;

-- 8. Create FOCUS LOGS table
CREATE TABLE public.focus_logs (
  id            uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       uuid    NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  date          date    NOT NULL,
  focus_minutes integer NOT NULL DEFAULT 0,
  UNIQUE (user_id, date)
);

-- Enable RLS
ALTER TABLE public.focus_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all" ON public.focus_logs FOR ALL USING (true) WITH CHECK (true);

-- 9. Create USER NOTES table
CREATE TABLE public.user_notes (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid        NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  note_text   text        NOT NULL DEFAULT '',
  updated_at  timestamptz NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.user_notes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all" ON public.user_notes FOR ALL USING (true) WITH CHECK (true);

-- 10. Create trigger function to auto-pick first 7 characters of email as display_name for new signups
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    default_name TEXT;
BEGIN
    IF new.email IS NOT NULL THEN
        default_name := SUBSTRING(new.email FROM 1 FOR 7);
    ELSE
        default_name := 'User_' || SUBSTRING(new.id::text FROM 1 FOR 7);
    END IF;

    INSERT INTO public.profiles (id, email, display_name, avatar_color_start, avatar_color_end, onboarding_completed)
    VALUES (
        new.id, 
        new.email,
        default_name,
        'FF0072FF',
        'FF00F2FE',
        false
    )
    ON CONFLICT (id) DO UPDATE
    SET 
        email = EXCLUDED.email,
        display_name = COALESCE(profiles.display_name, EXCLUDED.display_name);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Attach trigger to auth.users table
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 11. Storage Bucket initialization and RLS
INSERT INTO storage.buckets (id, name, public)
VALUES ('secure-files', 'secure-files', false)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "secure-files: allow upload" ON storage.objects;
DROP POLICY IF EXISTS "secure-files: allow download" ON storage.objects;
DROP POLICY IF EXISTS "secure-files: allow delete" ON storage.objects;

CREATE POLICY "secure-files: allow upload"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'secure-files');

CREATE POLICY "secure-files: allow download"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'secure-files');

CREATE POLICY "secure-files: allow delete"
  ON storage.objects FOR DELETE
  USING (bucket_id = 'secure-files');
