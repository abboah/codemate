-- Migration script for the "Learn" feature.
-- Creates all necessary tables and populates initial course data.

-- Step 1: Create ENUM types for data integrity
CREATE TYPE course_type AS ENUM ('language', 'framework');
CREATE TYPE topic_type AS ENUM ('regular', 'project');
CREATE TYPE enrollment_status AS ENUM ('not_started', 'in_progress', 'completed');
CREATE TYPE difficulty_level AS ENUM ('beginner', 'intermediate', 'advanced');
CREATE TYPE learning_style AS ENUM ('visual', 'kinesthetic', 'auditory', 'reading/writing');
CREATE TYPE message_sender AS ENUM ('user', 'ai');

-- Step 2: Create the `courses` table
CREATE TABLE public.courses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  description TEXT,
  course_type course_type NOT NULL,
  cover_image_url TEXT,
  estimated_time_hours INT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
COMMENT ON TABLE public.courses IS 'Stores the master list of all available courses.';

-- Step 3: Create the `topics` table
CREATE TABLE public.topics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id UUID NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  topic_order INT NOT NULL,
  topic_type topic_type NOT NULL DEFAULT 'regular',
  estimated_time_minutes INT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
COMMENT ON TABLE public.topics IS 'Stores the individual lessons or modules for each course.';

-- Step 4: Create the `enrollments` table
CREATE TABLE public.enrollments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  course_id UUID NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
  status enrollment_status NOT NULL DEFAULT 'not_started',
  progress INT NOT NULL DEFAULT 0 CHECK (progress >= 0 AND progress <= 100),
  difficulty difficulty_level NOT NULL DEFAULT 'beginner',
  learning_style learning_style NOT NULL DEFAULT 'visual',
  enrolled_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (user_id, course_id)
);
COMMENT ON TABLE public.enrollments IS 'Tracks user enrollment and progress in courses.';

-- Step 5: Create the `topic_notes` table
CREATE TABLE public.topic_notes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  enrollment_id UUID NOT NULL REFERENCES public.enrollments(id) ON DELETE CASCADE,
  topic_id UUID NOT NULL REFERENCES public.topics(id) ON DELETE CASCADE,
  note_title TEXT NOT NULL,
  note_content TEXT,
  note_order INT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
COMMENT ON TABLE public.topic_notes IS 'Stores AI-generated notes for a user''s specific topic enrollment.';

-- Step 6: Create the `topic_quizzes` table
CREATE TABLE public.topic_quizzes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  enrollment_id UUID NOT NULL REFERENCES public.enrollments(id) ON DELETE CASCADE,
  topic_id UUID NOT NULL REFERENCES public.topics(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
COMMENT ON TABLE public.topic_quizzes IS 'Stores a specific quiz instance for a user and topic.';

-- Step 7: Create the `quiz_questions` table
CREATE TABLE public.quiz_questions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  quiz_id UUID NOT NULL REFERENCES public.topic_quizzes(id) ON DELETE CASCADE,
  question_order INT NOT NULL,
  question_text TEXT NOT NULL,
  options JSONB NOT NULL,
  correct_option TEXT NOT NULL,
  explanation TEXT
);
COMMENT ON TABLE public.quiz_questions IS 'Stores the questions for a given quiz.';

-- Step 8: Create the `suggested_projects` table
CREATE TABLE public.suggested_projects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  topic_id UUID NOT NULL REFERENCES public.topics(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  stack TEXT[],
  estimated_time_hours INT
);
COMMENT ON TABLE public.suggested_projects IS 'Stores project ideas related to a specific topic.';

-- Step 9: Create the `topic_chats` table
CREATE TABLE public.topic_chats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  enrollment_id UUID NOT NULL REFERENCES public.enrollments(id) ON DELETE CASCADE,
  topic_id UUID NOT NULL REFERENCES public.topics(id) ON DELETE CASCADE,
  title TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
COMMENT ON TABLE public.topic_chats IS 'Stores a chat session for a user within a topic.';

-- Step 10: Create the `chat_messages` table
CREATE TABLE public.chat_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  chat_id UUID NOT NULL REFERENCES public.topic_chats(id) ON DELETE CASCADE,
  sender message_sender NOT NULL,
  content TEXT NOT NULL,
  sent_at TIMESTAMPTZ DEFAULT NOW()
);
COMMENT ON TABLE public.chat_messages IS 'Stores the individual messages within a chat session.';

-- Step 11: Seed the `courses` table with initial data
INSERT INTO public.courses (name, description, course_type, estimated_time_hours)
VALUES
  ('Python', 'Master the world''s most popular language for data science, web development, and automation.', 'language', 40),
  ('JavaScript', 'Learn the fundamental language of the web, from basic syntax to advanced concepts.', 'language', 50),
  ('SQL', 'Unlock the power of data by learning to query and manage relational databases.', 'language', 30),
  ('Dart', 'The language behind Flutter. Learn Dart to build beautiful, natively compiled applications for mobile, web, and desktop.', 'language', 35),
  ('Flutter', 'Build stunning, high-performance applications for any screen from a single codebase.', 'framework', 60),
  ('React', 'A JavaScript library for building user interfaces, maintained by Facebook.', 'framework', 55),
  ('Django', 'A high-level Python web framework that encourages rapid development and clean, pragmatic design.', 'framework', 45),
  ('Supabase', 'The open source Firebase alternative. Build a backend in minutes with a Postgres database, authentication, and more.', 'framework', 25);
  ('C++', 'Master the powerful systems programming language used for game development, embedded systems, and high-performance applications.', 'language', 50),
  ('Swift', 'Learn Apple''s modern programming language for iOS, macOS, watchOS, and tvOS app development.', 'language', 45),
  ('PyTorch', 'Build and train deep learning AI models with PyTorch, the dynamic neural network framework preferred by researchers.', 'framework', 40);
  ('Unity', 'Create immersive 2D and 3D games and interactive experiences with Unity, the world''s leading game development platform.', 'framework', 55);



-- End of migration script
