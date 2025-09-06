import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { GoogleGenAI, createPartFromUri } from "https://esm.sh/@google/genai";
import { projectCardPreviewTool, todoListCreateTool, todoListCheckTool, artifactReadTool, buildToolboxGuidance, analyzeDocumentTool, lintCheckTool, analyzeCodeTool } from "../_shared/tools.ts";

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
  const geminiApiKey = Deno.env.get("GEMINI_API_KEY_2") || Deno.env.get("GEMINI_API_KEY");
  if (!geminiApiKey) throw new Error("GEMINI_API_KEY_2 or GEMINI_API_KEY is not set in the Supabase project secrets.");

  const { prompt, history, projectId, model: requestedModel, attachedFiles: rawAttachedFiles, includeThoughts, chatId } = await req.json();

  // Helper for agent artifact tools (persist in agent_artifacts)
  async function executeAgentArtifactTool(
    name: string,
    args: Record<string, any>,
    opts: { projectId: string; chatId?: string | null; supabase: any }
  ): Promise<any> {
    const { projectId, chatId, supabase } = opts;
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

          // Unified tool list for Ask (read-only) mode: read/search + agent artifact tools
          const agentAskFunctionDeclarations = [
            {
              name: 'read_file',
              description: 'Read the full content of a project file by path',
              parameters: {
                type: 'OBJECT',
                properties: { path: { type: 'STRING', description: 'The path to the file within the project' } },
                required: ['path'],
              },
            },
            {
              name: 'search',
              description: 'Search the project files for lines containing a query (case-insensitive). Returns files and matching line numbers.',
              parameters: {
                type: 'OBJECT',
                properties: {
                  query: { type: 'STRING', description: 'The substring or simple pattern to search for (no regex).' },
                  max_results_per_file: { type: 'NUMBER', description: 'Optional cap for matches per file (default 20).' },
                },
                required: ['query'],
              },
            },
            projectCardPreviewTool,
            todoListCreateTool,
            todoListCheckTool,
            artifactReadTool,
          ];
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
      default:
        return { status: 'error', message: `Unknown tool: ${name}` };
    }
  }

    const ai = new GoogleGenAI({ apiKey: geminiApiKey });
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: req.headers.get("Authorization") ?? '' } } }
    );

    // Match agent-handler helpers and approach
    const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || '';
    const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || '';
    const admin = SERVICE_ROLE_KEY ? createClient(SUPABASE_URL, SERVICE_ROLE_KEY) : null;

    function parseBucketKeyFromUrl(u: string): { bucket?: string; key?: string } {
      // Robustly parse URLs like: /storage/v1/object/(public|sign|authenticated)?/<bucket>/<key...>
      try {
        const url = new URL(u);
        const parts = url.pathname.split('/').filter(Boolean);
        const idx = parts.findIndex((p) => p === 'object');
        if (idx === -1 || idx + 1 >= parts.length) return {};
        let offset = idx + 1;
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
        const { bucket, key } = (() => {
          const b = att?.bucket || att?.bucket_id || undefined;
          const k = att?.key || att?.path || att?.storage_path || att?.object_path || undefined;
          if (b && k) return { bucket: b, key: k };
          if (att?.url) return parseBucketKeyFromUrl(att.url);
          if (att?.publicUrl) return parseBucketKeyFromUrl(att.publicUrl);
          if (att?.signedUrl) return parseBucketKeyFromUrl(att.signedUrl);
          return {} as any;
        })();
        if (bucket && key) {
          const signed = await supabase.storage.from(bucket).createSignedUrl(key, 3600);
          const url = (signed as any)?.data?.signedUrl;
          if (typeof url === 'string' && url.startsWith('http')) return url;
        }
      } catch (_) {}
      return '';
    }

    // Ensure attachments have resolvable URIs; upload base64 payloads to Storage (images -> images/, others -> docs/)
    async function sanitizeAttachments(list: any[]): Promise<any[]> {
      const out: any[] = [];
      const bucket = 'user-uploads';
      for (const att of (Array.isArray(list) ? list : [])) {
        try {
          const mime = (typeof att?.mime_type === 'string' && att.mime_type) ? String(att.mime_type) : 'application/octet-stream';
          const name = (typeof att?.file_name === 'string' && att.file_name) ? String(att.file_name) : (typeof att?.name === 'string' ? String(att.name) : 'file');
          // If base64 is present, upload first time
          if (typeof att?.data === 'string' && att.data.length > 0) {
            const b64 = att.data as string;
            const bin = Uint8Array.from(atob(b64), c => c.charCodeAt(0));
            const folder = mime.startsWith('image/') ? 'images' : 'docs';
            const safeName = name.replace(/[^a-zA-Z0-9_.-]/g, '_');
            const path = `${folder}/${Date.now()}_${safeName}`;
            const client = admin ?? supabase;
            // @ts-ignore runtime storage API
            const { error: upErr } = await (client as any).storage.from(bucket).upload(path, new Blob([bin], { type: mime }), { contentType: mime, upsert: true });
            if (upErr) { out.push(att); continue; }
            // @ts-ignore
            const { data: s } = await (client as any).storage.from(bucket).createSignedUrl(path, 600);
            const signedUrl = (s && (s.signedUrl || s.signed_url)) || '';
            const bucketUrl = `${SUPABASE_URL}/storage/v1/object/${bucket}/${path}`;
            out.push({
              ...att,
              bucket,
              path,
              mime_type: mime,
              file_name: name,
              bucket_url: bucketUrl,
              ...(signedUrl ? { signedUrl } : {}),
              uri: signedUrl || bucketUrl,
              data: undefined,
            });
            continue;
          }
          // If already has bucket/path, ensure signed URL and uri
          if (att?.bucket && (att?.path || att?.key || att?.storage_path || att?.object_path)) {
            const fresh = await createFreshSignedUrlFromAttachment(att);
            const prefer = (att.signedUrl || att.publicUrl || att.url || att.bucket_url || '') as string;
            const uri = fresh || prefer;
            out.push({ ...att, ...(fresh ? { signedUrl: fresh } : {}), ...(uri ? { uri } : {}) });
            continue;
          }
          // If has direct http URL, keep it as uri
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
      if (url && url.startsWith('http')) return { url, source: 'args.file_uri' };
      const needle = alias.trim().toLowerCase();
      const hit = Array.isArray(list) ? list.find((f: any) => [f.name, f.path, f.file_name]
        .filter(Boolean)
        .map((x: any) => String(x))
        .some((x: string) => x.toLowerCase() === needle || x.toLowerCase().endsWith(`/${needle}`))) : undefined;
      if (hit) {
        const u = prefer(hit);
        if (u && u.startsWith('http')) return { url: u, source: 'attachments' };
        const signed = await createFreshSignedUrlFromAttachment(hit);
        if (signed) return { url: signed, source: 'attachments.signed' };
      }
      if (Array.isArray(list) && list.length === 1) {
        const u = prefer(list[0]);
        if (u && u.startsWith('http')) return { url: u, source: 'attachments[0]' };
        const signed = await createFreshSignedUrlFromAttachment(list[0]);
        if (signed) return { url: signed, source: 'attachments[0].signed' };
      }
      if (typeof args?.file_uri === 'string' && args.file_uri.startsWith(SUPABASE_URL)) {
        const parsed = parseBucketKeyFromUrl(args.file_uri);
        if (parsed.bucket && parsed.key) {
          const signed = await supabase.storage.from(parsed.bucket).createSignedUrl(parsed.key, 3600);
          const u = (signed as any)?.data?.signedUrl;
          if (u && u.startsWith('http')) return { url: u, source: 'resigned' };
        }
      }
      return { url: '', source: 'none' };
    }

    async function fetchWithRetry(fileUrl: string, authHeader: string): Promise<Response> {
      let resp = await fetch(fileUrl);
      if (!resp.ok && authHeader) resp = await fetch(fileUrl, { headers: { Authorization: authHeader } });
      return resp;
    }

    async function parseSupabaseStorageError(resp: Response): Promise<{ code?: string; message?: string; raw?: string }>{
      try {
        const txt = await resp.text();
        try {
          const j = JSON.parse(txt);
          const code = j?.error?.code || j?.code;
          const message = j?.error?.message || j?.message || txt;
          return { code, message };
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
        if (!admin) return { ok: false, err: 'no admin' };
        const { data, error } = await admin.storage.from(bucket).download(key);
        if (error) return { ok: false, err: error.message };
        const ab = await data.arrayBuffer();
        const bytes = new Uint8Array(ab);
        let mime = 'application/octet-stream';
        try { mime = (data as any)?.type || mime; } catch {}
        return { ok: true, bytes, mime };
      } catch (e: any) {
        return { ok: false, err: e?.message ?? String(e) };
      }
    }

    function bytesToBase64(bytes: Uint8Array): string {
      let binary = '';
      const chunkSize = 0x8000;
      for (let i = 0; i < bytes.length; i += chunkSize) {
        const sub = bytes.subarray(i, i + chunkSize);
        binary += String.fromCharCode.apply(null, Array.from(sub) as any);
      }
      return btoa(binary);
    }

    function guessMimeFromUrl(u: string): string | '' {
      try {
        const l = u.toLowerCase();
        if (l.endsWith('.png')) return 'image/png';
        if (l.endsWith('.jpg') || l.endsWith('.jpeg')) return 'image/jpeg';
        if (l.endsWith('.gif')) return 'image/gif';
        if (l.endsWith('.webp')) return 'image/webp';
        return '';
      } catch (_) { return ''; }
    }

  const DEFAULT_MODEL = "gemini-2.5-flash";
  const preferredModel = (typeof requestedModel === 'string' && requestedModel.length > 0) ? requestedModel : DEFAULT_MODEL;
  // Normalize attachments once (images and docs) so URIs exist for analyze_document
  const attachedFiles = await sanitizeAttachments(rawAttachedFiles);

    // Unified tool list for Ask (read-only) mode
    const askFunctionDeclarations = [
      { name: 'read_file' },
      { name: 'search' },
      projectCardPreviewTool,
      todoListCreateTool,
      todoListCheckTool,
      artifactReadTool,
      analyzeDocumentTool,
      lintCheckTool,
      analyzeCodeTool,
    ];

  async function runOnce(modelName: string): Promise<{ text: string; fileEdits: any[]; filesAnalyzed?: any[]; artifactIds?: string[] }> {
      // Project context
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

      // Attachments guidance with exact URLs for analyze_document
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

  const toolGuidance = `\n\nTOOLS AND WHEN TO USE THEM:\n- read_file: Read exact file content or metadata like line count.\n- search: Search across many files for a query, when you don’t know exact files.\n- project_card_preview: Summarize scope/ideas as an artifact.\n- todo_list_create: Break work into actionable tasks as an artifact.\n- todo_list_check: Mark task(s) done; optionally include brief context.\n- artifact_read: Recall an artifact by id.\n- analyze_document: Analyze an attached document/image via URL with a clear instruction.\n- lint_check: Quick, non‑LLM static pass to catch obvious syntax problems after edits.\n- analyze_code: Lightweight model review for concise issues/suggestions after batches of changes.\n\nBEHAVIOR:\n- Prefer read/search before proposing edits.\n- Keep responses concise and actionable.\n- Do not prefix replies with 'Robin:' or similar.`;
  const localAskFunctionDeclarations = [
    { name: 'read_file' },
    { name: 'search' },
    projectCardPreviewTool,
    todoListCreateTool,
    todoListCheckTool,
    artifactReadTool,
    analyzeDocumentTool,
    lintCheckTool,
    analyzeCodeTool,
  ];
  const systemInstruction = `You are Robin, an expert AI software development assistant working inside a multi-pane IDE. Always identify yourself as Robin.\nCurrent project: ${projectName}.\n Project description: ${projectDescription}. \n Stack for the project: ${projectStack.map((s: string) => `- ${s}`).join('\n')}\n\n Project files (${filePaths.length}):\n${filePaths.map((p: string) => `- ${p}`).join('\n')}\n\n Assist the user with requests in the context of the project.${buildToolboxGuidance(localAskFunctionDeclarations)}${attachmentsNote}`;

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
        } catch (_) {}
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
            tools: [{
              functionDeclarations: [
                {
                  name: 'read_file',
                  description: 'Read the full content of a project file by path',
                  parameters: {
                    type: 'OBJECT',
                    properties: { path: { type: 'STRING', description: 'The path to the file within the project' } },
                    required: ['path'],
                  },
                },
                {
                  name: 'search',
                  description: 'Search the project files for lines containing a query (case-insensitive). Returns files and matching line numbers.',
                  parameters: {
                    type: 'OBJECT',
                    properties: {
                      query: { type: 'STRING', description: 'The substring or simple pattern to search for (no regex).' },
                      max_results_per_file: { type: 'NUMBER', description: 'Optional cap for matches per file (default 20).' },
                    },
                    required: ['query'],
                  },
                },
                projectCardPreviewTool,
                todoListCreateTool,
                todoListCheckTool,
                artifactReadTool,
                analyzeDocumentTool,
                lintCheckTool,
                analyzeCodeTool,
              ],
            }],
            systemInstruction,
          },
        });

        if (result.functionCalls && result.functionCalls.length > 0) {
          for (const functionCall of result.functionCalls) {
            const { name, args } = functionCall as { name: string; args: Record<string, any> };
            let toolResponse: any = {};
            try {
              switch (name) {
                case 'project_card_preview':
                case 'todo_list_create':
                case 'todo_list_check':
                case 'artifact_read': {
                  toolResponse = await executeAgentArtifactTool(name, args, { projectId, chatId, supabase });
                  try {
                    const aid = (toolResponse as any)?.artifact_id;
                    if (typeof aid === 'string' && aid) createdArtifactIds.push(aid);
                  } catch (_) {}
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
                case 'analyze_document': {
                  const list = Array.isArray(attachedFiles) ? attachedFiles : [];
                  const { url: resolvedUrl } = await resolveBestUrl(args, list);
                  if (!resolvedUrl) { toolResponse = { status: 'error', message: 'file_uri not found among attachments; provide a valid URL.' }; break; }
                  const mimeExplicit = (typeof args?.mime_type === 'string' && args.mime_type) ? String(args.mime_type) : '';
                  let mime = mimeExplicit || guessMimeFromUrl(resolvedUrl) || 'application/octet-stream';
                  const instruction = String(args.instruction ?? 'Analyze this file.');
                  try {
                    const analysis = await ai.models.generateContent({ model: preferredModel, contents: [ { role: 'user', parts: [ createPartFromUri(resolvedUrl, mime), { text: instruction } ] } ] });
                    toolResponse = { status: 'success', analysis: analysis.text ?? '', mime_type: mime, file_uri: resolvedUrl, source: 'uri' };
                  } catch (uriErr: any) {
                    // Try normal fetch with user token, then admin download
                    const authHeader = req.headers.get('Authorization') ?? '';
                    let inline: { ok: boolean; b64?: string; mime?: string; err?: string } = { ok: false } as any;
                    try {
                      const resp = await fetchWithRetry(resolvedUrl, authHeader);
                      if (resp.ok) {
                        const bytes = new Uint8Array(await resp.arrayBuffer());
                        const ct = resp.headers.get('content-type') || mime;
                        inline = { ok: true, b64: bytesToBase64(bytes), mime: ct };
                      } else {
                        const parsed = await parseSupabaseStorageError(resp);
                        inline = { ok: false, err: `${resp.status} ${parsed.code ?? ''} ${parsed.message ?? parsed.raw ?? ''}` } as any;
                      }
                    } catch (e: any) {
                      inline = { ok: false, err: e?.message ?? String(e) } as any;
                    }
                    if (!inline.ok) {
                      const { bucket, key } = parseBucketKeyFromUrl(resolvedUrl);
                      const dl = await downloadStorageObject(bucket, key);
                      if (dl.ok) { inline = { ok: true, b64: bytesToBase64(dl.bytes!), mime: dl.mime }; }
                    }
                    if (inline.ok && inline.b64) {
                      const analysis2 = await ai.models.generateContent({ model: preferredModel, contents: [ { role: 'user', parts: [ { inlineData: { data: inline.b64, mimeType: inline.mime || mime } }, { text: instruction } ] } ] });
                      toolResponse = { status: 'success', analysis: analysis2.text ?? '', mime_type: inline.mime || mime, file_uri: resolvedUrl, source: 'inlineData' };
                    } else {
                      toolResponse = { status: 'error', message: inline.err || (uriErr?.message ?? 'Failed to analyze document'), mime_type: mime, file_uri: resolvedUrl };
                    }
                  }
                  // Collect for non-stream clients
                  try { filesAnalyzed.push(toolResponse); } catch (_) {}
                  break;
                }
                case 'lint_check': {
                  // Provide either content or path (reads from project_files)
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
                  } else { toolResponse = { status: 'error', message: 'Provide either path or content' }; break; }
                  const issues: Array<{ kind: string; message: string; index?: number }> = [];
                  const pairs: Array<[string, string, string]> = [['paren','(',')'], ['brace','{','}'], ['bracket','[',']']];
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
                  const analysis = await ai.models.generateContent({ model: modelForAnalysis, contents: [ { role: 'user', parts: [ { text: instruction }, { text: content.slice(0, 16000) } ] } ] });
                  toolResponse = { status: 'success', summary: analysis.text ?? '', focused_on_issue: issue || undefined, model: modelForAnalysis };
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

            contents.push({ role: 'model', parts: [{ functionCall }] });
            contents.push({ role: 'user', parts: [{ functionResponse: { name, response: { result: toolResponse } } }] });
          }
          continue;
        } else {
          finalText = result.text ?? '';
          break;
        }
      }

  // Return unique filesAnalyzed (dedupe by file_url + mime + source)
  const uniq: any[] = [];
  const seen = new Set<string>();
  for (const r of filesAnalyzed) {
    try {
      const m = (r && typeof r === 'object') ? r as any : {};
      const key = [m.file_uri || m.file_url || '', m.status || '', m.source || '', m.mime_type || '', String(m.byte_length || '')].join('|');
      if (!seen.has(key)) { seen.add(key); uniq.push(r); }
    } catch { uniq.push(r); }
  }
  return { text: finalText, fileEdits, filesAnalyzed: uniq, artifactIds: createdArtifactIds };
    }

    // Streaming support via NDJSON (text + end). Tools are read-only.
    const wantsStream = (req.headers.get('accept')?.includes('application/x-ndjson')) || (req.headers.get('x-stream') === 'true');
  if (wantsStream) {
      const encoder = new TextEncoder();
      const stream = new ReadableStream<Uint8Array>({
        async start(controller) {
          function emit(obj: unknown) {
            controller.enqueue(encoder.encode(JSON.stringify(obj) + "\n"));
          }
          const interval = setInterval(() => {
            try { emit({ type: 'ping', t: Date.now() }); } catch (_) {}
          }, 1000);

          async function streamOnce(modelName: string) {
            const filesAnalyzed: any[] = [];
            const createdArtifactIds: string[] = [];
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

            const attachedSummary = Array.isArray(attachedFiles) && attachedFiles.length
              ? `\n\nAttached files (${attachedFiles.length}):\n${attachedFiles.map((f: any) => `- ${f.path} (${(f.content || '').split('\n').length} lines)`).join('\n')}`
              : '';

            // Collect chat-specific agent artifacts (ids and short titles)
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

            // Attachments guidance (streaming)
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
            const systemInstruction = `You are Robin, acting in Ask mode. Provide analysis, suggestions, and code review. You must NOT modify files or suggest that you changed files. You only read code via the read_file tool and reason about it.\nCurrent project: ${projectName}.\n Project description: ${projectDescription}. \n Stack: ${projectStack.map((s: string) => `- ${s}`).join('\n')}\n\n Project files (${filePaths.length}):\n${filePaths.map((p: string) => `- ${p}`).join('\n')}${buildToolboxGuidance(askFunctionDeclarations)}${attachmentsNote}${artifactsList}`;

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
              } catch (_) {}
            } else if (Array.isArray(history) && history.length > 0) {
              contents.push(...history);
            }
            contents.push({ role: 'user', parts: [{ text: prompt }] });

  let textSoFar = '';
  let thoughtsSoFar = '';
  let nextToolId = 1;
            emit({ type: 'start', model: modelName });

            while (true) {
              try {
                // Collect pending function calls to execute after this round
                const pendingCalls: Array<{ name: string; args: Record<string, any>; id: number }> = [];
                // Use new streaming API pattern
                // @ts-ignore
                const streamResp: AsyncIterable<any> | any = await ai.models.generateContentStream({
                  model: modelName,
                  contents,
                  config: {
                    tools: [{
                      functionDeclarations: [
                        {
                          name: 'read_file',
                          description: 'Read the full content of a project file by path',
                          parameters: {
                            type: 'OBJECT',
                            properties: { path: { type: 'STRING', description: 'The path to the file within the project' } },
                            required: ['path'],
                          },
                        },
                        {
                          name: 'search',
                          description: 'Search the project files for lines containing a query (case-insensitive). Returns files and matching line numbers.',
                          parameters: {
                            type: 'OBJECT',
                            properties: {
                              query: { type: 'STRING', description: 'The substring or simple pattern to search for (no regex).' },
                              max_results_per_file: { type: 'NUMBER', description: 'Optional cap for matches per file (default 20).' },
                            },
                            required: ['query'],
                          },
                        },
                        analyzeDocumentTool,
                        lintCheckTool,
                        analyzeCodeTool,
                      ],
                    }],
                    systemInstruction,
                    ...(includeThoughts ? { thinkingConfig: { thinkingBudget: -1, includeThoughts: true } } : {}),
                  },
                });

                let receivedAny = false;
                for await (const chunk of (streamResp as AsyncIterable<any>)) {
                  receivedAny = true;
                  const delta: string | undefined = chunk?.text;
                  if (delta && delta.length > 0) {
                    textSoFar += delta;
                    emit({ type: 'text', delta });
                  }
                  const parts = chunk?.candidates?.[0]?.content?.parts;
                  if (Array.isArray(parts)) {
                    for (const p of parts) {
                      const t = (p?.thought && typeof p.text === 'string') ? p.text :
                                (p?.role === 'thought' && typeof p.text === 'string') ? p.text : undefined;
                      if (t && t.length > 0) {
                        thoughtsSoFar += t;
                        emit({ type: 'thought', delta: t });
                        console.log('[agent-chat-handler] thought delta:', t);
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
                  const single = await ai.models.generateContent({
                    model: modelName,
                    contents,
                    config: {
                      tools: [{
                        functionDeclarations: [
                          {
                            name: 'read_file',
                            description: 'Read the full content of a project file by path',
                            parameters: {
                              type: 'OBJECT',
                              properties: { path: { type: 'STRING', description: 'The path to the file within the project' } },
                              required: ['path'],
                            },
                          },
                          analyzeDocumentTool,
                        ],
                      }],
                      systemInstruction,
                      ...(includeThoughts ? { thinkingConfig: { thinkingBudget: -1, includeThoughts: true } } : {}),
                    },
                  });
                  if (single.functionCalls && single.functionCalls.length > 0) {
                    for (const c of single.functionCalls) {
                      if (c && typeof c.name === 'string') {
                        const id = nextToolId++;
                        pendingCalls.push({ name: c.name, args: c.args ?? {}, id });
                      }
                    }
                  } else {
                    const finalText = single.text ?? '';
                    for (let i = 0; i < finalText.length; i += 64) {
                      const d = finalText.slice(i, i + 64);
                      textSoFar += d;
                      emit({ type: 'text', delta: d });
                    }
                  }
                }
                // Execute calls (read-only in Ask)
                if (pendingCalls.length > 0) {
                  for (const { name, args, id } of pendingCalls as Array<{ name: string; args: Record<string, any>; id: number }>) {
                    let toolResponse: any = {};
                    try {
                      emit({ type: 'text', delta: `\n\n[tool:${id}]\n\n` });
                      emit({ type: 'tool_in_progress', id, name });
                      switch (name) {
                        case 'project_card_preview':
                        case 'todo_list_create':
                        case 'todo_list_check':
                        case 'artifact_read': {
                          toolResponse = await executeAgentArtifactTool(name, args, { projectId, chatId, supabase });
                          try {
                            const aid = (toolResponse as any)?.artifact_id;
                            if (typeof aid === 'string' && aid) createdArtifactIds.push(aid);
                          } catch (_) {}
                          break;
                        }
                        case 'analyze_document': {
                          try {
                            const list = Array.isArray(attachedFiles) ? attachedFiles : [];
                            const { url: resolvedUrl } = await resolveBestUrl(args, list);
                            if (!resolvedUrl) throw new Error('file_uri is required for analyze_document');
                            const mimeExplicit = (typeof args?.mime_type === 'string' && args.mime_type) ? String(args.mime_type) : '';
                            let mime = mimeExplicit || guessMimeFromUrl(resolvedUrl) || 'application/octet-stream';
                            const instruction = String(args.instruction ?? 'Analyze this file.');
                            try {
                              const analysis = await ai.models.generateContent({ model: preferredModel, contents: [ { role: 'user', parts: [ createPartFromUri(resolvedUrl, mime), { text: instruction } ] } ] });
                              toolResponse = { status: 'success', analysis: analysis.text ?? '', mime_type: mime, file_uri: resolvedUrl, source: 'uri' };
                            } catch (_uriErr: any) {
                              // Fallback to fetch+inlineData, then admin download
                              let inlineOk = false; let b64: string | undefined; let effectiveMime = mime;
                              try {
                                const resp = await fetchWithRetry(resolvedUrl, req.headers.get('Authorization') ?? '');
                                if (resp.ok) { const bytes = new Uint8Array(await resp.arrayBuffer()); b64 = bytesToBase64(bytes); effectiveMime = resp.headers.get('content-type') || effectiveMime; inlineOk = true; }
                              } catch (_) { /* will try admin */ }
                              if (!inlineOk) {
                                const { bucket, key } = parseBucketKeyFromUrl(resolvedUrl);
                                const dl = await downloadStorageObject(bucket, key);
                                if (dl.ok) { b64 = bytesToBase64(dl.bytes!); effectiveMime = dl.mime || mime; inlineOk = true; }
                              }
                              if (!inlineOk || !b64) throw new Error('Failed to fetch document for inline analysis');
                              const analysis2 = await ai.models.generateContent({ model: preferredModel, contents: [ { role: 'user', parts: [ { inlineData: { data: b64, mimeType: effectiveMime } }, { text: instruction } ] } ] });
                              toolResponse = { status: 'success', analysis: analysis2.text ?? '', mime_type: effectiveMime, file_uri: resolvedUrl, source: 'inlineData' };
                            }
                          } catch (err: any) {
                            toolResponse = { status: 'error', message: err?.message ?? String(err) };
                          }
                          break;
                        }
                        case 'lint_check': {
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
                          } else { toolResponse = { status: 'error', message: 'Provide either path or content' }; break; }
                          const issues: Array<{ kind: string; message: string; index?: number }> = [];
                          const pairs: Array<[string, string, string]> = [['paren','(',')'], ['brace','{','}'], ['bracket','[',']']];
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
                          const analysis = await ai.models.generateContent({ model: modelForAnalysis, contents: [ { role: 'user', parts: [ { text: instruction }, { text: content.slice(0, 16000) } ] } ] });
                          toolResponse = { status: 'success', summary: analysis.text ?? '', focused_on_issue: issue || undefined, model: modelForAnalysis };
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
                    contents.push({ role: 'model', parts: [{ functionCall: { name, args } }] });
                    contents.push({ role: 'user', parts: [{ functionResponse: { name, response: { result: toolResponse } } }] });
                    // Track analyze_document outcomes for end-summary
                    try {
                      if (name === 'analyze_document') filesAnalyzed.push(toolResponse);
                    } catch (_) {}
                    emit({ type: 'tool_result', id, name, ok: toolResponse.status === 'success', result: toolResponse });
                  }
                  // Continue loop to let the model produce final text
                  continue;
                }
                // No tool calls => we have the full text for this turn
                break;
              } catch (err: any) {
                emit({ type: 'error', message: err?.message ?? String(err) });
                throw err;
              }
            }

            // Deduplicate filesAnalyzed before emitting end
            const uniq: any[] = [];
            const seen = new Set<string>();
            for (const r of filesAnalyzed) {
              try {
                const m = (r && typeof r === 'object') ? r as any : {};
                const key = [m.file_uri || m.file_url || '', m.status || '', m.source || '', m.mime_type || '', String(m.byte_length || '')].join('|');
                if (!seen.has(key)) { seen.add(key); uniq.push(r); }
              } catch { uniq.push(r); }
            }
            emit({ type: 'end', finalText: textSoFar, fileEdits: [], filesAnalyzed: uniq, artifactIds: createdArtifactIds });
            console.log('[agent-chat-handler] final thoughts length:', thoughtsSoFar.length);
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

    // Fallback JSON response
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