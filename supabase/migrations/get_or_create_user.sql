CREATE OR REPLACE FUNCTION public.get_or_create_user()
RETURNS TABLE (
  id UUID,
  username TEXT,
  full_name TEXT,
  email TEXT,
  has_completed_onboarding BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  user_profile record;
  auth_user_id UUID := auth.uid();
  auth_user_email TEXT := auth.email();
  auth_user_full_name TEXT := auth.jwt()->>'user_metadata'->>'full_name';
  auth_user_username TEXT := split_part(auth_user_full_name, ' ', 1);

BEGIN
  -- Try to find the user profile
  SELECT * INTO user_profile FROM public.users WHERE public.users.id = auth_user_id;

  -- If the user profile does not exist, create it.
  IF user_profile IS NULL THEN
    INSERT INTO public.users (id, email, username, full_name)
    VALUES (auth_user_id, auth_user_email, auth_user_username, auth_user_full_name)
    ON CONFLICT (id) DO NOTHING; -- Safely do nothing if the user already exists

    -- Also create their settings
    INSERT INTO public.user_settings (user_id)
    VALUES (auth_user_id)
    ON CONFLICT (user_id) DO NOTHING; -- Safely do nothing if settings exist
  END IF;

  -- Return the found or newly created profile
  RETURN QUERY
    SELECT u.id, u.username, u.full_name, u.email, us.has_completed_onboarding
    FROM public.users u
    JOIN public.user_settings us ON u.id = us.user_id
    WHERE u.id = auth_user_id;
END;
$$;