-- Migration: Add other_prefs JSONB to user_settings with default flags
-- This backfills existing rows and sets a default for new rows

ALTER TABLE public.user_settings
ADD COLUMN IF NOT EXISTS other_prefs JSONB NOT NULL DEFAULT jsonb_build_object(
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
);

-- Ensure any NULLs (if column existed without NOT NULL previously) are filled
UPDATE public.user_settings
SET other_prefs = jsonb_build_object(
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
WHERE other_prefs IS NULL;
