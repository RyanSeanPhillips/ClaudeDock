$ErrorActionPreference = "Stop"
$logFile = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "debug.log"
try {

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
        "ClaudeDock", "OK", "Error")
    exit 1
}

$config = Get-Content $configPath -Raw | ConvertFrom-Json
$projects = $config.projects
$launchOpts = $config.launch

# --- Load icon ---
$icoPath = Join-Path $scriptDir "ClaudeDock.ico"
if (Test-Path $icoPath) {
    $icon = New-Object System.Drawing.Icon($icoPath)
} else {
    # Fallback: generate simple icon if .ico missing
    $bmp = New-Object System.Drawing.Bitmap(64, 64)
    $gfx = [System.Drawing.Graphics]::FromImage($bmp)
    $gfx.SmoothingMode = "AntiAlias"
    $gfx.Clear([System.Drawing.Color]::Transparent)
    $bgBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(217, 119, 6))
    $gfx.FillEllipse($bgBrush, 2, 2, 60, 60)
    $font = New-Object System.Drawing.Font("Consolas", 20, [System.Drawing.FontStyle]::Bold)
    $textBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(30, 30, 30))
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = "Center"
    $sf.LineAlignment = "Center"
    $gfx.DrawString("CD", $font, $textBrush, (New-Object System.Drawing.RectangleF(0, 0, 64, 64)), $sf)
    $gfx.Dispose()
    $hIcon = $bmp.GetHicon()
    $icon = [System.Drawing.Icon]::FromHandle($hIcon)
}

# --- Claude sessions directory ---
$claudeProjectsDir = Join-Path $env:USERPROFILE ".claude\projects"

function Get-ProjectSlug($path) {
    # Convert project path to Claude's directory slug format
    $slug = $path -replace ':', ''
    $slug = $slug -replace '\\', '-'
    $slug = $slug -replace '/', '-'
    $slug = $slug -replace ' ', '-'
    return $slug
}

function Get-RecentSessions($projectPath, $maxSessions) {
    $slug = Get-ProjectSlug $projectPath
    $sessionDir = Join-Path $claudeProjectsDir $slug
    $sessions = @()

    if (Test-Path $sessionDir) {
        $jsonlFiles = Get-ChildItem -Path $sessionDir -Filter "*.jsonl" -File |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First $maxSessions

        foreach ($file in $jsonlFiles) {
            $sessionId = $file.BaseName
            $modified = $file.LastWriteTime

            # Try to get first user message for context
            $summary = ""
            try {
                $lines = Get-Content $file.FullName -TotalCount 10 -ErrorAction SilentlyContinue
                foreach ($line in $lines) {
                    if ($line -match '"type":"user"' -and $line -match '"role":"user"') {
                        # Extract a snippet of the user message
                        if ($line -match '"content":"([^"]{1,80})') {
                            $summary = $Matches[1]
                            # Clean up escape sequences
                            $summary = $summary -replace '\\n', ' '
                            $summary = $summary -replace '\\t', ' '
                            if ($summary.Length -gt 50) {
                                $summary = $summary.Substring(0, 47) + "..."
                            }
                        }
                        break
                    }
                }
            } catch { }

            if (-not $summary) {
                $summary = $modified.ToString("MMM d, h:mm tt")
            }

            $sessions += @{
                Id = $sessionId
                Modified = $modified
                Summary = $summary
                DateLabel = $modified.ToString("MMM d")
            }
        }
    }
    return $sessions
}

