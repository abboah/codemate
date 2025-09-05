-- This script backfills existing users from `auth.users` into `public.users` and `public.user_settings`.
-- It's designed to be run once to migrate old users to the new profile system.

DO $$
DECLARE
  auth_user RECORD;
  full_name_var TEXT;
  username_var TEXT;
BEGIN
  FOR auth_user IN
    SELECT id, email, raw_user_meta_data FROM auth.users
  LOOP
    -- Check if a profile already exists in `public.users` to prevent duplicates.
    IF NOT EXISTS (SELECT 1 FROM public.users WHERE id = auth_user.id) THEN
      
      -- Extract full name from user metadata. Handles different providers (e.g., Google vs. email).
      full_name_var := auth_user.raw_user_meta_data->>'full_name';
      IF full_name_var IS NULL OR full_name_var = '' THEN
        full_name_var := auth_user.raw_user_meta_data->>'name';
      END IF;

      -- Generate a username from the full name or fallback to the email prefix.
      IF full_name_var IS NOT NULL AND full_name_var <> '' THEN
        username_var := split_part(full_name_var, ' ', 1);
      ELSE
        username_var := split_part(auth_user.email, '@', 1);
      END IF;

      -- Insert the new record into the public users table.
      INSERT INTO public.users (id, email, username, full_name, avatar_url)
      VALUES (
        auth_user.id,
        auth_user.email,
        username_var,
        full_name_var,
        auth_user.raw_user_meta_data->>'avatar_url'
      );

      -- Create the corresponding settings entry for the new user.
      INSERT INTO public.user_settings (user_id)
      VALUES (auth_user.id);
      
      -- Log a notice for each user that is backfilled.
      RAISE NOTICE 'Backfilled profile and settings for user %', auth_user.id;
    END IF;
  END LOOP;
END;
$$;
