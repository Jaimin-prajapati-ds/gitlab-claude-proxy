# setup.ps1 - Automated Setup Script for Windows
# Configures GitLab Duo -> Claude Code Proxy on your system

$proxyDir = $PSScriptRoot
if (-not $proxyDir) {
    $proxyDir = Get-Location
}

Write-Host "=============================================" -ForegroundColor Green
Write-Host " GitLab Duo to Claude Code Proxy Installer   " -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green
Write-Host ""

# 1. Check for Node.js
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Node.js is not installed or not in PATH." -ForegroundColor Red
    Write-Host "Please install Node.js from https://nodejs.org/ before running this setup."
    Exit 1
}
Write-Host "✅ Node.js detected." -ForegroundColor Green

# 2. Check for glab CLI
if (-not (Get-Command glab -ErrorAction SilentlyContinue)) {
    Write-Host "⚠️ GitLab CLI (glab) not detected." -ForegroundColor Yellow
    Write-Host "Please install it by running: winget install GitLab.GLAB"
    Write-Host "Then run 'glab auth login' to authenticate."
    Write-Host ""
} else {
    Write-Host "✅ GitLab CLI (glab) detected." -ForegroundColor Green
}

# 3. Configure Claude Code settings (~/.claude/settings.json)
$claudeDir = Join-Path $HOME ".claude"
if (-not (Test-Path $claudeDir)) {
    New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null
}
$settingsPath = Join-Path $claudeDir "settings.json"

$settingsObj = @{
    "env" = @{
        "ANTHROPIC_BASE_URL" = "http://127.0.0.1:3456"
        "ANTHROPIC_API_KEY" = "gitlab-proxy"
        "ANTHROPIC_AUTH_TOKEN" = "gitlab-proxy"
        "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC" = "1"
        "MAX_THINKING_TOKENS" = 8192
    }
    "permissions" = @{
        "allow" = @()
        "deny" = @()
    }
    "model" = "claude-opus-4-8"
    "effortLevel" = "xhigh"
}

if (Test-Path $settingsPath) {
    Write-Host "Updating existing ~/.claude/settings.json..." -ForegroundColor Cyan
    try {
        $existingSettings = Get-Content $settingsPath -Raw | ConvertFrom-Json
        if (-not $existingSettings.env) { 
            $existingSettings | Add-Member -MemberType NoteProperty -Name "env" -Value @{} 
        }
        $existingSettings.env.ANTHROPIC_BASE_URL = "http://127.0.0.1:3456"
        $existingSettings.env.ANTHROPIC_API_KEY = "gitlab-proxy"
        $existingSettings.env.ANTHROPIC_AUTH_TOKEN = "gitlab-proxy"
        $existingSettings.env.CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1"
        $existingSettings.env.MAX_THINKING_TOKENS = 8192
        $existingSettings.model = "claude-opus-4-8"
        $existingSettings | ConvertTo-Json -Depth 10 | Out-File $settingsPath -Encoding utf8
    } catch {
        Write-Host "⚠️ Error parsing settings.json, overwriting..." -ForegroundColor Yellow
        $settingsObj | ConvertTo-Json -Depth 10 | Out-File $settingsPath -Encoding utf8
    }
} else {
    Write-Host "Creating ~/.claude/settings.json..." -ForegroundColor Cyan
    $settingsObj | ConvertTo-Json -Depth 10 | Out-File $settingsPath -Encoding utf8
}
Write-Host "✅ Claude Code settings updated successfully." -ForegroundColor Green

# 4. Update PowerShell Profiles
$profilePaths = @(
    $PROFILE,
    (Join-Path (Split-Path $PROFILE) "Microsoft.PowerShell_profile.ps1"), # Windows PowerShell
    (Join-Path $HOME "Documents\PowerShell\Microsoft.PowerShell_profile.ps1"), # PowerShell 7/Core default documents path
    (Join-Path $HOME "OneDrive\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"),
    (Join-Path $HOME "OneDrive\Dokumen\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"),
    (Join-Path $HOME "OneDrive\Dokumen\PowerShell\Microsoft.PowerShell_profile.ps1")
) | Select-Object -Unique

