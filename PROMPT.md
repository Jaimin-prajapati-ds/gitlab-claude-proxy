# AI Prompt Template

You can copy and paste the prompt below into any AI assistant (like Cursor, Claude, ChatGPT, or Gemini) to have it generate the proxy code, custom configuration scripts, or explain the setup for your system.

---

### Copy-Paste Prompt for AIs

```text
I want to use Anthropic's Claude Code CLI with GitLab Duo's AI backend (which runs Claude Opus 4.8 / Sonnet 4.6 for free during their 30-day Ultimate trial). Since Claude Code makes standard Anthropic Messages API calls, I need a local Node.js proxy server that intercepts these requests and translates them into GitLab Duo CLI (`glab duo cli run`) executions.

Please generate a lightweight, dependency-free Node.js proxy server that:
1. Listens on localhost (port 3456).
2. Mocks the GET `/v1/models` endpoint returning a model list featuring `claude-opus-4-8`.
3. Handles POST `/v1/messages` (with SSE streaming support).
4. Extracts only the final user query content (filtering out the large Claude Code system prompts to fit context limits).
5. Runs `glab duo cli run --model claude_opus_4_8` under the hood. It should pass the user goal safely via the environment variable `DUO_WORKFLOW_GOAL` to avoid command-line quoting and length limitations on Windows.
6. Parses the stdout/stderr stream from glab, extracts the JSON chunks/lines with the assistant role or complete markers, and streams the responses back in standard Server-Sent Event (SSE) format.
7. Uses a dynamic path resolution to locate the active Git repository (e.g., reading a local file like `~/.cg-cwd.txt`).

Also, generate:
1. A PowerShell integration script/snippet to auto-start the proxy hidden in the background, update the current path pointer (`~/.cg-cwd.txt`), and launch Claude Code pointing to this local proxy.
2. A configuration for `~/.claude/settings.json` that redirects Claude Code API requests to the proxy on localhost.
3. Steps to obtain the GitLab Ultimate free trial (no credit card) and log in with the glab CLI.
```
