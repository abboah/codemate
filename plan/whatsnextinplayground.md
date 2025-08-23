# Playground: recent wins and what's next

## recent accomplishments

We evolved the Playground into a fast, stream-first chat + build experience with inline tooling and artifact management:

- Streaming UX
  - NDJSON streaming end-to-end; model text and “thoughts” now stream live.
  - Thoughts render in a collapsible panel and persist per AI message.
- Inline tools (rich, contextual)
  - Introduced inline tool markers during streaming (`[tool:<id>]`) so tool activity renders inline with the text instead of a single block at the top.
  - Live tool state updates: “in-progress” chips switch to results without refreshing the chat.
- Artifacts pipeline
  - Added `playground_artifacts` (id, chat_id, message_id, type, data, timestamps) and linked artifacts to the AI message that produced them.
  - New read tools: `artifact_read`, `canvas_read_file_by_id`; previews now show friendly titles instead of raw IDs.
- Project card + To‑Do lists
  - Simplified project card schema (name, summary, stack, key_features, can_implement_in_canvas), with a polished card and static glow.
  - To‑Do lists render as beautiful cards with counts, notes, and completion percentage.
- Canvas & artifacts controls
  - Canvas button appears only when canvas files exist and opens the most recent canvas directly.
  - Artifacts button opens the latest artifact previews instantly (no dropdown).
  - Canvas title pill shows a friendly “Title · type” label with a custom dropdown/chooser.
- Conversation context
  - The last 3–4 messages and their tool_results are folded into the system/context for better follow-up (thoughts excluded).
- Feedback
  - Message feedback (like/dislike) persists to the database and updates the UI optimistically.

## next steps

- Visual/interaction polish
  - Improve animation cadence (subtle motion, parallax glows, delightful micro‑interactions).
  - Modernize visual language: elevated cards, depth, softened dividers, and dynamic color accents.
- Instant code preview (HTML/CSS/JS)
  - Integrate `webview_flutter` (and `webview_flutter_web` on web) to run JS/HTML snippets safely for instant previews of mini‑projects/components.
  - Add a “Run in Preview” action for generated snippets (from tools or inline code blocks).
- Canvas editing
  - Inline editing with save/revert, dirty-state prompts, and auto-restore on errors.
  - Visual diffs for tool-driven updates; highlight changed regions.
- Tool depth
  - Snippet-to-canvas: apply generated code directly to a chosen canvas file with attribution.
  - Fuzzy search across canvas files and artifacts; preview before insertion.
- Resilience
  - Backpressure-aware streaming, transient error retries, and partial failure UI.

---

## Technical approach: Inline code previews (replicable)

This section documents a reusable pattern for inline tool rendering and instant code previews.

1) Inline tool rendering with stream markers
- Server (Edge Function) emits a plain‑text marker when the model requests a tool:
  - Insert a special token into the streamed text, e.g. `\n\n[tool:<id>]\n\n` and also emit structured events:
    - `tool_in_progress` { id, name }
    - `tool_result` { id, name, result }
- Client parses the streamed text into “segments”: normal text, fenced code, and tool markers.
  - A light parser splits by code fences and recognizes `[tool:<id>]` lines.
  - For each tool marker segment, the UI looks up matching tool events by id and renders the proper preview widget inline.
  - If an event hasn’t arrived yet, show an inline “running…” chip; it updates when the result arrives.

2) Segmented Markdown renderer
- We avoid heavy Markdown builders by splitting the message into segments first:
  - Text segments render as Markdown (with a concise style sheet).
  - Code segments render via a dedicated code block widget (syntax highlighted, copy affordance).
  - Tool marker segments render dedicated preview widgets (e.g., Project Card, To‑Do, Canvas Read, File Edits).
- This makes insertion points deterministic and mapping to tool ids trivial.

3) Artifact‑backed data flow
- Tool outputs that should be reusable are persisted as artifacts (`playground_artifacts`).
- We store only titles and IDs in the system prompt for discoverability; tools can later read full contents by ID (`artifact_read`).
- On streaming end, we attach the `message_id` to any artifacts created during the turn for auditability and UX (preview from message).

4) Instant HTML/CSS/JS previews via WebView (Flutter)
- Technical plan:
  - Use `webview_flutter` on mobile/desktop; on web, rely on `webview_flutter_web` (or a fallback `HtmlElementView` + sandboxed iframe).
  - For security and portability, prefer loading previews via `data:` URLs (or a tiny local web server in dev) and sandboxed iframes on web.
  - Inject snippet into a minimal HTML template that includes:
    - A <style> block for CSS, a <script> block for JS (scoped to the preview context)
    - A postMessage bridge (WebMessageChannel) to capture console, runtime errors, and emit back to Flutter for logging.
  - Add a small debounce so updating the snippet doesn’t thrash the WebView; refresh only on pause of typing or when the user clicks Run.
- Replication checklist:
  - Build a `PreviewController` that accepts a snippet { html, css, js }, produces an HTML data URL, and `loadUrl()` on the WebView.
  - Create a “Run in Preview” button under code blocks; when clicked, open/refresh the preview panel with the current snippet.
  - On web, set iframe sandbox attributes (allow-scripts, allow-modals if needed) and block navigation/remote requests.
  - Capture console/error events via `onConsoleMessage`/`onWebResourceError` (platform-dependent) and surface them inline for fast iteration.

5) Friendly labels for search/read
- When rendering read/search tool results inline, always show human-friendly labels (strip paths and extensions) and hide internal IDs.
- Project cards use `data.name`; To‑Do lists use `data.title`.

This stack is modular: keep the segmented renderer, the inline tool event bus, and the preview controller independently testable so other screens (Build, Learn) can adopt the same pattern.
