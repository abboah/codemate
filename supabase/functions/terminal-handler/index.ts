import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

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
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: req.headers.get("Authorization") ?? '' } } }
    );

    const { command, projectId, currentDirectory, sessionId } = await req.json();
    const cwd = normalizeCwd(String(currentDirectory || '/'));
    const [cmd, ...args] = String(command || '').trim().split(/\s+/);

    async function listDir(dir: string) {
      const pattern = dir === '/' ? '%' : `${dir}/%`;
      const { data, error } = await supabase
        .from('project_files')
        .select('path, last_modified')
        .eq('project_id', projectId)
        .like('path', pattern)
        .order('path');
      if (error) throw error;
      const names = (data || []).map((r: any) => r.path);
      // Format as tree-like immediate children
      const immediate = new Set<string>();
      for (const p of names) {
        const rest = dir === '/' ? p : p.replace(new RegExp(`^${escapeRegExp(dir)}/?`), '');
        const first = rest.split('/')[0];
        if (first) immediate.add(first);
      }
      return Array.from(immediate).sort().join('\n');
    }

    async function readFile(path: string) {
      const full = toPath(cwd, path);
      const { data, error } = await supabase
        .from('project_files')
        .select('content')
        .eq('project_id', projectId)
        .eq('path', full)
        .single();
      if (error) return `cat: ${full}: No such file`;
      return String(data?.content ?? '');
    }

    async function makeDir(path: string) {
      // VFS is implicit; directories are prefixes. No-op but validate path
      const full = toPath(cwd, path);
      if (!full || full === '/') return 'mkdir: invalid path';
      return '';
    }

    async function touch(path: string) {
      const full = toPath(cwd, path);
      const { data } = await supabase
        .from('project_files')
        .select('id')
        .eq('project_id', projectId)
        .eq('path', full)
        .maybeSingle();
      if (data) {
        await supabase
          .from('project_files')
          .update({ last_modified: new Date().toISOString() })
          .eq('project_id', projectId)
          .eq('path', full);
      } else {
        await supabase
          .from('project_files')
          .insert({ project_id: projectId, path: full, content: '' });
      }
      return '';
    }

    async function remove(path: string) {
      const full = toPath(cwd, path);
      const { error } = await supabase
        .from('project_files')
        .delete()
        .eq('project_id', projectId)
        .eq('path', full);
      if (error) return `rm: cannot remove ${full}: ${error.message}`;
      return '';
    }

    function cd(path: string) {
      if (!path || path === '/') return '/';
      if (path.startsWith('/')) return normalizeCwd(path);
      return normalizeCwd(`${cwd}/${path}`);
    }

    let output = '';
    let exitCode = 0;
    let nextCwd = cwd;

    switch (cmd) {
      case 'ls': {
        output = await listDir(cwd);
        break;
      }
      case 'cat': {
        output = await readFile(args[0] || '');
        break;
      }
      case 'echo': {
        output = args.join(' ');
        break;
      }
      case 'head': {
        const content = await readFile(args[0] || '');
        output = content.split('\n').slice(0, 10).join('\n');
        break;
      }
      case 'tail': {
        const content = await readFile(args[0] || '');
        const lines = content.split('\n');
        output = lines.slice(Math.max(0, lines.length - 10)).join('\n');
        break;
      }
      case 'whoami': {
        output = 'robin';
        break;
      }
      case 'mkdir': {
        output = await makeDir(args[0] || '');
        break;
      }
      case 'touch': {
        output = await touch(args[0] || '');
        break;
      }
      case 'rm': {
        output = await remove(args[0] || '');
        break;
      }
      case 'cd': {
        nextCwd = cd(args[0] || '/');
        break;
      }
      case 'pwd': {
        output = nextCwd;
        break;
      }
      case 'help':
      default: {
        output = `Available commands:\nls, cat <path>, echo <text>, head <path>, tail <path>, cd <path>, pwd, mkdir <path>, touch <path>, rm <path>, whoami`;
        break;
      }
    }

    return new Response(JSON.stringify({ output, exitCode, cwd: nextCwd }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
  } catch (error: any) {
    return new Response(JSON.stringify({ output: String(error), exitCode: 1, cwd: '/' }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    });
  }
});

function toPath(cwd: string, p: string) {
  if (!p || p === '.') return cwd;
  if (p.startsWith('/')) return normalizeCwd(p);
  return normalizeCwd(`${cwd}/${p}`);
}

function normalizeCwd(p: string) {
  const parts = p.split('/').filter(Boolean);
  const stack: string[] = [];
  for (const part of parts) {
    if (part === '.') continue;
    if (part === '..') stack.pop(); else stack.push(part);
  }
  return '/' + stack.join('/');
}

function escapeRegExp(s: string) {
  return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
} 