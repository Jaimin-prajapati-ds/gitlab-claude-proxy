@echo off
echo %CD% > "%USERPROFILE%\.cg-cwd.txt"
netstat -an | find "3456" | find "LISTENING" >nul 2>&1
if errorlevel 1 (
    echo Starting GitLab Duo Proxy...
    wscript //B "%~dp0start-hidden.vbs"
    timeout /t 3 /nobreak >nul
)
set ANTHROPIC_BASE_URL=http://localhost:3456
set ANTHROPIC_API_KEY=gitlab-proxy
claude --model claude-opus-4-8 %*
