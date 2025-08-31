import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { GoogleGenAI, createPartFromUri, createUserContent, Modality } from "https://esm.sh/@google/genai";
import {
  playgroundTools,
  playgroundCanvasTools,
  playgroundCompositeTools,
  playgroundReadTools,
  buildToolboxGuidance,
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
  const geminiApiKey = (globalThis as any).Deno?.env.get("GEMINI_API_KEY_3");
    if (!geminiApiKey) throw new Error("GEMINI_API_KEY_3 is not set.");

    const { prompt, history, chatId, model: requestedModel, includeThoughts, attachments } = await req.json();

    const ai = new GoogleGenAI({ apiKey: geminiApiKey });
    const supabase = createClient(
      (globalThis as any).Deno?.env.get("SUPABASE_URL")!,
      (globalThis as any).Deno?.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: req.headers.get("Authorization") ?? '' } } }
    );

  const DEFAULT_MODEL = "gemini-2.5-flash";
  const preferredModel = (typeof requestedModel === 'string' && requestedModel.length > 0) ? requestedModel : DEFAULT_MODEL;

    // Match agent-handler helpers and approach for robust file access
  const SUPABASE_URL = (globalThis as any).Deno?.env.get("SUPABASE_URL") || '';
  const SERVICE_ROLE_KEY = (globalThis as any).Deno?.env.get("SUPABASE_SERVICE_ROLE_KEY") || '';
    const admin = SERVICE_ROLE_KEY ? createClient(SUPABASE_URL, SERVICE_ROLE_KEY) : null;

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
        const direct = att?.signedUrl || att?.publicUrl || att?.url || att?.bucket_url;
        const client = admin ?? supabase;
        const trySign = async (b?: string, k?: string) => {
          if (!b || !k) return '';
          // @ts-ignore - runtime typings available
          const { data, error } = await (client as any).storage.from(b).createSignedUrl(k, 600);
          if (!error && data?.signedUrl) return data.signedUrl as string;
          return '';
        };
        const b = att?.bucket || att?.bucket_id;
        const k = att?.key || att?.path || att?.storage_path || att?.object_path;
        if (b && k) {
          const signed = await trySign(b, k);
          if (signed) return signed;
        }
        if (typeof direct === 'string' && direct.startsWith('http')) {
          const { bucket, key } = parseBucketKeyFromUrl(direct);
          if (bucket && key) {
            const signed = await trySign(bucket, key);
            if (signed) return signed;
          }
        }
      } catch (_) {}
      return '';
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

    async function downloadStorageObject(bucket?: string, key?: string): Promise<{ ok: boolean; bytes?: Uint8Array; mime?: string; err?: string }>{
      try {
        if (!bucket || !key) return { ok: false, err: 'missing bucket/key' };
        const client = admin ?? supabase;
        // @ts-ignore - runtime typings available
        const { data, error } = await (client as any).storage.from(bucket).download(key);
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
        if (l.endsWith('.pdf')) return 'application/pdf';
        if (l.endsWith('.txt')) return 'text/plain';
        if (l.endsWith('.md') || l.endsWith('.markdown')) return 'text/markdown';
        if (l.endsWith('.html') || l.endsWith('.htm')) return 'text/html';
        if (l.endsWith('.xml')) return 'application/xml';
        if (l.endsWith('.json')) return 'application/json';
        return '';
      } catch (_) { return ''; }
    }

    async function waitForGeminiFileReady(ai: any, fileName: string, maxMs = 30000): Promise<'READY' | 'FAILED' | 'TIMEOUT'> {
      const started = Date.now();
      try {
        while (Date.now() - started < maxMs) {
          const f = await ai.files.get({ name: fileName });
          const state = (f as any)?.state || (f as any)?.status || '';
          if (state === 'READY' || state === 'ACTIVE') return 'READY';
          if (state === 'FAILED') return 'FAILED';
          await new Promise((r) => setTimeout(r, 1500));
        }
      } catch (_) {}
      return 'TIMEOUT';
    }

    async function uploadDocToGemini(ai: any, bytes: Uint8Array, mime: string, displayName: string): Promise<{ ok: boolean; file?: any; err?: string }>{
      try {
        const blob = new Blob([bytes.buffer as ArrayBuffer], { type: mime });
        const file = await ai.files.upload({ file: blob, config: { displayName } });
        const name = (file as any)?.name as string | undefined;
        if (!name) return { ok: false, err: 'no file.name' };
        const state = await waitForGeminiFileReady(ai, name, 45000);
        if (state !== 'READY') return { ok: false, err: `file not ready: ${state}` };
        return { ok: true, file };
      } catch (e: any) {
        return { ok: false, err: e?.message ?? String(e) };
      }
    }

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

    // Helper: process attachments by uploading bytes/base64 to 'user-uploads' and returning sanitized metadata only
    async function processAttachmentsIfAny(arr: any[]): Promise<any[]> {
      if (!Array.isArray(arr) || arr.length === 0) return [];
      const out: any[] = [];
      for (const item of arr) {
        try {
          const mime: string = item?.mime_type ?? item?.mimeType ?? 'application/octet-stream';
          const name: string = item?.file_name ?? item?.name ?? `upload_${Date.now()}`;
          const folder = 'playground/uploads';
          const bucket = 'user-uploads';

          // Normalize possible inputs
          const base64: string | undefined = typeof item?.base64 === 'string' ? item.base64 : (typeof item?.data === 'string' ? item.data : undefined);
          const bytesArr: number[] | undefined = Array.isArray(item?.bytes) ? item.bytes : undefined;
          const bytesB64: string | undefined = typeof item?.bytesBase64 === 'string' ? item.bytesBase64 : undefined;
          const uri: string | undefined = typeof item?.uri === 'string' ? item.uri : undefined;
          const urlIn: string | undefined = typeof item?.url === 'string' ? item.url : undefined;

          // Upload path: any kind of bytes/base64 provided
          if (base64 || bytesArr || bytesB64) {
            let bytes: Uint8Array;
            if (base64) {
              bytes = Uint8Array.from(atob(base64), c => c.charCodeAt(0));
            } else if (bytesB64) {
              bytes = Uint8Array.from(atob(bytesB64), c => c.charCodeAt(0));
            } else {
              bytes = new Uint8Array(bytesArr!);
            }
            const path = `${folder}/${Date.now()}_${Math.random().toString(36).slice(2)}_${name}`;
            const { publicUrl, signedUrl } = await uploadBytesToStorage(bucket, path, bytes, mime);
            const bucket_url = `${SUPABASE_URL}/storage/v1/object/${bucket}/${path}`;
            out.push({ bucket, path, url: publicUrl ?? signedUrl ?? bucket_url, publicUrl, signedUrl, bucket_url, mime_type: mime, file_name: name });
            continue;
          }

          // If we already have a URL (http) or a Supabase bucket ref, sanitize
          if (urlIn && urlIn.startsWith('http')) {
            // Try to infer bucket_url
            let bucket_url: string | undefined;
            try {
              const { bucket: b, key: k } = parseBucketKeyFromUrl(urlIn);
              if (b && k) bucket_url = `${SUPABASE_URL}/storage/v1/object/${b}/${k}`;
            } catch (_) {}
            out.push({ url: urlIn, bucket_url, mime_type: mime, file_name: name });
            continue;
          }
          if (uri && uri.startsWith('http')) {
            out.push({ url: uri, mime_type: mime, file_name: name });
            continue;
          }
          if ((item?.bucket && item?.path)) {
            const b = String(item.bucket);
            const p = String(item.path);
            let signedUrl: string | undefined;
            try {
              const signed = await supabase.storage.from(b).createSignedUrl(p, 3600);
              signedUrl = (signed as any)?.data?.signedUrl;
            } catch (_) {}
            const bucket_url = `${SUPABASE_URL}/storage/v1/object/${b}/${p}`;
            out.push({ bucket: b, path: p, url: signedUrl ?? bucket_url, signedUrl, bucket_url, mime_type: mime, file_name: name });
            continue;
          }

          // As a last resort, drop unknown large fields and keep only minimal metadata
          out.push({ mime_type: mime, file_name: name });
        } catch (_) {
          // If anything goes wrong, keep minimal info rather than raw payloads
          out.push({ mime_type: (item?.mime_type ?? item?.mimeType ?? 'application/octet-stream'), file_name: (item?.file_name ?? item?.name ?? 'file') });
        }
      }
      return out;
    }

  async function executeTool(name: string, args: Record<string, any>, effectiveChatId: string, opts?: { attachments?: any[] }): Promise<any> {
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
          const inserted = await supabase
            .from('canvas_files')
            .insert({ chat_id: effectiveChatId, path, content: template })
            .select('id, path, content')
            .single();
          if ((inserted as any)?.error) return { status: 'error', message: (inserted as any).error.message };
          const row = (inserted as any)?.data;
          return { status: 'success', id: row?.id, path: row?.path, content: String(row?.content ?? '') };
        }
        case 'implement_feature_and_update_todo': {
          const artifactId = String(args.artifact_id ?? '').trim();
          const taskId = String(args.task_id ?? '').trim();
          const path = String(args.path ?? '').trim();
          const newContent = String(args.new_content ?? '');
          if (!artifactId || !taskId || !path) return { status: 'error', message: 'artifact_id, task_id and path are required' };
          // 1) Update existing canvas file if present; otherwise only create if none exist in this chat
          let canvasRow: any | null = null;
          let mode: 'updated' | 'created' = 'updated';
          {
            const { data: existing } = await supabase
              .from('canvas_files')
              .select('id, path, content')
              .match({ chat_id: effectiveChatId, path })
              .maybeSingle();
            if (existing) {
              const updated = await supabase
                .from('canvas_files')
                .update({ content: newContent, last_modified: new Date().toISOString() })
                .match({ chat_id: effectiveChatId, path })
                .select('id, path, content')
                .single();
              if ((updated as any)?.error) return { status: 'error', message: (updated as any).error.message };
              canvasRow = (updated as any)?.data;
              mode = 'updated';
            } else {
              const { data: anyFiles } = await supabase
                .from('canvas_files')
                .select('path')
                .eq('chat_id', effectiveChatId)
                .limit(1);
              if (Array.isArray(anyFiles) && anyFiles.length > 0) {
                const { data: list } = await supabase
                  .from('canvas_files')
                  .select('path')
                  .eq('chat_id', effectiveChatId)
                  .order('last_modified', { ascending: false });
                return { status: 'error', message: 'A canvas file already exists for this chat. Update an existing file instead of creating a new one.', available_paths: (list ?? []).map((r: any) => r.path) };
              }
              const inserted = await supabase
                .from('canvas_files')
                .insert({ chat_id: effectiveChatId, path, content: newContent })
                .select('id, path, content')
                .single();
              if ((inserted as any)?.error) return { status: 'error', message: (inserted as any).error.message };
              canvasRow = (inserted as any)?.data;
              mode = 'created';
            }
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
          let taskTitle: string | undefined;
          for (const t of tasks) {
            if (String(t.id) === taskId) { t.done = true; taskTitle = typeof t.title === 'string' ? t.title : String(t.id); }
          }
          const updated = { ...todo, tasks };
          const { error: updErr } = await supabase
            .from('playground_artifacts')
            .update({ data: updated, last_modified: new Date().toISOString() })
            .eq('id', artifactId);
          if (updErr) return { status: 'error', message: updErr.message };
          return { status: 'success', mode, canvas_file: { id: canvasRow?.id, path: canvasRow?.path, content: String(canvasRow?.content ?? '') }, artifact_id: artifactId, task_id: taskId, task_title: taskTitle };
        }
        case 'analyze_document': {
          const instruction = String(args.instruction ?? 'Describe the image.');
          const list = Array.isArray(opts?.attachments) ? opts!.attachments! : [];
          const { url: resolvedUrl } = await resolveBestUrl(args, list);
          const explicit = typeof args?.mime_type === 'string' && args.mime_type ? String(args.mime_type) : '';
          let mime = explicit || (resolvedUrl ? guessMimeFromUrl(resolvedUrl) : '') || '';
          const base64Arg = (args as any)?.base64 as string | undefined;

          // IMAGE PATH (unchanged behavior)
          if (mime.startsWith('image/') || (!mime && base64Arg && (args?.mime_type || '').toString().startsWith('image/'))) {
            mime = mime || String(args?.mime_type);
            if (!resolvedUrl && !(typeof base64Arg === 'string' && base64Arg.length > 0)) {
              return { status: 'error', message: 'No valid image provided. Provide file_uri (preferred) or base64.' };
            }
            if (resolvedUrl) {
              try {
                const res = await ai.models.generateContent({ model: preferredModel, contents: [ { role: 'user', parts: [ createPartFromUri(resolvedUrl, mime || 'image/png'), { text: instruction } ] } ] });
                return { status: 'success', analysis: res.text ?? '', mime_type: mime || 'image/png', file_uri: resolvedUrl, source: 'uri' };
              } catch (_) {
                try {
                  const resp = await fetchWithRetry(resolvedUrl, req.headers.get('Authorization') ?? '');
                  if (resp.ok) {
                    const bytes = new Uint8Array(await resp.arrayBuffer());
                    const b64 = bytesToBase64(bytes);
                    const parts = createUserContent([ instruction, { inlineData: { mimeType: mime || 'image/png', data: b64 } } ]);
                    const res2 = await ai.models.generateContent({ model: preferredModel, contents: parts });
                    return { status: 'success', analysis: res2.text ?? '', mime_type: mime || 'image/png', file_uri: resolvedUrl, source: 'inlineData' };
                  }
                } catch (_) {}
                let dl = await (async () => {
                  const alias = String(args?.file_uri || args?.name || args?.file_name || '').trim();
                  const att = Array.isArray(list) ? list.find((f: any) => [f.name, f.path, f.file_name].filter(Boolean).map((x: any) => String(x)).some((x: string) => x.toLowerCase() === alias.toLowerCase() || x.toLowerCase().endsWith(`/${alias.toLowerCase()}`))) : undefined;
                  const first = await downloadStorageObject(att?.bucket || att?.bucket_id, att?.key || att?.path || att?.storage_path || att?.object_path);
                  if (first.ok) return first;
                  const { bucket, key } = parseBucketKeyFromUrl(resolvedUrl);
                  return await downloadStorageObject(bucket, key);
                })();
                if (dl.ok) {
                  const b64 = bytesToBase64(dl.bytes!);
                  const parts = createUserContent([ instruction, { inlineData: { mimeType: dl.mime || mime || 'image/png', data: b64 } } ]);
                  const res3 = await ai.models.generateContent({ model: preferredModel, contents: parts });
                  return { status: 'success', analysis: res3.text ?? '', mime_type: dl.mime || mime || 'image/png', file_uri: resolvedUrl, source: 'inlineData' };
                }
              }
            }
            if (base64Arg && base64Arg.length > 0) {
              const parts = createUserContent([ instruction, { inlineData: { mimeType: mime || 'image/png', data: base64Arg } } ]);
              const res = await ai.models.generateContent({ model: preferredModel, contents: parts });
              return { status: 'success', analysis: res.text ?? '', mime_type: mime || 'image/png', file_uri: resolvedUrl || undefined, source: 'inlineData' };
            }
            return { status: 'error', message: 'Failed to analyze image' };
          }

          // DOCUMENT PATH (multi-doc default): PDFs and other non-image files
          // Collect target URIs: prefer explicit array, else single file_uri, else attachments (non-images)
          const uris: string[] = [];
          // Prefer explicit file_uris
          if (Array.isArray((args as any)?.file_uris)) {
            for (const u of (args as any).file_uris) if (typeof u === 'string' && u.startsWith('http')) uris.push(u);
          }
          // Single arg file_uri
          if (typeof (args as any)?.file_uri === 'string' && (args as any).file_uri.startsWith('http')) {
            uris.push((args as any).file_uri);
          }
          // Attached files (sanitized and uploaded earlier)
          if (Array.isArray(list) && list.length > 0) {
            for (const f of list) {
              const u = f?.signedUrl || f?.publicUrl || f?.bucket_url || f?.url || '';
              const m = (f?.mime_type as string) || guessMimeFromUrl(u) || '';
              if (u && u.startsWith('http') && (!m.startsWith('image/'))) uris.push(u);
            }
          }
          if (uris.length === 0 && typeof base64Arg === 'string' && base64Arg.length > 0) {
            // Single base64 doc upload
            const m = explicit || 'application/pdf';
            const decoded = Uint8Array.from(atob(base64Arg), (c) => c.charCodeAt(0));
            const up = await uploadDocToGemini(ai, decoded, m, `upload.${(m.split('/')[1] || 'bin')}`);
            if (!up.ok || !up.file?.uri || !up.file?.mimeType) return { status: 'error', message: up.err || 'Upload failed' };
            const parts = createUserContent([ instruction, createPartFromUri(up.file.uri, up.file.mimeType) ]);
            const resp = await ai.models.generateContent({ model: preferredModel, contents: parts });
            return { status: 'success', analysis: resp.text ?? '', doc_count: 1, files: [{ uri: up.file.uri, mime_type: up.file.mimeType }] };
          }
          if (uris.length === 0) {
            return { status: 'error', message: 'No document found to analyze. Provide file_uri(s) or attach PDFs/text files.' };
          }
          const partsList: any[] = [ instruction ];
          const used: Array<{ uri: string; mime_type: string; byte_length?: number }> = [];
          for (const u of uris) {
            // Fetch bytes with retry, fallback to storage download
            let bytes: Uint8Array | null = null;
            let m = guessMimeFromUrl(u) || explicit || 'application/pdf';
            try {
              const resp = await fetchWithRetry(u, req.headers.get('Authorization') ?? '');
              if (resp.ok) {
                const ab = await resp.arrayBuffer();
                bytes = new Uint8Array(ab);
                m = resp.headers.get('content-type') || m;
              }
            } catch (_) {}
            if (!bytes) {
              const { bucket, key } = parseBucketKeyFromUrl(u);
              const dl = await downloadStorageObject(bucket, key);
              if (dl.ok && dl.bytes) { bytes = dl.bytes; m = dl.mime || m; }
            }
            if (!bytes) continue;
            const display = u.split('/').pop() || 'document';
            const up = await uploadDocToGemini(ai, bytes, m, display);
            if (!up.ok || !up.file?.uri || !up.file?.mimeType) continue;
            partsList.push(createPartFromUri(up.file.uri, up.file.mimeType));
            used.push({ uri: up.file.uri, mime_type: up.file.mimeType, byte_length: bytes.length });
          }
          if (used.length === 0) return { status: 'error', message: 'Failed to upload any document(s) for analysis.' };
          const resDocs = await ai.models.generateContent({ model: preferredModel, contents: createUserContent(partsList) });
          return { status: 'success', analysis: resDocs.text ?? '', doc_count: used.length, files: used };
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
          const inserted = await supabase
            .from('canvas_files')
            .insert({ chat_id: effectiveChatId, path, content })
            .select('id, path, content')
            .single();
          if ((inserted as any)?.error) return { status: 'error', message: (inserted as any).error.message };
          const row = (inserted as any)?.data;
          return { status: 'success', id: row?.id, path: row?.path, content: String(row?.content ?? '') };
        }
        case 'canvas_update_file_content': {
          const path = String(args.path ?? '').trim();
          const newContent = String(args.new_content ?? '');
          if (!path) return { status: 'error', message: 'path is required' };
          const updated = await supabase
            .from('canvas_files')
            .update({ content: newContent, last_modified: new Date().toISOString() })
            .match({ chat_id: effectiveChatId, path })
            .select('id, path, content')
            .single();
          if ((updated as any)?.error) return { status: 'error', message: (updated as any).error.message };
          const row = (updated as any)?.data;
          return { status: 'success', id: row?.id, path: row?.path, content: String(row?.content ?? '') };
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
      const toolbox = buildToolboxGuidance([...playgroundTools, ...playgroundCanvasTools, ...playgroundReadTools, ...playgroundCompositeTools]);
      const hardRules = `\n\nHARD CONSTRAINTS (Playground Canvas)\n• Single-file policy: Keep the entire app in ONE canvas file. Inline CSS and JS if needed.\n• Do NOT create a new canvas file if any canvas file already exists for this chat. Always update the existing file.\n• Prefer implement_feature_and_update_todo (or canvas_update_file_content) over canvas_create_file when a canvas exists.\n• If you attempt to create a second file, expect an error and immediately switch to updating the available path(s).\n• Be supportive and friendly. Explain what you’re doing briefly and keep the user informed.\n• When the user asks to build a project, prioritize: (1) todo_list_create to plan tasks, then (2) implement_feature_and_update_todo to implement each task and mark it done.`;
      const oneShot = `\n\nONE-SHOT EXAMPLE\nUser: \"Build a simple quote generator website with separate HTML, CSS, and JS files.\"\nAssistant (thought): The Playground uses a single-file canvas. I’ll embed HTML, CSS, and JS in one file and update that file.\nAssistant (tools):\n1) todo_list_create → Create tasks: setup HTML structure, add styles, implement JS logic.\n2) implement_feature_and_update_todo(path: 'index.html', new_content: '<!doctype html>...<style>/* CSS */</style><script>/* JS */</script>...', artifact_id: '...', task_id: '...') → Update single file and mark task done.\nAssistant: I’ve implemented the quote generator in one file (index.html) with inline CSS and JS. Next, I’ll complete the remaining tasks similarly.`;
      const guidance = `You are Robin, a powerful AI assistant in \'Playground mode\', a place where users experiement and prototype their project ideas .\n- Prefer web-first solutions (React or HTML/CSS/JS) unless the user specifically requests another stack or web is unsuitable.\n- Use tools when needed instead of fabricating results.\n- When creating simple web features that can run in a single file, prefer making self-contained components suitable for Canvas preview.\n- Do not dump large JSON inline unless asked. Summarize and store structured outputs as artifacts when appropriate.${hardRules}${oneShot}${toolbox}\n${artifactsList}`;
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
            const toolResponse = await executeTool(name, args, effectiveChatId, { attachments: sanitizedAttachments });
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
                    const toolResponse = await executeTool(name, args, effectiveChatId, { attachments: sanitizedAttachments });
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
