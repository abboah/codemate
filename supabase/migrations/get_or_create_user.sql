-- This function retrieves a user's profile data.
-- The profile and settings are automatically created by a trigger (`on_auth_user_created`)
-- when a new user signs up, so this function no longer needs to handle creation.
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
AS $
BEGIN
  -- Return the user profile by joining users and user_settings.
  RETURN QUERY
    SELECT
      u.id,
      u.username,
      u.full_name,
      u.email,
      us.has_completed_onboarding
    FROM public.users u
    JOIN public.user_settings us ON u.id = us.user_id
    WHERE u.id = auth.uid();
END;
$;