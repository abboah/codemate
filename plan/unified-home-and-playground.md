# Unified Home → Playground Plan

This document defines the UX, architecture, and implementation plan for a minimal Home page that routes user input directly into the Playground (chat-driven builder), where the initial prompt is immediately sent and streamed.

## Goals

- Keep Home lightweight and welcoming (first-time onboarding, Build/Learn CTAs, single input).
- Use a dedicated Playground page as the primary workspace (chat + canvas), preserving clear mental models and simpler navigation.
- When a user types on Home and submits, navigate to Playground and auto-send that prompt server-side with streaming.
- Support deep-linking to Playground with a pre-seeded prompt.

## Why this approach

- Separation of concerns: Home helps users start; Playground is where work happens.
- Avoids heavy widget trees on the default route and keeps back navigation predictable.
- Easy onboarding for new users and fast entry for returning users.
- Scales to multi-session and deep links without cluttering Home.

## Top-level UX

- Home
  - Minimal hero area, two CTAs (Build, Learn), and a single input bar.
  - If the user submits text, immediately navigate to Playground with that text as `initialPrompt`.
  - First-time users see a brief tour overlay explaining capabilities and how input flows into the Playground.
- Playground (ChatPage + Chatbot + Canvas)
  - Accepts an optional `initialPrompt`.
  - If present, auto-sends once and starts streaming server-side results.
  - Offers "New Activity" to clear context and start fresh without leaving Playground.
  - Optional: "Resume last session" chip for returning users.

## Routing & data flow

- Contract
  - Home → Playground: `initialPrompt: String?`
  - Playground → Chatbot: `initialPrompt: String?` (one-time consumption)
- Behavior
  - On Home submit: `Navigator.push(ChatPage(initialPrompt: text))`.
  - In Chatbot: if `initialPrompt != null && !seedConsumed`, dispatch one send, set `seedConsumed = true`.
  - Deep link: `/playground?q=...` populates `initialPrompt` from query params.

## Server-side requests (authoritative)

- Keep all model calls on the server via Supabase Edge Functions.
- Use existing streaming endpoints (NDJSON) and async iterable pattern.
- Client sends the initial prompt as the first message of a new (or resumed) Playground session.
- Persist message, tool events, and thoughts (if enabled) per the existing schema.

## Client responsibilities

- Home
  - Collect input and navigate with `initialPrompt`.
  - Preserve Build/Learn CTAs.
  - Show first-time tour when `userProfile.hasCompletedOnboarding == false`.
- Playground
  - Accept `initialPrompt`.
  - Auto-dispatch the first send on mount exactly once; guard against double send.
  - Stream and render: text, tool results, thoughts (if requested), canvas updates.
  - Provide "New Activity" to start a fresh session.

## State management

- Riverpod
  - A single source of truth provider for Playground session state (messages, streaming status, tool results).
  - A lightweight controller for Home input (TextEditingController) — ephemeral.
- One-time seed
  - `seedConsumed` boolean in Chatbot’s state to avoid duplicate sends on rebuild/hot-restart.

## Deep links (optional v1.1)

- Add route `/playground?q=...`.
- On route parsing, pass `q` to `ChatPage(initialPrompt: q)`.
- For web refresh, this allows immediate replay of the user’s query.

## Back navigation

- From Playground: normal `maybePop()` to return to Home.
- From Home: normal stack root — no special logic needed.
- Keep Learn page’s custom back fallback isolated to Learn to avoid conflicts.

## Telemetry & product signals

- Log Home → Playground entries with prompt length buckets and CTA clicks (Build/Learn).
- In Playground, track: time to first token, tokens streamed, tool usage, errors.
- Use anonymized session IDs to correlate events across a single Playground session.

## Accessibility

- Ensure the Home input has a descriptive label and supports keyboard submit (Enter).
- Maintain visible focus states for input and CTAs.
- Live region for streaming in the Playground so screen readers are updated progressively.

## Performance

- Keep Home page light (no heavy providers or streams).
- Consider pre-warming the Edge Function DNS/connection after Home renders to reduce TTFB.
- Use BigShimmer/MiniWave loaders in Playground for perceived responsiveness.

## Error handling

- Empty input on Home: disable submit or show an inline hint.
- Network failure on initial send: show retry in Playground with the preserved prompt.
- Server 429/5xx: exponential backoff, surface a friendly error and suggest trying again.

## Incremental rollout

- Phase 1
  - Add `initialPrompt` to ChatPage and Chatbot.
  - Wire Home input to navigate with `initialPrompt`.
  - Guard auto-send with `seedConsumed`.
- Phase 2
  - Deep-link support with `q` param.
  - "Resume last session" chip on Home (reads last session ID).
- Phase 3
  - A/B test Home prompts vs direct landing on Playground for power users.
  - Pre-warm server-call on Home mount.

## Acceptance criteria

- Submitting input on Home navigates to Playground and starts streaming the prompt.
- No double-send on rebuilds/hot reloads.
- Build/Learn CTAs unchanged and functional.
- Learn back behavior remains isolated; no freezes introduced.
- Deep link `/playground?q=...` sends the query on load (when enabled).

## Risks & mitigations

- Double send: guard with a one-time seed flag in Chatbot.
- Back-stack confusion: keep Playground in its own route; don’t turn Home into Playground.
- Slow first token: pre-warm DNS/connection or show shimmers promptly.

## Implementation notes (dev-facing)

- ChatPage: `const ChatPage({ Key? key, this.initialPrompt }); final String? initialPrompt;`.
- Chatbot: store `bool _seedConsumed = false;` and dispatch first send in `didChangeDependencies()` or `initState()` when `!_seedConsumed`.
- Home input: `Navigator.push(MaterialPageRoute(builder: (_) => ChatPage(initialPrompt: text)))`.
- Optional: support `go_router` query parsing for `/playground?q=`.

## Out of scope (for now)

- Turning Home into a full Playground.
- Multi-session dashboard on Home (can be added later as "Recent sessions").