function Get-GitStatus($projectPath) {
    # Returns git status string like "(main ✓)" or "(main ↑2 ●3)"
    try {
        $gitDir = Join-Path $projectPath ".git"
        if (-not (Test-Path $gitDir)) { return "" }

        $branch = & git -C $projectPath rev-parse --abbrev-ref HEAD 2>$null
        if (-not $branch) { return "" }

        # Uncommitted changes
        $statusOutput = & git -C $projectPath status --porcelain 2>$null
        $dirty = 0
        if ($statusOutput) {
            $dirty = ($statusOutput | Measure-Object).Count
        }

        # Unpushed commits
        $unpushed = 0
        $upstream = & git -C $projectPath rev-parse --abbrev-ref "@{upstream}" 2>$null
        if ($upstream) {
            $unpushedOutput = & git -C $projectPath rev-list "$upstream..HEAD" 2>$null
            if ($unpushedOutput) {
                $unpushed = ($unpushedOutput | Measure-Object).Count
            }
        }

        $upArrow = [char]0x2191
        $bullet = [char]0x25CF
        $check = [char]0x2713
        $status = "($branch"
        if ($unpushed -gt 0) { $status += " $upArrow$unpushed" }
        if ($dirty -gt 0) { $status += " $bullet$dirty" }
        if ($unpushed -eq 0 -and $dirty -eq 0) { $status += " $check" }
        $status += ")"

        return $status
    } catch {
        return ""
    }
}

# --- Launch functions ---
function Open-Explorer($path) {
    Start-Process explorer.exe -ArgumentList "/n,`"$path`""
}

function Open-VSCode($path) {
    Start-Process cmd -ArgumentList ("/c code --new-window `"$path`"") -WindowStyle Hidden
}

