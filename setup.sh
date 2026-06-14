#!/bin/bash

# setup.sh - Automated Setup Script for macOS and Linux
# Configures GitLab Duo -> Claude Code Proxy on your system

PROXY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROXY_SCRIPT="$PROXY_DIR/server.js"

echo "============================================="
echo " GitLab Duo to Claude Code Proxy Installer   "
echo " (macOS & Linux Edition)                     "
echo "============================================="
echo ""

# 1. Check for Node.js
if ! command -v node >/dev/null 2>&1; then
    echo "❌ Node.js is not installed or not in PATH."
    echo "Please install Node.js (v16+) before running this setup."
    exit 1
fi
echo "✅ Node.js detected."

# 2. Check for glab CLI
if ! command -v glab >/dev/null 2>&1; then
    echo "⚠️ GitLab CLI (glab) not detected."
    echo "Please install it using your package manager (e.g., brew install glab or sudo apt install glab)."
    echo "Then run 'glab auth login' to authenticate."
    echo ""
else
    echo "✅ GitLab CLI (glab) detected."
fi

# 3. Configure Claude Code settings (~/.claude/settings.json)
CLAUDE_DIR="$HOME/.claude"
mkdir -p "$CLAUDE_DIR"
SETTINGS_PATH="$CLAUDE_DIR/settings.json"

create_settings() {
    cat <<EOF > "$SETTINGS_PATH"
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
EOF
}

if [ -f "$SETTINGS_PATH" ]; then
    echo "Updating existing ~/.claude/settings.json..."
    create_settings
else
    echo "Creating ~/.claude/settings.json..."
    create_settings
fi
echo "✅ Claude Code settings updated successfully."

# Make cg.sh executable
chmod +x "$PROXY_DIR/cg.sh"

# 4. Update Shell Profile (.zshrc or .bashrc)
SHELL_NAME=$(basename "$SHELL")
PROFILE_PATH=""

if [ "$SHELL_NAME" = "zsh" ]; then
    PROFILE_PATH="$HOME/.zshrc"
elif [ "$SHELL_NAME" = "bash" ]; then
    if [ "$(uname)" = "Darwin" ]; then
        PROFILE_PATH="$HOME/.bash_profile"
    else
        PROFILE_PATH="$HOME/.bashrc"
    fi
else
    if [ -f "$HOME/.zshrc" ]; then
        PROFILE_PATH="$HOME/.zshrc"
    elif [ -f "$HOME/.bashrc" ]; then
        PROFILE_PATH="$HOME/.bashrc"
    fi
fi

SNIPPET=$(cat <<EOF

# --- GitLab Duo → Claude Code (Opus 4.8) Proxy Setup -------------------------
export ANTHROPIC_BASE_URL="http://127.0.0.1:3456"
export ANTHROPIC_API_KEY="gitlab-proxy"
PROXY_SCRIPT="$PROXY_SCRIPT"

cg() {
    pwd > "\$HOME/.cg-cwd.txt"

    # Check if port 3456 is listening
    if ! nc -z 127.0.0.1 3456 >/dev/null 2>&1 && ! lsof -i :3456 >/dev/null 2>&1; then
        echo "🚀 Starting GitLab Duo Proxy (Claude Opus 4.8)..."
        pkill -f "node.*server.js" >/dev/null 2>&1
        sleep 0.3
        node "\$PROXY_SCRIPT" >/dev/null 2>&1 &
        
        waited=0
        while ! nc -z 127.0.0.1 3456 >/dev/null 2>&1 && [ \$waited -lt 10 ]; do
            sleep 1
            ((waited++))
        done
        if nc -z 127.0.0.1 3456 >/dev/null 2>&1; then
            echo "✅ Proxy ready!"
        else
            echo "⚠️ Proxy starting in background..."
        fi
    fi

    export ANTHROPIC_BASE_URL="http://127.0.0.1:3456"
    export ANTHROPIC_API_KEY="gitlab-proxy"
    claude --model claude-opus-4-8 "\$@"
}

stop-proxy() {
    pkill -f "node.*server.js" >/dev/null 2>&1
    echo "🛑 Proxy stopped"
}

restart-proxy() {
    stop-proxy
    sleep 0.5
    node "\$PROXY_SCRIPT" >/dev/null 2>&1 &
    echo "🔄 Proxy restarting..."
}
# -----------------------------------------------------------------------------
EOF
)

if [ -n "$PROFILE_PATH" ] && [ -f "$PROFILE_PATH" ]; then
    if grep -q "GitLab Duo → Claude Code" "$PROFILE_PATH"; then
        echo "Shell profile already configured: $PROFILE_PATH"
    else
        echo "Configuring shell profile: $PROFILE_PATH"
        echo "$SNIPPET" >> "$PROFILE_PATH"
    fi
    echo ""
    echo "🎉 Setup complete! Restart your terminal or run this command to load the settings:"
    echo "   source $PROFILE_PATH"
    echo "Then type 'cg' anywhere to run Claude Code via GitLab Duo."
else
    echo "⚠️ Could not find a default shell profile (.zshrc or .bashrc)."
    echo "Please add the following snippet to your shell profile manually:"
    echo "$SNIPPET"
fi
