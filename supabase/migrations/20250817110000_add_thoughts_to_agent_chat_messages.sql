-- Migration: Add `thoughts` column to agent_chat_messages
-- Date: 2025-08-17

ALTER TABLE public.agent_chat_messages
	ADD COLUMN IF NOT EXISTS thoughts TEXT; -- Stores the model's internal chain-of-thought-like stream (if enabled)

COMMENT ON COLUMN public.agent_chat_messages.thoughts IS 'Optional streamed thinking text emitted by the model when thinking is enabled.';

