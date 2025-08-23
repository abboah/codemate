import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { GoogleGenAI } from "https://esm.sh/@google/genai";

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
    const geminiApiKey = Deno.env.get("GEMINI_API_KEY_2");
    if (!geminiApiKey) throw new Error("GEMINI_API_KEY_2 is not set in the Supabase project secrets.");

  const { prompt, history, projectId, model: requestedModel, attachedFiles, includeThoughts, chatId } = await req.json();

    const ai = new GoogleGenAI({ apiKey: geminiApiKey });
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: req.headers.get("Authorization") ?? '' } } }
    );

    const DEFAULT_MODEL = "gemini-2.5-flash";
    const preferredModel = (typeof requestedModel === 'string' && requestedModel.length > 0) ? requestedModel : DEFAULT_MODEL;

  async function runOnce(modelName: string): Promise<{ text: string; fileEdits: any[] }> {
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

      // Add attached files content to system context (read-only)
      const attachedSummary = Array.isArray(attachedFiles) && attachedFiles.length
        ? `\n\nAttached files (${attachedFiles.length}):\n${attachedFiles.map((f: any) => `- ${f.path} (${(f.content || '').split('\n').length} lines)`).join('\n')}`
        : '';

      const systemInstruction = `You are Robin, acting in Ask mode. Provide analysis, suggestions, and code review. You must NOT modify files or suggest that you changed files. You only read code via the read_file tool and reason about it.\nCurrent project: ${projectName}.\n Project description: ${projectDescription}. \n Stack: ${projectStack.map((s: string) => `- ${s}`).join('\n')}\n\n Project files (${filePaths.length}):\n${filePaths.map((p: string) => `- ${p}`).join('\n')}${attachedSummary}`;

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

      return { text: finalText, fileEdits };
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

            const systemInstruction = `You are Robin, acting in Ask mode. Provide analysis, suggestions, and code review. You must NOT modify files or suggest that you changed files. You only read code via the read_file tool and reason about it.\nCurrent project: ${projectName}.\n Project description: ${projectDescription}. \n Stack: ${projectStack.map((s: string) => `- ${s}`).join('\n')}\n\n Project files (${filePaths.length}):\n${filePaths.map((p: string) => `- ${p}`).join('\n')}${attachedSummary}`;

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
                const pendingCalls: Array<{ name: string; args: Record<string, any> }> = [];
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
                        ],
                      }],
                      systemInstruction,
                      ...(includeThoughts ? { thinkingConfig: { thinkingBudget: -1, includeThoughts: true } } : {}),
                    },
                  });
                  if (single.functionCalls && single.functionCalls.length > 0) {
                    for (const c of single.functionCalls) {
                      if (c && typeof c.name === 'string') {
                        pendingCalls.push({ name: c.name, args: c.args ?? {} });
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

            emit({ type: 'end', finalText: textSoFar, fileEdits: [] });
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