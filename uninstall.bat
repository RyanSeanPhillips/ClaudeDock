@echo off
echo Removing Claude Launcher from Windows startup...
del "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\ClaudeLauncher.vbs" 2>nul
echo Done. Claude Launcher will no longer start on login.
pause
