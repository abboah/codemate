-- RLS for Playground tables
-- Helper: function to check whether current auth user can access the playground chat
create or replace function public.has_playground_chat_access(cid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.playground_chats c
    where c.id = cid
      and c.user_id = auth.uid()
  );
$$;

-- Enable RLS
alter table if exists public.playground_chats enable row level security;
alter table if exists public.playground_chat_messages enable row level security;
alter table if exists public.playground_artifacts enable row level security;

-- playground_chats policies (owner-only)
 drop policy if exists playground_chats_select_own on public.playground_chats;
create policy playground_chats_select_own on public.playground_chats
  for select using (user_id = auth.uid());

 drop policy if exists playground_chats_insert_own on public.playground_chats;
create policy playground_chats_insert_own on public.playground_chats
  for insert with check (user_id = auth.uid());

 drop policy if exists playground_chats_update_own on public.playground_chats;
create policy playground_chats_update_own on public.playground_chats
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());

 drop policy if exists playground_chats_delete_own on public.playground_chats;
create policy playground_chats_delete_own on public.playground_chats
  for delete using (user_id = auth.uid());

-- playground_chat_messages policies (scoped via chat -> user)
 drop policy if exists playground_messages_select on public.playground_chat_messages;
create policy playground_messages_select on public.playground_chat_messages
  for select using (
    exists (
      select 1 from public.playground_chats c
      where c.id = playground_chat_messages.chat_id
        and c.user_id = auth.uid()
    )
  );

 drop policy if exists playground_messages_insert on public.playground_chat_messages;
create policy playground_messages_insert on public.playground_chat_messages
  for insert with check (
    exists (
      select 1 from public.playground_chats c
      where c.id = chat_id and c.user_id = auth.uid()
    )
  );

 drop policy if exists playground_messages_update on public.playground_chat_messages;
create policy playground_messages_update on public.playground_chat_messages
  for update using (
    exists (
      select 1 from public.playground_chats c
      where c.id = playground_chat_messages.chat_id
        and c.user_id = auth.uid()
    )
  ) with check (
    exists (
      select 1 from public.playground_chats c
      where c.id = playground_chat_messages.chat_id
        and c.user_id = auth.uid()
    )
  );

 drop policy if exists playground_messages_delete on public.playground_chat_messages;
create policy playground_messages_delete on public.playground_chat_messages
  for delete using (
    exists (
      select 1 from public.playground_chats c
      where c.id = playground_chat_messages.chat_id
        and c.user_id = auth.uid()
    )
  );

-- playground_artifacts policies (scoped by chat_id)
 drop policy if exists playground_artifacts_select on public.playground_artifacts;
create policy playground_artifacts_select on public.playground_artifacts
  for select using (
    public.has_playground_chat_access(chat_id)
  );

 drop policy if exists playground_artifacts_insert on public.playground_artifacts;
create policy playground_artifacts_insert on public.playground_artifacts
  for insert with check (
    public.has_playground_chat_access(chat_id)
  );

 drop policy if exists playground_artifacts_update on public.playground_artifacts;
create policy playground_artifacts_update on public.playground_artifacts
  for update using (
    public.has_playground_chat_access(chat_id)
  ) with check (
    public.has_playground_chat_access(chat_id)
  );

 drop policy if exists playground_artifacts_delete on public.playground_artifacts;
create policy playground_artifacts_delete on public.playground_artifacts
  for delete using (
    public.has_playground_chat_access(chat_id)
  );
