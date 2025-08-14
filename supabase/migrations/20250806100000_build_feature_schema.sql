-- Migration script for the revamped "Build" feature.
-- Creates a new, robust schema for an IDE-like experience with an AI agent.
-- This schema supports project management, agent chats, file operations, and checkpointing.

-- Step 1: Define ENUM types for consistency and data integrity.
-- NOTE: The 'message_sender' type is likely already created by the 'learn_feature_schema'.
-- We include 'CREATE TYPE ... IF NOT EXISTS' for robustness in case migrations are run out of order.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'message_sender') THEN
        CREATE TYPE message_sender AS ENUM ('user', 'ai');
    END IF;
END$$;

CREATE TYPE agent_message_type AS ENUM ('text', 'tool_request', 'tool_result', 'error');
CREATE TYPE file_operation_type AS ENUM ('create', 'update', 'delete');

-- Step 2: Create the `projects` table to store user projects.
CREATE TABLE public.projects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  stack TEXT[], -- e.g., {'Flutter', 'Supabase', 'Riverpod'}
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
COMMENT ON TABLE public.projects IS 'Stores user-created software projects.';

-- Step 3: Create the `agent_chats` table for chat sessions within a project.
CREATE TABLE public.agent_chats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  title TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
COMMENT ON TABLE public.agent_chats IS 'Stores a single chat session between a user and the AI agent for a project.';

-- Step 4: Create the `agent_chat_messages` table for individual chat messages.
-- This table is enhanced to handle structured agent operations (tool calls/results).
CREATE TABLE public.agent_chat_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  chat_id UUID NOT NULL REFERENCES public.agent_chats(id) ON DELETE CASCADE,
  sender message_sender NOT NULL,
  message_type agent_message_type NOT NULL DEFAULT 'text',
  content TEXT NOT NULL,
  tool_calls JSONB, -- Stores the agent's requested tool calls, e.g., {'tool': 'create_file', 'path': 'a.txt'}
  tool_results JSONB, -- Stores the results of those tool calls
  sent_at TIMESTAMPTZ DEFAULT NOW()
);
COMMENT ON TABLE public.agent_chat_messages IS 'Stores individual messages within an agent chat, including tool usage.';

-- Step 5: Create the `project_files` table to store the current state of all files in a project.
CREATE TABLE public.project_files (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
  path TEXT NOT NULL, -- Full path within the project, e.g., 'lib/main.dart'
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  last_modified TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (project_id, path)
);
COMMENT ON TABLE public.project_files IS 'Represents the current state of all files in a given project.';

-- Step 6: Create the `file_checkpoints` table to allow users to save project states.
CREATE TABLE public.file_checkpoints (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
  message_id UUID REFERENCES public.agent_chat_messages(id) ON DELETE SET NULL, -- Optional link to the message that prompted the checkpoint
  name TEXT NOT NULL, -- A user-defined name for the checkpoint, e.g., "Initial setup"
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
COMMENT ON TABLE public.file_checkpoints IS 'A named snapshot of a project''s state at a point in time.';

-- Step 7: Create the `checkpoint_files` table to store the file contents for each checkpoint.
-- This denormalized approach makes restoring a checkpoint fast and simple.
CREATE TABLE public.checkpoint_files (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  checkpoint_id UUID NOT NULL REFERENCES public.file_checkpoints(id) ON DELETE CASCADE,
  path TEXT NOT NULL,
  content TEXT NOT NULL
);
COMMENT ON TABLE public.checkpoint_files IS 'Stores the content of a single file as part of a checkpoint.';

-- Step 8: Create the `file_operations` table to log all agent-driven file modifications.
CREATE TABLE public.file_operations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID NOT NULL REFERENCES public.agent_chat_messages(id) ON DELETE CASCADE,
  project_id UUID NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
  operation_type file_operation_type NOT NULL,
  path TEXT NOT NULL,
  old_content TEXT, -- Content before the operation, for 'update' and 'delete'.
  new_content TEXT, -- Content after the operation, for 'create' and 'update'.
  timestamp TIMESTAMPTZ DEFAULT NOW()
);
COMMENT ON TABLE public.file_operations IS 'A log of every file modification performed by the agent.';

-- End of migration script
--

-- Appendix: Terminal feature schema (sessions and command history)

-- Terminal sessions: groups a sequence of terminal commands for a user within a project
CREATE TABLE public.terminal_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  name TEXT, -- optional session name
  created_at TIMESTAMPTZ DEFAULT NOW()
);
COMMENT ON TABLE public.terminal_sessions IS 'Groups a sequence of terminal commands (a session) for a specific user and project.';

-- Terminal command history: one row per executed command with resulting output
CREATE TABLE public.terminal_commands (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID REFERENCES public.terminal_sessions(id) ON DELETE SET NULL,
  project_id UUID NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  command TEXT NOT NULL,
  output TEXT,
  exit_code INTEGER, -- 0 for success, non-zero for failures
  cwd TEXT DEFAULT '/', -- current working directory when the command was run
  created_at TIMESTAMPTZ DEFAULT NOW()
);
COMMENT ON TABLE public.terminal_commands IS 'History of commands executed in the terminal, including outputs.';

-- Helpful indexes to improve query performance
CREATE INDEX IF NOT EXISTS idx_terminal_commands_project ON public.terminal_commands(project_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_terminal_commands_session ON public.terminal_commands(session_id, created_at DESC);
