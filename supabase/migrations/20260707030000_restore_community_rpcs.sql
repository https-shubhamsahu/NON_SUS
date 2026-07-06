-- Migration: 20260707030000_restore_community_rpcs.sql
-- These two functions exist in the repo's baseline.sql but were never applied
-- to the live project (its schema evolved through an independent migration
-- chain). Without them, the app's community auto-join at startup fails
-- silently (PGRST202 "not found in schema cache"), the user never becomes a
-- member of "Global Community", and downstream audit events logged against
-- that group are rejected with "Not a member of the study group".
-- Definitions copied verbatim from 20260629000000_baseline.sql.

CREATE OR REPLACE FUNCTION public.join_public_group_by_name(
  p_group_name text
)
RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_group_id text;
  v_user_id uuid;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT id INTO v_group_id
  FROM public.study_groups
  WHERE name = p_group_name;

  IF v_group_id IS NULL THEN
    RAISE EXCEPTION 'Group not found';
  END IF;

  INSERT INTO public.study_group_members (group_id, user_id, is_admin)
  VALUES (v_group_id, v_user_id, false)
  ON CONFLICT (group_id, user_id) DO NOTHING;

  INSERT INTO public.audit_logs (group_id, actor_id, file_id, event_type, metadata)
  VALUES (v_group_id, v_user_id, NULL, 'member_joined', '{}'::jsonb);

  RETURN v_group_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.ensure_community_exists(
  p_name text,
  p_description text
)
RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_group_id text;
BEGIN
  SELECT id INTO v_group_id
  FROM public.study_groups
  WHERE name = p_name;

  IF v_group_id IS NULL THEN
    v_group_id := gen_random_uuid()::text;
    INSERT INTO public.study_groups (id, name, description, is_watermark_enabled)
    VALUES (v_group_id, p_name, p_description, true);
  END IF;

  RETURN v_group_id;
END;
$$;
