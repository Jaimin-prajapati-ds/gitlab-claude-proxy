/**
 * GitLab → Claude Code Proxy Server v3
 *
 * Routes Claude Code API calls → glab duo cli run (GitLab Duo)
 * Uses DUO_WORKFLOW_GOAL env var to pass prompt safely (avoids Windows cmd-line limits)
 *
 * Usage:
 *   node server.js
 *
 * Then in another terminal (or let the cg function do it):
 *   $env:ANTHROPIC_BASE_URL="http://localhost:3456"
 *   $env:ANTHROPIC_API_KEY="gitlab-proxy"
 *   claude --model claude-opus-4-8
 */

const http = require('http');
const { spawnSync } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

const PORT = process.env.CG_PORT || 3456;
const CWD_FILE = path.join(os.homedir(), '.cg-cwd.txt');
const MODEL = process.env.CG_MODEL || 'claude_opus_4_8';

// Default project path defaults to environment variable or the directory containing the proxy
const DEFAULT_PATH = process.env.CG_DEFAULT_PROJECT_PATH || process.cwd();

function getCurrentPath() {
  try {
    const cwd = fs.readFileSync(CWD_FILE, 'utf8').trim();
    if (cwd && fs.existsSync(cwd)) return cwd;
  } catch (_) {}
  return DEFAULT_PATH;
}

/**
 * Extract the last user message text from the messages array.
 * Claude Code sends enormous system prompts — we only forward the
 * actual user intent to GitLab Duo.
 */
function extractUserGoal(requestData) {
  const messages = requestData.messages || [];
  // Walk backwards to find the last user message
  for (let i = messages.length - 1; i >= 0; i--) {
    const m = messages[i];
    if (m.role !== 'user') continue;
    if (typeof m.content === 'string') return m.content.trim();
    if (Array.isArray(m.content)) {
      // Filter out system-reminder injections (huge XML blobs)
      const texts = m.content
        .filter(c => c && c.type === 'text')
        .map(c => (c.text || '').trim())
        .filter(t => !t.startsWith('<system-reminder>') && t.length > 0);
      if (texts.length > 0) return texts.join('\n');
    }
  }
  return 'Hello';
}

function callGitLabDuo(goal) {
  const projectPath = getCurrentPath();
  console.log(`\n[PROXY] → CWD: ${projectPath}`);
  console.log(`[PROXY] → goal: "${goal.substring(0, 120)}"`);

  // Pass goal via env var to avoid Windows cmd-line length limit and quoting issues
  const result = spawnSync('glab', [
    'duo', 'cli', 'run',
    '--model', MODEL,
    '-C', projectPath,
  ], {
    encoding: 'utf8',
    shell: false,          // shell:false + env var = safe paths with spaces
    timeout: 120000,
    env: { ...process.env, DUO_WORKFLOW_GOAL: goal },
    maxBuffer: 10 * 1024 * 1024,
  });

  if (result.error) {
    console.error('[PROXY] ❌ spawn error:', result.error.message);
    return `Error calling GitLab Duo: ${result.error.message}`;
  }

  const combined = (result.stdout || '') + (result.stderr || '');

  if (result.status !== 0) {
    console.error('[PROXY] ❌ glab exited', result.status, combined.slice(-300));
  }

  // Strategy 1: RunController log line with isComplete:true
  const runControllerMatch = combined.match(/\[RunController\]\s*(\{[\s\S]+?"isComplete":\s*true\s*\})/);
  if (runControllerMatch) {
    try {
      const obj = JSON.parse(runControllerMatch[1]);
      if (obj.content) {
        console.log(`[PROXY] ✅ RunController: "${obj.content.substring(0, 80)}"`);
        return obj.content;
      }
    } catch (_) {}
  }

  // Strategy 2: Any JSON line with role=assistant
  for (const line of combined.split('\n')) {
    const jsonStart = line.indexOf('{');
    if (jsonStart === -1) continue;
    try {
      const obj = JSON.parse(line.slice(jsonStart));
      if (obj.role === 'assistant' && obj.content) {
        console.log(`[PROXY] ✅ JSON scan: "${obj.content.substring(0, 80)}"`);
        return obj.content;
      }
    } catch (_) {}
  }

  console.log('[PROXY] ⚠️ Could not parse response. Raw tail:', combined.slice(-400));
  return combined.trim() || 'No response from GitLab Duo';
}

