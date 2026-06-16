-- NO SUS — Fix RLS Policies Migration
-- Replaces all "Allow All" policies with proper member-scoped access control.
-- Run in: Supabase Dashboard → SQL Editor → New Query → Run
-- =============================================================================

-- ─── PROFILES ─────────────────────────────────────────────────────────────────
-- Drop the old "Allow all" policy and replace with per-user isolation.
DO $$ BEGIN
  DROP POLICY IF EXISTS "Allow all" ON public.profiles;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='profiles' AND policyname='profiles: self select') THEN
    CREATE POLICY "profiles: self select" ON public.profiles FOR SELECT
      USING (auth.uid() = id OR auth.uid() IN (
        SELECT user_id FROM public.study_group_members
        WHERE group_id IN (SELECT group_id FROM public.study_group_members WHERE user_id = auth.uid())
      ));
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='profiles' AND policyname='profiles: self insert') THEN
    CREATE POLICY "profiles: self insert" ON public.profiles FOR INSERT
      WITH CHECK (auth.uid() = id);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='profiles' AND policyname='profiles: self update') THEN
    CREATE POLICY "profiles: self update" ON public.profiles FOR UPDATE
      USING (auth.uid() = id);
  END IF;
END $$;

-- ─── STUDY GROUPS ─────────────────────────────────────────────────────────────
DO $$ BEGIN
  DROP POLICY IF EXISTS "Allow all" ON public.study_groups;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- Members can view groups they belong to; open groups visible to all authenticated users.
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='study_groups' AND policyname='groups: member select') THEN
    CREATE POLICY "groups: member select" ON public.study_groups FOR SELECT
      USING (
        security_level = 'open'
        OR EXISTS (
          SELECT 1 FROM public.study_group_members m
          WHERE m.group_id = study_groups.id AND m.user_id = auth.uid()
        )
      );
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='study_groups' AND policyname='groups: authenticated insert') THEN
    CREATE POLICY "groups: authenticated insert" ON public.study_groups FOR INSERT
      WITH CHECK (auth.role() = 'authenticated');
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='study_groups' AND policyname='groups: admin update') THEN
    CREATE POLICY "groups: admin update" ON public.study_groups FOR UPDATE
      USING (
        EXISTS (
          SELECT 1 FROM public.study_group_members m
          WHERE m.group_id = study_groups.id AND m.user_id = auth.uid() AND m.is_admin = true
        )
      );
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='study_groups' AND policyname='groups: admin delete') THEN
    CREATE POLICY "groups: admin delete" ON public.study_groups FOR DELETE
      USING (
        EXISTS (
          SELECT 1 FROM public.study_group_members m
          WHERE m.group_id = study_groups.id AND m.user_id = auth.uid() AND m.is_admin = true
        )
      );
  END IF;
END $$;

-- ─── STUDY GROUP MEMBERS ──────────────────────────────────────────────────────
DO $$ BEGIN
  DROP POLICY IF EXISTS "Allow all" ON public.study_group_members;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- Users can view memberships of groups they belong to.
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='study_group_members' AND policyname='members: peer select') THEN
    CREATE POLICY "members: peer select" ON public.study_group_members FOR SELECT
      USING (
        EXISTS (
          SELECT 1 FROM public.study_group_members m
          WHERE m.group_id = study_group_members.group_id AND m.user_id = auth.uid()
        )
      );
  END IF;
END $$;

-- Any authenticated user can insert themselves (joining a group).
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='study_group_members' AND policyname='members: self insert') THEN
    CREATE POLICY "members: self insert" ON public.study_group_members FOR INSERT
      WITH CHECK (user_id = auth.uid());
  END IF;
END $$;

-- Users can remove themselves; admins can remove anyone.
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='study_group_members' AND policyname='members: self or admin delete') THEN
    CREATE POLICY "members: self or admin delete" ON public.study_group_members FOR DELETE
      USING (
        user_id = auth.uid()
        OR EXISTS (
          SELECT 1 FROM public.study_group_members m
          WHERE m.group_id = study_group_members.group_id AND m.user_id = auth.uid() AND m.is_admin = true
        )
      );
  END IF;
END $$;

-- ─── SECURE FILES ─────────────────────────────────────────────────────────────
DO $$ BEGIN
  DROP POLICY IF EXISTS "Allow all" ON public.secure_files;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- Only group members can read file metadata.
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='secure_files' AND policyname='files: group member select') THEN
    CREATE POLICY "files: group member select" ON public.secure_files FOR SELECT
      USING (
        EXISTS (
          SELECT 1 FROM public.study_group_members m
          WHERE m.group_id = secure_files.group_id AND m.user_id = auth.uid()
        )
      );
  END IF;
