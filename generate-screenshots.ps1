Add-Type -AssemblyName System.Drawing

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$docsDir = Join-Path $scriptDir "docs"
if (-not (Test-Path $docsDir)) { New-Item -ItemType Directory -Path $docsDir | Out-Null }

# Colors matching the dark theme
$bgColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
$textColor = [System.Drawing.Color]::White
$dimColor = [System.Drawing.Color]::FromArgb(160, 160, 160)
$sepColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
$quitColor = [System.Drawing.Color]::FromArgb(180, 80, 80)
$hoverColor = [System.Drawing.Color]::FromArgb(55, 55, 58)
$accentColor = [System.Drawing.Color]::FromArgb(217, 119, 6)

$menuFont = New-Object System.Drawing.Font("Segoe UI", 12)
$headerFont = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Italic)
$smallFont = New-Object System.Drawing.Font("Segoe UI", 9)

function Draw-MenuMockup($filename, $items, $width, $hoverIndex) {
    # items: array of @{ text; type; color }
    # type: "header", "item", "separator", "quit"

    $rowHeight = 34
    $headerHeight = 28
    $sepHeight = 12
    $padding = 16

    # Calculate height
    $totalH = 8  # top padding
    foreach ($item in $items) {
        switch ($item.type) {
            "header"    { $totalH += $headerHeight }
            "separator" { $totalH += $sepHeight }
            default     { $totalH += $rowHeight }
        }
    }
    $totalH += 8  # bottom padding

    $bmp = New-Object System.Drawing.Bitmap($width, $totalH)
    $gfx = [System.Drawing.Graphics]::FromImage($bmp)
    $gfx.SmoothingMode = "AntiAlias"
    $gfx.TextRenderingHint = "ClearTypeGridFit"

    # Background with rounded feel
    $gfx.Clear($bgColor)

    # Border
    $borderPen = New-Object System.Drawing.Pen($sepColor, 1)
    $gfx.DrawRectangle($borderPen, 0, 0, $width - 1, $totalH - 1)

    $y = 8
    $idx = 0
    foreach ($item in $items) {
        switch ($item.type) {
            "header" {
                $brush = New-Object System.Drawing.SolidBrush($dimColor)
                $gfx.DrawString("  " + $item.text, $headerFont, $brush, $padding, $y + 4)
                $brush.Dispose()
                $y += $headerHeight
            }
            "separator" {
                $pen = New-Object System.Drawing.Pen($sepColor, 1)
                $gfx.DrawLine($pen, $padding, $y + $sepHeight/2, $width - $padding, $y + $sepHeight/2)
                $pen.Dispose()
                $y += $sepHeight
            }
            "quit" {
                if ($idx -eq $hoverIndex) {
                    $hBrush = New-Object System.Drawing.SolidBrush($hoverColor)
                    $gfx.FillRectangle($hBrush, 2, $y, $width - 4, $rowHeight)
                    $hBrush.Dispose()
                }
                $brush = New-Object System.Drawing.SolidBrush($quitColor)
                $gfx.DrawString($item.text, $menuFont, $brush, $padding, $y + 6)
                $brush.Dispose()
                $y += $rowHeight
            }
            default {
                if ($idx -eq $hoverIndex) {
                    $hBrush = New-Object System.Drawing.SolidBrush($hoverColor)
                    $gfx.FillRectangle($hBrush, 2, $y, $width - 4, $rowHeight)
                    $hBrush.Dispose()
                }
                $color = if ($item.color) { $item.color } else { $textColor }
                $brush = New-Object System.Drawing.SolidBrush($color)
                $gfx.DrawString($item.text, $menuFont, $brush, $padding, $y + 6)
                $brush.Dispose()

                # Draw arrow for submenu items
                if ($item.submenu) {
                    $arrowBrush = New-Object System.Drawing.SolidBrush($dimColor)
                    $gfx.DrawString([char]0x25B8, $smallFont, $arrowBrush, $width - 28, $y + 8)
                    $arrowBrush.Dispose()
                }
                $y += $rowHeight
            }
        }
        $idx++
    }

    $gfx.Dispose()
    $bmp.Save((Join-Path $docsDir $filename), [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Host "  Generated $filename"
}

# --- Screenshot 1: Basic menu ---
$menuItems = @(
    @{ text = "Launch Project"; type = "header" },
    @{ text = ""; type = "separator" },
    @{ text = "Weather Dashboard"; type = "item" },
    @{ text = "ML Pipeline"; type = "item" },
    @{ text = "React Frontend"; type = "item" },
    @{ text = "API Server"; type = "item" },
    @{ text = ""; type = "separator" },
    @{ text = "Quit"; type = "quit" }
)
Draw-MenuMockup "screenshot_menu.png" $menuItems 260 $null

# --- Screenshot 2: Menu with hover ---
Draw-MenuMockup "screenshot_hover.png" $menuItems 260 3

# --- Screenshot 3: Future - with submenus (session resume) ---
$menuItems2 = @(
    @{ text = "Launch Project"; type = "header" },
    @{ text = ""; type = "separator" },
    @{ text = "Weather Dashboard"; type = "item"; submenu = $true },
    @{ text = "ML Pipeline"; type = "item"; submenu = $true },
    @{ text = "React Frontend"; type = "item"; submenu = $true },
    @{ text = "API Server"; type = "item"; submenu = $true },
    @{ text = ""; type = "separator" },
    @{ text = "Quit"; type = "quit" }
)
Draw-MenuMockup "screenshot_submenu.png" $menuItems2 260 $null

# --- Screenshot 4: Tray area mockup ---
$trayW = 320
$trayH = 44
$trayBmp = New-Object System.Drawing.Bitmap($trayW, $trayH)
$gfx = [System.Drawing.Graphics]::FromImage($trayBmp)
$gfx.Clear([System.Drawing.Color]::FromArgb(28, 28, 28))

# Fake taskbar line at top
$linePen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(50, 50, 50), 1)
$gfx.DrawLine($linePen, 0, 0, $trayW, 0)

# System tray icons (fake)
$trayFont = New-Object System.Drawing.Font("Segoe UI", 9)
$trayBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(180, 180, 180))
$gfx.DrawString("^", $trayFont, $trayBrush, 8, 12)
$gfx.DrawString("Wi-Fi", $smallFont, $trayBrush, 40, 14)
$gfx.DrawString("Vol", $smallFont, $trayBrush, 90, 14)

# ClaudeDock rocket icon - load from variant_c.png and draw scaled
$rocketPath = Join-Path $docsDir "variant_c.png"
if (Test-Path $rocketPath) {
    $rocketImg = [System.Drawing.Image]::FromFile($rocketPath)
    $gfx.InterpolationMode = "NearestNeighbor"
    $gfx.DrawImage($rocketImg, 138, 8, 28, 28)
    $rocketImg.Dispose()
} else {
    # Fallback orange circle
    $iconBrush = New-Object System.Drawing.SolidBrush($accentColor)
    $gfx.FillEllipse($iconBrush, 140, 10, 24, 24)
}

# Time
$timeBrush = New-Object System.Drawing.SolidBrush($textColor)
$gfx.DrawString("2:45 PM", $trayFont, $timeBrush, 250, 8)
$gfx.DrawString("2/27/2026", $smallFont, $trayBrush, 248, 24)

$gfx.Dispose()
$trayBmp.Save((Join-Path $docsDir "screenshot_tray.png"), [System.Drawing.Imaging.ImageFormat]::Png)
$trayBmp.Dispose()
Write-Host "  Generated screenshot_tray.png"

Write-Host ""
Write-Host "All screenshots generated!"
