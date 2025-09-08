# Robin – AI-Driven Web IDE (Flutter + Supabase)

Robin is a modern, AI-assisted IDE-like experience built with Flutter and Supabase. It combines a file explorer, a code editor, and an AI agent chat in a three-pane layout, plus a terminal for safe virtual file system operations. Robin helps you scaffold and iterate on projects with full visibility and control.

## Key Features

- IDE Layout
  - Nested File Tree with expand/collapse
  - Code Editor with syntax highlighting, autosave, and resilient file-switching
  - Agent Chat with rich markdown, code blocks, inline code, and copy actions
- AI Agent Workflows
  - Agent vs Ask modes toggle
  - Ask mode is read-only (only `read_file`), powered by `agent-chat-handler`
  - Attach Code dialog: searchable multi-select of project files to include as context
  - Inline `@file` mentions to quickly attach files from the editor tree
  - Tool results with diff previews; clicking a diff opens the file with a diff overlay (full-height, scrollable)
- Terminal (V1)
  - Modal terminal with prompt, history, sessions drawer, and a subtle wallpaper
  - Path suggestions: type `/` to list current dir; Tab to autocomplete; supports drilling deeper
  - Safe commands: `ls`, `cd`, `pwd`, `cat`, `mkdir`, `touch`, `rm` via `terminal-handler`
  - Persistent command history in `terminal_sessions` and `terminal_commands`

## Screens & Components

- `lib/screens/ide_page.dart`: Main three-pane layout
- `lib/components/ide/file_tree_view.dart`: Nested explorer
- `lib/components/ide/code_editor_view.dart`: Editor view
- `lib/components/ide/agent_chat_view.dart`: Agent chat pane
- `lib/components/ide/diff_preview.dart`: Unified diff preview (JetBrains Mono)
- `lib/components/ide/terminal_view.dart`: Terminal modal with sessions and path suggestions

## Backend (Supabase Edge Functions)

- `supabase/functions/agent-handler/`: Full agent tools (create/update/delete/read)
- `supabase/functions/agent-chat-handler/`: Ask mode (read-only `read_file`), uses `GEMINI_API_KEY_2`
- `supabase/functions/terminal-handler/`: Safe VFS operations for terminal
- Planned:
  - `supabase/functions/code-reviewer/`: AI security reviewer (uses `GEMINI_API_KEY_3`)
  - `supabase/functions/submission-retriever/`: Judge0 result polling

## Database Schema

See `supabase/migrations/20250806100000_build_feature_schema.sql`.

- Core: `projects`, `project_files`, `agent_chats`, `agent_chat_messages` (with `attached_files` JSONB)
- File history and checkpoints
- Terminal: `terminal_sessions`, `terminal_commands`

## Getting Started

### Prerequisites
- Flutter (stable)
- Supabase CLI
- A Supabase project with URL and Anon key

### Setup
1. Clone the repo and install deps
```bash
flutter pub get
```
2. Configure Supabase environment
```bash
supabase login
supabase link --project-ref YOUR_PROJECT_REF
```
3. Run database migrations
```bash
supabase db push
```
4. Set secrets
```bash
supabase functions secrets set GEMINI_API_KEY=YOUR_KEY
supabase functions secrets set GEMINI_API_KEY_2=YOUR_ASK_MODE_KEY
# Later for reviewer:
# supabase functions secrets set GEMINI_API_KEY_3=YOUR_REVIEWER_KEY
```
5. Deploy functions
```bash
supabase functions deploy agent-handler
supabase functions deploy agent-chat-handler
supabase functions deploy terminal-handler
```
6. Run the app
```bash
flutter run -d chrome
```

## Usage Notes

## Live Preview (WebContainers) Setup

WebContainers require cross-origin isolation. To run locally or deploy, ensure COOP/COEP headers are set.

### Local testing

1. Build the Flutter web app.
2. Serve the built `build/web` with a server that sends headers:

- Cross-Origin-Opener-Policy: same-origin
- Cross-Origin-Embedder-Policy: require-corp
- Cross-Origin-Resource-Policy: cross-origin
- X-Content-Type-Options: nosniff

3. Optionally use `node devserver.js 8080 build/web` (provided in repo).

### Deploying

Configure your host to send the headers above for all files. For Netlify/Cloudflare Pages, include `web/_headers` in the output or add rules in UI.

## Learn Feature (Planned)
See `plan/learn_page_plan.md`.
- Schema for courses, topics, enrollments, notes, quizzes, facts, practice problems, and topic chats is defined.
- UI will adopt Material 3 and align with the app’s aesthetic (glassmorphism/gradients) for a cohesive experience.
- Roadmap:
  - Phase 1: Create DB tables and seed initial courses
  - Phase 2: Topic content generation and note rendering
  - Phase 3: Topic chat and quizzes with progress tracking

## Roadmap
- Sprint 2: Code Reviewer function and editor/terminal integration
- Sprint 3: Judge0 sandboxed execution via terminal `run`
- Enhancements: session rename, persist explorer state, improved diffs, tokenized mentions

## Contributing
PRs and issues welcome. Please follow the code style guidelines and keep changes well-scoped.

## License
MIT
