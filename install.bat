@echo off
echo Installing ClaudeDock to Windows startup...
set "STARTUP=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"
set "SCRIPT_DIR=%~dp0"

(
echo Set WshShell = CreateObject^("WScript.Shell"^)
echo WshShell.Run "powershell -ExecutionPolicy Bypass -WindowStyle Hidden -File ""%SCRIPT_DIR%ClaudeDock.ps1""", 0, False
) > "%STARTUP%\ClaudeDock.vbs"

echo Done. ClaudeDock will start automatically on login.
echo.
echo To run now, double-click ClaudeDock.ps1 or restart your PC.
pause
