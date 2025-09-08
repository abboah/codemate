import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { GoogleGenAI } from "https://esm.sh/@google/genai";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
};

function fallbackFacts(): string[] {
  return [
    'The first computer bug was a real moth found in 1947.',
    'Python is named after Monty Python, not the snake.',
    'CSS stands for Cascading Style Sheets—order matters!',
    'JavaScript was created in just 10 days in 1995.',
    'In Git, HEAD is just a pointer to your current branch.',
    'SQL is declarative: you say what you want, not how to get it.',
    'HTTP/2 multiplexes multiple streams over one connection.',
    'Rust’s borrow checker prevents data races at compile time.',
  ];
}

async function generateFacts(n: number, apiKey: string): Promise<string[]> {
  try {
    const ai = new GoogleGenAI({ apiKey });
    const prompt = `Return exactly ${n} short one-line programming facts as a JSON array of strings. No prose, no markdown, just the JSON array.`;
    const res: any = await ai.models.generateContent({
      model: 'gemini-2.5-flash',
      contents: [{ role: 'user', parts: [{ text: prompt }] }],
    });
    const text: string = res?.text ?? '';
    // Try strict JSON first
    try {
      const parsed = JSON.parse(text);
      if (Array.isArray(parsed)) {
        return parsed.map((x) => String(x)).filter((s) => s.trim().length > 0).slice(0, n);
      }
    } catch (_) { /* not JSON, try to salvage */ }
    // Fallback: split by lines/bullets
    const lines = text
      .split(/\r?\n|•|\-|\d+\./)
      .map((s) => s.trim())
      .filter((s) => s.length > 0);
    if (lines.length > 0) return lines.slice(0, n);
    return fallbackFacts().slice(0, n);
  } catch (_) {
    return fallbackFacts().slice(0, n);
  }
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  try {
    const url = new URL(req.url);
    const countParam = url.searchParams.get('count');
    const nRaw = Number(countParam ?? 8);
    const n = Number.isFinite(nRaw) ? Math.max(1, Math.min(20, Math.trunc(nRaw))) : 8;

    const apiKey = (globalThis as any).Deno?.env.get('GEMINI_API_KEY_5');
    if (!apiKey) {
      // No API key: return a fallback set so the UI still works
      return new Response(JSON.stringify({ facts: fallbackFacts().slice(0, n), source: 'fallback' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const facts = await generateFacts(n, apiKey);
    return new Response(JSON.stringify({ facts, source: 'gemini' }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (error: any) {
    return new Response(JSON.stringify({ facts: fallbackFacts(), error: error?.message ?? String(error), source: 'error-fallback' }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200, // return 200 with fallback to avoid UI failure
    });
  }
});
