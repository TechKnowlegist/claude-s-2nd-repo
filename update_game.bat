@echo off
REM Double-click this file to pull the latest Rift Blade code.
REM It forces your local copy to exactly match GitHub, discarding any
REM local edits in this folder (safe, since you shouldn't be editing
REM these files directly).

cd /d "%~dp0"

echo Fetching latest code from GitHub...
git fetch origin
if errorlevel 1 goto :error

echo Resetting local files to match origin/claude/eloquent-thompson-c6twll...
git reset --hard origin/claude/eloquent-thompson-c6twll
if errorlevel 1 goto :error

echo.
echo Done. You are now on:
git log -1 --oneline
echo.
echo Close and reopen Godot, then press F5 to play the latest version.
echo.
pause
exit /b 0

:error
echo.
echo Something went wrong - scroll up to see the error above.
echo Make sure this file is sitting inside your claude-s-2nd-repo folder.
echo.
pause
exit /b 1