function Launch-Project($path) {
    if ($launchOpts.explorer) { Open-Explorer $path }
    if ($launchOpts.vscode)   { Open-VSCode $path }
    if ($launchOpts.claude) {
        Start-Process cmd -ArgumentList ("/k cd /d `"$path`" `&`& claude")
    }
}

function Launch-ProjectContinue($path) {
    if ($launchOpts.explorer) { Open-Explorer $path }
    if ($launchOpts.vscode)   { Open-VSCode $path }
    Start-Process cmd -ArgumentList ("/k cd /d `"$path`" `&`& claude --continue")
}

function Launch-ProjectResume($path, $sessionId) {
    if ($launchOpts.explorer) { Open-Explorer $path }
    if ($launchOpts.vscode)   { Open-VSCode $path }
    Start-Process cmd -ArgumentList ("/k cd /d `"$path`" `&`& claude --resume $sessionId")
}

# --- Build context menu dynamically on each open ---
function Build-Menu() {
    $contextMenu = New-Object System.Windows.Forms.ContextMenuStrip
    $contextMenu.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
    $contextMenu.ForeColor = [System.Drawing.Color]::White
    $contextMenu.ShowImageMargin = $false
    $contextMenu.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $contextMenu.Renderer = New-Object System.Windows.Forms.ToolStripProfessionalRenderer(
        (New-Object System.Windows.Forms.ProfessionalColorTable)
    )

    # Header
    $header = New-Object System.Windows.Forms.ToolStripLabel("  ClaudeDock")
    $header.ForeColor = [System.Drawing.Color]::FromArgb(160, 160, 160)
    $header.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Italic)
    $contextMenu.Items.Add($header) | Out-Null
    $contextMenu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null

    foreach ($proj in $projects) {
        $projPath = $proj.path
        $projName = $proj.name

        # Get git status
        $gitStatus = Get-GitStatus $projPath
        $displayName = if ($gitStatus) { "$projName  $gitStatus" } else { $projName }

        # Create project submenu
        $projItem = New-Object System.Windows.Forms.ToolStripMenuItem($displayName)
        $projItem.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
        $projItem.ForeColor = [System.Drawing.Color]::White

        # Color the git status portion
        if ($gitStatus -match ([char]0x2713)) {
            # all clean - no special color needed
        } elseif ($gitStatus -match ([char]0x25CF) -or $gitStatus -match ([char]0x2191)) {
            $projItem.ForeColor = [System.Drawing.Color]::FromArgb(255, 200, 80)
        }

        # --- Submenu items ---

        # New Session
        $newItem = New-Object System.Windows.Forms.ToolStripMenuItem("New Session")
        $newItem.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 43)
        $newItem.ForeColor = [System.Drawing.Color]::White
        $newItem.Tag = $projPath
        $newItem.Add_Click({
            param($sender, $e)
            Launch-Project $sender.Tag
        })
        $projItem.DropDownItems.Add($newItem) | Out-Null

        # Continue Last
        $contItem = New-Object System.Windows.Forms.ToolStripMenuItem("Continue Last")
        $contItem.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 43)
        $contItem.ForeColor = [System.Drawing.Color]::FromArgb(140, 200, 255)
        $contItem.Tag = $projPath
        $contItem.Add_Click({
            param($sender, $e)
            Launch-ProjectContinue $sender.Tag
        })
        $projItem.DropDownItems.Add($contItem) | Out-Null

        # Separator before recent sessions
        $projItem.DropDownItems.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null

        # Recent sessions
        $sessions = Get-RecentSessions $projPath 5
        if ($sessions.Count -gt 0) {
            $recentLabel = New-Object System.Windows.Forms.ToolStripLabel("  Recent Sessions")
            $recentLabel.ForeColor = [System.Drawing.Color]::FromArgb(120, 120, 120)
            $recentLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Italic)
            $projItem.DropDownItems.Add($recentLabel) | Out-Null

            foreach ($session in $sessions) {
                $label = "$($session.DateLabel) - $($session.Summary)"
                $sessItem = New-Object System.Windows.Forms.ToolStripMenuItem($label)
                $sessItem.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 43)
                $sessItem.ForeColor = [System.Drawing.Color]::FromArgb(180, 180, 180)
                $sessItem.Font = New-Object System.Drawing.Font("Segoe UI", 9)
                $sessItem.Tag = @{ Path = $projPath; SessionId = $session.Id }
                $sessItem.Add_Click({
                    param($sender, $e)
                    $info = $sender.Tag
                    Launch-ProjectResume $info.Path $info.SessionId
                })
                $projItem.DropDownItems.Add($sessItem) | Out-Null
            }
        } else {
            $noSess = New-Object System.Windows.Forms.ToolStripLabel("  No recent sessions")
            $noSess.ForeColor = [System.Drawing.Color]::FromArgb(100, 100, 100)
            $noSess.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Italic)
            $projItem.DropDownItems.Add($noSess) | Out-Null
        }

        # Style submenu
        $projItem.DropDown.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 43)

        $contextMenu.Items.Add($projItem) | Out-Null
    }

    # Separator + Quit
    $contextMenu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null

    $quit = New-Object System.Windows.Forms.ToolStripMenuItem("Quit")
    $quit.ForeColor = [System.Drawing.Color]::FromArgb(180, 80, 80)
    $quit.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
    $quit.Add_Click({
        $notifyIcon.Visible = $false
        $notifyIcon.Dispose()
        [System.Windows.Forms.Application]::Exit()
    })
    $contextMenu.Items.Add($quit) | Out-Null

    # Style separators
    foreach ($item in $contextMenu.Items) {
        if ($item -is [System.Windows.Forms.ToolStripSeparator]) {
            $item.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
            $item.ForeColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
        }
    }

    return $contextMenu
}

# --- System tray icon ---
$notifyIcon = New-Object System.Windows.Forms.NotifyIcon
$notifyIcon.Icon = $icon
$notifyIcon.Text = "ClaudeDock"
$notifyIcon.Visible = $true

# Build menu fresh on each click (so git status and sessions are current)
$notifyIcon.Add_MouseClick({
    param($sender, $e)
    $menu = Build-Menu
    $notifyIcon.ContextMenuStrip = $menu
    if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left -or
        $e.Button -eq [System.Windows.Forms.MouseButtons]::Right) {
        # Use reflection to invoke the private ShowContextMenu method
        $mi = $notifyIcon.GetType().GetMethod("ShowContextMenu",
            [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic)
        $mi.Invoke($notifyIcon, $null)
    }
})

$appContext = New-Object System.Windows.Forms.ApplicationContext
[System.Windows.Forms.Application]::Run($appContext)

} catch {
    $_ | Out-File $logFile -Append
    $_.ScriptStackTrace | Out-File $logFile -Append
}
