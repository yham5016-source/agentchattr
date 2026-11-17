@echo off
REM agentchattr — one-click: server + agents (bypass/yolo) in Windows Terminal tabs
REM Edit AGENTS to change which agents start. Already-running agents are skipped.
setlocal EnableDelayedExpansion
set "AGENTS=claude codex antigravity"
set "WAIT_SECONDS=60"

cd /d "%~dp0.."

REM Auto-create venv once here so agent tabs don't race to create it
if not exist ".venv" (
    python -m venv .venv
    .venv\Scripts\pip install -q -r requirements.txt >nul 2>nul
)
call .venv\Scripts\activate.bat

REM Start server if the web port isn't answering yet
python -c "import socket; socket.create_connection(('127.0.0.1', 8300), 1)" >nul 2>&1
if %errorlevel% neq 0 (
    start "agentchattr server" /min cmd /k "python run.py"
)

REM Wait for web (8300) AND MCP HTTP (8200), with a time limit
set /a WAITED=0
:wait_server
python -c "import socket; socket.create_connection(('127.0.0.1', 8300), 1); socket.create_connection(('127.0.0.1', 8200), 1)" >nul 2>&1
if %errorlevel% neq 0 (
    if !WAITED! geq %WAIT_SECONDS% (
        echo.
        echo   Error: server not ready on 8300/8200 after %WAIT_SECONDS%s.
        echo   Check the "agentchattr server" window for the error.
        pause
        exit /b 1
    )
    timeout /t 1 /nobreak >nul
    set /a WAITED+=1
    goto :wait_server
)

REM Pick agents that aren't already running (match "wrapper.py <agent>" in python processes)
set "TODO="
for %%A in (%AGENTS%) do (
    powershell -NoProfile -Command "if (Get-CimInstance Win32_Process -Filter \"Name='python.exe'\" | Where-Object { $_.CommandLine -match 'wrapper\.py\s+%%A(\s|$)' }) { exit 0 } else { exit 1 }"
    if !errorlevel! equ 0 (
        echo   %%A already running - skipped.
    ) else (
        set "TODO=!TODO! %%A"
    )
)
if "!TODO!"=="" (
    echo   All agents already running.
    goto :open_ui
)

REM One Windows Terminal window with a tab per agent; fall back to separate windows
where wt >nul 2>&1
if %errorlevel% equ 0 (
    set "WTARGS="
    for %%A in (!TODO!) do (
        if defined WTARGS set "WTARGS=!WTARGS! ;"
        set "WTARGS=!WTARGS! new-tab --title %%A cmd /c call "%~dp0_run_agent.bat" %%A"
    )
    start "" wt -w agentchattr !WTARGS!
) else (
    for %%A in (!TODO!) do start "agentchattr %%A" cmd /c call "%~dp0_run_agent.bat" %%A
)

:open_ui
REM Open chat UI as an app-style window if Edge is installed, else default browser
set "EDGE=%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe"
if not exist "%EDGE%" set "EDGE=%ProgramFiles%\Microsoft\Edge\Application\msedge.exe"
if exist "%EDGE%" (
    start "" "%EDGE%" --app=http://127.0.0.1:8300
) else (
    start "" http://127.0.0.1:8300
)
