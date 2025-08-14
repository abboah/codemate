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

    const { prompt, history, projectId, model: requestedModel, attachedFiles } = await req.json();

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

      const contents: any[] = Array.isArray(history) && history.length > 0 ? [...history] : [];
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