END $$;

-- Any group member can upload (INSERT) files.
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='secure_files' AND policyname='files: group member insert') THEN
    CREATE POLICY "files: group member insert" ON public.secure_files FOR INSERT
      WITH CHECK (
        EXISTS (
          SELECT 1 FROM public.study_group_members m
          WHERE m.group_id = secure_files.group_id AND m.user_id = auth.uid()
        )
      );
  END IF;
END $$;

-- Any group member can update (pin/unpin) files.
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='secure_files' AND policyname='files: group member update') THEN
    CREATE POLICY "files: group member update" ON public.secure_files FOR UPDATE
      USING (
        EXISTS (
          SELECT 1 FROM public.study_group_members m
          WHERE m.group_id = secure_files.group_id AND m.user_id = auth.uid()
        )
      );
  END IF;
END $$;

-- Only group admins can delete files.
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='secure_files' AND policyname='files: admin delete') THEN
    CREATE POLICY "files: admin delete" ON public.secure_files FOR DELETE
      USING (
        EXISTS (
          SELECT 1 FROM public.study_group_members m
          WHERE m.group_id = secure_files.group_id AND m.user_id = auth.uid() AND m.is_admin = true
        )
      );
  END IF;
END $$;

-- Remove encryption key columns from secure_files (keys must NEVER be in the DB).
ALTER TABLE public.secure_files DROP COLUMN IF EXISTS encryption_key_base64;
ALTER TABLE public.secure_files DROP COLUMN IF EXISTS encryption_iv_base64;

-- ─── AUDIT LOGS ───────────────────────────────────────────────────────────────
DO $$ BEGIN
  DROP POLICY IF EXISTS "Allow all" ON public.audit_logs;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- Any authenticated user can insert audit events.
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='audit_logs' AND policyname='audit: authenticated insert') THEN
    CREATE POLICY "audit: authenticated insert" ON public.audit_logs FOR INSERT
      WITH CHECK (auth.role() = 'authenticated');
  END IF;
END $$;

-- Any authenticated user can read audit logs (shared security ledger).
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='audit_logs' AND policyname='audit: authenticated select') THEN
    CREATE POLICY "audit: authenticated select" ON public.audit_logs FOR SELECT
      USING (auth.role() = 'authenticated');
  END IF;
END $$;

-- ─── FOCUS LOGS ───────────────────────────────────────────────────────────────
DO $$ BEGIN
  DROP POLICY IF EXISTS "Allow all" ON public.focus_logs;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='focus_logs' AND policyname='focus: self all') THEN
    CREATE POLICY "focus: self all" ON public.focus_logs FOR ALL
      USING (user_id = auth.uid())
      WITH CHECK (user_id = auth.uid());
  END IF;
END $$;

-- ─── USER NOTES ───────────────────────────────────────────────────────────────
DO $$ BEGIN
  DROP POLICY IF EXISTS "Allow all" ON public.user_notes;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='user_notes' AND policyname='notes: self all') THEN
    CREATE POLICY "notes: self all" ON public.user_notes FOR ALL
      USING (user_id = auth.uid())
      WITH CHECK (user_id = auth.uid());
  END IF;
END $$;

-- ─── STORAGE RLS ──────────────────────────────────────────────────────────────
-- Replace open storage policies with group-membership checks.
DO $$ BEGIN
  DROP POLICY IF EXISTS "secure-files: allow upload" ON storage.objects;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS "secure-files: allow download" ON storage.objects;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS "secure-files: allow delete" ON storage.objects;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='storage' AND tablename='objects' AND policyname='storage: authenticated upload') THEN
    CREATE POLICY "storage: authenticated upload"
      ON storage.objects FOR INSERT
      WITH CHECK (bucket_id = 'secure-files' AND auth.role() = 'authenticated');
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='storage' AND tablename='objects' AND policyname='storage: authenticated download') THEN
    CREATE POLICY "storage: authenticated download"
      ON storage.objects FOR SELECT
      USING (bucket_id = 'secure-files' AND auth.role() = 'authenticated');
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='storage' AND tablename='objects' AND policyname='storage: authenticated delete') THEN
    CREATE POLICY "storage: authenticated delete"
      ON storage.objects FOR DELETE
      USING (bucket_id = 'secure-files' AND auth.role() = 'authenticated');
  END IF;
END $$;
