# Copilot Instructions for this repo

This project is Robin — a Flutter web IDE backed by Supabase. It ships a 3‑pane layout (file tree, code editor, agent chat) plus a modal terminal. The backend is a set of Supabase Edge Functions that power agent tooling and a safe virtual file system.

## Architecture in 10 lines
- Frontend: Flutter (web-first) with Riverpod for state. Entry: `lib/main.dart`. Theme: `lib/themes/`.
- Screens/UX: `lib/screens/ide_page.dart` (3‑pane), components in `lib/components/ide/*`:
  - `file_tree_view.dart`, `code_editor_view.dart`, `agent_chat_view.dart`, `terminal_view.dart`.
- Agent chat renders segmented markdown and tool results (diffs, search matches) in `agent_chat_view.dart`.
- Terminal is a safe VFS UI; path suggestions and listing read from `project_files` via Supabase (`terminal_view.dart`).
- Backend: Supabase Edge Functions in `supabase/functions/`:
  - `agent-handler/` (full tools: read/create/update/delete, search, lint_check, analyze_code)
  - `agent-chat-handler/` (Ask/read-only flows: read_file, search, analyze_document/code)
  - `terminal-handler/` (safe ops: ls/cd/pwd/cat/mkdir/touch/rm)
- Shared tool schemas and guidance live in `supabase/functions/_shared/tools.ts`.

## Build, run, test (Linux/zsh)
- Install deps: `flutter pub get`
- Run web dev: `flutter run -d chrome`
- Build web: `flutter build web --release`
- Lint/analyze: `flutter analyze`; format: `flutter format lib/`
- Tests: `flutter test` (see `test/widget_test.dart`)
- Supabase: `supabase db push`; deploy: `supabase functions deploy <name>`

## Configuration and env
- Supabase URL is derived in `lib/supabase_config.dart` (env `SUPABASE_URL` -> functions origin via host rewrite). Prefer using this utility over hardcoding.
- Edge Function secrets (e.g., `GEMINI_API_KEY`, `GEMINI_API_KEY_2`) are set via `supabase functions secrets set ...` (see `README.md`). Do not commit keys.
- WebContainers/live preview require COOP/COEP headers; `web/_headers` and `devserver.js` show working values.

## Code style and patterns (Dart/Flutter)
- Imports order: `dart:` → `package:` → relative (example in `AGENTS.md`).
- Naming: Classes PascalCase; variables/methods camelCase; files snake_case.
- Widgets: Prefer `ConsumerStatefulWidget` + `super.key`; use `const` constructors when possible.
- State: Riverpod providers for services/state; use `Consumer`/`WidgetRef` to read/watch.
- Error handling: guard async with try/catch; check `mounted` before `setState`.

## Working with agents & tools
- Ask mode uses `agent-chat-handler` and is read-only (primarily `read_file`, `search`, `analyze_*`).
- Full agent mode uses `agent-handler` and can propose file edits (create/update/delete). Guidance text for tools is generated in `_shared/tools.ts` (`buildToolboxGuidance`).
- UI surfaces tool results: diff previews open the target file; search results show file/line snippets (see `agent_chat_view.dart`).

## Data model touchpoints
- Code files live in Supabase table `project_files` (fields include `path`, `content`). Terminal path suggestions and search iterate over this content.
- Agent chat/todo/artifacts are persisted (see migrations under `supabase/migrations/`). Review `README.md` for table names like `agent_chats`, `agent_chat_messages`.

## When adding features
- Place page-level widgets in `lib/screens/`, reusable pieces in `lib/components/`, app logic/services in `lib/services/`, state in `lib/providers/`.
- If integrating with agents, add/extend tools in `_shared/tools.ts` and wire handlers in the relevant Edge Function.
- Keep edits minimal and idiomatic; prefer full-file updates via the existing patterns over ad-hoc diffs on the backend.
