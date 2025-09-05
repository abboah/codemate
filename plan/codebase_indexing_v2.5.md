# Plan V2.5: Retrieval-Augmented Generation (RAG) for Codebase Awareness

This document outlines the plan to upgrade the AI agent from a simple file-reader to a fully context-aware assistant by implementing a Retrieval-Augmented Generation (RAG) pipeline. This will allow the agent to answer questions about the entire codebase, even files not explicitly opened.

**Prerequisite:** This plan assumes the completion of the V1 and V2 plans. It is a "half-step" that dramatically increases the agent's intelligence before moving on to V3/V4.

---

## The Core Concept: From Prompting to Querying

The fundamental limitation of any LLM is its finite context window. We cannot feed an entire project's source code into a single prompt. RAG solves this by creating a searchable, semantic index of the codebase.

1.  **Indexing:** We break down every file into small, meaningful chunks (like functions or classes). We then use a specialized AI model (an embedding model) to convert each chunk into a vector—a list of numbers that represents its semantic meaning. These vectors are stored in a specialized database.
2.  **Retrieval:** When a user asks a question (e.g., "How does user login work?"), we convert the *question* into a vector. We then query the database to find the code chunks with vectors most similar to the question's vector.
3.  **Augmentation:** We take these top-matching chunks and inject them as context into the prompt we send to the main Gemini chat model. The model then answers the user's question with this highly relevant, dynamically retrieved information.

---

## The Architecture: Using Supabase `pgvector`

Our existing Supabase stack is perfectly suited for this. We don't need to add external services.

*   **Vector Database:** We will use Supabase's built-in `pgvector` extension.
*   **Embedding Model:** We will use Google's `text-embedding-004` model via the Gemini API.
*   **Orchestration:** A new Supabase Edge Function will handle the indexing process.

---

## Implementation Sprints

### **Sprint 1: Setting Up the Vector Database**

**Objective:** Prepare the database to store the code embeddings.

**Step 1.1: Enable `pgvector`**
In the Supabase dashboard, navigate to `Database` -> `Extensions` and enable the `vector` extension.

**Step 1.2: Create the `code_embeddings` Table**
Execute the following SQL in the Supabase SQL Editor to create the table that will hold the vectors and their associated code chunks.

```sql
-- This table stores the vector representation of each code chunk
CREATE TABLE public.code_embeddings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
  file_id UUID NOT NULL REFERENCES public.project_files(id) ON DELETE CASCADE,
  chunk_content TEXT NOT NULL,
  embedding VECTOR(768) -- The dimension for Google's text-embedding-004 model
);

-- Create an index for fast similarity searches, crucial for performance
CREATE INDEX ON public.code_embeddings USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);
```

### **Sprint 2: The Indexing Backend**

**Objective:** Build the backend function that creates and stores the embeddings.

**Step 2.1: Create the `code-indexer` Edge Function**
*   **Create file:** `supabase/functions/code-indexer/index.ts`
*   This function will be triggered whenever a file is created or updated.

**Step 2.2: Implement the Indexing Logic**
```typescript
// In supabase/functions/code-indexer/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { GoogleGenerativeAI } from "@google/genai";

serve(async (req) => {
  const { fileId, content, projectId } = await req.json();
  const supabase = createClient(/*...*/);
  const gemini = new GoogleGenerativeAI(Deno.env.get("GEMINI_API_KEY")!);

  // A simple strategy: split the code by double newlines.
  // This can be improved later with more intelligent, language-aware chunking.
  const chunks = content.split("\n\n").filter(c => c.trim().length > 0);

  const embeddingModel = gemini.getGenerativeModel({ model: "text-embedding-004" });
  const result = await embeddingModel.batchEmbedContents({
    requests: chunks.map(chunk => ({ model: "models/text-embedding-004", content: { parts: [{ text: chunk }] } })),
  });
  const embeddings = result.embeddings;

  const rows = embeddings.map((embedding, i) => ({
    project_id: projectId,
    file_id: fileId,
    chunk_content: chunks[i],
    embedding: embedding.value,
  }));

  // Atomically delete old embeddings and insert the new ones
  await supabase.from("code_embeddings").delete().eq("file_id", fileId);
  await supabase.from("code_embeddings").insert(rows);

  return new Response(JSON.stringify({ status: "success" }));
});
```

**Step 2.3: Automate Indexing with Database Triggers**
Create a database trigger to automatically call this function, ensuring the index is always up-to-date.

```sql
-- Trigger function
CREATE OR REPLACE FUNCTION handle_project_file_change()
RETURNS TRIGGER AS $$
BEGIN
  -- Call the 'code-indexer' Edge Function
  PERFORM net.http_post(
    url:='https://<YOUR_PROJECT_REF>.supabase.co/functions/v1/code-indexer',
    headers:='{"Authorization": "Bearer <YOUR_SUPABASE_ANON_KEY>"}'::jsonb,
    body:=jsonb_build_object('fileId', NEW.id, 'content', NEW.content, 'projectId', NEW.project_id)
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger registration
CREATE TRIGGER on_project_file_change
AFTER INSERT OR UPDATE ON public.project_files
FOR EACH ROW EXECUTE FUNCTION handle_project_file_change();
```

### **Sprint 3: Integrating RAG into the Agent Handler**

**Objective:** Upgrade the main agent to use the vector search for context.

**Step 3.1: Create a Search Stored Procedure**
Create a function in Supabase to efficiently find relevant code chunks.

```sql
-- in Supabase SQL Editor
CREATE OR REPLACE FUNCTION match_code_chunks (
  query_embedding VECTOR(768),
  match_threshold FLOAT,
  match_count INT,
  p_project_id UUID
)
RETURNS TABLE (chunk_content TEXT) AS $$
BEGIN
  RETURN QUERY
  SELECT
    ce.chunk_content
  FROM public.code_embeddings AS ce
  WHERE ce.project_id = p_project_id AND (1 - (ce.embedding <=> query_embedding)) > match_threshold
  ORDER BY (ce.embedding <=> query_embedding)
  LIMIT match_count;
END;
$$ LANGUAGE plpgsql;
```

**Step 3.2: Update the `agent-handler` to Use RAG**
Modify the main agent function to perform the search and augment the prompt.

```typescript
// In supabase/functions/agent-handler/index.ts

// ... inside the main serve function, after getting the user's prompt

// 1. Embed the user's prompt to create a search vector
const embeddingModel = gemini.getGenerativeModel({ model: "text-embedding-004" });
const promptEmbedding = await embeddingModel.embedContent(prompt);

// 2. Call the RPC to find relevant code chunks from the database
const { data: chunks } = await supabase.rpc("match_code_chunks", {
  query_embedding: promptEmbedding.embedding.value,
  match_threshold: 0.75, // Tweak this for best results
  match_count: 5,
  p_project_id: projectId,
});

// 3. Construct the augmented prompt
const contextForPrompt = chunks.map(c => c.chunk_content).join("\n---\n");
const augmentedPrompt = `
  You are an expert AI software development assistant. Answer the user's question based on the following relevant code snippets from the project.
  --- RELEVANT CODE ---
  ${contextForPrompt}
  --- END CODE ---
  User's question: ${prompt}
`;

// 4. Call the main chat model with the NEW, augmented prompt
const chat = model.startChat({ history });
let result = await chat.sendMessage(augmentedPrompt);

// ... the rest of the tool-calling loop continues as before
```
This architecture provides a powerful, scalable, and cost-effective way to give your agent long-term memory and full codebase awareness.
