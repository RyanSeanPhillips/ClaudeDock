Add-Type -AssemblyName System.Drawing

# --- Pixel art rocket (16x16 grid, scaled to 64x64) ---
# Color key:
#   . = transparent
#   A = orange (body)
#   B = darker orange
#   C = white/light (window highlight)
#   E = window shade
#   D = dark (outline)
#   R = red/flame
#   Y = yellow/flame
#   F = grey (fins)
#   H = dark grey

$palette = @{
    '.' = [System.Drawing.Color]::Transparent
    'A' = [System.Drawing.Color]::FromArgb(218, 143, 78)   # claude orange
    'B' = [System.Drawing.Color]::FromArgb(190, 120, 60)   # darker orange
    'C' = [System.Drawing.Color]::FromArgb(220, 230, 240)  # window highlight
    'E' = [System.Drawing.Color]::FromArgb(160, 190, 220)  # window shade
    'D' = [System.Drawing.Color]::FromArgb(40, 40, 45)     # dark outline
    'R' = [System.Drawing.Color]::FromArgb(200, 70, 50)    # red flame
    'Y' = [System.Drawing.Color]::FromArgb(240, 190, 60)   # yellow flame
    'F' = [System.Drawing.Color]::FromArgb(100, 100, 110)  # grey fins
    'H' = [System.Drawing.Color]::FromArgb(75, 75, 85)     # dark grey
}

# 16x16 pixel art rocket
$pixels = @(
    '......DD........',
    '.....DADD.......',
    '.....DADD.......',
    '....DAAAAD......',
    '....DACEAD......',
    '....DACEAD......',
    '...DAAAAAAD.....',
    '...DAAAAAAD.....',
    '..DAAAAAAAD.....',
    '..DAAAAAAADH....',
    '.DAAAAAAAADHH...',
    '.DAAAAAAADH.H...',
    'HDAAAAAADH..H...',
    'HDAAAAADH.......',
    '.HDYRRYDHH......',
    '..HYR.YDH.......'
)

$scale = 4  # 16 * 4 = 64px
$size = 16 * $scale

$bmp = New-Object System.Drawing.Bitmap($size, $size)
$gfx = [System.Drawing.Graphics]::FromImage($bmp)
$gfx.Clear([System.Drawing.Color]::Transparent)

for ($y = 0; $y -lt $pixels.Count; $y++) {
    $row = $pixels[$y]
    for ($x = 0; $x -lt $row.Length; $x++) {
        $ch = $row[$x].ToString()
        if ($ch -ne '.') {
            $color = $palette[$ch]
            $brush = New-Object System.Drawing.SolidBrush($color)
            $gfx.FillRectangle($brush, $x * $scale, $y * $scale, $scale, $scale)
            $brush.Dispose()
        }
    }
}
$gfx.Dispose()

# Save as proper ICO
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$icoPath = Join-Path $scriptDir "ClaudeDock.ico"

# First save PNG to memory
$ms = New-Object System.IO.MemoryStream
$bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
$pngBytes = $ms.ToArray()
$ms.Close()

# Write ICO format
$icoStream = [System.IO.File]::Create($icoPath)
$writer = New-Object System.IO.BinaryWriter($icoStream)
$writer.Write([UInt16]0)      # reserved
$writer.Write([UInt16]1)      # type: icon
$writer.Write([UInt16]1)      # count: 1
$writer.Write([byte]64)       # width
$writer.Write([byte]64)       # height
$writer.Write([byte]0)        # color palette
$writer.Write([byte]0)        # reserved
$writer.Write([UInt16]1)      # color planes
$writer.Write([UInt16]32)     # bits per pixel
$writer.Write([UInt32]$pngBytes.Length)
$writer.Write([UInt32]22)     # offset
$writer.Write($pngBytes)
$writer.Close()
$icoStream.Close()

# Also save a PNG for the README
$pngPath = Join-Path $scriptDir "docs"
if (-not (Test-Path $pngPath)) { New-Item -ItemType Directory -Path $pngPath | Out-Null }
$bmp.Save((Join-Path $pngPath "icon.png"), [System.Drawing.Imaging.ImageFormat]::Png)

$bmp.Dispose()

Write-Host "Generated ClaudeDock.ico ($size x $size px)"
Write-Host "Generated docs/icon.png"
