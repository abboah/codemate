import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { GoogleGenAI } from "https://esm.sh/@google/genai";
import { availableTools } from "../_shared/tools.ts";

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

  const { prompt, history, projectId, model: requestedModel, includeThoughts } = await req.json();

    const ai = new GoogleGenAI({ apiKey: geminiApiKey });
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: req.headers.get("Authorization") ?? '' } } }
    );

    const DEFAULT_MODEL = "gemini-2.5-flash";
    const preferredModel = (typeof requestedModel === 'string' && requestedModel.length > 0) ? requestedModel : DEFAULT_MODEL;

  async function runOnce(modelName: string): Promise<{ text: string; fileEdits: any[] }> {
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
      const systemInstruction = `You are Robin, an expert AI software development assistant working inside a multi-pane IDE. Always identify yourself as Robin.\nCurrent project: ${projectName}.\n Project description: ${projectDescription}. \n Stack for the project: ${projectStack.map((s: string) => `- ${s}`).join('\n')}\n\n Project files (${filePaths.length}):\n${filePaths.map((p: string) => `- ${p}`).join('\n')}\n\n Assist the user with requests in the context of the project.
      
      NOTE:
        Do not start a conversation with any phrase like "Robin:", "AI:", "Assistant:" or anything similar. Just provide the response. If you will intriduce yourself to the user, do it only at the start of the conversation.
      `;

      // Build compositional contents
      const contents: any[] = Array.isArray(history) && history.length > 0 ? [...history] : [];
      contents.push({ role: 'user', parts: [{ text: prompt }] });

      const fileEdits: any[] = [];
      let finalText = '';

      while (true) {
        const result = await ai.models.generateContent({
          model: modelName,
          contents,
          config: { tools: [{ functionDeclarations: availableTools }], systemInstruction },
        });

        if (result.functionCalls && result.functionCalls.length > 0) {
          // Execute each function call, then push functionCall and functionResponse back into contents
          for (const functionCall of result.functionCalls) {
            const { name, args } = functionCall as { name: string; args: Record<string, any> };
            let toolResponse: any = {};
            try {
              switch (name) {
                case 'create_file': {
                  const newContent = String(args.content ?? '');
                  const { error } = await supabase.from('project_files').insert({
                    project_id: projectId,
                    path: args.path,
                    content: newContent,
                  });
                  if (error) throw error;
                  fileEdits.push({ operation: 'create', path: args.path, old_content: '', new_content: newContent });
                  toolResponse = { status: 'success', message: `Created ${args.path}` };
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
                  toolResponse = { status: 'success', message: `Updated ${args.path}` };
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
                  toolResponse = { status: 'success', message: `Deleted ${args.path}` };
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
                default:
                  toolResponse = { status: 'error', message: `Unknown function call: ${name}` };
              }
            } catch (err: any) {
              toolResponse = { status: 'error', message: err?.message ?? String(err) };
            }

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

      return { text: `${finalText}${toolHeader}`, fileEdits };
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
            const systemInstruction = `You are Robin, an expert AI software development assistant working inside a multi-pane IDE. Always identify yourself as Robin.\nCurrent project: ${projectName}.\n Project description: ${projectDescription}. \n Stack for the project: ${projectStack.map((s: string) => `- ${s}`).join('\n')}\n\n Project files (${filePaths.length}):\n${filePaths.map((p: string) => `- ${p}`).join('\n')}\n\n Assist the user with requests in the context of the project.\n      \n      NOTE:\n        Do not start a conversation with any phrase like "Robin:", "AI:", "Assistant:" or anything similar. Just provide the response. If you will intriduce yourself to the user, do it only at the start of the conversation.\n      `;

            const contents: any[] = Array.isArray(history) && history.length > 0 ? [...history] : [];
            contents.push({ role: 'user', parts: [{ text: prompt }] });

            const fileEdits: any[] = [];
            let textSoFar = '';
            let thoughtsSoFar = '';

            emit({ type: 'start', model: modelName });

            // Tool-call loop with streaming text
            while (true) {
              // Collect function calls (if any) from this round
              const pendingCalls: Array<{ name: string; args: Record<string, any> } > = [];
              try {
                // Use the latest streaming API: the returned value is an async iterable
                // of chunks with .text and possibly .functionCalls and parts (including thoughts).
                // @ts-ignore - types may differ across SDK versions
                const streamResp: AsyncIterable<any> | any = await ai.models.generateContentStream({
                  model: modelName,
                  contents,
                  config: {
                    tools: [{ functionDeclarations: availableTools }],
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
                        pendingCalls.push({ name: c.name, args: c.args ?? {} });
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
                      tools: [{ functionDeclarations: availableTools }],
                      systemInstruction,
                      ...(includeThoughts ? { thinkingConfig: {thinkingBudget: -1, includeThoughts: true } } : {}),
                    },
                  });
                  // If tool calls requested, mark flag; else stream the text in chunks
                  if (single.functionCalls && single.functionCalls.length > 0) {
                    for (const c of single.functionCalls) {
                      if (c && typeof c.name === 'string') {
                        pendingCalls.push({ name: c.name, args: c.args ?? {} });
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
                  for (const { name, args } of pendingCalls) {
                    let toolResponse: any = {};
                    try {
                      switch (name) {
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
                          toolResponse = { status: 'success', message: `Created ${args.path}` };
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
                          toolResponse = { status: 'success', message: `Updated ${args.path}` };
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
                          toolResponse = { status: 'success', message: `Deleted ${args.path}` };
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
                    emit({ type: 'tool_result', name, ok: toolResponse.status === 'success', result: toolResponse });
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
            emit({ type: 'end', finalText, fileEdits });
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