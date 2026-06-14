#!/bin/bash

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROXY_SCRIPT="$SCRIPT_DIR/server.js"
CWD_FILE="$HOME/.cg-cwd.txt"

# Save current directory so the proxy knows the workspace context
pwd > "$CWD_FILE"

# Check if port 3456 is listening
if ! nc -z 127.0.0.1 3456 >/dev/null 2>&1 && ! lsof -i :3456 >/dev/null 2>&1; then
    echo "🚀 Starting GitLab Duo Proxy (Claude Opus 4.8)..."
    # Kill any orphaned node processes running the proxy server
    pkill -f "node.*server.js" >/dev/null 2>&1
    sleep 0.3
    # Start proxy in background silently
    node "$PROXY_SCRIPT" >/dev/null 2>&1 &
    
    # Wait up to 10 seconds for port 3456 to be ready
    waited=0
    while ! nc -z 127.0.0.1 3456 >/dev/null 2>&1 && [ $waited -lt 10 ]; do
        sleep 1
        ((waited++))
    done
    if nc -z 127.0.0.1 3456 >/dev/null 2>&1; then
        echo "✅ Proxy ready!"
    else
        echo "⚠️ Proxy starting in background..."
    fi
fi

# Set environment variables for the Claude Code session
export ANTHROPIC_BASE_URL="http://127.0.0.1:3456"
export ANTHROPIC_API_KEY="gitlab-proxy"

# Execute Claude Code with passed arguments
claude --model claude-opus-4-8 "$@"
