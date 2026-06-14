# GitLab Duo ⇄ Claude Code Proxy

A lightweight local proxy that bridges Anthropic's Messages API to GitLab Duo's CLI client, enabling you to use **Claude Opus 4.8** (or Sonnet 4.6) for free inside **Claude Code** (with a 30-day GitLab Ultimate trial, no credit card required).

---

## Features

- **Zero External Dependencies**: Pure Node.js standard library (no `npm install` needed).
- **Real-time Streaming (SSE)**: Renders Claude Code's responses instantly line-by-line.
- **System Prompt Optimization**: Automatically filters out massive system-reminder injections to avoid cluttering context windows and stay within API limits.
- **Dynamic CWD Resolution**: Automatically routes commands to your active Git repository workspace so GitLab Duo has the correct project context.
- **Windows Silent Background Runner**: Starts hidden in the background without spawning cluttering terminal windows.

---

## Step-by-Step Setup

### Prerequisites
- **Node.js** (v16+) installed.
- **Git** installed.
- **Claude Code CLI** installed (`npm install -g @anthropic-ai/claude-code`).

---

### Step 1: Claim your GitLab Ultimate 30-Day Free Trial
1. Go to [GitLab.com](https://gitlab.com) and create a new account.
2. Once registered, start a 30-day **GitLab Ultimate Free Trial** (available for personal namespaces or groups).
3. **No credit card is required**—just complete the email verification and start the trial.

---

### Step 2: Install and Log in with GitLab CLI (`glab`)
1. **Install the CLI**:
   - **Windows**: `winget install GitLab.GLAB` (or download from GitHub Releases)
   - **macOS**: `brew install glab`
   - **Linux**: Use your package manager (e.g., `sudo apt install glab` or `sudo dnf install glab`)
2. **Authenticate the CLI**:
   - Run: `glab auth login`
   - Select `gitlab.com`
   - Choose your preferred protocol (HTTPS/SSH)
   - Authenticate via browser or paste a personal access token (ensure `api` and `read_user` scopes are checked).

---

### Step 3: Test GitLab Duo in a Repository
Because the GitLab CLI requires a Git project workspace context:
1. Open any Git repository on your machine.
2. Run the following command:
   ```bash
   glab duo cli run --model claude_opus_4_8 --goal "Say hello and confirm you are working."
   ```
3. If it outputs a response from Claude, you are ready to configure the proxy!

---

### Step 4: Configure the Proxy (Automated & Manual Setup)

Clone or download this repository to a folder of your choice (e.g., `~/gitlab-claude-proxy`).

#### Option A: Windows Automated Setup
1. Open PowerShell and navigate to the proxy folder.
2. Run the installer script:
   ```powershell
   Set-ExecutionPolicy Bypass -Scope Process
   .\setup.ps1
   ```
3. Restart your PowerShell terminal or run `. $PROFILE` to apply configuration.
4. Run `cg` inside any Git repository to launch Claude Code with GitLab Duo!

#### Option B: macOS & Linux Automated Setup
1. Open your terminal (Bash or Zsh) and navigate to the proxy folder.
2. Make the installer script executable and run it:
   ```bash
   chmod +x setup.sh
   ./setup.sh
   ```
3. Restart your terminal session or reload your shell profile (e.g., `source ~/.zshrc` or `source ~/.bashrc`).
4. Run `cg` inside any Git repository to launch Claude Code!

#### Option C: Manual Setup (Cross-Platform / Custom Shells)

##### 1. Configure Claude Code Settings
Create or modify your Claude Code settings file at `~/.claude/settings.json`:
```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "http://127.0.0.1:3456",
    "ANTHROPIC_API_KEY": "gitlab-proxy",
    "ANTHROPIC_AUTH_TOKEN": "gitlab-proxy",
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1",
    "MAX_THINKING_TOKENS": 8192
  },
  "permissions": {
    "allow": [],
    "deny": []
  },
  "model": "claude-opus-4-8",
  "effortLevel": "xhigh"
}
```

##### 2. Launch the Proxy Server
In the proxy directory, run:
```bash
node server.js
```
The server will start listening at `http://127.0.0.1:3456`.

##### 3. Run Claude Code
Define the environment variables in your active terminal:
```bash
# Bash / Zsh
export ANTHROPIC_BASE_URL="http://127.0.0.1:3456"
export ANTHROPIC_API_KEY="gitlab-proxy"
claude --model claude-opus-4-8

# Command Prompt (cmd)
set ANTHROPIC_BASE_URL=http://127.0.0.1:3456
set ANTHROPIC_API_KEY=gitlab-proxy
claude --model claude-opus-4-8
```

---

## Daily Usage & Shortcuts (Cross-Platform)

If you completed the automated setup (Option A or B), the following commands are added to your environment:

- `cg [arguments]`: Automatically saves your current directory path to `~/.cg-cwd.txt`, starts the Node proxy silently in the background if it isn't running, and launches Claude Code.
  - *Example*: `cg --print "write a quick python script to parse a csv"`
- `stop-proxy`: Stops and kills the background Node.js proxy server.
- `restart-proxy`: Force restarts the background Node.js proxy server.

---

## How it Works Under the Hood

```
┌─────────────┐                      ┌─────────────┐                      ┌────────────┐
│             │   Anthropic API API  │             │   Executes glab cli  │            │
│ Claude Code │  ─────────────────>  │ Local Proxy │  ─────────────────>  │ GitLab Duo │
│     CLI     │  <─────────────────  │ (server.js) │  <─────────────────  │ (via SaaS) │
│             │    Streamed (SSE)    │             │   Parsed Output      │            │
└─────────────┘                      └─────────────┘                      └────────────┘
```

1. **Model Discovery**: Claude Code probes the endpoint `/v1/models` on startup. The proxy returns a mockup model list featuring `claude-opus-4-8`.
2. **Context Filtering**: Claude Code transmits large system prompts. The proxy parses the messages array and extracts only the last active user query (`extractUserGoal`).
3. **Piped Stream**: The proxy passes the goal via the `DUO_WORKFLOW_GOAL` environment variable (to bypass command-line length limits on Windows) and invokes `glab duo cli run`.
4. **SSE Streaming Interface**: The proxy intercepts stdout/stderr, extracts the assistant response content block, and chunks it back to Claude Code using standard Server-Sent Events (SSE).

---

## Disclaimers & Security

- **Completely Local**: The proxy server operates strictly on localhost (`127.0.0.1:3456`). No external entities receive your data except GitLab's official API endpoints.
- **Privacy Safe**: None of your local paths, personal names, or authentication keys are stored or shared.
- **Educational Use**: This project is for personal educational testing of Claude Code integrations. Use in compliance with GitLab's Terms of Service.

---

## AI Prompt Template

If you want to recreate or customize this setup using another AI assistant (like Cursor, Claude, ChatGPT, or Gemini), we have provided a ready-to-use prompt template in the [PROMPT.md](PROMPT.md) file.
