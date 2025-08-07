# Plan: Implementing Robust Function Calling

This document outlines a detailed, three-sprint plan to implement a secure and scalable function-calling architecture for your AI agent. This approach moves the core logic to a backend Supabase Edge Function, making the Flutter client a secure and simple interface.

We will use the official `@google/genai` package on the backend, following the modern API standards you provided.

---

## Sprint 1: Building the Supabase Function-Calling Backend

**Goal:** Create a secure Supabase Edge Function that acts as the central orchestrator. This function will manage the conversation with the Gemini API, including executing tool calls against your database.

### **Step 1.1: Define the Tools**

First, we create a shared file that defines the structure of all tools the agent can use. This ensures consistency and reusability.

**Create file:** `supabase/functions/_shared/tools.ts`
```typescript
import { FunctionDeclaration, FunctionDeclarationSchemaType } from "@google/genai";

/**
 * Defines the tool for creating a new file in the project.
 */
export const createFileTool: FunctionDeclaration = {
  name: "create_file",
  description: "Creates a new file with a specified path and initial content. Use this to create new project files.",
  parameters: {
    type: FunctionDeclarationSchemaType.OBJECT,
    properties: {
      path: {
        type: FunctionDeclarationSchemaType.STRING,
        description: "The full, unique path of the file to create, e.g., 'lib/main.dart' or 'src/components/button.tsx'.",
      },
      content: {
        type: FunctionDeclarationSchemaType.STRING,
        description: "The initial content of the file. Can be empty.",
      },
    },
    required: ["path", "content"],
  },
};

/**
 * Defines the tool for updating the content of an existing file.
 */
export const updateFileTool: FunctionDeclaration = {
  name: "update_file_content",
  description: "Updates the entire content of an existing file, identified by its unique ID.",
  parameters: {
    type: FunctionDeclarationSchemaType.OBJECT,
    properties: {
      file_id: {
        type: FunctionDeclarationSchemaType.STRING,
        description: "The unique ID of the file to be updated.",
      },
      new_content: {
        type: FunctionDeclarationSchemaType.STRING,
        description: "The new, complete content that will overwrite the existing file content.",
      },
    },
    required: ["file_id", "new_content"],
  },
};

/**
 * Defines the tool for deleting a file.
 */
export const deleteFileTool: FunctionDeclaration = {
  name: "delete_file",
  description: "Permanently deletes a file from the project, identified by its unique ID.",
  parameters: {
    type: FunctionDeclarationSchemaType.OBJECT,
    properties: {
      file_id: {
        type: FunctionDeclarationSchemaType.STRING,
        description: "The unique ID of the file to be deleted.",
      },
    },
    required: ["file_id"],
  },
};

// Master list of all available tools for the agent
export const availableTools = [createFileTool, updateFileTool, deleteFileTool];
```

### **Step 1.2: Create the Agent Handler Function**

This is the main Edge Function. It will receive requests from the Flutter app, call Gemini, execute tools, and stream the final response back.

**Create file:** `supabase/functions/agent-handler/index.ts`
```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { GoogleGenAI, Content, Part, Tool } from "@google/genai";
import { availableTools } from "../_shared/tools.ts";

// The main server function
serve(async (req) => {
  const { prompt, history, projectId } = await req.json();

  // 1. Initialize API Clients
  const gemini = new GoogleGenAI(Deno.env.get("GEMINI_API_KEY")!);
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: req.headers.get("Authorization")! } } }
  );

  // 2. Configure the Gemini Model with our tools
  const model = gemini.getGenerativeModel({
    model: "gemini-1.5-pro-latest", // Use a powerful model for tool calling
    tools: [{ functionDeclarations: availableTools }],
  });

  const chat = model.startChat({ history });
  let result = await chat.sendMessage(prompt);

  // 3. The Tool-Calling Loop
  while (result.response.functionCalls && result.response.functionCalls.length > 0) {
    const functionCalls = result.response.functionCalls;
    const toolResponses: Part[] = [];

    for (const call of functionCalls) {
      console.log(`Agent requested to call: ${call.name}`);
      const { name, args } = call;
      let functionResult: any;

      // Execute the requested function
      try {
        switch (name) {
          case "create_file":
            await supabase.from("project_files").insert({
              project_id: projectId,
              path: args.path,
              content: args.content,
            });
            functionResult = { status: "success", message: `File '${args.path}' created.` };
            break;

          case "update_file_content":
            await supabase.from("project_files").update({ content: args.new_content }).eq("id", args.file_id);
            functionResult = { status: "success", message: `File ID '${args.file_id}' updated.` };
            break;

          case "delete_file":
            await supabase.from("project_files").delete().eq("id", args.file_id);
            functionResult = { status: "success", message: `File ID '${args.file_id}' deleted.` };
            break;

          default:
            throw new Error(`Unknown function call: ${name}`);
        }
      } catch (error) {
        functionResult = { status: "error", message: error.message };
      }

      // Add the result of the function execution to our list of responses
      toolResponses.push({
        functionResponse: {
          name,
          response: functionResult,
        },
      });
    }

    // 4. Send the tool responses back to Gemini
    result = await chat.sendMessage(toolResponses);
  }

  // 5. Stream the final text response back to the client
  const finalResponse = result.response.text();
  return new Response(finalResponse, {
    headers: { "Content-Type": "text/plain" },
  });
});
```

