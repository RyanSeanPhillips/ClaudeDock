Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Win32 API for virtual desktop window management ---
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class VDesktop {
    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();
}
"@

# --- Load config ---
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$configPath = Join-Path $scriptDir "config.json"

if (-not (Test-Path $configPath)) {
    [System.Windows.Forms.MessageBox]::Show(
        "config.json not found in:`n$scriptDir`n`nCreate a config.json with your projects.",
        "Claude Launcher", "OK", "Error")
    exit 1
}

$config = Get-Content $configPath -Raw | ConvertFrom-Json
$projects = $config.projects
$launchOpts = $config.launch

# Parse icon color from hex
$hexColor = $config.icon_color.TrimStart('#')
$r = [Convert]::ToInt32($hexColor.Substring(0,2), 16)
$g_val = [Convert]::ToInt32($hexColor.Substring(2,2), 16)
$b = [Convert]::ToInt32($hexColor.Substring(4,2), 16)
$iconColor = [System.Drawing.Color]::FromArgb($r, $g_val, $b)

# --- Generate icon ---
$bmp = New-Object System.Drawing.Bitmap(64, 64)
$gfx = [System.Drawing.Graphics]::FromImage($bmp)
$gfx.SmoothingMode = "AntiAlias"
$gfx.TextRenderingHint = "AntiAliasGridFit"
$gfx.Clear([System.Drawing.Color]::Transparent)

$bgBrush = New-Object System.Drawing.SolidBrush($iconColor)
$gfx.FillEllipse($bgBrush, 2, 2, 60, 60)

$font = New-Object System.Drawing.Font("Consolas", 20, [System.Drawing.FontStyle]::Bold)
$textBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(30, 30, 30))
$sf = New-Object System.Drawing.StringFormat
$sf.Alignment = "Center"
$sf.LineAlignment = "Center"
$gfx.DrawString("C>", $font, $textBrush, (New-Object System.Drawing.RectangleF(0, -2, 64, 52)), $sf)

$arrowPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(30, 30, 30), 3)
$arrowPen.StartCap = "Round"
$arrowPen.EndCap = "Round"
$gfx.DrawLine($arrowPen, 32, 58, 32, 46)
$gfx.DrawLine($arrowPen, 26, 52, 32, 46)
$gfx.DrawLine($arrowPen, 38, 52, 32, 46)
$gfx.Dispose()

$hIcon = $bmp.GetHicon()
$icon = [System.Drawing.Icon]::FromHandle($hIcon)

# --- Launch function ---
function Launch-Project($path) {
    # Open a new Explorer window (not reusing existing)
    if ($launchOpts.explorer) {
        Start-Process explorer.exe "/n,`"$path`""
    }
    # VS Code: --new-window forces a new window on the current desktop
    # Launch via cmd /c with hidden window to avoid extra cmd flash (code is a .cmd file)
    if ($launchOpts.vscode) {
        Start-Process cmd "/c code --new-window `"$path`"" -WindowStyle Hidden
    }
    # cmd always opens a new window on current desktop
    if ($launchOpts.claude) {
        Start-Process cmd "/k cd /d `"$path`" && claude"
    }
}

# --- Context menu ---
$contextMenu = New-Object System.Windows.Forms.ContextMenuStrip
$contextMenu.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
$contextMenu.ForeColor = [System.Drawing.Color]::White
$contextMenu.ShowImageMargin = $false
$contextMenu.Font = New-Object System.Drawing.Font("Segoe UI", 10)

$header = New-Object System.Windows.Forms.ToolStripLabel("  Launch Project")
$header.ForeColor = [System.Drawing.Color]::FromArgb(160, 160, 160)
$header.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Italic)
$contextMenu.Items.Add($header)
$contextMenu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))

foreach ($proj in $projects) {
    $item = New-Object System.Windows.Forms.ToolStripMenuItem($proj.name)
    $item.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
    $item.ForeColor = [System.Drawing.Color]::White
    $item.Tag = $proj.path
    $item.Add_Click({
        param($sender, $e)
        Launch-Project $sender.Tag
    })
    $contextMenu.Items.Add($item)
}

$contextMenu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))

$quit = New-Object System.Windows.Forms.ToolStripMenuItem("Quit")
$quit.ForeColor = [System.Drawing.Color]::FromArgb(180, 80, 80)
$quit.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
$quit.Add_Click({
    $notifyIcon.Visible = $false
    $notifyIcon.Dispose()
    [System.Windows.Forms.Application]::Exit()
})
$contextMenu.Items.Add($quit)

foreach ($item in $contextMenu.Items) {
    if ($item -is [System.Windows.Forms.ToolStripSeparator]) {
        $item.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
        $item.ForeColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    }
}

# --- System tray icon ---
$notifyIcon = New-Object System.Windows.Forms.NotifyIcon
$notifyIcon.Icon = $icon
$notifyIcon.Text = "ClaudeDock"
$notifyIcon.Visible = $true
$notifyIcon.ContextMenuStrip = $contextMenu

$notifyIcon.Add_Click({
    if ($_.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
        $notifyIcon.ContextMenuStrip.Show([System.Windows.Forms.Cursor]::Position)
    }
})

$appContext = New-Object System.Windows.Forms.ApplicationContext
[System.Windows.Forms.Application]::Run($appContext)
