# User Onboarding Flags: Frontend Usage

This document explains how to read and update the new onboarding/tutorial flags stored in `public.user_settings.other_prefs` and suggests a simple pattern to build UI components that react to these flags.

## Overview

- Table: `public.user_settings`
- Column: `other_prefs` (JSONB)
- Default flags (all default to `false` on creation/migration):
  - `has_seen_home_screen`
  - `has_seen_playground_page`
  - `has_seen_build_page`
  - `has_seen_learn_page`
  - `has_seen_sidebar_tutorial`
  - `has_seen_brainstorm_modal` (Build)
  - `has_seen_describe_modal` (Build)
  - `has_seen_ide` (Build)
  - `has_seen_terminal` (Build)
  - `has_seen_canvas` (Playground)
  - `has_seen_enrolled_courses_page` (Playground)
  - `has_seen_topic_interaction_modal` (Playground)

## Reading flags (Flutter + Supabase)

Use the authenticated user id and query `public.user_settings` for `other_prefs`.

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

Future<Map<String, dynamic>> fetchOtherPrefs() async {
  final uid = supabase.auth.currentUser?.id;
  if (uid == null) throw Exception('Not authenticated');
  final row = await supabase
      .from('user_settings')
      .select('other_prefs')
      .eq('user_id', uid)
      .single();
  return Map<String, dynamic>.from(row['other_prefs'] ?? {});
}
```

## Updating a single flag

Use Postgres JSONB concatenation (`||`) to update a single key without clobbering others.

```dart
Future<void> setFlag(String key, bool value) async {
  final uid = supabase.auth.currentUser?.id;
  if (uid == null) throw Exception('Not authenticated');
  await supabase
      .from('user_settings')
      .update({
        // NOTE: Use PostgREST "raw" to merge JSONB: other_prefs = other_prefs || '{"key": value}'
        'other_prefs': supabase.rpc(
          // If you prefer a SQL function, you can also add one. Below is inline guidance.
          // For simple cases use PostgREST filter with raw SQL via PostgREST is limited,
          // so we recommend a dedicated RPC for complex merges (see RPC option below).
          '',
        )
      })
      .eq('user_id', uid);
}
```

Because PostgREST's JSONB merge via raw expressions isn't supported directly in the normal `.update({...})` call, prefer one of these:

### Option A: Lightweight RPC to merge JSONB

Create a SQL function (RPC) that merges the flag into `other_prefs`:

```sql
create or replace function public.set_user_flag(flag_key text, flag_value boolean)
returns void
language sql
security definer
as $$
  update public.user_settings
  set other_prefs = other_prefs || jsonb_build_object(flag_key, flag_value)
  where user_id = auth.uid();
$$;
```

Then in Flutter:

```dart
Future<void> setFlag(String key, bool value) async {
  await supabase.rpc('set_user_flag', params: {
    'flag_key': key,
    'flag_value': value,
  });
}
```

### Option B: Read-modify-write client-side

If your RLS allows it, read `other_prefs`, modify locally, then write it back:

```dart
Future<void> setFlagClientSide(String key, bool value) async {
  final uid = supabase.auth.currentUser?.id;
  if (uid == null) throw Exception('Not authenticated');
  final row = await supabase
      .from('user_settings')
      .select('other_prefs')
      .eq('user_id', uid)
      .single();
  final prefs = Map<String, dynamic>.from(row['other_prefs'] ?? {});
  prefs[key] = value;
  await supabase
      .from('user_settings')
      .update({'other_prefs': prefs})
      .eq('user_id', uid);
}
```

## Example: Auto-show a one-time tooltip

```dart
class OneTimeTooltip extends StatefulWidget {
  final String flagKey; // e.g. 'has_seen_playground_page'
  final Widget child;   // The UI that the tooltip is attached to
  final String message; // Tooltip text
  const OneTimeTooltip({super.key, required this.flagKey, required this.child, required this.message});

  @override
  State<OneTimeTooltip> createState() => _OneTimeTooltipState();
}

class _OneTimeTooltipState extends State<OneTimeTooltip> {
  bool _show = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await fetchOtherPrefs();
    final seen = prefs[widget.flagKey] == true;
    if (!seen && mounted) setState(() => _show = true);
  }

  Future<void> _dismiss() async {
    setState(() => _show = false);
    await setFlag(widget.flagKey, true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_show) return widget.child;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        Positioned(
          top: -8,
          right: -8,
          child: Material(
            color: Colors.black.withOpacity(0.85),
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: _dismiss,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(widget.message, style: const TextStyle(color: Colors.white)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
```

Usage:

```dart
OneTimeTooltip(
  flagKey: 'has_seen_canvas',
  message: 'Tip: Use the Code/Preview toggle to switch views',
  child: SomeCanvasHeaderWidget(),
)
```

## Suggested RLS

Make sure your RLS permits the authenticated user to read/update their own row in `public.user_settings`.

```sql
alter table public.user_settings enable row level security;

create policy "user can select own settings" on public.user_settings
  for select using (auth.uid() = user_id);

create policy "user can update own settings" on public.user_settings
  for update using (auth.uid() = user_id);
```

## QA Checklist
- Migrations applied: `supabase db push`
- Existing users have `other_prefs` populated with defaults (all false)
- New users get defaults set automatically via `create_user_settings.sql`
- Frontend can read and set flags (RPC or client-side merge)
- UI components check flags to conditionally show tooltips/guides
