@echo off
echo Installing Claude Launcher to Windows startup...
set "STARTUP=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"
set "SCRIPT_DIR=%~dp0"

(
echo Set WshShell = CreateObject^("WScript.Shell"^)
echo WshShell.Run "powershell -ExecutionPolicy Bypass -WindowStyle Hidden -File ""%SCRIPT_DIR%ClaudeLauncher.ps1""", 0, False
) > "%STARTUP%\ClaudeLauncher.vbs"

echo Done. Claude Launcher will start automatically on login.
echo.
echo To run now, double-click ClaudeLauncher.ps1 or restart your PC.
pause
