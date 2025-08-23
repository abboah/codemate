import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { GoogleGenAI, createPartFromUri, Modality } from "https://esm.sh/@google/genai";
import {
  playgroundTools,
  playgroundCanvasTools,
  playgroundCompositeTools,
  playgroundReadTools,
} from "../_shared/tools.ts";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  try {
  const geminiApiKey = Deno.env.get("GEMINI_API_KEY_3");
    if (!geminiApiKey) throw new Error("GEMINI_API_KEY_3 is not set.");

    const { prompt, history, chatId, model: requestedModel, includeThoughts, attachments } = await req.json();

    const ai = new GoogleGenAI({ apiKey: geminiApiKey });
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: req.headers.get("Authorization") ?? '' } } }
    );

  const DEFAULT_MODEL = "gemini-2.5-flash";
  const preferredModel = (typeof requestedModel === 'string' && requestedModel.length > 0) ? requestedModel : DEFAULT_MODEL;

    // Helper: upload raw bytes to storage using a Blob (more reliable across runtimes)
    async function uploadBytesToStorage(bucket: string, path: string, bytes: Uint8Array, contentType: string) {
      // Use the underlying ArrayBuffer and cast to satisfy TS DOM lib types
      const ab = bytes.buffer as unknown as ArrayBuffer;
      const blob = new Blob([ab], { type: contentType });
      const upload = await supabase.storage.from(bucket).upload(path, blob, { contentType, upsert: true });
      if ((upload as any).error) throw (upload as any).error;
      // Try a signed URL (works for private buckets)
      let signedUrl: string | undefined;
      try {
        const signed = await supabase.storage.from(bucket).createSignedUrl(path, 3600);
        signedUrl = (signed as any)?.data?.signedUrl;
      } catch (_) { /* noop */ }
      // Also fetch public URL (works only for public buckets)
      let publicUrl: string | undefined;
      try {
        const { data: pub } = await supabase.storage.from(bucket).getPublicUrl(path);
        publicUrl = pub?.publicUrl;
      } catch (_) { /* noop */ }
      return { path, publicUrl, signedUrl };
    }

    // Helper: process attachments by uploading to 'user-uploads' and returning sanitized metadata
    async function processAttachmentsIfAny(arr: any[]): Promise<any[]> {
      if (!Array.isArray(arr) || arr.length === 0) return [];
      const out: any[] = [];
      for (const item of arr) {
        try {
          const base64: string | undefined = item?.base64 ?? item?.data;
          const mime: string = item?.mime_type ?? item?.mimeType ?? 'application/octet-stream';
          const name: string = item?.file_name ?? item?.name ?? `upload_${Date.now()}`;
          if (typeof base64 === 'string' && base64.length > 0) {
            const bytes = Uint8Array.from(atob(base64), c => c.charCodeAt(0));
            const folder = 'playground/uploads';
            const path = `${folder}/${Date.now()}_${Math.random().toString(36).slice(2)}_${name}`;
            // Note: requires bucket 'user-uploads' to exist
            const { publicUrl, signedUrl } = await uploadBytesToStorage('user-uploads', path, bytes, mime);
            out.push({ bucket: 'user-uploads', path, url: publicUrl ?? signedUrl, publicUrl, signedUrl, mime_type: mime, file_name: name });
          } else if (typeof item?.url === 'string') {
            // Already a URL (e.g., previously uploaded)
            out.push({ url: item.url, mime_type: mime, file_name: name });
          } else {
            out.push(item);
          }
        } catch (err) {
          // If upload fails (e.g., bucket missing), keep original item to avoid data loss
          out.push(item);
        }
      }
      return out;
    }

  async function executeTool(name: string, args: Record<string, any>, effectiveChatId: string): Promise<any> {
      switch (name) {
        case 'canvas_read_file_by_id': {
          const id = String(args.id ?? '').trim();
          if (!id) return { status: 'error', message: 'id is required' };
          const { data, error } = await supabase
            .from('canvas_files')
            .select('id, path, content, chat_id')
            .eq('id', id)
            .single();
          if (error) return { status: 'error', message: error.message };
          if (!data || data.chat_id !== effectiveChatId) return { status: 'error', message: 'Not found for this chat' };
          let content: string = data.content ?? '';
          const max = typeof args.max_bytes === 'number' ? args.max_bytes : undefined;
          if (typeof max === 'number' && max > 0 && content.length > max) content = content.slice(0, max);
          return { status: 'success', id: data.id, path: data.path, content };
        }
        case 'artifact_read': {
          const id = String(args.id ?? '').trim();
          if (!id) return { status: 'error', message: 'id is required' };
          const { data, error } = await supabase
            .from('playground_artifacts')
            .select('id, artifact_type, key, data, chat_id, last_modified')
            .eq('id', id)
            .single();
          if (error) return { status: 'error', message: error.message };
          if (!data || data.chat_id !== effectiveChatId) return { status: 'error', message: 'Not found for this chat' };
          return { status: 'success', id: data.id, artifact_type: data.artifact_type, key: data.key, data: data.data, last_modified: data.last_modified };
        }
        case 'project_card_preview': {
          // Sanitize and persist as an artifact
          const safe = {
            name: String(args.name ?? ''),
            summary: String(args.summary ?? ''),
            stack: Array.isArray(args.stack) ? args.stack.slice(0, 12).map(String) : [],
            key_features: Array.isArray(args.key_features) ? args.key_features.slice(0, 12).map(String) : [],
            can_implement_in_canvas: Boolean(args.can_implement_in_canvas ?? false),
          };
          const { data: art, error: artErr } = await supabase
            .from('playground_artifacts')
            .insert({ chat_id: effectiveChatId, artifact_type: 'project_card_preview', data: safe })
            .select('id')
            .single();
          if (artErr) return { status: 'error', message: artErr.message, card: safe };
          return { status: 'success', card: safe, artifact_id: art.id };
        }
        case 'todo_list_create': {
          const title = String(args.title ?? 'Todo');
          const tasks = Array.isArray(args.tasks) ? args.tasks : [];
          const items = tasks.map((t, i) => ({
            id: String(t.id ?? `${i+1}`),
            title: String(t.title ?? `Task ${i+1}`),
            done: Boolean(t.done ?? false),
            notes: typeof t.notes === 'string' ? t.notes : undefined,
          }));
          const todo = { title, tasks: items };
          const { data: art, error: artErr } = await supabase
            .from('playground_artifacts')
            .insert({ chat_id: effectiveChatId, artifact_type: 'todo_list', data: todo })
            .select('id')
            .single();
          if (artErr) return { status: 'error', message: artErr.message, todo };
          return { status: 'success', todo, artifact_id: art.id };
        }
        case 'todo_list_check': {
          const artifactId = String(args.artifact_id ?? '').trim();
          if (!artifactId) return { status: 'error', message: 'artifact_id is required' };
          const completedIds: string[] = Array.isArray(args.completed_task_ids) ? args.completed_task_ids.map((x: any) => String(x)) : [];
          const { data: artRow, error: selErr } = await supabase
            .from('playground_artifacts')
            .select('id, data, artifact_type, chat_id')
            .eq('id', artifactId)
            .single();
          if (selErr) return { status: 'error', message: selErr.message };
          if (!artRow || artRow.artifact_type !== 'todo_list' || artRow.chat_id !== effectiveChatId) {
            return { status: 'error', message: 'Artifact not found or not a todo_list for this chat' };
          }
          const todo = (artRow.data ?? {});
          const tasks = Array.isArray(todo.tasks) ? todo.tasks : [];
          if (completedIds.length > 0) {
            for (const t of tasks) {
              if (completedIds.includes(String(t.id))) {
                t.done = true;
              }
            }
          }
          const updated = { ...todo, tasks };
          const { error: updErr } = await supabase
            .from('playground_artifacts')
            .update({ data: updated, last_modified: new Date().toISOString() })
            .eq('id', artifactId);
          if (updErr) return { status: 'error', message: updErr.message };
          const context = typeof args.context === 'string' ? String(args.context) : undefined;
          return { status: 'success', todo: updated, artifact_id: artifactId, notes: context ? `Context considered: ${context.slice(0,200)}` : undefined };
        }
        case 'create_file_from_template': {
          const artifactId = String(args.artifact_id ?? '').trim();
          const path = String(args.path ?? '').trim();
          if (!artifactId) return { status: 'error', message: 'artifact_id is required' };
          if (!path) return { status: 'error', message: 'path is required' };
          const substitutions = (args.substitutions && typeof args.substitutions === 'object') ? { ...args.substitutions } : {};
          const { data: artRow, error: selErr } = await supabase
            .from('playground_artifacts')
            .select('id, data, artifact_type, chat_id')
            .eq('id', artifactId)
            .single();
          if (selErr) return { status: 'error', message: selErr.message };
          if (!artRow || artRow.chat_id !== effectiveChatId) {
            return { status: 'error', message: 'Artifact not found for this chat' };
          }
          let template: string | undefined = (artRow.data?.template as string | undefined);
          if (!template) return { status: 'error', message: "Artifact does not contain a 'template' string" };
          // Simple {{key}} substitution
          for (const [k, v] of Object.entries(substitutions)) {
            try { template = template!.split(`{{${k}}}`).join(String(v)); } catch (_) { /* noop */ }
          }
          const { error } = await supabase
            .from('canvas_files')
            .insert({ chat_id: effectiveChatId, path, content: template });
          if (error) return { status: 'error', message: error.message };
          return { status: 'success', path };
        }
        case 'implement_feature_and_update_todo': {
          const artifactId = String(args.artifact_id ?? '').trim();
          const taskId = String(args.task_id ?? '').trim();
          const path = String(args.path ?? '').trim();
          const newContent = String(args.new_content ?? '');
          if (!artifactId || !taskId || !path) return { status: 'error', message: 'artifact_id, task_id and path are required' };
          // 1) Update canvas file
          {
            const { error } = await supabase.from('canvas_files').update({ content: newContent, last_modified: new Date().toISOString() }).match({ chat_id: effectiveChatId, path });
            if (error) return { status: 'error', message: error.message };
          }
          // 2) Mark todo task as done in artifact
          const { data: artRow, error: selErr } = await supabase
            .from('playground_artifacts')
            .select('id, data, artifact_type, chat_id')
            .eq('id', artifactId)
            .single();
          if (selErr) return { status: 'error', message: selErr.message };
          if (!artRow || artRow.artifact_type !== 'todo_list' || artRow.chat_id !== effectiveChatId) {
            return { status: 'error', message: 'Artifact not found or not a todo_list for this chat' };
          }
          const todo = (artRow.data ?? {});
          const tasks = Array.isArray(todo.tasks) ? todo.tasks : [];
          for (const t of tasks) {
            if (String(t.id) === taskId) t.done = true;
          }
          const updated = { ...todo, tasks };
          const { error: updErr } = await supabase
            .from('playground_artifacts')
            .update({ data: updated, last_modified: new Date().toISOString() })
            .eq('id', artifactId);
          if (updErr) return { status: 'error', message: updErr.message };
          return { status: 'success', path, artifact_id: artifactId, task_id: taskId };
        }
        case 'analyze_document': {
          const instruction = String(args.instruction ?? 'Analyze');
          const source = String(args.source ?? '');
          const mime = String(args.mime_type ?? 'application/pdf');
          const parts: any[] = [ { text: instruction } ];
          if (source === 'base64' && typeof args.base64 === 'string' && args.base64.length > 0) {
            parts.push({ inlineData: { mimeType: mime, data: args.base64 } });
          } else if (source === 'file_uri' && typeof args.file_uri === 'string' && args.file_uri.length > 0) {
            parts.push(createPartFromUri(args.file_uri, mime));
          }
          const res = await ai.models.generateContent({ model: preferredModel, contents: parts });
          return { status: 'success', text: res.text ?? '' };
        }
        case 'generate_image': {
          const textPrompt = String(args.prompt ?? '');
          const folder = String(args.folder ?? 'playground/images');
          const fileName = String(args.file_name ?? `gen_${Date.now()}.png`);
          const response = await ai.models.generateContent({
            model: "gemini-2.0-flash-preview-image-generation",
            contents: textPrompt,
            config: { responseModalities: [Modality.TEXT, Modality.IMAGE] },
          });
          let b64: string | undefined;
          let caption: string | undefined;
          const parts = response.candidates?.[0]?.content?.parts ?? [];
          for (const p of parts) {
            if (p.text && !caption) caption = p.text;
            if (p.inlineData?.data && !b64) b64 = p.inlineData.data;
          }
          if (!b64) return { status: 'error', message: 'No image returned' };
          const bytes = Uint8Array.from(atob(b64), c => c.charCodeAt(0));
          const bucket = 'user-files';
          const path = `${folder}/${fileName}`;
          const { publicUrl, signedUrl } = await uploadBytesToStorage(bucket, path, bytes, 'image/png');
          return { status: 'success', path, url: publicUrl ?? signedUrl, publicUrl, signedUrl, caption };
        }
        case 'enhance_image': {
          const instruction = String(args.instruction ?? 'Enhance');
          const source = String(args.source ?? '');
          const mime = String(args.mime_type ?? 'image/png');
          const folder = String(args.folder ?? 'playground/images');
          const fileName = String(args.file_name ?? `enh_${Date.now()}.png`);
          const contents: any[] = [ { text: instruction } ];
          if (source === 'base64' && typeof args.base64 === 'string' && args.base64.length > 0) {
            contents.push({ inlineData: { mimeType: mime, data: args.base64 } });
          } else if (source === 'file_uri' && typeof args.file_uri === 'string' && args.file_uri.length > 0) {
            contents.push(createPartFromUri(args.file_uri, mime));
          } else {
            return { status: 'error', message: 'No source provided' };
          }
          const response = await ai.models.generateContent({
            model: "gemini-2.0-flash-preview-image-generation",
            contents,
            config: { responseModalities: [Modality.TEXT, Modality.IMAGE] },
          });
          let b64: string | undefined;
          let caption: string | undefined;
          const parts = response.candidates?.[0]?.content?.parts ?? [];
          for (const p of parts) {
            if (p.text && !caption) caption = p.text;
            if (p.inlineData?.data && !b64) b64 = p.inlineData.data;
          }
          if (!b64) return { status: 'error', message: 'No image returned' };
          const bytes = Uint8Array.from(atob(b64), c => c.charCodeAt(0));
          const bucket = 'user-files';
          const path = `${folder}/${fileName}`;
          const { publicUrl, signedUrl } = await uploadBytesToStorage(bucket, path, bytes, 'image/png');
          return { status: 'success', path, url: publicUrl ?? signedUrl, publicUrl, signedUrl, caption };
        }
        case 'canvas_create_file': {
          const path = String(args.path ?? '').trim();
          const content = String(args.content ?? '');
          if (!path) return { status: 'error', message: 'path is required' };
          const { error } = await supabase.from('canvas_files').insert({ chat_id: effectiveChatId, path, content });
          if (error) return { status: 'error', message: error.message };
          return { status: 'success', path };
        }
        case 'canvas_update_file_content': {
          const path = String(args.path ?? '').trim();
          const newContent = String(args.new_content ?? '');
          if (!path) return { status: 'error', message: 'path is required' };
          const { error } = await supabase.from('canvas_files').update({ content: newContent, last_modified: new Date().toISOString() }).match({ chat_id: effectiveChatId, path });
          if (error) return { status: 'error', message: error.message };
          return { status: 'success', path };
        }
        case 'canvas_delete_file': {
          const path = String(args.path ?? '').trim();
          if (!path) return { status: 'error', message: 'path is required' };
          const { error } = await supabase.from('canvas_files').delete().match({ chat_id: effectiveChatId, path });
          if (error) return { status: 'error', message: error.message };
          return { status: 'success', path };
        }
        case 'canvas_read_file': {
          const path = String(args.path ?? '').trim();
          if (!path) return { status: 'error', message: 'path is required' };
          const { data, error } = await supabase.from('canvas_files').select('path, content').match({ chat_id: effectiveChatId, path }).single();
          if (error) return { status: 'error', message: error.message };
          let content: string = data?.content ?? '';
          const max = typeof args.max_bytes === 'number' ? args.max_bytes : undefined;
          if (typeof max === 'number' && max > 0 && content.length > max) {
            content = content.slice(0, max);
          }
          return { status: 'success', path, content };
        }
        case 'canvas_search': {
          const query = String(args.query ?? '').toLowerCase();
          const limit = Math.max(1, Math.min(200, Number(args.max_results_per_file ?? 20)));
          if (!query) return { status: 'error', message: 'query is required' };
          const { data, error } = await supabase.from('canvas_files').select('path, content').eq('chat_id', effectiveChatId);
          if (error) return { status: 'error', message: error.message };
          const results: Array<{ path: string; matches: Array<{ line: number; text: string }> }> = [];
          for (const row of (data ?? [])) {
            const lines = String(row.content ?? '').split('\n');
            const matches: Array<{ line: number; text: string }> = [];
            for (let i = 0; i < lines.length; i++) {
              const L = lines[i];
              if (L.toLowerCase().includes(query)) {
                matches.push({ line: i + 1, text: L.trim() });
                if (matches.length >= limit) break;
              }
            }
            if (matches.length > 0) results.push({ path: row.path, matches });
          }
          return { status: 'success', query, results };
        }
        default:
          return { status: 'error', message: `Unknown tool: ${name}` };
      }
    }

    async function buildSystemInstruction(chatIdForCtx: string): Promise<string> {
      // Collect recently created artifacts (titles + ids only)
      let artifactsList = '';
      try {
        const { data: arts } = await supabase
          .from('playground_artifacts')
          .select('id, artifact_type, data, last_modified')
          .eq('chat_id', chatIdForCtx)
          .order('last_modified', { ascending: false })
          .limit(20);
        const lines: string[] = [];
        for (const a of (arts ?? [])) {
          const d = a?.data ?? {};
          const title = (d?.title ?? d?.name ?? a?.artifact_type ?? 'untitled');
          lines.push(`- ${a.id}: ${title} [${a.artifact_type}]`);
        }
        if (lines.length > 0) {
          artifactsList = `\nAvailable artifacts (id: title [type]):\n${lines.join('\n')}`;
        }
      } catch (_) { /* ignore */ }
      const guidance = `You are Robin in Playground mode.\n- Prefer web-first solutions (React or HTML/CSS/JS) unless the user specifically requests another stack or web is unsuitable.\n- Use tools when needed instead of fabricating results.\n- When creating simple web features that can run in a single file, prefer making self-contained components suitable for Canvas preview.\n- Do not dump large JSON inline unless asked. Summarize and store structured outputs as artifacts when appropriate.\n${artifactsList}`;
      return guidance;
    }

  async function runOnce(modelName: string): Promise<{ text: string; chatId: string }> {
      // Ensure authenticated user
      const { data: userData, error: userErr } = await supabase.auth.getUser();
      if (userErr) throw userErr;
      const userId = userData?.user?.id as string | undefined;
      if (!userId) throw new Error('Not authenticated');

      // Ensure a playground chat exists
      let effectiveChatId = chatId as string | undefined;
      if (!effectiveChatId) {
        const title = 'New Playground Chat';
        const { data: chatRow, error: chatErr } = await supabase
          .from('playground_chats')
          .insert({ user_id: userId, title })
          .select('id, title')
          .single();
        if (chatErr) throw chatErr;
        effectiveChatId = chatRow.id as string;
      }

      // Upload attachments (if any) to storage, then persist user message
      const sanitizedAttachments = await processAttachmentsIfAny(Array.isArray(attachments) ? attachments : []);
      await supabase.from('playground_chat_messages').insert({
        chat_id: effectiveChatId,
        sender: 'user',
        message_type: 'text',
        content: String(prompt ?? ''),
        attached_files: sanitizedAttachments.length ? sanitizedAttachments : null,
      });

      // Compose model contents with last 4 messages from DB (including tool_results, excluding thoughts)
      const contents: any[] = [];
      try {
        const { data: histRows } = await supabase
          .from('playground_chat_messages')
          .select('sender, content, tool_results, sent_at')
          .eq('chat_id', effectiveChatId)
          .order('sent_at', { ascending: false })
          .limit(4);
        const prior = (histRows ?? []).slice().reverse();
        for (const m of prior) {
          const role = (m.sender === 'user') ? 'user' : 'model';
          const contentText = String(m.content ?? '');
          if (contentText) contents.push({ role, parts: [{ text: contentText }] });
          const tr = (m.tool_results as any)?.events;
          if (Array.isArray(tr) && tr.length > 0) {
            const summary = JSON.stringify({ tool_results: tr });
            contents.push({ role, parts: [{ text: `Previous tool activity:\n${summary}` }] });
          }
        }
      } catch (_) { /* ignore history failures */ }
      contents.push({ role: 'user', parts: [{ text: prompt }] });
      if (sanitizedAttachments.length > 0) {
        const list = sanitizedAttachments.map((f) => `- ${f.file_name || 'file'} (${f.mime_type || 'unknown'}) -> ${f.url || f.publicUrl || f.signedUrl || f.path}`).join('\n');
        contents.push({ role: 'user', parts: [{ text: `Attached files:\n${list}` }] });
      }

      const createdArtifactIds: string[] = [];
      while (true) {
        const systemInstruction = await buildSystemInstruction(effectiveChatId);
        const result = await ai.models.generateContent({
          model: modelName,
          contents,
          config: {
            tools: [{ functionDeclarations: [...playgroundTools, ...playgroundCanvasTools, ...playgroundReadTools, ...playgroundCompositeTools] }],
            systemInstruction,
            ...(includeThoughts ? { thinkingConfig: { thinkingBudget: -1, includeThoughts: true } } : {}),
          },
        });
        if (result.functionCalls && result.functionCalls.length > 0) {
          for (const c of result.functionCalls) {
            const name = (c as any).name as string; const args = (c as any).args ?? {};
            const toolResponse = await executeTool(name, args, effectiveChatId);
            try { const aid = (toolResponse as any)?.artifact_id; if (typeof aid === 'string' && aid) createdArtifactIds.push(aid); } catch (_) {}
            contents.push({ role: 'model', parts: [{ functionCall: { name, args } }] });
            contents.push({ role: 'user', parts: [{ functionResponse: { name, response: { result: toolResponse } } }] });
          }
          continue;
        } else {
          const text = result.text ?? '';
          // Persist AI message
          const inserted = await supabase.from('playground_chat_messages').insert({
            chat_id: effectiveChatId,
            sender: 'ai',
            message_type: 'text',
            content: text,
          }).select('id').single();
          const messageId = (inserted as any)?.data?.id as string | undefined;
          if (messageId && createdArtifactIds.length > 0) {
            for (const aid of createdArtifactIds) {
              try { await supabase.from('playground_artifacts').update({ message_id: messageId }).eq('id', aid); } catch (_) {}
            }
          }
          return { text, chatId: effectiveChatId };
        }
      }
    }
    const wantsStream = (req.headers.get('accept')?.includes('application/x-ndjson')) || (req.headers.get('x-stream') === 'true');
    if (wantsStream) {
      const encoder = new TextEncoder();
      const stream = new ReadableStream<Uint8Array>({
        async start(controller) {
          function emit(obj: unknown) {
            controller.enqueue(encoder.encode(JSON.stringify(obj) + "\n"));
          }
          const interval = setInterval(() => { try { emit({ type: 'ping', t: Date.now() }); } catch (_) {} }, 1000);

          async function streamOnce(modelName: string) {
            // Ensure user and chat
            const { data: userData, error: userErr } = await supabase.auth.getUser();
            if (userErr) throw userErr;
            const userId = userData?.user?.id as string | undefined;
            if (!userId) throw new Error('Not authenticated');

            let effectiveChatId = chatId as string | undefined;
            if (!effectiveChatId) {
              const title = 'New Playground Chat';
              const { data: chatRow, error: chatErr } = await supabase
                .from('playground_chats')
                .insert({ user_id: userId, title })
                .select('id, title')
                .single();
              if (chatErr) throw chatErr;
              effectiveChatId = chatRow.id as string;
            }
            emit({ type: 'start', model: modelName, chatId: effectiveChatId });

            // Upload attachments (if any) to storage, then persist user message
            const sanitizedAttachments = await processAttachmentsIfAny(Array.isArray(attachments) ? attachments : []);
            await supabase.from('playground_chat_messages').insert({
              chat_id: effectiveChatId,
              sender: 'user',
              message_type: 'text',
              content: String(prompt ?? ''),
              attached_files: sanitizedAttachments.length ? sanitizedAttachments : null,
            });
            const contents: any[] = [];
            try {
              const { data: histRows } = await supabase
                .from('playground_chat_messages')
                .select('sender, content, tool_results, sent_at')
                .eq('chat_id', effectiveChatId)
                .order('sent_at', { ascending: false })
                .limit(3);
              const prior = (histRows ?? []).slice().reverse();
              for (const m of prior) {
                const role = (m.sender === 'user') ? 'user' : 'model';
                const contentText = String(m.content ?? '');
                if (contentText) contents.push({ role, parts: [{ text: contentText }] });
                const tr = (m.tool_results as any)?.events;
                if (Array.isArray(tr) && tr.length > 0) {
                  const summary = JSON.stringify({ tool_results: tr });
                  contents.push({ role, parts: [{ text: `Previous tool activity:\n${summary}` }] });
                }
              }
            } catch (_) { /* ignore history failures */ }
            contents.push({ role: 'user', parts: [{ text: prompt }] });
            if (sanitizedAttachments.length > 0) {
              const list = sanitizedAttachments.map((f) => `- ${f.file_name || 'file'} (${f.mime_type || 'unknown'}) -> ${f.url || f.publicUrl || f.signedUrl || f.path}`).join('\n');
              contents.push({ role: 'user', parts: [{ text: `Attached files:\n${list}` }] });
            }
            let textSoFar = '';
            let thoughtsSoFar = '';
            const toolEvents: Array<{ id: number; name: string; result: any }> = [];
            let toolCounter = 0;
            while (true) {
              try {
                const pending: Array<{ name: string; args: Record<string, any> }> = [];
                // @ts-ignore streaming iterable
        const systemInstruction = await buildSystemInstruction(effectiveChatId);
        const streamResp: AsyncIterable<any> | any = await ai.models.generateContentStream({
                  model: modelName,
                  contents,
                  config: {
          tools: [{ functionDeclarations: [...playgroundTools, ...playgroundCanvasTools, ...playgroundReadTools, ...playgroundCompositeTools] }],
                    systemInstruction,
                    ...(includeThoughts ? { thinkingConfig: { thinkingBudget: -1, includeThoughts: true } } : {}),
                  },
                });
                let received = false;
                for await (const chunk of (streamResp as AsyncIterable<any>)) {
                  received = true;
                  const delta: string | undefined = (chunk as any)?.text;
                  if (delta && delta.length > 0) {
                    textSoFar += delta; emit({ type: 'text', delta });
                  }
                  const parts = (chunk as any)?.candidates?.[0]?.content?.parts;
                  if (Array.isArray(parts)) {
                    for (const p of parts) {
                      const t = (p?.thought && typeof p.text === 'string') ? p.text : (p?.role === 'thought' && typeof p.text === 'string') ? p.text : undefined;
                      if (t) { thoughtsSoFar += t; emit({ type: 'thought', delta: t }); }
                    }
                  }
                  const fc = (chunk as any)?.functionCalls;
                  if (Array.isArray(fc) && fc.length > 0) {
                    for (const c of fc) { if (c?.name) pending.push({ name: c.name, args: c.args ?? {} }); }
                  }
                }
                if (!received) {
                  const systemInstruction2 = await buildSystemInstruction(effectiveChatId);
                  const single = await ai.models.generateContent({ model: modelName, contents, config: { tools: [{ functionDeclarations: [...playgroundTools, ...playgroundCanvasTools, ...playgroundReadTools, ...playgroundCompositeTools] }], systemInstruction: systemInstruction2, ...(includeThoughts ? { thinkingConfig: { thinkingBudget: -1, includeThoughts: true } } : {}), } });
                  if (single.functionCalls && single.functionCalls.length > 0) {
                    for (const c of single.functionCalls) { pending.push({ name: (c as any).name, args: (c as any).args ?? {} }); }
                  } else {
                    const final = single.text ?? '';
                    for (let i = 0; i < final.length; i += 64) { const d = final.slice(i, i+64); textSoFar += d; emit({ type: 'text', delta: d }); }
                  }
                }
                if (pending.length > 0) {
                  for (const { name, args } of pending) {
                    const id = ++toolCounter;
                    emit({ type: 'tool_in_progress', id, name });
                    const marker = `\n\n[tool:${id}]\n\n`;
                    textSoFar += marker; emit({ type: 'text', delta: marker });
                    const toolResponse = await executeTool(name, args, effectiveChatId);
                    emit({ type: 'tool_result', id, name, result: toolResponse });
                    toolEvents.push({ id, name, result: toolResponse });
                    contents.push({ role: 'model', parts: [{ functionCall: { name, args } }] });
                    contents.push({ role: 'user', parts: [{ functionResponse: { name, response: { result: toolResponse } } }] });
                  }
                  continue;
                }
                break;
              } catch (err: any) {
                emit({ type: 'error', message: err?.message ?? String(err) });
                throw err;
              }
            }
            // Persist AI message after stream ends, with sanitized tool results and thoughts
            const sanitizedToolResults = { events: toolEvents };
            const inserted = await supabase.from('playground_chat_messages').insert({
              chat_id: effectiveChatId,
              sender: 'ai',
              message_type: 'text',
              content: textSoFar,
              thoughts: thoughtsSoFar || null,
              tool_results: sanitizedToolResults,
            }).select('id').single();
            const messageId = (inserted as any)?.data?.id;
            // Update any artifacts created during this turn with message_id
            try {
              for (const ev of toolEvents) {
                const aid = (ev?.result as any)?.artifact_id as string | undefined;
                if (messageId && typeof aid === 'string' && aid) {
                  await supabase.from('playground_artifacts').update({ message_id: messageId }).eq('id', aid);
                }
              }
            } catch (_) { /* noop */ }
            emit({ type: 'end', finalText: textSoFar, messageId });
          }

          try {
            await streamOnce(preferredModel);
          } catch (err) {
            if (preferredModel !== DEFAULT_MODEL) { await streamOnce(DEFAULT_MODEL); } else { throw err; }
          } finally {
            clearInterval(interval); controller.close();
          }
        }
      });
      return new Response(stream, { headers: { ...corsHeaders, 'Content-Type': 'application/x-ndjson; charset=utf-8', 'Cache-Control': 'no-cache, no-transform', 'X-Accel-Buffering': 'no', 'Connection': 'keep-alive', 'Keep-Alive': 'timeout=5' } });
    }

    // Non-stream fallback
  const res = await runOnce(preferredModel);
    return new Response(JSON.stringify(res), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
  } catch (error: any) {
    return new Response(JSON.stringify({ error: error?.message ?? String(error) }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 500 });
  }
});
