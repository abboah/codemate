-- Creates a user_settings table to store user preferences.
-- Establishes a one-to-one relationship with the public.users table.

CREATE TABLE public.user_settings (
  user_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  theme TEXT NOT NULL DEFAULT 'dark' CHECK (theme IN ('light', 'dark')),
  notifications_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  other_prefs JSONB NOT NULL DEFAULT jsonb_build_object(
    'has_seen_home_screen', false,
    'has_seen_playground_page', false,
    'has_seen_build_page', false,
    'has_seen_learn_page', false,
    'has_seen_sidebar_tutorial', false,
    'has_seen_brainstorm_modal', false,
    'has_seen_describe_modal', false,
    'has_seen_ide', false,
    'has_seen_terminal', false,
    'has_seen_canvas', false,
    'has_seen_enrolled_courses_page', false,
    'has_seen_topic_interaction_modal', false
  ),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Optional: Create a trigger to automatically update the updated_at timestamp.
CREATE OR REPLACE FUNCTION public.handle_user_settings_update()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_user_settings_update
  BEFORE UPDATE ON public.user_settings
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_user_settings_update();

-- Also, let's ensure every new user gets a settings entry.
-- We'll modify the existing handle_new_user function.

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  full_name_var TEXT;
  username_var TEXT;
BEGIN
  -- Extract full name from metadata
  full_name_var := NEW.raw_user_meta_data->>'full_name';
  -- Extract the first name to use as username
  username_var := split_part(full_name_var, ' ', 1);

  -- Create a user profile
  INSERT INTO public.users (id, email, username, full_name)
  VALUES (NEW.id, NEW.email, username_var, full_name_var);
  
  -- Create a settings entry for the new user
  INSERT INTO public.user_settings (user_id, other_prefs)
  VALUES (
    NEW.id,
    jsonb_build_object(
      'has_seen_home_screen', false,
      'has_seen_playground_page', false,
      'has_seen_build_page', false,
      'has_seen_learn_page', false,
      'has_seen_sidebar_tutorial', false,
      'has_seen_brainstorm_modal', false,
      'has_seen_describe_modal', false,
      'has_seen_ide', false,
      'has_seen_terminal', false,
      'has_seen_canvas', false,
      'has_seen_enrolled_courses_page', false,
      'has_seen_topic_interaction_modal', false
    )
  );
  
  RETURN NEW;
END;
$$ SET search_path = public;