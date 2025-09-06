-- Migration: Canvas file versions (checkpointing)
-- Creates public.canvas_file_versions and triggers to snapshot on insert/update of canvas_files

-- Table: canvas_file_versions
create table if not exists public.canvas_file_versions (
  id uuid primary key default gen_random_uuid(),
  chat_id uuid not null references public.playground_chats(id) on delete cascade,
  file_id uuid not null references public.canvas_files(id) on delete cascade,
  path text not null,
  version_number integer not null,
  content text not null,
  description text,
  file_type text,
  can_implement_in_canvas boolean default false,
  created_at timestamptz default now(),
  created_by uuid default auth.uid()
);

-- Optional check on file_type
do $$ begin
  alter table public.canvas_file_versions
    add constraint canvas_file_versions_file_type_check
    check (file_type is null or file_type in ('code','document'));
exception when duplicate_object then null; end $$;

-- Uniqueness: one row per file_id + version number (snapshot)
create unique index if not exists uq_canvas_file_versions_file_ver on public.canvas_file_versions(file_id, version_number);
create index if not exists idx_canvas_file_versions_chat_path_ver on public.canvas_file_versions(chat_id, path, version_number desc);

-- RLS
alter table if exists public.canvas_file_versions enable row level security;

-- Select policy: anyone with access to the chat can see versions
drop policy if exists canvas_file_versions_select on public.canvas_file_versions;
create policy canvas_file_versions_select on public.canvas_file_versions
  for select using (
    public.has_playground_chat_access(chat_id)
  );

-- Insert policy: only via application when user has access
drop policy if exists canvas_file_versions_insert on public.canvas_file_versions;
create policy canvas_file_versions_insert on public.canvas_file_versions
  for insert with check (
    public.has_playground_chat_access(chat_id)
  );

-- (No update policy by default to keep snapshots immutable)

-- Optional delete policy (allow owners to prune)
drop policy if exists canvas_file_versions_delete on public.canvas_file_versions;
create policy canvas_file_versions_delete on public.canvas_file_versions
  for delete using (
    public.has_playground_chat_access(chat_id)
  );

-- Trigger functions to snapshot canvas_files on insert and update
create or replace function public.snap_canvas_file_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.canvas_file_versions(
    chat_id, file_id, path, version_number, content, description, file_type, can_implement_in_canvas, created_by
  ) values (
    NEW.chat_id, NEW.id, NEW.path, coalesce(NEW.version_number, 1), NEW.content, NEW.description, NEW.file_type, coalesce(NEW.can_implement_in_canvas, false), auth.uid()
  )
  on conflict (file_id, version_number) do nothing;
  return NEW;
end;
$$;

create or replace function public.snap_canvas_file_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Snapshot the row BEFORE it is updated (save OLD at its current version)
  insert into public.canvas_file_versions(
    chat_id, file_id, path, version_number, content, description, file_type, can_implement_in_canvas, created_by
  ) values (
    OLD.chat_id, OLD.id, OLD.path, coalesce(OLD.version_number, 1), OLD.content, OLD.description, OLD.file_type, coalesce(OLD.can_implement_in_canvas, false), auth.uid()
  )
  on conflict (file_id, version_number) do nothing;
  return NEW;
end;
$$;

-- Attach triggers
drop trigger if exists trg_snap_canvas_file_insert on public.canvas_files;
create trigger trg_snap_canvas_file_insert
after insert on public.canvas_files
for each row execute function public.snap_canvas_file_insert();

drop trigger if exists trg_snap_canvas_file_update on public.canvas_files;
create trigger trg_snap_canvas_file_update
before update on public.canvas_files
for each row execute function public.snap_canvas_file_update();