### **Step 1.3: Deploy the Function**

```bash
supabase functions deploy agent-handler
```

---

## Sprint 2: Refactoring the Flutter Client

**Goal:** Modify the Flutter app to communicate with our new `agent-handler` Edge Function instead of calling the Gemini API directly.

### **Step 2.1: Update Chat Providers**

Refactor the `sendMessage` and `_startNewChat` methods to invoke the Supabase Function.

**File to modify:** `lib/providers/agent_chat_provider.dart` and `lib/components/ide/agent_chat_view.dart`

The logic will be similar in both. Here is the new implementation for the provider's `sendMessage`:

```dart
// In agent_chat_provider.dart

Future<void> sendMessage({
  required String text,
  required String model, // Model can now be handled on the backend, but we keep it for now
}) async {
  _isSending = true;
  // ... (optimistic UI update for user message)

  try {
    // Prepare history for the backend
    final historyForBackend = _messages
        .where((m) => m.messageType == AgentMessageType.text)
        .map((m) => {
              "role": m.sender == MessageSender.user ? "user" : "model",
              "parts": [{"text": m.content}]
            })
        .toList();

    // Invoke the Supabase Edge Function
    final response = await _client.functions.invoke(
      'agent-handler',
      body: {
        'prompt': text,
        'history': historyForBackend,
        'projectId': this.projectId, // Assuming projectId is available in the notifier
      },
    );

    if (response.status != 200) {
      throw Exception('Backend function failed: ${response.data}');
    }

    final aiResponseContent = response.data as String;

    // Update the AI placeholder with the final response
    // ... (logic to find and update the AI message bubble)

    // Persist the final AI message
    // ...

  } catch (e) {
    // ... (error handling)
  } finally {
    _isSending = false;
    notifyListeners();
  }
}
```

---

## Sprint 3: Closing the Loop and Enhancing UI Feedback

**Goal:** Ensure the UI provides clear feedback during tool execution and that the file tree updates automatically.

### **Step 3.1: Verify Real-time File Tree Updates**

This should already work! Our backend function directly modifies the `project_files` table. The `ProjectFilesProvider` on the client calls `fetchFiles()` after every file operation is initiated by the agent. This triggers a UI rebuild for the `FileTreeView`. No new code is needed here, just verification.

### **Step 3.2: Implement "Tool in Progress" UI Feedback**

To improve the user experience, we should show a status message in the chat while the backend is working.

**File to modify:** `lib/components/ide/agent_chat_view.dart` (and the provider)

When `sendMessage` is called:
1.  Immediately add the user's message to the chat list for an optimistic update.
2.  Immediately add a *second* message with a type of `AgentMessageType.toolInProgress` and content like "Robin is thinking...".
3.  Invoke the Supabase Function.
4.  When the function returns its final text response, *replace* the "thinking" message with the actual response from the AI.

```dart
// In agent_chat_view.dart's _startNewChat or provider's sendMessage

// ... after adding the user message optimistically
final thinkingMessage = AgentChatMessage(
  id: 'local_thinking',
  chatId: '',
  sender: MessageSender.ai,
  messageType: AgentMessageType.toolInProgress,
  content: 'Robin is thinking...',
  sentAt: DateTime.now(),
);
setState(() {
  _localMessages.add(thinkingMessage);
});

// NOW, invoke the Supabase function...
final response = await _client.functions.invoke(...);

// AFTER getting the response, replace the thinking message
setState(() {
  final index = _localMessages.indexWhere((m) => m.id == 'local_thinking');
  if (index != -1) {
    _localMessages[index] = thinkingMessage.copyWith(
      messageType: AgentMessageType.text,
      content: response.data as String,
    );
  }
});
```

This completes the full, robust implementation plan. Once you confirm this approach, we can begin with Sprint 1.