$profileSnippet = @"

# --- GitLab Duo → Claude Code (Opus 4.8) Proxy Setup -------------------------
`$env:ANTHROPIC_BASE_URL = "http://127.0.0.1:3456"
`$env:ANTHROPIC_API_KEY  = "gitlab-proxy"
`$PROXY_SCRIPT = "$proxyDir\server.js"

function cg {
    `$PWD.Path | Out-File "`$HOME/.cg-cwd.txt" -Encoding utf8 -NoNewline

    `$proxyUp = Get-NetTCPConnection -LocalPort 3456 -ErrorAction SilentlyContinue
    if (-not `$proxyUp) {
        Write-Host "🚀 Starting GitLab Duo Proxy (Claude Opus 4.8)..." -ForegroundColor Cyan
        Get-Process node -ErrorAction SilentlyContinue |
            Where-Object { `$_.MainWindowTitle -eq '' } |
            Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 300
        Start-Process -FilePath "node" -ArgumentList "`"`$PROXY_SCRIPT`"" -WindowStyle Hidden
        `$waited = 0
        while (-not (Get-NetTCPConnection -LocalPort 3456 -ErrorAction SilentlyContinue) -and `$waited -lt 12) {
            Start-Sleep -Seconds 1; `$waited++
        }
        if (Get-NetTCPConnection -LocalPort 3456 -ErrorAction SilentlyContinue) {
            Write-Host "✅ Proxy ready!" -ForegroundColor Green
        } else {
            Write-Host "⚠️ Proxy starting in background..." -ForegroundColor Yellow
        }
    }

    `$env:ANTHROPIC_BASE_URL = "http://127.0.0.1:3456"
    `$env:ANTHROPIC_API_KEY  = "gitlab-proxy"
    & claude --model claude-opus-4-8 @args
}

function stop-proxy {
    Get-Process node -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Write-Host "🛑 Proxy stopped" -ForegroundColor Red
}

function restart-proxy {
    stop-proxy
    Start-Sleep -Milliseconds 500
    Start-Process -FilePath "node" -ArgumentList "`"`$PROXY_SCRIPT`"" -WindowStyle Hidden
    Write-Host "🔄 Proxy restarting..." -ForegroundColor Cyan
}
# -----------------------------------------------------------------------------
"@

$addedToAny = $false
foreach ($path in $profilePaths) {
    if (-not $path) { continue }
    
    # Determine if profile file exists, if not, check if parent folder exists
    $parentDir = Split-Path $path
    if (-not (Test-Path $parentDir)) {
        continue
    }
    
    # Read existing content if profile exists
    $exists = Test-Path $path
    $content = ""
    if ($exists) {
        $content = Get-Content $path -Raw
    }

    if ($content -like "*GitLab Duo → Claude Code (Opus 4.8) Proxy Setup*") {
        Write-Host "PowerShell Profile already configured: $path" -ForegroundColor Yellow
        $addedToAny = $true
        continue
    }

    Write-Host "Configuring PowerShell profile: $path" -ForegroundColor Cyan
    if (-not $exists) {
        New-Item -ItemType File -Path $path -Force | Out-Null
    }
    Add-Content -Path $path -Value $profileSnippet
    $addedToAny = $true
}

if ($addedToAny) {
    Write-Host ""
    Write-Host "🎉 Setup complete! Restart your PowerShell or run this command to load the settings:" -ForegroundColor Green
    Write-Host "   . `$PROFILE" -ForegroundColor Cyan
    Write-Host "Then type 'cg' anywhere to run Claude Code via GitLab Duo." -ForegroundColor Cyan
} else {
    Write-Host "⚠️ Could not find a default PowerShell profile directory. Please add the following snippet to your `$PROFILE manually:" -ForegroundColor Yellow
    Write-Host $profileSnippet -ForegroundColor DarkCyan
}
