-- Create profiles table linked to Supabase Auth users
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT UNIQUE,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS on profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Profile RLS Policies
CREATE POLICY "Users can view their own profile"
    ON public.profiles FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile"
    ON public.profiles FOR UPDATE
    USING (auth.uid() = id);

-- Trigger to automatically create a profile on user signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, email)
    VALUES (new.id, new.email);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Create study groups table
CREATE TABLE IF NOT EXISTS public.study_groups (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    security_level TEXT NOT NULL DEFAULT 'encrypted',
    is_watermark_enabled BOOLEAN NOT NULL DEFAULT true,
    invite_code TEXT,
    file_count INTEGER NOT NULL DEFAULT 0,
    last_activity TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS on study_groups
ALTER TABLE public.study_groups ENABLE ROW LEVEL SECURITY;

-- Create study group members mapping table
CREATE TABLE IF NOT EXISTS public.study_group_members (
    group_id TEXT REFERENCES public.study_groups(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    is_admin BOOLEAN NOT NULL DEFAULT false,
    PRIMARY KEY (group_id, user_id)
);

-- Enable RLS on study_group_members
ALTER TABLE public.study_group_members ENABLE ROW LEVEL SECURITY;

-- Study group memberships RLS Policies
CREATE POLICY "Users can view memberships of groups they belong to"
    ON public.study_group_members FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.study_group_members m
            WHERE m.group_id = study_group_members.group_id
            AND m.user_id = auth.uid()
        )
    );

CREATE POLICY "Admins can manage memberships for their group"
    ON public.study_group_members FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.study_group_members m
            WHERE m.group_id = study_group_members.group_id
            AND m.user_id = auth.uid()
            AND m.is_admin = true
        )
    );

-- Study groups RLS Policies
CREATE POLICY "Users can view study groups they are members of"
    ON public.study_groups FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.study_group_members m
            WHERE m.group_id = study_groups.id
            AND m.user_id = auth.uid()
        ) OR security_level = 'open'
    );

CREATE POLICY "Authenticated users can create study groups"
    ON public.study_groups FOR INSERT
    WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Admins can update study groups"
    ON public.study_groups FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.study_group_members m
            WHERE m.group_id = study_groups.id
            AND m.user_id = auth.uid()
            AND m.is_admin = true
        )
    );

CREATE POLICY "Admins can delete study groups"
    ON public.study_groups FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM public.study_group_members m
            WHERE m.group_id = study_groups.id
            AND m.user_id = auth.uid()
            AND m.is_admin = true
        )
    );
