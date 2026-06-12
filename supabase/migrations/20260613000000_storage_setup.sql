-- Create private storage bucket named 'secure-files'
INSERT INTO storage.buckets (id, name, public)
VALUES ('secure-files', 'secure-files', false)
ON CONFLICT (id) DO NOTHING;

-- Policy to allow authenticated users to upload to the secure-files bucket
CREATE POLICY "Allow authenticated uploads to secure-files"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'secure-files');

-- Policy to allow study group members to download secure-files objects
CREATE POLICY "Allow members to download secure-files"
ON storage.objects FOR SELECT
TO authenticated
USING (
    bucket_id = 'secure-files' AND
    EXISTS (
        SELECT 1 FROM public.secure_files f
        JOIN public.study_group_members m ON m.group_id = f.group_id
        WHERE f.id = storage.objects.name
        AND m.user_id = auth.uid()
    )
);

-- Policy to allow study group admins to delete secure-files objects
CREATE POLICY "Allow group admins to delete secure-files"
ON storage.objects FOR DELETE
TO authenticated
USING (
    bucket_id = 'secure-files' AND
    EXISTS (
        SELECT 1 FROM public.secure_files f
        JOIN public.study_group_members m ON m.group_id = f.group_id
        WHERE f.id = storage.objects.name
        AND m.user_id = auth.uid()
        AND m.is_admin = true
    )
);
