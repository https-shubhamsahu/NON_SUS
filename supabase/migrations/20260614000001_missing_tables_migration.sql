-- NO SUS — Complete Database Setup (idempotent — safe to run multiple times)
-- Run in: Supabase Dashboard → SQL Editor → New Query → Run
-- =============================================================================
-- This script:
--   1. Creates all required tables (profiles, study_groups, study_group_members,
--      secure_files, audit_logs, focus_logs, user_notes)
--   2. Enables Row Level Security on every table
--   3. Adds permissive "Allow all" policies for MVP/development mode
--   4. Registers tables with the Realtime publication (idempotent)
-- =============================================================================

-- ─── EXTENSION ────────────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ─── 1. PROFILES ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.profiles (
  id                  uuid        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email               text,
  display_name        text,
  avatar_color_start  text        DEFAULT 'FF0072FF',
  avatar_color_end    text        DEFAULT 'FF00F2FE',
  updated_at          timestamptz DEFAULT now()
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='profiles' AND policyname='Allow all') THEN
    CREATE POLICY "Allow all" ON public.profiles FOR ALL USING (true) WITH CHECK (true);
  END IF;
END $$;

-- ─── 2. STUDY GROUPS ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.study_groups (
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

ALTER TABLE public.study_groups ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='study_groups' AND policyname='Allow all') THEN
    CREATE POLICY "Allow all" ON public.study_groups FOR ALL USING (true) WITH CHECK (true);
  END IF;
END $$;

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

-- ─── 3. STUDY GROUP MEMBERS ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.study_group_members (
  group_id  text    NOT NULL REFERENCES public.study_groups(id) ON DELETE CASCADE,
  user_id   uuid    NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  is_admin  boolean NOT NULL DEFAULT false,
  joined_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (group_id, user_id)
);

ALTER TABLE public.study_group_members ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='study_group_members' AND policyname='Allow all') THEN
    CREATE POLICY "Allow all" ON public.study_group_members FOR ALL USING (true) WITH CHECK (true);
  END IF;
END $$;

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

-- ─── 4. SECURE FILES ──────────────────────────────────────────────────────────
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
  encryption_key_base64 text,
  encryption_iv_base64  text,
  uploaded_at           timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.secure_files ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='secure_files' AND policyname='Allow all') THEN
    CREATE POLICY "Allow all" ON public.secure_files FOR ALL USING (true) WITH CHECK (true);
  END IF;
END $$;

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

-- ─── 5. AUDIT LOGS ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.audit_logs (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  event      text        NOT NULL,
  status     text        NOT NULL DEFAULT 'INFO',
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='audit_logs' AND policyname='Allow all') THEN
    CREATE POLICY "Allow all" ON public.audit_logs FOR ALL USING (true) WITH CHECK (true);
  END IF;
END $$;

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

-- ─── 6. FOCUS LOGS ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.focus_logs (
  id            uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       uuid    NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  date          date    NOT NULL,
  focus_minutes integer NOT NULL DEFAULT 0,
  UNIQUE (user_id, date)
);

ALTER TABLE public.focus_logs ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='focus_logs' AND policyname='Allow all') THEN
    CREATE POLICY "Allow all" ON public.focus_logs FOR ALL USING (true) WITH CHECK (true);
  END IF;
END $$;

-- ─── 7. USER NOTES ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.user_notes (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid        NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  note_text   text        NOT NULL DEFAULT '',
  updated_at  timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.user_notes ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='user_notes' AND policyname='Allow all') THEN
    CREATE POLICY "Allow all" ON public.user_notes FOR ALL USING (true) WITH CHECK (true);
  END IF;
END $$;

-- ─── 8. STORAGE BUCKET: secure-files ──────────────────────────────────────────
-- Create the bucket if it doesn't exist
INSERT INTO storage.buckets (id, name, public)
VALUES ('secure-files', 'secure-files', false)
ON CONFLICT (id) DO NOTHING;

-- Allow anyone to upload (INSERT) to secure-files bucket
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='storage' AND tablename='objects' AND policyname='secure-files: allow upload') THEN
    CREATE POLICY "secure-files: allow upload"
      ON storage.objects FOR INSERT
      WITH CHECK (bucket_id = 'secure-files');
  END IF;
END $$;

-- Allow anyone to download (SELECT) from secure-files bucket
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='storage' AND tablename='objects' AND policyname='secure-files: allow download') THEN
    CREATE POLICY "secure-files: allow download"
      ON storage.objects FOR SELECT
      USING (bucket_id = 'secure-files');
  END IF;
END $$;

-- Allow anyone to delete from secure-files bucket
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='storage' AND tablename='objects' AND policyname='secure-files: allow delete') THEN
    CREATE POLICY "secure-files: allow delete"
      ON storage.objects FOR DELETE
      USING (bucket_id = 'secure-files');
  END IF;
END $$;
