@echo off
echo Removing ClaudeDock from Windows startup...
del "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\ClaudeDock.vbs" 2>nul
del "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\ClaudeLauncher.vbs" 2>nul
echo Done. ClaudeDock will no longer start on login.
pause
