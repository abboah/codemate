-- RLS for canvas_files

alter table if exists public.canvas_files enable row level security;

-- Select
drop policy if exists canvas_files_select on public.canvas_files;
create policy canvas_files_select on public.canvas_files
  for select using (
    public.has_playground_chat_access(chat_id)
  );

-- Insert
drop policy if exists canvas_files_insert on public.canvas_files;
create policy canvas_files_insert on public.canvas_files
  for insert with check (
    public.has_playground_chat_access(chat_id)
  );

-- Update
drop policy if exists canvas_files_update on public.canvas_files;
create policy canvas_files_update on public.canvas_files
  for update using (
    public.has_playground_chat_access(chat_id)
  ) with check (
    public.has_playground_chat_access(chat_id)
  );

-- Delete
drop policy if exists canvas_files_delete on public.canvas_files;
create policy canvas_files_delete on public.canvas_files
  for delete using (
    public.has_playground_chat_access(chat_id)
  );
