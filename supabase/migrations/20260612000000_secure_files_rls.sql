-- Enable Row Level Security on secure_files table
ALTER TABLE public.secure_files ENABLE ROW LEVEL SECURITY;

-- Select policy: users can view files belonging to study groups they are members of
CREATE POLICY "Users can view secure files of groups they belong to"
    ON public.secure_files FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.study_group_members m
            WHERE m.group_id = secure_files.group_id
            AND m.user_id = auth.uid()
        )
    );

-- Insert policy: users can upload/insert files to study groups they are members of
CREATE POLICY "Users can upload secure files to groups they belong to"
    ON public.secure_files FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.study_group_members m
            WHERE m.group_id = secure_files.group_id
            AND m.user_id = auth.uid()
        )
    );

-- Update policy: users can update files (like pinning or editing name) in groups they belong to
CREATE POLICY "Users can update secure files in groups they belong to"
    ON public.secure_files FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.study_group_members m
            WHERE m.group_id = secure_files.group_id
            AND m.user_id = auth.uid()
        )
    );

-- Delete policy: only group admins can delete files from groups
CREATE POLICY "Only group admins can delete secure files"
    ON public.secure_files FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM public.study_group_members m
            WHERE m.group_id = secure_files.group_id
            AND m.user_id = auth.uid()
            AND m.is_admin = true
        )
    );
