-- Create storage bucket and RLS policies for user uploads
-- This migration creates a private bucket 'user-uploads' (if it doesn't exist)
-- and policies that allow authenticated users to manage files under their own
-- prefix: <uid>/*

-- 1) Ensure bucket exists
insert into storage.buckets (id, name, public)
select 'user-uploads', 'user-uploads', false
where not exists (
  select 1 from storage.buckets where id = 'user-uploads'
);

-- 2) RLS note: storage.objects already has RLS enabled in Supabase-managed schemas.
--    Attempting to enable/disable RLS here can fail with "must be owner of table objects".
--    We skip altering RLS and only add policies below.

-- 3) Policies: allow authenticated users to CRUD their own objects under their uid prefix
--    NOTE: Creating policies may still require elevated privileges. If your SQL editor
--    role is restricted, use the Storage UI to add these policies instead (same expressions).

-- Read
create policy "Users can read own objects in user-uploads"
  on storage.objects for select
  using (
    bucket_id = 'user-uploads'
    and auth.role() = 'authenticated'
    and (owner = auth.uid() or (position(auth.uid()::text || '/' in name) = 1))
  );

-- Insert
create policy "Users can insert own objects in user-uploads"
  on storage.objects for insert
  with check (
    bucket_id = 'user-uploads'
    and auth.role() = 'authenticated'
    and (owner = auth.uid() or (position(auth.uid()::text || '/' in name) = 1))
  );

-- Update
create policy "Users can update own objects in user-uploads"
  on storage.objects for update
  using (
    bucket_id = 'user-uploads'
    and auth.role() = 'authenticated'
    and (owner = auth.uid() or (position(auth.uid()::text || '/' in name) = 1))
  )
  with check (
    bucket_id = 'user-uploads'
    and auth.role() = 'authenticated'
    and (owner = auth.uid() or (position(auth.uid()::text || '/' in name) = 1))
  );

-- Delete
create policy "Users can delete own objects in user-uploads"
  on storage.objects for delete
  using (
    bucket_id = 'user-uploads'
    and auth.role() = 'authenticated'
    and (owner = auth.uid() or (position(auth.uid()::text || '/' in name) = 1))
  );

-- Note: We rely on the client to prefix keys with `auth.uid()` as implemented
-- in the app. This keeps ownership checks simple and secure.
