# Build Section: Progress & Next Steps

This document outlines the recent achievements in the development of the "Build" section and the immediate plan for upcoming features.

## ✅ Recent Achievements (IDE & Agent Implementation)

We have successfully implemented the core IDE functionality and a foundational agent, transforming the build section into a powerful, interactive environment.

1.  **Full IDE Layout & Functionality:**
    -   **Hierarchical File Tree:** A `FileTreeView` now fetches and displays the project's file structure from the database, correctly handling nested files and folders.
    -   **Integrated Code Editor:** The `flutter_code_editor` is now fully integrated. Clicking a file in the tree opens its content in the `CodeEditorView` with appropriate syntax highlighting for the file type.
    -   **Dynamic & Stable Layout:** The IDE features a robust, three-pane layout (File Tree, Editor, Chat) using `multi_split_view`. The layout ratios are correctly configured, and minimum pane sizes prevent UI collapsing.

2.  **Advanced Agent Chat Interface:**
    -   **Rich Markdown Formatting:** The agent's responses are now parsed and rendered as Markdown, with custom builders for syntax-highlighted code blocks (`CodeBlockBuilder`) and inline code snippets.
    -   **Copy Functionality:** A "copy to clipboard" button is now present on the agent's messages for easy use of its output.
    -   **Tool Feedback:** The UI now provides clear feedback when the agent is executing a tool, showing "in-progress" and "completed" states.

3.  **Client-Side Function Calling:**
    -   The agent can now request file operations (`create_file`, `update_file_content`, `delete_file`) by responding with a structured JSON payload.
    -   The Flutter client correctly parses these requests and calls the appropriate methods on the `ProjectFilesProvider`.
    -   The `FileTreeView` automatically refreshes upon completion of these operations, creating a seamless feedback loop.

## 🚀 Next Steps: The Backend-Driven Agent & Terminal

With the client-side foundation complete, the next phase focuses on migrating logic to a secure backend and building out the terminal, as detailed in our new architecture plans.

### **Sprint 1: Implement Backend Function-Calling**

**Goal:** Refactor the agent's core logic to a secure Supabase Edge Function, moving away from the client-side implementation.

-   **Create the `agent-handler` Edge Function:** This TypeScript function will become the central orchestrator for all agent interactions.
-   **Define Formal Tool Declarations:** Implement the `create_file`, `update_file_content`, and `delete_file` tools using the official `@google/genai` SDK schema.
-   **Implement the Tool-Calling Loop:** The `agent-handler` will manage the conversation with Gemini, securely executing tool calls against the database when requested.
-   **Refactor Flutter Client:** The Flutter app will be updated to call this single `agent-handler` function instead of the Gemini API directly.

### **Sprint 2: The Foundational Terminal & AI Security Gate (V1)**

**Goal:** Build a "safe mode" terminal for file management and introduce an AI-powered security reviewer.

-   **Build the Terminal UI:** Create a `TerminalView` widget in Flutter that simulates a terminal interface.
-   **Create the `terminal-handler` Function:** This backend function will interpret and execute safe VFS commands like `ls`, `cat`, and `mkdir`.
-   **Develop the `code-reviewer` Function:** This critical security function will use Gemini to analyze code snippets for potential malicious patterns, acting as a prerequisite for any future code execution.

### **Sprint 3: Sandboxed Code Execution (V2)**

**Goal:** Integrate the Judge0 API to allow the agent and user to safely compile and run code.

-   **Integrate Judge0 API:** Enhance the `terminal-handler` to recognize a `run` command (e.g., `run main.py`).
-   **Implement the Execution Flow:** The handler will send the code to the Judge0 API for sandboxed execution.
-   **Handle Asynchronous Results:** The Flutter client will be updated to handle Judge0's asynchronous token-based system, polling for the result and displaying the `stdout` or `stderr` in the terminal.