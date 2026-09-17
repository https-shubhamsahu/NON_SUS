-- Play UGC reporting: signed-in members can flag a file, another member, a
-- group, or the app. Reports are write-only for clients and are read by the
-- founder via the dashboard (service role bypasses RLS). No document names,
-- file contents, or private URLs belong in this table.

CREATE TABLE public.content_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  target_kind text NOT NULL,
  target_id text NOT NULL,
  group_id text REFERENCES public.study_groups (id) ON DELETE SET NULL,
  reason text NOT NULL,
  details text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT content_reports_kind_allowed
    CHECK (target_kind IN ('file', 'member', 'group', 'other')),
  CONSTRAINT content_reports_reason_allowed
    CHECK (reason IN ('spam', 'harassment', 'inappropriate', 'illegal', 'other')),
  CONSTRAINT content_reports_target_id_len
    CHECK (length(target_id) BETWEEN 1 AND 128),
  CONSTRAINT content_reports_details_len
    CHECK (details IS NULL OR length(details) BETWEEN 1 AND 500)
);

CREATE INDEX content_reports_created_at
  ON public.content_reports (created_at DESC);

CREATE UNIQUE INDEX content_reports_once_per_day
  ON public.content_reports (
    reporter_id,
    target_kind,
    target_id,
    ((created_at AT TIME ZONE 'utc')::date)
  );

ALTER TABLE public.content_reports ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.content_reports FROM public, anon, authenticated;
GRANT INSERT ON TABLE public.content_reports TO authenticated;

-- Members report inside a group they belong to. The Settings fallback
-- (`other`) has no group. Nobody can report themselves as a member.
CREATE POLICY content_reports_insert_own
  ON public.content_reports
  FOR INSERT TO authenticated
  WITH CHECK (
    reporter_id = (SELECT auth.uid())
    AND (
      (
        target_kind = 'other'
        AND group_id IS NULL
      )
      OR (
        group_id IS NOT NULL
        AND public.is_group_member(group_id)
        AND (
          target_kind = 'file'
          OR (
            target_kind = 'member'
            AND target_id <> (SELECT auth.uid())::text
          )
          OR (
            target_kind = 'group'
            AND target_id = group_id
          )
        )
      )
    )
  );
