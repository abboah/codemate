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

    const { prompt, history, projectId, model: requestedModel } = await req.json();

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