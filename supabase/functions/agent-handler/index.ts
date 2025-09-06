import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { GoogleGenAI, createUserContent, createPartFromUri } from "https://esm.sh/@google/genai";
import {
  availableTools,
  projectCardPreviewTool,
  todoListCreateTool,
  todoListCheckTool,
  artifactReadTool,
  analyzeDocumentTool,
  implementFeatureAndUpdateTodoTool,
  buildToolboxGuidance,
  lintCheckTool,
  analyzeCodeTool,
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
    const geminiApiKey = Deno.env.get("GEMINI_API_KEY");
    if (!geminiApiKey) throw new Error("GEMINI_API_KEY is not set in the Supabase project secrets.");

  const { prompt, history, projectId, model: requestedModel, includeThoughts, chatId, attachedFiles: rawAttachedFiles } = await req.json();

    const ai = new GoogleGenAI({ apiKey: geminiApiKey });
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: req.headers.get("Authorization") ?? '' } } }
    );

    // Helpers for robust file URL access
    const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || '';
    const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || '';
    const admin = SERVICE_ROLE_KEY
      ? createClient(SUPABASE_URL, SERVICE_ROLE_KEY)
      : null;

    function parseBucketKeyFromUrl(u: string): { bucket?: string; key?: string } {
      try {
        const url = new URL(u);
        if (!SUPABASE_URL || !u.startsWith(SUPABASE_URL)) return {};
        // Expect path like /storage/v1/object/(public|sign|authenticated)?/bucket/key...
        const parts = url.pathname.split('/').filter(Boolean);
        const idx = parts.findIndex((p) => p === 'object');
        if (idx === -1 || idx + 1 >= parts.length) return {};
        let offset = idx + 1;
        // Skip mode segment if present
        const mode = parts[offset];
        const modes = new Set(['public', 'sign', 'authenticated']);
        if (modes.has(mode)) offset += 1;
        const bucket = parts[offset];
        const keyParts = parts.slice(offset + 1);
        if (!bucket || keyParts.length === 0) return {};
        const key = decodeURIComponent(keyParts.join('/'));
        return { bucket, key };
      } catch (_) { return {}; }
    }

    async function createFreshSignedUrlFromAttachment(att: any): Promise<string | ''> {
      try {
        const bucket = att?.bucket || att?.bucket_id || undefined;
        const key = att?.key || att?.path || att?.storage_path || att?.object_path || undefined;
        if (bucket && key) {
          const client = admin ?? supabase;
          // 10 minutes
          // @ts-ignore storage typings available in runtime
          const { data, error } = await (client as any).storage.from(bucket).createSignedUrl(key, 600);
          if (!error && data?.signedUrl) return data.signedUrl as string;
        }
        // Try derive from an existing URL
        const fromUrl = att?.signedUrl || att?.publicUrl || att?.url || att?.bucket_url;
        if (typeof fromUrl === 'string' && fromUrl.startsWith('http')) {
          const { bucket: b, key: k } = parseBucketKeyFromUrl(fromUrl);
          if (b && k) {
            const client = admin ?? supabase;
            // 10 minutes
            // @ts-ignore
            const { data, error } = await (client as any).storage.from(b).createSignedUrl(k, 600);
            if (!error && data?.signedUrl) return data.signedUrl as string;
          }
        }
      } catch (_) {}
      return '';
    }

    // Normalize attachments: if base64 provided, upload to Storage (images -> images/, others -> docs/)
    async function sanitizeAttachments(list: any[]): Promise<any[]> {
      const out: any[] = [];
      const bucket = 'user-uploads';
      for (const att of (Array.isArray(list) ? list : [])) {
        try {
          const mime = (typeof att?.mime_type === 'string' && att.mime_type) ? String(att.mime_type) : 'application/octet-stream';
          const name = (typeof att?.file_name === 'string' && att.file_name) ? String(att.file_name) : (typeof att?.name === 'string' ? String(att.name) : 'file');
          if (typeof att?.data === 'string' && att.data.length > 0) {
            const b64 = att.data as string;
            const bytes = Uint8Array.from(atob(b64), c => c.charCodeAt(0));
            const folder = mime.startsWith('image/') ? 'images' : 'docs';
            const safeName = name.replace(/[^a-zA-Z0-9_.-]/g, '_');
            const path = `${folder}/${Date.now()}_${safeName}`;
            const client = admin ?? supabase;
            // @ts-ignore
            const { error: upErr } = await (client as any).storage.from(bucket).upload(path, new Blob([bytes], { type: mime }), { contentType: mime, upsert: true });
            if (upErr) { out.push(att); continue; }
            // @ts-ignore
            const { data: s } = await (client as any).storage.from(bucket).createSignedUrl(path, 600);
            const signedUrl = (s && (s.signedUrl || s.signed_url)) || '';
            const bucketUrl = `${SUPABASE_URL}/storage/v1/object/${bucket}/${path}`;
            out.push({ ...att, bucket, path, mime_type: mime, file_name: name, bucket_url: bucketUrl, ...(signedUrl ? { signedUrl } : {}), uri: signedUrl || bucketUrl, data: undefined });
            continue;
          }
          if (att?.bucket && (att?.path || att?.key || att?.storage_path || att?.object_path)) {
            const fresh = await createFreshSignedUrlFromAttachment(att);
            const prefer = (att.signedUrl || att.publicUrl || att.url || att.bucket_url || '') as string;
            const uri = fresh || prefer;
            out.push({ ...att, ...(fresh ? { signedUrl: fresh } : {}), ...(uri ? { uri } : {}) });
            continue;
          }
          const prefer = (att.signedUrl || att.publicUrl || att.url || att.bucket_url || '') as string;
          if (prefer && prefer.startsWith('http')) { out.push({ ...att, uri: prefer }); continue; }
          out.push(att);
        } catch (_) {
          out.push(att);
        }
      }
      return out;
    }

    async function resolveBestUrl(args: any, list: any[]): Promise<{ url: string; source: string }> {
      const prefer = (f: any) => f?.signedUrl || f?.publicUrl || f?.url || f?.bucket_url || '';
      let alias = '';
      let url = typeof args?.file_uri === 'string' ? String(args.file_uri) : '';
      if (!url.startsWith('http')) alias = url || String(args?.name || args?.file_name || '');
      if (url && url.startsWith('http')) return { url, source: 'args' };
      const needle = alias.trim().toLowerCase();
      const hit = Array.isArray(list) ? list.find((f: any) => [f.name, f.path, f.file_name]
        .filter(Boolean)
        .map((x: any) => String(x))
        .some((x: string) => x.toLowerCase() === needle || x.toLowerCase().endsWith(`/${needle}`))) : undefined;
      if (hit) {
        const direct = prefer(hit);
        if (direct && direct.startsWith('http')) return { url: direct, source: 'attachment-direct' };
        const fresh = await createFreshSignedUrlFromAttachment(hit);
        if (fresh) return { url: fresh, source: 'attachment-signed' };
      }
      if (Array.isArray(list) && list.length === 1) {
        const single = list[0];
        const direct = prefer(single);
        if (direct && direct.startsWith('http')) return { url: direct, source: 'single-direct' };
        const fresh = await createFreshSignedUrlFromAttachment(single);
        if (fresh) return { url: fresh, source: 'single-signed' };
      }
      // Last resort: if args provided a Supabase URL without signature, try to sign it
      if (typeof args?.file_uri === 'string' && args.file_uri.startsWith(SUPABASE_URL)) {
        const { bucket, key } = parseBucketKeyFromUrl(args.file_uri);
        if (bucket && key) {
          const client = admin ?? supabase;
          // @ts-ignore
          const { data } = await (client as any).storage.from(bucket).createSignedUrl(key, 600);
          if (data?.signedUrl) return { url: data.signedUrl as string, source: 'arg-resigned' };
        }
      }
      return { url: '', source: 'none' };
    }

    async function fetchWithRetry(fileUrl: string, authHeader: string): Promise<Response> {
      let resp = await fetch(fileUrl);
      if (!resp.ok && authHeader) resp = await fetch(fileUrl, { headers: { Authorization: authHeader } });
      return resp;
    }

    // Try to parse Supabase Storage error JSON to capture `code` and `message`
    async function parseSupabaseStorageError(resp: Response): Promise<{ code?: string; message?: string; raw?: string }>{
      try {
        const clone = resp.clone();
        const txt = await clone.text();
        try {
          const json = JSON.parse(txt);
          const code = typeof json?.code === 'string' ? json.code : undefined;
          const message = typeof json?.message === 'string' ? json.message : undefined;
          if (code || message) return { code, message, raw: txt };
          return { raw: txt };
        } catch {
          return { raw: txt };
        }
      } catch {
        return {};
      }
    }

    function deriveBucketKey(att: any): { bucket?: string; key?: string } {
      const bucket = att?.bucket || att?.bucket_id || undefined;
      const key = att?.key || att?.path || att?.storage_path || att?.object_path || undefined;
      return { bucket, key };
    }

    async function downloadStorageObject(bucket?: string, key?: string): Promise<{ ok: boolean; bytes?: Uint8Array; mime?: string; err?: string }>{
      try {
        if (!bucket || !key) return { ok: false, err: 'missing bucket/key' };
        const client = admin ?? supabase;
        // @ts-ignore runtime typings
        const { data, error } = await (client as any).storage.from(bucket).download(key);
        if (error) return { ok: false, err: error.message };
        // data is a Blob in edge runtime
        const buf = new Uint8Array(await data.arrayBuffer());
        const mime = (data as any)?.type || 'application/octet-stream';
        return { ok: true, bytes: buf, mime };
      } catch (e: any) {
        return { ok: false, err: e?.message ?? String(e) };
      }
    }

    // Safe base64 encoder for potentially large byte arrays
    function bytesToBase64(bytes: Uint8Array): string {
      let binary = '';
      const chunkSize = 0x8000; // 32KB chunks to avoid call stack overflow
      for (let i = 0; i < bytes.length; i += chunkSize) {
        const sub = bytes.subarray(i, i + chunkSize);
        binary += String.fromCharCode.apply(null, Array.from(sub) as any);
      }
      return btoa(binary);
    }

    function guessMimeFromUrl(u: string): string | '' {
      try {
        const lower = u.toLowerCase();
        if (lower.includes('.png')) return 'image/png';
        if (lower.includes('.jpg') || lower.includes('.jpeg')) return 'image/jpeg';
        if (lower.includes('.webp')) return 'image/webp';
        if (lower.includes('.heic')) return 'image/heic';
        if (lower.includes('.heif')) return 'image/heif';
        if (lower.includes('.gif')) return 'image/gif';
        if (lower.includes('.svg')) return 'image/svg+xml';
        if (lower.includes('.pdf')) return 'application/pdf';
        if (lower.endsWith('.txt')) return 'text/plain';
        if (lower.endsWith('.md')) return 'text/markdown';
        if (lower.endsWith('.csv')) return 'text/csv';
        if (lower.endsWith('.json')) return 'application/json';
        if (lower.endsWith('.html') || lower.endsWith('.htm')) return 'text/html';
        if (lower.endsWith('.xml')) return 'application/xml';
        if (lower.endsWith('.docx')) return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
        if (lower.endsWith('.pptx')) return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
        if (lower.endsWith('.xlsx')) return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
        if (lower.endsWith('.zip')) return 'application/zip';
      } catch (_) {}
      return '';
    }

  const DEFAULT_MODEL = "gemini-2.5-flash";
  const preferredModel = (typeof requestedModel === 'string' && requestedModel.length > 0) ? requestedModel : DEFAULT_MODEL;
  const attachedFiles = await sanitizeAttachments(rawAttachedFiles);

    // Unified function declarations for build mode (read/write + agent artifacts)
    const functionDeclarations = [
      ...availableTools,
      projectCardPreviewTool,
      todoListCreateTool,
      todoListCheckTool,
      artifactReadTool,
      analyzeDocumentTool,
      implementFeatureAndUpdateTodoTool,
      // Quality tools available to agents
      lintCheckTool,
      analyzeCodeTool,
    ];

    // Helper to execute agent artifact tools against agent_artifacts table
    async function executeAgentArtifactTool(
      name: string,
      args: Record<string, any>,
      opts: {
        projectId: string;
        chatId?: string | null;
        supabase: any;
        fileEdits?: any[];
        emit?: (obj: unknown) => void;
      },
    ): Promise<any> {
      const { projectId, chatId, supabase, fileEdits, emit } = opts;
      switch (name) {
        case 'project_card_preview': {
          const safe = {
            name: String(args.name ?? ''),
            summary: String(args.summary ?? ''),
            stack: Array.isArray(args.stack) ? args.stack.slice(0, 12).map(String) : [],
            key_features: Array.isArray(args.key_features) ? args.key_features.slice(0, 12).map(String) : [],
            can_implement_in_canvas: Boolean(args.can_implement_in_canvas ?? false),
          };
          const { data: art, error: artErr } = await supabase
            .from('agent_artifacts')
            .insert({ project_id: projectId, chat_id: chatId || null, artifact_type: 'project_card_preview', data: safe })
            .select('id')
            .single();
          if (artErr) return { status: 'error', message: artErr.message, card: safe };
          return { status: 'success', card: safe, artifact_id: (art as any)?.id };
        }
        case 'todo_list_create': {
          const title = String(args.title ?? 'Todo');
          const tasks = Array.isArray(args.tasks) ? args.tasks : [];
          const items = tasks.map((t: any, i: number) => ({
            id: String(t?.id ?? `${i + 1}`),
            title: String(t?.title ?? `Task ${i + 1}`),
            done: Boolean(t?.done ?? false),
            notes: typeof t?.notes === 'string' ? t.notes : undefined,
          }));
          const todo = { title, tasks: items };
          const { data: art, error: artErr } = await supabase
            .from('agent_artifacts')
            .insert({ project_id: projectId, chat_id: chatId || null, artifact_type: 'todo_list', data: todo })
            .select('id')
            .single();
          if (artErr) return { status: 'error', message: artErr.message, todo };
          return { status: 'success', todo, artifact_id: (art as any)?.id };
        }
        case 'todo_list_check': {
          const artifactId = String(args.artifact_id ?? '').trim();
          if (!artifactId) return { status: 'error', message: 'artifact_id is required' };
          const completedIds: string[] = Array.isArray(args.completed_task_ids)
            ? (args.completed_task_ids as any[]).map((x) => String(x))
            : [];
          const { data: artRow, error: selErr } = await supabase
            .from('agent_artifacts')
            .select('id, data, artifact_type, project_id, chat_id')
            .eq('id', artifactId)
            .single();
          if (selErr) return { status: 'error', message: selErr.message };
          if (!artRow || (artRow as any).project_id !== projectId || (artRow as any).artifact_type !== 'todo_list') {
            return { status: 'error', message: 'Artifact not found for this project or not a todo_list' };
          }
          const todo = (artRow as any).data ?? {};
          const tasks: any[] = Array.isArray(todo.tasks) ? todo.tasks : [];
          if (completedIds.length > 0) {
            for (const t of tasks) if (completedIds.includes(String(t.id))) t.done = true;
          }
          const updated = { ...todo, tasks };
          const { error: updErr } = await supabase
            .from('agent_artifacts')
            .update({ data: updated, last_modified: new Date().toISOString() })
            .eq('id', artifactId);
          if (updErr) return { status: 'error', message: updErr.message };
          const contextNote = typeof args.context === 'string' ? String(args.context) : undefined;
          return { status: 'success', todo: updated, artifact_id: artifactId, notes: contextNote ? `Context considered: ${contextNote.slice(0,200)}` : undefined };
        }
        case 'artifact_read': {
          const id = String(args.id ?? '').trim();
          if (!id) return { status: 'error', message: 'id is required' };
          const { data, error } = await supabase
            .from('agent_artifacts')
            .select('id, artifact_type, key, data, project_id, chat_id, last_modified')
            .eq('id', id)
            .single();
          if (error) return { status: 'error', message: error.message };
          if (!data || (data as any).project_id !== projectId) return { status: 'error', message: 'Not found for this project' };
          return { status: 'success', id: (data as any).id, artifact_type: (data as any).artifact_type, key: (data as any).key, data: (data as any).data, last_modified: (data as any).last_modified };
        }
        case 'implement_feature_and_update_todo': {
          const artifactId = String(args.artifact_id ?? '').trim();
          const taskId = String(args.task_id ?? '').trim();
          if (!artifactId || !taskId) return { status: 'error', message: 'artifact_id and task_id are required' };
          const edits: Array<any> = Array.isArray(args.edits) ? args.edits : [];
          const singlePath = String(args.path ?? '').trim();
          const singleNewContent = String(args.new_content ?? '');
          const plannedEdits = edits.length > 0 ? edits : (singlePath ? [{ operation: 'update', path: singlePath, new_content: singleNewContent }] : []);
          if (plannedEdits.length === 0) return { status: 'error', message: 'No edits provided' };

          const applied: Array<{ operation: string; path: string; old_content: string; new_content: string }> = [];
          for (const e of plannedEdits) {
            const op = String(e.operation ?? 'update');
            const path = String(e.path ?? '').trim();
            const newContent = String(e.new_content ?? '');
            if (!path) return { status: 'error', message: 'Each edit requires a path' };
            if ((op === 'create' || op === 'update') && typeof newContent !== 'string') return { status: 'error', message: `Edit for ${path} missing new_content` };

            const { data: existing } = await supabase
              .from('project_files')
              .select('content')
              .eq('project_id', projectId)
              .eq('path', path)
              .maybeSingle();

            if (op === 'delete') {
              const oldContent = String(existing?.content ?? '');
              const { error } = await supabase
                .from('project_files')
                .delete()
                .eq('project_id', projectId)
                .eq('path', path);
              if (error) return { status: 'error', message: error.message };
              applied.push({ operation: 'delete', path, old_content: oldContent, new_content: '' });
              fileEdits?.push?.({ operation: 'delete', path, old_content: oldContent, new_content: '' });
              emit?.({ type: 'file_edit', operation: 'delete', path, old_content: oldContent, new_content: '' });
              continue;
            }

            if (existing) {
              const oldContent = String(existing.content ?? '');
              const { error } = await supabase
                .from('project_files')
                .update({ content: newContent, last_modified: new Date().toISOString() })
                .eq('project_id', projectId)
                .eq('path', path);
              if (error) return { status: 'error', message: error.message };
              applied.push({ operation: 'update', path, old_content: oldContent, new_content: newContent });
              fileEdits?.push?.({ operation: 'update', path, old_content: oldContent, new_content: newContent });
              emit?.({ type: 'file_edit', operation: 'update', path, old_content: oldContent, new_content: newContent });
            } else {
              const { error } = await supabase
                .from('project_files')
                .insert({ project_id: projectId, path, content: newContent });
              if (error) return { status: 'error', message: error.message };
              applied.push({ operation: 'create', path, old_content: '', new_content: newContent });
              fileEdits?.push?.({ operation: 'create', path, old_content: '', new_content: newContent });
              emit?.({ type: 'file_edit', operation: 'create', path, old_content: '', new_content: newContent });
            }
          }

          // Mark todo task done
          const { data: artRow, error: selErr } = await supabase
            .from('agent_artifacts')
            .select('id, data, artifact_type, project_id, chat_id')
            .eq('id', artifactId)
            .single();
          if (selErr) return { status: 'error', message: selErr.message };
          if (!artRow || (artRow as any).project_id !== projectId || (artRow as any).artifact_type !== 'todo_list') {
            return { status: 'error', message: 'Artifact not found for this project or not a todo_list' };
          }
          const todo = (artRow as any).data ?? {};
          const tasks: any[] = Array.isArray(todo.tasks) ? todo.tasks : [];
          let taskTitle: string | undefined;
          for (const t of tasks) if (String(t.id) === taskId) { t.done = true; taskTitle = typeof t.title === 'string' ? t.title : String(t.id); }
          const updated = { ...todo, tasks };
          const { error: updErr } = await supabase
            .from('agent_artifacts')
            .update({ data: updated, last_modified: new Date().toISOString() })
            .eq('id', artifactId);
          if (updErr) return { status: 'error', message: updErr.message };
          return { status: 'success', edits: applied, artifact_id: artifactId, task_id: taskId, task_title: taskTitle };
        }
        default:
          return { status: 'error', message: `Unknown tool: ${name}` };
      }
    }

  async function runOnce(modelName: string): Promise<{ text: string; fileEdits: any[]; filesAnalyzed?: any[]; artifactIds?: string[] }> {
      // System instruction with project context
      const projectRows = await supabase
        .from('projects')
        .select('name, description, stack')
        .eq('id', projectId)
        .single();
      const projectName = (projectRows as any)?.data?.name || 'Project';
      const projectDescription = (projectRows as any)?.data?.description || 'No description provided';
      const projectStack = (projectRows as any)?.data?.stack || [];

      const filesList = await supabase
        .from('project_files')
        .select('path')
        .eq('project_id', projectId)
        .order('path');
      const filePaths = Array.isArray((filesList as any)) ? (filesList as any).map((r: any) => r.path) : (((filesList as any)?.data) || []).map((r: any) => r.path);
  const toolGuidance = buildToolboxGuidance(functionDeclarations);

  const attachmentsNote = (() => {
    const list = Array.isArray(attachedFiles) ? attachedFiles : [];
    const usable = list
      .map((f: any) => ({
        name: f.name || f.path || 'file',
        mime_type: f.mime_type || 'application/octet-stream',
        file_uri: f.bucket_url || f.url || f.publicUrl || f.signedUrl || '',
      }))
      .filter((f: any) => typeof f.file_uri === 'string' && f.file_uri.startsWith('http'));
    if (!usable.length) return '';
    const attachmentsJson = JSON.stringify(usable, null, 2);
    return `\n\nATTACHMENTS CONTEXT\n- Use ONLY the exact value of file_uri from the JSON list below.\n- DO NOT pass file names or local paths as file_uri.\n- Call analyze_document like: { file_uri: "<exact file_uri>", mime_type: "<mime>" }.\n- If unsure which to pick, ask the user.\n\nattachments =\n\n\`\`\`json\n${attachmentsJson}\n\`\`\`\n Besides these, if the user manually adds a link in the prompt, analyze that too.`;
  })();
  const systemInstruction = `You are Robin, an expert AI software development assistant working inside a multi-pane IDE. Always identify yourself as Robin.\nCurrent project: ${projectName}.\n Project description: ${projectDescription}. \n Stack for the project: ${projectStack.map((s: string) => `- ${s}`).join('\n')}\n\n Project files (${filePaths.length}):\n${filePaths.map((p: string) => `- ${p}`).join('\n')}\n\n Assist the user with requests in the context of the project.${toolGuidance}${attachmentsNote}\n\nQUALITY GATES\n- After batches of edits, run lint_check (fast, non‑LLM) to catch obvious syntax issues.\n- When helpful, use analyze_code for a concise review before presenting results.\n- Keep responses focused and avoid dumping huge code unless necessary.`;

      // Build compositional contents
      // Build history: prefer server-side last 5 turns if chatId provided
      const contents: any[] = [];
      if (typeof chatId === 'string' && chatId.length > 0) {
        try {
          const { data: histRows } = await supabase
            .from('agent_chat_messages')
            .select('sender, content')
            .eq('chat_id', chatId)
            .order('sent_at', { ascending: false })
            .limit(10);
          const rows = Array.isArray(histRows) ? histRows.slice().reverse() : [];
          for (const r of rows) {
            const role = (r.sender === 'user') ? 'user' : 'model';
            const text = String(r.content || '');
            if (text.length > 0) contents.push({ role, parts: [{ text }] });
          }
        } catch (_) {
          // fallback to client history below
        }
      } else if (Array.isArray(history) && history.length > 0) {
        contents.push(...history);
      }
      contents.push({ role: 'user', parts: [{ text: prompt }] });

  const fileEdits: any[] = [];
  const filesAnalyzed: any[] = [];
  const createdArtifactIds: string[] = [];
      let finalText = '';

      while (true) {
        const result = await ai.models.generateContent({
          model: modelName,
      contents,
          config: {
            tools: [{ functionDeclarations: [
              ...availableTools,
              projectCardPreviewTool,
              todoListCreateTool,
              todoListCheckTool,
              artifactReadTool,
              analyzeDocumentTool,
              implementFeatureAndUpdateTodoTool,
              lintCheckTool,
              analyzeCodeTool,
            ] }],
            systemInstruction,
          },
        });

        if (result.functionCalls && result.functionCalls.length > 0) {
          // Execute each function call, then push functionCall and functionResponse back into contents
          for (const functionCall of result.functionCalls) {
            const { name, args } = functionCall as { name: string; args: Record<string, any> };
            let toolResponse: any = {};
            try {
              switch (name) {
                case 'project_card_preview':
                case 'todo_list_create':
                case 'todo_list_check':
                case 'artifact_read': {
                  toolResponse = await executeAgentArtifactTool(name, args, { projectId, chatId, supabase, fileEdits });
                  break;
                }
                case 'implement_feature_and_update_todo': {
                  toolResponse = await executeAgentArtifactTool(name, args, { projectId, chatId, supabase, fileEdits });
                  try {
                    const aid = (toolResponse as any)?.artifact_id;
                    if (typeof aid === 'string' && aid) createdArtifactIds.push(aid);
                  } catch (_) {}
                  break;
                }
                case 'analyze_document': {
                  try {
                    // If base64 provided, analyze directly
                    const base64Arg = (typeof args?.base64 === 'string' && args.base64.trim().length) ? String(args.base64) : '';
                    const instruction = String(args?.instruction ?? 'summarize');
                    if (base64Arg) {
                      let mime = typeof args?.mime_type === 'string' && args.mime_type ? String(args.mime_type) : 'application/octet-stream';
                      const parts = createUserContent([
                        instruction || 'Analyze this file.',
                        { inlineData: { mimeType: mime, data: base64Arg } },
                      ]);
                      const analysis = await ai.models.generateContent({ model: preferredModel, contents: parts });
                      toolResponse = { status: 'success', analysis: analysis.text ?? '', source: 'base64' };
                      break;
                    }

                    // Resolve file_uri robustly: prefer signedUrl/publicUrl from attachments; allow filename alias
                    const list = Array.isArray(attachedFiles) ? attachedFiles : [];
                    const { url: fileUrl } = await resolveBestUrl(args, list);
                    let mime = (typeof args?.mime_type === 'string' && args.mime_type) ? String(args.mime_type) : '';
                    if (fileUrl) {
                      // Fetch URL to bytes and send as inlineData (matches docs and local test)
                      const authHeader = req.headers.get('Authorization') ?? '';
                      let resp = await fetchWithRetry(fileUrl, authHeader);
                      if (!resp.ok) {
                        const supaErr = await parseSupabaseStorageError(resp);
                        // try storage fallback as last resort
                        const alias = String(args?.file_uri || args?.name || args?.file_name || '').trim();
                        const att = Array.isArray(list) ? list.find((f: any) => [f.name, f.path, f.file_name]
                          .filter(Boolean)
                          .map((x: any) => String(x))
                          .some((x: string) => x.toLowerCase() === alias.toLowerCase() || x.toLowerCase().endsWith(`/${alias.toLowerCase()}`))) : undefined;
                        const dk = att ? deriveBucketKey(att) : {};
                        let dl = await downloadStorageObject(dk.bucket, dk.key);
                        // Secondary fallback: parse bucket/key from the (possibly expired) URL itself
                        if (!dl.ok || !dl.bytes) {
                          const { bucket: pb, key: pk } = parseBucketKeyFromUrl(fileUrl) || {} as any;
                          if (pb && pk) dl = await downloadStorageObject(pb, pk);
                        }
                        if (!dl.ok || !dl.bytes) { toolResponse = { status: 'error', stage: 'url_fetch_and_storage_fallback', http_status: resp.status, supabase_error: supaErr, storage_download_error: dl.err || 'unknown', file_url: fileUrl }; break; }
                        if (!mime) mime = dl.mime || 'application/octet-stream';
                        const b64 = bytesToBase64(dl.bytes);
                        const parts = createUserContent([
                          instruction || 'Analyze this file.',
                          { inlineData: { mimeType: mime, data: b64 } },
                        ]);
                        const analysis = await ai.models.generateContent({ model: preferredModel, contents: parts });
                        toolResponse = { status: 'success', analysis: analysis.text ?? '', source: 'storage_download', mime_type: mime, byte_length: dl.bytes.length, file_url: fileUrl };
                      } else {
                        const bytes = new Uint8Array(await resp.arrayBuffer());
                        if (!mime) mime = resp.headers.get('content-type') || guessMimeFromUrl(fileUrl) || 'application/octet-stream';
                        const b64 = bytesToBase64(bytes);
                        const parts = createUserContent([
                          instruction || 'Analyze this file.',
                          { inlineData: { mimeType: mime, data: b64 } },
                        ]);
                        const analysis = await ai.models.generateContent({ model: preferredModel, contents: parts });
                        toolResponse = { status: 'success', analysis: analysis.text ?? '', source: 'url', mime_type: mime, byte_length: bytes.length, file_url: fileUrl };
                      }
                    } else {
                      // Fallback: download from storage and send inline
                      const alias = String(args?.file_uri || args?.name || args?.file_name || '').trim();
                      const att = Array.isArray(list) ? list.find((f: any) => [f.name, f.path, f.file_name]
                        .filter(Boolean)
                        .map((x: any) => String(x))
                        .some((x: string) => x.toLowerCase() === alias.toLowerCase() || x.toLowerCase().endsWith(`/${alias.toLowerCase()}`))) : undefined;
                      const dk = att ? deriveBucketKey(att) : {};
                      const dl = await downloadStorageObject(dk.bucket, dk.key);
                      if (!dl.ok || !dl.bytes) throw new Error('Unable to fetch or download the file (400/404).');
                      if (!mime) mime = dl.mime || 'application/octet-stream';
                      const b64 = btoa(String.fromCharCode(...dl.bytes));
                      const parts = createUserContent([
                        instruction || 'Analyze this file.',
                        { inlineData: { mimeType: mime, data: b64 } },
                      ]);
                      const analysis = await ai.models.generateContent({ model: preferredModel, contents: parts });
                      toolResponse = { status: 'success', analysis: analysis.text ?? '', source: 'storage_download', file_url: null };
                    }
                  } catch (err: any) {
                    toolResponse = { status: 'error', message: err?.message ?? String(err) };
                  }
                  break;
                }
                case 'lint_check': {
                  // Prefer path; else content must be provided
                  let content = '';
                  const maxIssues = Math.max(1, Math.min(200, Number(args.max_issues ?? 50)));
                  if (typeof args.content === 'string' && args.content.length > 0) {
                    content = String(args.content);
                  } else if (typeof args.path === 'string' && args.path.trim().length > 0) {
                    const r = await supabase
                      .from('project_files')
                      .select('content')
                      .eq('project_id', projectId)
                      .eq('path', String(args.path).trim())
                      .single();
                    if ((r as any)?.error) throw (r as any).error;
                    content = String((r as any)?.data?.content ?? '');
                  } else {
                    toolResponse = { status: 'error', message: 'Provide either path or content' };
                    break;
                  }
                  const issues: Array<{ kind: string; message: string; index?: number }> = [];
                  const pairs: Array<[string, string, string]> = [ ['paren','(',')'], ['brace','{','}'], ['bracket','[',']'] ];
                  for (const [kind, open, close] of pairs) {
                    let bal = 0;
                    for (let i = 0; i < content.length; i++) {
                      const ch = content[i];
                      if (ch === open) bal++;
                      else if (ch === close) bal--;
                      if (bal < 0) { issues.push({ kind, message: `Unexpected '${close}' at ${i}`, index: i }); break; }
                      if (issues.length >= maxIssues) break;
                    }
                    if (bal > 0 && issues.length < maxIssues) issues.push({ kind, message: `Unclosed '${open}' (${bal} more)` });
                    if (issues.length >= maxIssues) break;
                  }
                  const quotes: Array<[string, string]> = [["\"",'double'],["'",'single'],['`','backtick']];
                  for (const [q, label] of quotes) {
                    const count = (content.match(new RegExp(q, 'g')) || []).length;
                    if (count % 2 !== 0 && issues.length < maxIssues) issues.push({ kind: 'quote', message: `Unbalanced ${label} quotes` });
                  }
                  toolResponse = { status: 'success', issues, issue_count: issues.length };
                  break;
                }
                case 'analyze_code': {
                  let content = '';
                  if (typeof args.content === 'string' && args.content.length > 0) {
                    content = String(args.content);
                  } else if (typeof args.path === 'string' && args.path.trim().length > 0) {
                    const r = await supabase
                      .from('project_files')
                      .select('content')
                      .eq('project_id', projectId)
                      .eq('path', String(args.path).trim())
                      .single();
                    if ((r as any)?.error) throw (r as any).error;
                    content = String((r as any)?.data?.content ?? '');
                  } else { toolResponse = { status: 'error', message: 'Provide either path or content' }; break; }
                  const max = typeof args.max_bytes === 'number' ? Math.max(0, Math.trunc(args.max_bytes)) : 0;
                  if (max > 0 && content.length > max) content = content.slice(0, max);
                  const language = typeof args.language === 'string' ? String(args.language) : '';
                  const issue = typeof args.issuesToDiagnose === 'string' ? String(args.issuesToDiagnose).trim() : '';
                  const instruction = issue
                    ? `You are a senior software engineer. Diagnose and propose fixes for the following issue in the provided code${language ? ` (${language})` : ''}: "${issue}". Provide 5-10 bullet points: likely causes, concrete fixes with references to lines/sections, and quick sanity checks/tests to validate. Keep it concise and actionable.`
                    : `You are a strict code reviewer. In 6-10 bullet points, list potential errors, risky patterns, and suggestions to improve the code${language ? ` (${language})` : ''}. Keep it concise, concrete, and actionable.`;
                  const modelForAnalysis = issue ? 'gemini-2.5-pro' : 'gemini-2.5-flash';
                  const analysis = await ai.models.generateContent({ model: modelForAnalysis, contents: createUserContent([ instruction, content.slice(0, 16000) ]) });
                  toolResponse = { status: 'success', summary: analysis.text ?? '', focused_on_issue: issue || undefined, model: modelForAnalysis };
                  break;
                }
                case 'create_file': {
                  const newContent = String(args.content ?? '');
                  const { error } = await supabase.from('project_files').insert({
                    project_id: projectId,
                    path: args.path,
                    content: newContent,
                  });
                  if (error) throw error;
                  fileEdits.push({ operation: 'create', path: args.path, old_content: '', new_content: newContent });
                  toolResponse = { status: 'success', message: `Created ${args.path}`, path: args.path, old_content: '', new_content: newContent };
                  break;
                }
                case 'update_file_content': {
                  const { data: existing, error: selectError } = await supabase
                    .from('project_files')
                    .select('content')
                    .eq('project_id', projectId)
                    .eq('path', args.path)
                    .single();
                  if (selectError) throw selectError;
                  const oldContent = String(existing?.content ?? '');
                  const newContent = String(args.new_content ?? '');
                  const { error } = await supabase
                    .from('project_files')
                    .update({ content: newContent })
                    .eq('project_id', projectId)
                    .eq('path', args.path);
                  if (error) throw error;
                  fileEdits.push({ operation: 'update', path: args.path, old_content: oldContent, new_content: newContent });
                  toolResponse = { status: 'success', message: `Updated ${args.path}`, path: args.path, old_content: oldContent, new_content: newContent };
                  break;
                }
                case 'delete_file': {
                  const { data: existing, error: selectError } = await supabase
                    .from('project_files')
                    .select('content')
                    .eq('project_id', projectId)
                    .eq('path', args.path)
                    .single();
                  if (selectError) throw selectError;
                  const oldContent = String(existing?.content ?? '');
                  const { error } = await supabase
                    .from('project_files')
                    .delete()
                    .eq('project_id', projectId)
                    .eq('path', args.path);
                  if (error) throw error;
                  fileEdits.push({ operation: 'delete', path: args.path, old_content: oldContent, new_content: '' });
                  toolResponse = { status: 'success', message: `Deleted ${args.path}`, path: args.path, old_content: oldContent, new_content: '' };
                  break;
                }
                case 'read_file': {
                  const { data, error } = await supabase
                    .from('project_files')
                    .select('content')
                    .eq('project_id', projectId)
                    .eq('path', args.path)
                    .single();
                  if (error) throw error;
                  const content = String(data?.content ?? '');
                  fileEdits.push({ operation: 'read', path: args.path, old_content: content, new_content: content });
                  toolResponse = { status: 'success', content };
                  break;
                }
                case 'search': {
                  const query = String(args.query ?? '');
                  const maxPerFile = Number.isFinite(args.max_results_per_file) ? Number(args.max_results_per_file) : 20;
                  if (!query) {
                    toolResponse = { status: 'error', message: 'query is required' };
                    break;
                  }
                  const { data: files, error: listErr } = await supabase
                    .from('project_files')
                    .select('path, content')
                    .eq('project_id', projectId)
                    .order('path');
                  if (listErr) throw listErr;
                  const results: Array<{ path: string; matches: Array<{ line: number; text: string }> }> = [];
                  const q = query.toLowerCase();
                  for (const f of (files as any[]) ?? []) {
                    const path = String((f as any).path);
                    const content = String((f as any).content ?? '');
                    const lines = content.split('\n');
                    const matches: Array<{ line: number; text: string }> = [];
                    for (let i = 0; i < lines.length; i++) {
                      if (lines[i].toLowerCase().includes(q)) {
                        matches.push({ line: i + 1, text: lines[i].slice(0, 400) });
                        if (matches.length >= maxPerFile) break;
                      }
                    }
                    if (matches.length > 0) results.push({ path, matches });
                  }
                  toolResponse = { status: 'success', query, results };
                  break;
                }
                default:
                  toolResponse = { status: 'error', message: `Unknown function call: ${name}` };
              }
            } catch (err: any) {
              toolResponse = { status: 'error', message: err?.message ?? String(err) };
            }

            // Collect analyze_document results for non-stream clients
            try {
              if (name === 'analyze_document') {
                filesAnalyzed.push(toolResponse);
              }
            } catch (_) {}

            // Push model functionCall and user functionResponse per docs
            contents.push({ role: 'model', parts: [{ functionCall }] });
            contents.push({ role: 'user', parts: [{ functionResponse: { name, response: { result: toolResponse } } }] });
          }
          // Continue loop to let the model compose more calls or produce text
          continue;
        } else {
          finalText = result.text ?? '';
          break;
        }
      }

  const toolHeader = fileEdits.length ? `\n\nChanges applied:\n${fileEdits
        .filter((e) => e.operation !== 'read')
        .map((e) => `- ${e.operation} ${e.path}`)
        .join('\n')}` : '';

  // Deduplicate filesAnalyzed by composite key to avoid double entries
  const uniq: any[] = [];
  const seen = new Set<string>();
  for (const r of filesAnalyzed) {
    try {
      const m = (r && typeof r === 'object') ? r as any : {};
      const key = [m.file_url || '', m.status || '', m.source || '', m.mime_type || '', String(m.byte_length || '')].join('|');
      if (!seen.has(key)) { seen.add(key); uniq.push(r); }
    } catch { uniq.push(r); }
  }
  return { text: `${finalText}${toolHeader}`, fileEdits, filesAnalyzed: uniq, artifactIds: createdArtifactIds };
    }

    // If client requests streaming (NDJSON), emit chunks in real time.
    const wantsStream = (req.headers.get('accept')?.includes('application/x-ndjson')) || (req.headers.get('x-stream') === 'true');
  if (wantsStream) {
      const encoder = new TextEncoder();
      const stream = new ReadableStream<Uint8Array>({
        async start(controller) {
          function emit(obj: unknown) {
            controller.enqueue(encoder.encode(JSON.stringify(obj) + "\n"));
          }
          // Heartbeat to nudge proxies to flush buffers
          const interval = setInterval(() => {
            try { emit({ type: 'ping', t: Date.now() }); } catch (_) { /* noop */ }
          }, 1000);

          async function streamOnce(modelName: string) {
            const createdArtifactIds: string[] = [];
            // Same context build as runOnce
            const projectRows = await supabase
              .from('projects')
              .select('name, description, stack')
              .eq('id', projectId)
              .single();
            const projectName = (projectRows as any)?.data?.name || 'Project';
            const projectDescription = (projectRows as any)?.data?.description || 'No description provided';
            const projectStack = (projectRows as any)?.data?.stack || [];

            const filesList = await supabase
              .from('project_files')
              .select('path')
              .eq('project_id', projectId)
              .order('path');
            const filePaths = Array.isArray((filesList as any)) ? (filesList as any).map((r: any) => r.path) : (((filesList as any)?.data) || []).map((r: any) => r.path);
            // Collect chat-specific agent artifacts (ids and short titles) and include in guidance
            let artifactsList = '';
            try {
              if (chatId) {
                const { data: arts } = await supabase
                  .from('agent_artifacts')
                  .select('id, artifact_type, data, last_modified')
                  .eq('chat_id', chatId)
                  .order('last_modified', { ascending: false })
                  .limit(30);
                const lines: string[] = [];
                for (const a of (arts ?? [])) {
                  const d: any = (a as any)?.data ?? {};
                  const title = (d?.title ?? d?.name ?? a?.artifact_type ?? 'untitled');
                  lines.push(`- ${a.id}: ${title} [${a.artifact_type}]`);
                }
                if (lines.length > 0) {
                  artifactsList = `\nAvailable artifacts for this chat (id: title [type]):\n${lines.join('\n')}`;
                }
              }
            } catch (_) { /* ignore */ }

            const attachmentsNote = (() => {
              const list = Array.isArray(attachedFiles) ? attachedFiles : [];
              const usable = list
                .map((f: any) => ({
                  name: f.name || f.path || 'file',
                  mime_type: f.mime_type || 'application/octet-stream',
                  file_uri: f.bucket_url || f.url || f.publicUrl || f.signedUrl || '',
                }))
                .filter((f: any) => typeof f.file_uri === 'string' && f.file_uri.startsWith('http'));
              if (!usable.length) return '';
              const attachmentsJson = JSON.stringify(usable, null, 2);
              return `\n\nATTACHMENTS CONTEXT\n- Use ONLY the exact value of file_uri from the JSON list below.\n- DO NOT pass file names or local paths as file_uri.\n- Call analyze_document like: { file_uri: "<exact file_uri>", mime_type: "<mime>" }.\n- If unsure which to pick, ask the user.\n\nattachments =\n\n\`\`\`json\n${attachmentsJson}\n\`\`\`\n`;
            })();
            const systemInstruction = `You are Robin, an expert AI software development assistant working inside a multi-pane IDE. Always identify yourself as Robin.\nCurrent project: ${projectName}.\n Project description: ${projectDescription}. \n Stack for the project: ${projectStack.map((s: string) => `- ${s}`).join('\n')}\n\n Project files (${filePaths.length}):\n${filePaths.map((p: string) => `- ${p}`).join('\n')}\n\n Assist the user with requests in the context of the project.${buildToolboxGuidance(functionDeclarations)}${attachmentsNote}\n\nQUALITY GATES\n- After batches of edits, run lint_check (fast, non‑LLM) to catch obvious syntax issues.\n- When helpful, use analyze_code for a concise review before presenting results.\n- Keep responses focused and avoid dumping huge code unless necessary.\n\nNOTE:\n- Do not start a response with labels like 'Robin:', 'AI:', or 'Assistant:'. If you introduce yourself, do it only at the start of the conversation.${artifactsList}`;

            const contents: any[] = Array.isArray(history) && history.length > 0 ? [...history] : [];
            contents.push({ role: 'user', parts: [{ text: prompt }] });

            const fileEdits: any[] = [];
            let textSoFar = '';
            let thoughtsSoFar = '';
            let nextToolId = 1;

            emit({ type: 'start', model: modelName });

            // Tool-call loop with streaming text
            while (true) {
              // Collect function calls (if any) from this round
              const pendingCalls: Array<{ name: string; args: Record<string, any>; id: number } > = [];
              try {
                // Use the latest streaming API: the returned value is an async iterable
                // of chunks with .text and possibly .functionCalls and parts (including thoughts).
                // @ts-ignore - types may differ across SDK versions
                const streamResp: AsyncIterable<any> | any = await ai.models.generateContentStream({
                  model: modelName,
                  contents,
                  config: {
                    tools: [{ functionDeclarations: [
                      ...availableTools,
                      projectCardPreviewTool,
                      todoListCreateTool,
                      todoListCheckTool,
                      artifactReadTool,
                      analyzeDocumentTool,
                      implementFeatureAndUpdateTodoTool,
                      lintCheckTool,
                      analyzeCodeTool,
                    ] }],
                    systemInstruction,
                    ...(includeThoughts ? { thinkingConfig: { thinkingBudget: -1, includeThoughts: true } } : {}),
                  },
                });

                let receivedAny = false;
                // Some SDKs return the iterable directly; iterate over it
                for await (const chunk of (streamResp as AsyncIterable<any>)) {
                  receivedAny = true;
                  const delta: string | undefined = chunk?.text;
                  if (delta && delta.length > 0) {
                    textSoFar += delta;
                    emit({ type: 'text', delta });
                  }
                  // Emit thought deltas when present (UI currently ignores by default)
                  const parts = chunk?.candidates?.[0]?.content?.parts;
                  if (Array.isArray(parts)) {
                    for (const p of parts) {
                      const t = (p?.thought && typeof p.text === 'string') ? p.text :
                                (p?.role === 'thought' && typeof p.text === 'string') ? p.text : undefined;
                      if (t && t.length > 0) {
                        thoughtsSoFar += t;
                        emit({ type: 'thought', delta: t });
                        console.log('[agent-handler] thought delta:', t);
                      }
                    }
                  }
                  const fc = chunk?.functionCalls;
                  if (Array.isArray(fc) && fc.length > 0) {
                    for (const c of fc) {
                      if (c && typeof c.name === 'string') {
                        const id = nextToolId++;
                        pendingCalls.push({ name: c.name, args: c.args ?? {}, id });
                      }
                    }
                  }
                }

                if (!receivedAny) {
                  // Fallback to non-streaming single shot
                  const single = await ai.models.generateContent({
                    model: modelName,
                    contents,
                    config: {
                      tools: [{ functionDeclarations: [
                        ...availableTools,
                        projectCardPreviewTool,
                        todoListCreateTool,
                        todoListCheckTool,
                        artifactReadTool,
                        analyzeDocumentTool,
                        implementFeatureAndUpdateTodoTool,
                        lintCheckTool,
                        analyzeCodeTool,
                      ] }],
                      systemInstruction,
                      ...(includeThoughts ? { thinkingConfig: {thinkingBudget: -1, includeThoughts: true } } : {}),
                    },
                  });
                  // If tool calls requested, mark flag; else stream the text in chunks
                  if (single.functionCalls && single.functionCalls.length > 0) {
                    for (const c of single.functionCalls) {
                      if (c && typeof c.name === 'string') {
                        const id = nextToolId++;
                        pendingCalls.push({ name: c.name, args: c.args ?? {}, id });
                      }
                    }
                  } else {
                    const finalText = single.text ?? '';
                    // Emit in chunks for better UX
                    for (let i = 0; i < finalText.length; i += 64) {
                      const d = finalText.slice(i, i + 64);
                      textSoFar += d;
                      emit({ type: 'text', delta: d });
                    }
                  }
                }

                // Execute function calls (if any), do not stream the calls themselves
                if (pendingCalls.length > 0) {
                  for (const { name, args, id } of pendingCalls as Array<{ name: string; args: Record<string, any>; id: number }>) {
                    let toolResponse: any = {};
                    try {
                      // Insert inline marker and emit in-progress event
                      emit({ type: 'text', delta: `\n\n[tool:${id}]\n\n` });
                      emit({ type: 'tool_in_progress', id, name });
                      switch (name) {
                        case 'project_card_preview':
                        case 'todo_list_create':
                        case 'todo_list_check':
                        case 'artifact_read':
                        case 'analyze_document': {
                          if (name === 'analyze_document') {
                            try {
                              const instruction = String(args?.instruction ?? 'Analyze this file.');
                              const base64Arg = (typeof args?.base64 === 'string' && args.base64.trim().length) ? String(args.base64) : '';
                              if (base64Arg) {
                                const mime = (typeof args?.mime_type === 'string' && args.mime_type) ? String(args.mime_type) : 'application/octet-stream';
                                const contentsForBase64 = [ { role: 'user', parts: [ { inlineData: { mimeType: mime, data: base64Arg } }, { text: instruction } ] } ];
                                const analysis = await ai.models.generateContent({ model: preferredModel, contents: contentsForBase64 });
                                toolResponse = { status: 'success', analysis: analysis.text ?? '', source: 'base64', mime_type: mime };
                              } else {
                                // Resolve URL and prefer direct URI consumption via createPartFromUri
                                const list = Array.isArray(attachedFiles) ? attachedFiles : [];
                                const { url: resolvedUrl } = await resolveBestUrl(args, list);
                                if (!resolvedUrl) throw new Error('file_uri is required for analyze_document');
                                const explicitMime = (typeof args?.mime_type === 'string' && args.mime_type) ? String(args.mime_type) : '';
                                let mime = explicitMime || guessMimeFromUrl(resolvedUrl) || 'application/octet-stream';
                                try {
                                  const analysis = await ai.models.generateContent({ model: preferredModel, contents: [ { role: 'user', parts: [ createPartFromUri(resolvedUrl, mime), { text: instruction } ] } ] });
                                  toolResponse = { status: 'success', analysis: analysis.text ?? '', mime_type: mime, file_uri: resolvedUrl, source: 'uri' };
                                } catch (_uriErr: any) {
                                  // Fallback: fetch into inlineData; try public/auth header fetch then admin download
                                  let b64: string | undefined; let effectiveMime = mime;
                                  try {
                                    const resp = await fetchWithRetry(resolvedUrl, req.headers.get('Authorization') ?? '');
                                    if (resp.ok) {
                                      const bytes = new Uint8Array(await resp.arrayBuffer());
                                      b64 = bytesToBase64(bytes);
                                      effectiveMime = resp.headers.get('content-type') || effectiveMime;
                                    }
                                  } catch (_) {/* ignore, try admin below */}
                                  if (!b64) {
                                    const { bucket, key } = parseBucketKeyFromUrl(resolvedUrl);
                                    const dl = await downloadStorageObject(bucket, key);
                                    if (dl.ok && dl.bytes) { b64 = bytesToBase64(dl.bytes); effectiveMime = dl.mime || effectiveMime; }
                                  }
                                  if (!b64) throw new Error('Failed to fetch document for inline analysis');
                                  const analysis2 = await ai.models.generateContent({ model: preferredModel, contents: [ { role: 'user', parts: [ { inlineData: { data: b64, mimeType: effectiveMime } }, { text: instruction } ] } ] });
                                  toolResponse = { status: 'success', analysis: analysis2.text ?? '', mime_type: effectiveMime, file_uri: resolvedUrl, source: 'inlineData' };
                                }
                              }
                            } catch (err: any) {
                              toolResponse = { status: 'error', message: err?.message ?? String(err) };
                            }
                          } else {
                            toolResponse = await executeAgentArtifactTool(name, args, { projectId, chatId, supabase, fileEdits });
                          }
                          try { emit && emit({ type: 'tool_result', id: nextToolId++, name, result: toolResponse }); } catch (_) {}
                          break;
                        }
                        case 'implement_feature_and_update_todo': {
                          toolResponse = await executeAgentArtifactTool(name, args, { projectId, chatId, supabase, fileEdits, emit });
                          try {
                            const aid = (toolResponse as any)?.artifact_id;
                            if (typeof aid === 'string' && aid) createdArtifactIds.push(aid);
                          } catch (_) {}
                          break;
                        }
                        case 'create_file': {
                          const newContent = String(args.content ?? '');
                          const { error } = await supabase.from('project_files').insert({
                            project_id: projectId,
                            path: args.path,
                            content: newContent,
                          });
                          if (error) throw error;
                          fileEdits.push({ operation: 'create', path: args.path, old_content: '', new_content: newContent });
                          emit({ type: 'file_edit', operation: 'create', path: args.path, old_content: '', new_content: newContent });
                          toolResponse = { status: 'success', message: `Created ${args.path}`, path: args.path, old_content: '', new_content: newContent };
                          break;
                        }
                        case 'update_file_content': {
                          const { data: existing, error: selectError } = await supabase
                            .from('project_files')
                            .select('content')
                            .eq('project_id', projectId)
                            .eq('path', args.path)
                            .single();
                          if (selectError) throw selectError;
                          const oldContent = String(existing?.content ?? '');
                          const newContent = String(args.new_content ?? '');
                          const { error } = await supabase
                            .from('project_files')
                            .update({ content: newContent })
                            .eq('project_id', projectId)
                            .eq('path', args.path);
                          if (error) throw error;
                          fileEdits.push({ operation: 'update', path: args.path, old_content: oldContent, new_content: newContent });
                          emit({ type: 'file_edit', operation: 'update', path: args.path, old_content: oldContent, new_content: newContent });
                          toolResponse = { status: 'success', message: `Updated ${args.path}`, path: args.path, old_content: oldContent, new_content: newContent };
                          break;
                        }
                        case 'delete_file': {
                          const { data: existing, error: selectError } = await supabase
                            .from('project_files')
                            .select('content')
                            .eq('project_id', projectId)
                            .eq('path', args.path)
                            .single();
                          if (selectError) throw selectError;
                          const oldContent = String(existing?.content ?? '');
                          const { error } = await supabase
                            .from('project_files')
                            .delete()
                            .eq('project_id', projectId)
                            .eq('path', args.path);
                          if (error) throw error;
                          fileEdits.push({ operation: 'delete', path: args.path, old_content: oldContent, new_content: '' });
                          emit({ type: 'file_edit', operation: 'delete', path: args.path, old_content: oldContent, new_content: '' });
                          toolResponse = { status: 'success', message: `Deleted ${args.path}`, path: args.path, old_content: oldContent, new_content: '' };
                          break;
                        }
                        case 'read_file': {
                          const { data, error } = await supabase
                            .from('project_files')
                            .select('content')
                            .eq('project_id', projectId)
                            .eq('path', args.path)
                            .single();
                          if (error) throw error;
                          const content = String(data?.content ?? '');
                          // Do not include read operations in fileEdits; just emit a tool_result
                          toolResponse = { status: 'success', path: args.path, lines: content.split('\n').length };
                          break;
                        }
                        case 'search': {
                          const query = String(args.query ?? '');
                          const maxPerFile = Number.isFinite(args.max_results_per_file) ? Number(args.max_results_per_file) : 20;
                          const { data, error } = await supabase
                            .from('project_files')
                            .select('path, content')
                            .eq('project_id', projectId);
                          if (error) throw error;
                          const rows = Array.isArray(data) ? data : [];
                          const q = query.toLowerCase();
                          const results: any[] = [];
                          for (const r of rows) {
                            const path = r.path as string;
                            const content = String(r.content ?? '');
                            const lines = content.split('\n');
                            const matches: any[] = [];
                            for (let i = 0; i < lines.length; i++) {
                              if (lines[i].toLowerCase().includes(q)) {
                                matches.push({ line: i + 1, text: lines[i] });
                                if (matches.length >= maxPerFile) break;
                              }
                            }
                            if (matches.length > 0) results.push({ path, matches });
                          }
                          toolResponse = { status: 'success', query, results };
                          break;
                        }
                        default:
                          toolResponse = { status: 'error', message: `Unknown function call: ${name}` };
                      }
                    } catch (err: any) {
                      toolResponse = { status: 'error', message: err?.message ?? String(err) };
                    }
                    // Push back tool IO and continue loop
                    contents.push({ role: 'model', parts: [{ functionCall: { name, args } }] });
                    contents.push({ role: 'user', parts: [{ functionResponse: { name, response: { result: toolResponse } } }] });
                    emit({ type: 'tool_result', id, name, ok: toolResponse.status === 'success', result: toolResponse });
                  }
                  // Continue outer while to let the model produce more text
                  continue;
                }

                // No tool calls => finished
                break;
              } catch (err: any) {
                emit({ type: 'error', message: err?.message ?? String(err) });
                throw err;
              }
            }

            const toolHeader = fileEdits.length ? `\n\nChanges applied:\n${fileEdits
              .map((e) => `- ${e.operation} ${e.path}`)
              .join('\n')}` : '';

            const finalText = textSoFar + toolHeader;
            // Include any created artifact IDs so client can link message_id post-save
            emit({ type: 'end', finalText, fileEdits, artifactIds: createdArtifactIds });
            // Persist both messages with optional thoughts for AI message
            try {
              const userId = (await supabase.auth.getUser()).data.user?.id;
              if (userId) {
                // Try to find or create a chat for this project+user if not provided via history; client saves in new-chat path.
                // We won't create a chat here to avoid duplication; persistence mainly handled client-side for now.
                console.log('[agent-handler] final thoughts length:', thoughtsSoFar.length);
              }
            } catch (e) {
              console.warn('[agent-handler] persistence skipped:', e);
            }
          }

          try {
            await streamOnce(preferredModel);
          } catch (err) {
            if (preferredModel !== DEFAULT_MODEL) {
              await streamOnce(DEFAULT_MODEL);
            } else {
              throw err;
            }
          } finally {
            clearInterval(interval);
            controller.close();
          }
        }
      });

      return new Response(stream, {
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/x-ndjson; charset=utf-8',
          'Cache-Control': 'no-cache, no-transform',
          'X-Accel-Buffering': 'no',
          'Connection': 'keep-alive',
          'Keep-Alive': 'timeout=5',
        },
      });
    }

    // Fallback: existing JSON response (non-stream clients)
    try {
      const res = await runOnce(preferredModel);
      return new Response(JSON.stringify(res), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    } catch (err: any) {
      if (preferredModel !== DEFAULT_MODEL) {
        const res = await runOnce(DEFAULT_MODEL);
        return new Response(JSON.stringify(res), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      throw err;
    }

  } catch (error: any) {
    return new Response(JSON.stringify({ error: error?.message ?? String(error) }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    });
  }
});