-- Migration: Canvas files for Playground
-- Creates public.canvas_files tied to playground_chats, similar to project_files

create table if not exists public.canvas_files (
  id uuid primary key default gen_random_uuid(),
  chat_id uuid not null references public.playground_chats(id) on delete cascade,
  path text not null,
  content text not null,
  created_at timestamptz default now(),
  last_modified timestamptz default now(),
  unique(chat_id, path)
);

comment on table public.canvas_files is 'Represents per-chat canvas files for the Playground, similar to project_files but scoped to a chat.';

create index if not exists idx_canvas_files_chat on public.canvas_files(chat_id, last_modified desc);
