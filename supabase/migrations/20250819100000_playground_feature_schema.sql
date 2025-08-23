-- Migration: Playground chat feature schema
-- Creates lightweight chat tables for the unified Home → Playground experience
-- Mirrors agent chat schema patterns but without project scoping

-- Ensure required enum types exist (idempotent)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'message_sender') THEN
        CREATE TYPE message_sender AS ENUM ('user', 'ai');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'agent_message_type') THEN
        CREATE TYPE agent_message_type AS ENUM ('text', 'tool_request', 'tool_result', 'error', 'tool_in_progress');
    END IF;
END$$;

-- Playground chats (one per conversational thread for a user)
CREATE TABLE IF NOT EXISTS public.playground_chats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  title TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
COMMENT ON TABLE public.playground_chats IS 'Stores a conversational Playground session for a user.';

-- Playground chat messages (individual messages + tool metadata)
CREATE TABLE IF NOT EXISTS public.playground_chat_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  chat_id UUID NOT NULL REFERENCES public.playground_chats(id) ON DELETE CASCADE,
  sender message_sender NOT NULL,
  message_type agent_message_type NOT NULL DEFAULT 'text',
  content TEXT NOT NULL,
  tool_calls JSONB,      -- model-requested tool calls
  tool_results JSONB,    -- results of tool calls (sanitized)
  thoughts TEXT,         -- optional model thoughts (if enabled)
  attached_files JSONB,  -- optional array of attached files metadata
  sent_at TIMESTAMPTZ DEFAULT NOW()
);
COMMENT ON TABLE public.playground_chat_messages IS 'Stores Playground chat messages including tool usage and optional thoughts.';

-- Helpful indexes
CREATE INDEX IF NOT EXISTS idx_playground_chats_user ON public.playground_chats(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_playground_messages_chat ON public.playground_chat_messages(chat_id, sent_at ASC);

-- Playground artifacts: stores JSON outputs from tool calls (e.g., project cards, todo lists)
CREATE TABLE IF NOT EXISTS public.playground_artifacts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  chat_id UUID NOT NULL REFERENCES public.playground_chats(id) ON DELETE CASCADE,
  message_id UUID REFERENCES public.playground_chat_messages(id) ON DELETE SET NULL,
  artifact_type TEXT NOT NULL,
  key TEXT,
  data JSONB NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  last_modified TIMESTAMPTZ DEFAULT NOW()
);
COMMENT ON TABLE public.playground_artifacts IS 'Stores JSON artifacts produced by Playground tool calls (project cards, todo lists, templates, etc).';
CREATE INDEX IF NOT EXISTS idx_playground_artifacts_chat ON public.playground_artifacts(chat_id, last_modified DESC);
CREATE INDEX IF NOT EXISTS idx_playground_artifacts_message ON public.playground_artifacts(message_id);
CREATE INDEX IF NOT EXISTS idx_playground_artifacts_type ON public.playground_artifacts(artifact_type);
