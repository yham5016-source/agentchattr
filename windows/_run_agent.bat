@echo off
REM agentchattr — run ONE agent wrapper in bypass/yolo mode (used by start_all.bat)
REM Usage: _run_agent.bat claude^|codex^|antigravity
REM Assumes the server is already up (start_all.bat checks that first).
setlocal
set "AGENT=%~1"
cd /d "%~dp0.."
call .venv\Scripts\activate.bat

set "FLAGS="
set "CLI=%AGENT%"
if /i "%AGENT%"=="claude" set "FLAGS=--dangerously-skip-permissions"
if /i "%AGENT%"=="codex"  set "FLAGS=--dangerously-bypass-approvals-and-sandbox"
if /i "%AGENT%"=="antigravity" (
    set "CLI=agy"
    set "FLAGS=--dangerously-skip-permissions"
    set AGY_CLI_DISABLE_AUTO_UPDATE=1
    if exist "%LOCALAPPDATA%\agy\bin\agy.exe" set "PATH=%LOCALAPPDATA%\agy\bin;%PATH%"
)
if "%FLAGS%"=="" (
    echo   Error: unknown agent "%AGENT%". Use claude, codex or antigravity.
    pause
    exit /b 1
)

where %CLI% >nul 2>&1
if %errorlevel% neq 0 (
    echo   Error: "%CLI%" was not found on PATH.
    pause
    exit /b 1
)

python wrapper.py %AGENT% -- %FLAGS%

REM Always pause so the tab never closes before you can read the error.
echo.
echo   [%AGENT%] wrapper exited with code %errorlevel%. Review the output above.
pause
