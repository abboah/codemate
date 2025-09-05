# Plan: Terminal, AI Security & Sandboxed Code Execution

This document details the implementation of a secure, simulated terminal within the Codemate IDE. It is broken into two major versions:

*   **V1: The Foundational Terminal & AI Security Gate.** This version establishes a "safe mode" terminal that can manage the virtual file system and introduces an AI-powered security reviewer to analyze code for potential threats.
*   **V2: Live Code Execution with Judge0.** This version integrates a sandboxed execution engine to allow users to safely run their code.

---

## Version 1: The Foundational Terminal & AI Security Gate

**Goal:** Implement a functional terminal UI that can manage the virtual file system (VFS) and introduce a critical AI security layer to vet all user-modified code before any execution is considered.

### **Sprint 1: The Simulated Terminal UI & Safe Commands**

**Objective:** Create the frontend and backend for a terminal that can execute *non-code-execution* commands against our VFS.

**Step 1.1: Create the Terminal UI in Flutter**
We'll build a new widget that looks and feels like a terminal.

*   **Create file:** `lib/components/ide/terminal_view.dart`
    *   This widget will contain a scrollable list for command history and an input field for new commands. clicking on the 'Terminal' button in the `ide_page.dart` 's should trigger this modal to popup, nicely designed with a modern feel and a blur backdrop.
    *   It will manage its own state, such as the current virtual working directory (e.g., `/`).

**Step 1.2: Create the Terminal Handler Edge Function**
This backend function will interpret safe commands.

*   **Create file:** `supabase/functions/terminal-handler/index.ts`
    ```typescript
    import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
    import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

    serve(async (req) => {
      const { command, projectId, currentDirectory } = await req.json();
      const supabase = createClient(/*...*/);
      const [cmd, ...args] = command.split(" ");

      switch (cmd) {
        case "ls":
          const { data: files } = await supabase
            .from("project_files")
            .select("path, last_modified")
            .eq("project_id", projectId)
            .like("path", `${currentDirectory}%`);
          // Format 'files' into a user-friendly string and return it
          return new Response(JSON.stringify(files));

        case "cat":
          const { data: file } = await supabase
            .from("project_files")
            .select("content")
            .eq("project_id", projectId)
            .eq("path", args[0])
            .single();
          return new Response(file?.content ?? "File not found.");

        // Add cases for 'touch', 'rm', 'mkdir' which manipulate the DB rows
        // These are safe as they don't execute code.

        default:
          return new Response(`Command not found: ${cmd}`);
      }
    });
    ```

**Step 1.3: Connect the UI to the Backend**
The Flutter `TerminalView` will call this function when the user enters a command and display the returned string.

### **Sprint 2: The AI Code Security Reviewer**

**Objective:** Build a dedicated AI function to act as a security gate, analyzing code for malicious patterns. This is a prerequisite for any code execution.

We will use a very lightweight-but-reliable model for this, to reduce inference costs (`gemini-2.5-flash-lite`; use key `GEMINI_API_KEY_3`)

**Step 2.1: Create the Code Reviewer Edge Function**
This function's sole purpose is security analysis.

*   **Create file:** `supabase/functions/code-reviewer/index.ts`

**Step 2.2: Implement the Security Analysis Logic**
The function will take code as input and use a specifically crafted prompt to ask Gemini to act as a security expert.

```typescript
// In supabase/functions/code-reviewer/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { GoogleGenAI } from "@google/genai";

const securityPrompt = `
  You are a senior cybersecurity analyst. Your task is to analyze the following code snippet for any potential security risks or malicious intent.
  Analyze for the following:
  - Infinite loops or resource exhaustion attacks.
  - Attempts to access the local file system, environment variables, or network.
  - Obfuscated or suspicious code.
  - Any other behavior that seems unsafe for a sandboxed execution environment.

  Respond ONLY with a JSON object of the format: {"is_safe": boolean, "reason": "your analysis here"}.
`;

serve(async (req) => {
  const { code } = await req.json();
  const gemini = new GoogleGenAI(Deno.env.get("GEMINI_API_KEY")!);
  const model = gemini.getGenerativeModel({ model: "gemini-2.5-flash" });

  const result = await model.generateContent([securityPrompt, code]);
  const jsonResponse = JSON.parse(result.response.text());

  return new Response(JSON.stringify(jsonResponse), {
    headers: { "Content-Type": "application/json" },
  });
});
```

