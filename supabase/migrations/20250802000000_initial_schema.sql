-- Create the users table to store public user data
CREATE TABLE public.users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT,
  username TEXT,
  email TEXT UNIQUE,
  avatar_url TEXT,
  bio TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create the user_settings table
CREATE TABLE public.user_settings (
  user_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  theme TEXT NOT NULL DEFAULT 'dark' CHECK (theme IN ('light', 'dark')),
  notifications_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  has_completed_onboarding BOOLEAN NOT NULL DEFAULT FALSE,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Function to handle new user creation
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  full_name_var TEXT;
  username_var TEXT;
BEGIN
  -- Extract full name from metadata, if available
  full_name_var := NEW.raw_user_meta_data->>'full_name';
  
  -- Use email to get a username if full_name is not available
  IF full_name_var IS NULL OR full_name_var = '' THEN
    full_name_var := NEW.raw_user_meta_data->>'name'; -- For providers like Google
  END IF;

  -- Generate a username from the full name or email
  IF full_name_var IS NOT NULL AND full_name_var <> '' THEN
    username_var := split_part(full_name_var, ' ', 1);
  ELSE
    username_var := split_part(NEW.email, '@', 1);
  END IF;

  -- Create a user profile
  INSERT INTO public.users (id, email, username, full_name, avatar_url)
  VALUES (
    NEW.id,
    NEW.email,
    username_var,
    full_name_var,
    NEW.raw_user_meta_data->>'avatar_url'
  );

  -- Create a settings entry for the new user
  INSERT INTO public.user_settings (user_id)
  VALUES (NEW.id);

  RETURN NEW;
END;
$$ SET search_path = public;

-- Trigger to call handle_new_user on new user signup
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- Function to automatically update `updated_at` timestamps
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for user_settings updates
CREATE TRIGGER on_user_settings_update
  BEFORE UPDATE ON public.user_settings
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();
