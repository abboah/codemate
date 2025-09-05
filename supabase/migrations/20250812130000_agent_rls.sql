-- Enable hierarchical RLS for agent-related tables and files
-- Helper: function to check whether the current auth user owns the project
create or replace function public.has_project_access(pid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.projects p
    where p.id = pid
      and p.user_id = auth.uid()
  );
$$;

-- Projects (owner-only access)
alter table if exists public.projects enable row level security;

drop policy if exists projects_select_own on public.projects;
create policy projects_select_own on public.projects
  for select using (user_id = auth.uid());

drop policy if exists projects_insert_own on public.projects;
create policy projects_insert_own on public.projects
  for insert with check (user_id = auth.uid());

drop policy if exists projects_update_own on public.projects;
create policy projects_update_own on public.projects
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists projects_delete_own on public.projects;
create policy projects_delete_own on public.projects
  for delete using (user_id = auth.uid());

-- Agent chats (scoped by project)
alter table if exists public.agent_chats enable row level security;

drop policy if exists agent_chats_select on public.agent_chats;
create policy agent_chats_select on public.agent_chats
  for select using (public.has_project_access(project_id));

drop policy if exists agent_chats_insert on public.agent_chats;
create policy agent_chats_insert on public.agent_chats
  for insert with check (
    public.has_project_access(project_id) and user_id = auth.uid()
  );

drop policy if exists agent_chats_update on public.agent_chats;
create policy agent_chats_update on public.agent_chats
  for update using (public.has_project_access(project_id))
  with check (public.has_project_access(project_id));

drop policy if exists agent_chats_delete on public.agent_chats;
create policy agent_chats_delete on public.agent_chats
  for delete using (public.has_project_access(project_id));

-- Agent chat messages (scoped via chat -> project)
alter table if exists public.agent_chat_messages enable row level security;

drop policy if exists chat_messages_select on public.agent_chat_messages;
create policy chat_messages_select on public.agent_chat_messages
  for select using (
    exists (
      select 1 from public.agent_chats c
      where c.id = agent_chat_messages.chat_id
        and public.has_project_access(c.project_id)
    )
  );

drop policy if exists chat_messages_insert on public.agent_chat_messages;
create policy chat_messages_insert on public.agent_chat_messages
  for insert with check (
    exists (
      select 1 from public.agent_chats c
      where c.id = chat_id and public.has_project_access(c.project_id)
    )
  );

drop policy if exists chat_messages_update on public.agent_chat_messages;
create policy chat_messages_update on public.agent_chat_messages
  for update using (
    exists (
      select 1 from public.agent_chats c
      where c.id = agent_chat_messages.chat_id
        and public.has_project_access(c.project_id)
    )
  ) with check (
    exists (
      select 1 from public.agent_chats c
      where c.id = agent_chat_messages.chat_id
        and public.has_project_access(c.project_id)
    )
  );

drop policy if exists chat_messages_delete on public.agent_chat_messages;
create policy chat_messages_delete on public.agent_chat_messages
  for delete using (
    exists (
      select 1 from public.agent_chats c
      where c.id = agent_chat_messages.chat_id
        and public.has_project_access(c.project_id)
    )
  );

-- Project files (scoped by project)
alter table if exists public.project_files enable row level security;

drop policy if exists project_files_select on public.project_files;
create policy project_files_select on public.project_files
  for select using (public.has_project_access(project_id));

drop policy if exists project_files_insert on public.project_files;
create policy project_files_insert on public.project_files
  for insert with check (public.has_project_access(project_id));

drop policy if exists project_files_update on public.project_files;
create policy project_files_update on public.project_files
  for update using (public.has_project_access(project_id))
  with check (public.has_project_access(project_id));

drop policy if exists project_files_delete on public.project_files;
create policy project_files_delete on public.project_files
  for delete using (public.has_project_access(project_id));

-- File checkpoints (scoped by project)
alter table if exists public.file_checkpoints enable row level security;

drop policy if exists file_checkpoints_select on public.file_checkpoints;
create policy file_checkpoints_select on public.file_checkpoints
  for select using (public.has_project_access(project_id));

drop policy if exists file_checkpoints_insert on public.file_checkpoints;
create policy file_checkpoints_insert on public.file_checkpoints
  for insert with check (public.has_project_access(project_id));

drop policy if exists file_checkpoints_update on public.file_checkpoints;
create policy file_checkpoints_update on public.file_checkpoints
  for update using (public.has_project_access(project_id))
  with check (public.has_project_access(project_id));

drop policy if exists file_checkpoints_delete on public.file_checkpoints;
create policy file_checkpoints_delete on public.file_checkpoints
  for delete using (public.has_project_access(project_id));

-- Checkpoint files (scoped via checkpoint -> project)
alter table if exists public.checkpoint_files enable row level security;

drop policy if exists checkpoint_files_select on public.checkpoint_files;
create policy checkpoint_files_select on public.checkpoint_files
  for select using (
    exists (
      select 1 from public.file_checkpoints fc
      where fc.id = checkpoint_files.checkpoint_id
        and public.has_project_access(fc.project_id)
    )
  );

drop policy if exists checkpoint_files_insert on public.checkpoint_files;
create policy checkpoint_files_insert on public.checkpoint_files
  for insert with check (
    exists (
      select 1 from public.file_checkpoints fc
      where fc.id = checkpoint_id
        and public.has_project_access(fc.project_id)
    )
  );

drop policy if exists checkpoint_files_update on public.checkpoint_files;
create policy checkpoint_files_update on public.checkpoint_files
  for update using (
    exists (
      select 1 from public.file_checkpoints fc
      where fc.id = checkpoint_files.checkpoint_id
        and public.has_project_access(fc.project_id)
    )
  ) with check (
    exists (
      select 1 from public.file_checkpoints fc
      where fc.id = checkpoint_files.checkpoint_id
        and public.has_project_access(fc.project_id)
    )
  );

drop policy if exists checkpoint_files_delete on public.checkpoint_files;
create policy checkpoint_files_delete on public.checkpoint_files
  for delete using (
    exists (
      select 1 from public.file_checkpoints fc
      where fc.id = checkpoint_files.checkpoint_id
        and public.has_project_access(fc.project_id)
    )
  );

-- File operations (scoped by project)
alter table if exists public.file_operations enable row level security;

drop policy if exists file_operations_select on public.file_operations;
create policy file_operations_select on public.file_operations
  for select using (public.has_project_access(project_id));

drop policy if exists file_operations_insert on public.file_operations;
create policy file_operations_insert on public.file_operations
  for insert with check (public.has_project_access(project_id));

drop policy if exists file_operations_update on public.file_operations;
create policy file_operations_update on public.file_operations
  for update using (public.has_project_access(project_id))
  with check (public.has_project_access(project_id));

drop policy if exists file_operations_delete on public.file_operations;
create policy file_operations_delete on public.file_operations
  for delete using (public.has_project_access(project_id)); 