NOTE: The above function signature is outdated, use the modern gemini api standard you've used in other implementations. But the idea on the implementation has been made clear with the snippet above.

**Step 2.3: Integrate the Reviewer**
When the user modifies code in the `CodeEditorView`, a "review" button or an automatic on-save hook will call this function. The result will be displayed to the user (e.g., a small green checkmark or a red warning icon).
However to minimize api usage, we don't run this anytime the user edits a file, but instead keep a check of the files that have been modified by the user, and then when they want to execute it, we 'review' the modified files.

---

## Version 2: Live Code Execution with Judge0

**Goal:** Integrate the Judge0 API to allow users to safely compile and run their code from the simulated terminal.

### **Sprint 3: Setting Up and Integrating Judge0**

**Objective:** Connect our `terminal-handler` to the Judge0 API to handle a new `run` command.

**Step 3.1: Set Up Judge0**
You have two primary options:
*   **A) RapidAPI (Recommended for MVP):** Use the [Judge0 API on RapidAPI](https://rapidapi.com/judge0-official/api/judge0-ce). It's fast to set up but has usage limits and costs. You will get an API key to use in your function.
*   **B) Self-Hosting (For Scale):** Follow the [official Judge0 documentation](https://github.com/judge0/judge0) to deploy it using Docker. This is more cost-effective and gives you full control but requires server maintenance.

**Step 3.2: Enhance the Terminal Handler for Execution**
We will add a `run` case to our `terminal-handler` function.

*   **Modify file:** `supabase/functions/terminal-handler/index.ts`

```typescript
// Add this case to the switch statement in terminal-handler/index.ts

case "run":
  const filePathToRun = args[0]; // e.g., 'main.py'

  // 1. Get the code from our VFS (Supabase DB)
  const { data: file } = await supabase.from("project_files").select("content").eq("path", filePathToRun).single();
  if (!file) return new Response("File not found.");

  // 2. (FUTURE) Call our AI security reviewer first!
  // const review = await supabase.functions.invoke('code-reviewer', { body: { code: file.content } });
  // if (!review.data.is_safe) return new Response(`Security Alert: ${review.data.reason}`);

  // 3. Submit to Judge0
  const languageId = 71; // 71 is for Python. See Judge0 docs for more.
  const judge0Response = await fetch("https://judge0-ce.p.rapidapi.com/submissions", {
    method: "POST",
    headers: {
      "X-RapidAPI-Key": Deno.env.get("JUDGE0_API_KEY")!,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      source_code: file.content,
      language_id: languageId,
    }),
  });

  const submission = await judge0Response.json();
  // Return the submission token to the client to poll for results
  return new Response(JSON.stringify({ token: submission.token }));
```

### **Sprint 4: Handling Asynchronous Execution & Streaming Results**

**Objective:** Implement the client-side logic to handle Judge0's asynchronous workflow and display the output.

**Step 4.1: Implement Polling Logic**
Judge0 works by first giving you a `token`. You then have to poll another endpoint to get the result.

*   **Modify file:** `lib/components/ide/terminal_view.dart`
    *   When the `terminal-handler` returns a `token`, the Flutter client will start a loop (e.g., using a `Timer.periodic`).
    *   In each loop, it will call a new `submission-retriever` Supabase function, passing the token.

**Step 4.2: Create the Submission Retriever Function**
This function checks the status of a Judge0 submission.

*   **Create file:** `supabase/functions/submission-retriever/index.ts`
    ```typescript
    // This function retrieves the result from Judge0 using a token
    serve(async (req) => {
      const { token } = await req.json();
      const response = await fetch(`https://judge0-ce.p.rapidapi.com/submissions/${token}`, {
        headers: { "X-RapidAPI-Key": Deno.env.get("JUDGE0_API_KEY")! },
      });
      const result = await response.json();
      // Return the full result (stdout, stderr, status, etc.)
      return new Response(JSON.stringify(result));
    });
    ```

**Step 4.3: Displaying the Final Output**
*   **Modify file:** `lib/components/ide/terminal_view.dart`
    *   When the polling retriever function returns a status of "Accepted" (or an error), the polling stops.
    *   The `stdout` or `stderr` from the result is then printed to the terminal UI history.

This V1/V2 plan provides a clear, secure, and scalable path to building the advanced terminal and code execution features you envision.
