-- Migration: Add is_special flag to Playground chat messages
ALTER TABLE public.playground_chat_messages
ADD COLUMN IF NOT EXISTS is_special BOOLEAN DEFAULT FALSE;

-- Helpful index for queries that filter special prompts
CREATE INDEX IF NOT EXISTS idx_playground_messages_is_special
  ON public.playground_chat_messages(is_special);