// ─────────────────────────────────────────────────────────────────────────────

const server = http.createServer((req, res) => {
  console.log(`[HTTP] ${req.method} ${req.url}`);
  const pathname = req.url.split('?')[0];

  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, GET, OPTIONS, HEAD');
  res.setHeader('Access-Control-Allow-Headers', '*');

  if (req.method === 'OPTIONS' || req.method === 'HEAD') {
    res.writeHead(200); res.end(); return;
  }

  // GET /v1/models — Claude Code calls this at startup to validate the model name
  if (req.method === 'GET' && pathname === '/v1/models') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      object: 'list',
      data: [
        { id: 'claude-opus-4-8',          object: 'model', created: 1700000000, owned_by: 'gitlab-duo' },
        { id: 'claude-opus-4-5-20251101', object: 'model', created: 1700000000, owned_by: 'gitlab-duo' },
        { id: 'claude-sonnet-4-6',        object: 'model', created: 1700000000, owned_by: 'gitlab-duo' },
      ]
    }));
    return;
  }

  // POST /v1/messages — main inference endpoint
  if (req.method === 'POST' && pathname === '/v1/messages') {
    let body = '';
    req.on('data', chunk => body += chunk.toString());
    req.on('end', () => {
      let requestData;
      try { requestData = JSON.parse(body); }
      catch (e) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: { type: 'invalid_request_error', message: 'Invalid JSON' } }));
        return;
      }

      // Extract only the real user goal, not the enormous system prompts
      const goal = extractUserGoal(requestData);
      const responseText = callGitLabDuo(goal);

      const anthropicResponse = {
        id: `msg_${Date.now()}`,
        type: 'message',
        role: 'assistant',
        content: [{ type: 'text', text: responseText }],
        model: requestData.model || 'claude-opus-4-8',
        stop_reason: 'end_turn',
        stop_sequence: null,
        usage: {
          input_tokens: Math.ceil(goal.length / 4),
          output_tokens: Math.ceil(responseText.length / 4),
        }
      };

      // Streaming (SSE) — Claude Code uses this by default
      if (requestData.stream) {
        res.writeHead(200, {
          'Content-Type': 'text/event-stream',
          'Cache-Control': 'no-cache',
          'Connection': 'keep-alive',
        });
        const send = (obj) => res.write(`data: ${JSON.stringify(obj)}\n\n`);
        send({ type: 'message_start', message: { ...anthropicResponse, content: [] } });
        send({ type: 'content_block_start', index: 0, content_block: { type: 'text', text: '' } });
        for (let i = 0; i < responseText.length; i += 20) {
          send({ type: 'content_block_delta', index: 0, delta: { type: 'text_delta', text: responseText.slice(i, i + 20) } });
        }
        send({ type: 'content_block_stop', index: 0 });
        send({ type: 'message_delta', delta: { stop_reason: 'end_turn' }, usage: anthropicResponse.usage });
        send({ type: 'message_stop' });
        res.end();
      } else {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify(anthropicResponse));
      }
    });
    return;
  }

  res.writeHead(404, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ error: 'Not found' }));
});

server.listen(PORT, '127.0.0.1', () => {
  console.log(`
╔═══════════════════════════════════════════════════════╗
║    GitLab Duo → Claude Code Proxy  ✅  v3             ║
║    Model: Claude Opus 4.8 (FREE via GitLab)           ║
╠═══════════════════════════════════════════════════════╣
║  Listening: http://127.0.0.1:${PORT}                     ║
╚═══════════════════════════════════════════════════════╝
  `);
});
