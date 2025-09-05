-- Migration script to add user topic progress tracking.

-- Step 1: Create a new ENUM type for topic status
CREATE TYPE topic_status AS ENUM ('not_started', 'in_progress', 'completed');

-- Step 2: Create the `user_topic_status` table
CREATE TABLE public.user_topic_status (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  enrollment_id UUID NOT NULL REFERENCES public.enrollments(id) ON DELETE CASCADE,
  topic_id UUID NOT NULL REFERENCES public.topics(id) ON DELETE CASCADE,
  status topic_status NOT NULL DEFAULT 'not_started',
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (enrollment_id, topic_id)
);

COMMENT ON TABLE public.user_topic_status IS 'Tracks the completion status of each topic for a user''s enrollment.';

-- Step 3: Create a trigger function to automatically populate this table when a user enrolls
CREATE OR REPLACE FUNCTION public.handle_new_enrollment()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Insert a 'not_started' status for every topic in the course for the new enrollment
  INSERT INTO public.user_topic_status (enrollment_id, topic_id, status)
  SELECT
    NEW.id,
    t.id,
    'not_started'
  FROM public.topics t
  WHERE t.course_id = NEW.course_id;
  
  RETURN NEW;
END;
$$ SET search_path = public;

-- Step 4: Create a trigger to call the function after a new enrollment is created
CREATE TRIGGER on_enrollment_created
  AFTER INSERT ON public.enrollments
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_enrollment();

-- Step 5: Create a function to update the `updated_at` timestamp on status changes
CREATE OR REPLACE FUNCTION public.handle_user_topic_status_update()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Step 6: Create a trigger for `user_topic_status` updates
CREATE TRIGGER on_user_topic_status_update
  BEFORE UPDATE ON public.user_topic_status
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_user_topic_status_update();
