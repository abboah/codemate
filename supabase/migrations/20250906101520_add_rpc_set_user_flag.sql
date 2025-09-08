-- RPC to set a single onboarding flag in user_settings.other_prefs for the current user
create or replace function public.set_user_flag(flag_key text, flag_value boolean)
returns void
language sql
security definer
set search_path = public
as $$
  update public.user_settings
  set other_prefs = other_prefs || jsonb_build_object(flag_key, flag_value)
  where user_id = auth.uid();
$$;
