-- 1. Ensure public.profiles table has all necessary columns
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS display_name TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS avatar_color_start TEXT DEFAULT 'FF0072FF';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS avatar_color_end TEXT DEFAULT 'FF00F2FE';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS onboarding_completed BOOLEAN NOT NULL DEFAULT false;

-- 2. Create or replace trigger function to auto-pick first 7 characters of email as display_name for new signups
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
