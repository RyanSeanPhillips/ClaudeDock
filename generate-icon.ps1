Add-Type -AssemblyName System.Drawing

# Anthropic orange
$orange = [System.Drawing.Color]::FromArgb(217, 119, 6)
$darkOrange = [System.Drawing.Color]::FromArgb(180, 95, 10)
$yellow = [System.Drawing.Color]::FromArgb(255, 200, 40)
$red = [System.Drawing.Color]::FromArgb(200, 50, 20)
$darkRed = [System.Drawing.Color]::FromArgb(140, 30, 10)
$white = [System.Drawing.Color]::FromArgb(240, 240, 240)
$window = [System.Drawing.Color]::FromArgb(140, 180, 220)
$dark = [System.Drawing.Color]::FromArgb(40, 40, 45)
$trans = [System.Drawing.Color]::Transparent

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$docsDir = Join-Path $scriptDir "docs"
if (-not (Test-Path $docsDir)) { New-Item -ItemType Directory -Path $docsDir | Out-Null }

function Draw-Variant($name, $pixels, $palette, $pixelSize, $rotate) {
    $gridH = $pixels.Count
    $gridW = $pixels[0].Length
    $srcW = $gridW * $pixelSize
    $srcH = $gridH * $pixelSize

    $srcBmp = New-Object System.Drawing.Bitmap($srcW, $srcH)
    $gfx = [System.Drawing.Graphics]::FromImage($srcBmp)
    $gfx.Clear($trans)

    for ($y = 0; $y -lt $gridH; $y++) {
        $row = $pixels[$y]
        for ($x = 0; $x -lt $row.Length; $x++) {
            $ch = $row[$x].ToString()
            if ($ch -ne '.' -and $palette.ContainsKey($ch)) {
                $brush = New-Object System.Drawing.SolidBrush($palette[$ch])
                $gfx.FillRectangle($brush, $x * $pixelSize, $y * $pixelSize, $pixelSize, $pixelSize)
                $brush.Dispose()
            }
        }
    }
    $gfx.Dispose()

    # Save upright
    $srcBmp.Save((Join-Path $docsDir "${name}_upright.png"), [System.Drawing.Imaging.ImageFormat]::Png)

    if ($rotate) {
        $finalSize = 64
        $finalBmp = New-Object System.Drawing.Bitmap($finalSize, $finalSize)
        $gfx2 = [System.Drawing.Graphics]::FromImage($finalBmp)
        $gfx2.Clear($trans)
        $gfx2.InterpolationMode = "NearestNeighbor"
        $gfx2.PixelOffsetMode = "Half"
        $cx = $finalSize / 2.0
        $cy = $finalSize / 2.0
        $gfx2.TranslateTransform($cx, $cy)
        $gfx2.RotateTransform(45)
        $gfx2.TranslateTransform(-$cx, -$cy)
        $ox = ($finalSize - $srcW) / 2.0
        $oy = ($finalSize - $srcH) / 2.0
        $gfx2.DrawImage($srcBmp, [float]$ox, [float]$oy, [float]$srcW, [float]$srcH)
        $gfx2.Dispose()
        $finalBmp.Save((Join-Path $docsDir "${name}.png"), [System.Drawing.Imaging.ImageFormat]::Png)
        $finalBmp.Dispose()
    }

    $srcBmp.Dispose()
    Write-Host "  Generated $name"
}

# ============================================================
# VARIANT A: Minimal - thin body, triangle nose, square fins
# ============================================================
$palA = @{
    'O' = $orange; 'Y' = $yellow; 'R' = $red; 'D' = $darkRed
}
$vA = @(
    '..O..',
    '.OOO.',
    '..O..',
    '..O..',
    '..O..',
    '..O..',
    '..O..',
    '..O..',
    '.OOO.',
    'O.O.O',
    '..Y..',
    '.YOY.',
    '..R..',
    '..D..'
)
Draw-Variant "variant_a" $vA $palA 5 $true

# ============================================================
# VARIANT B: Chunky - 2px wide body, blocky nose, square fins
# ============================================================
$palB = @{
    'O' = $orange; 'Y' = $yellow; 'R' = $red; 'D' = $darkRed; 'W' = $window
}
$vB = @(
    '...OO...',
    '..OOOO..',
    '..OOOO..',
    '..OOOO..',
    '..OWOO..',
    '..OOOO..',
    '..OOOO..',
    '..OOOO..',
    '.OOOOOO.',
    'OO.OO.OO',
    '...YY...',
    '..YOOY..',
    '...RR...',
    '...DD...'
)
Draw-Variant "variant_b" $vB $palB 5 $true

# ============================================================
# VARIANT C: Classic - pointed nose, straight body, angled fins
# ============================================================
$palC = @{
    'O' = $orange; 'Y' = $yellow; 'R' = $red; 'D' = $darkRed; 'W' = $window
}
$vC = @(
    '...O...',
    '..OOO..',
    '..OOO..',
    '..OOO..',
    '..OWO..',
    '..OOO..',
    '..OOO..',
    '..OOO..',
    '.OOOOO.',
    'O.OOO.O',
    '..OOO..',
    '...Y...',
    '..YOY..',
    '..ROR..',
    '...D...'
)
Draw-Variant "variant_c" $vC $palC 4 $true

# ============================================================
# VARIANT D: Bold - wide body, big fins, big flames
# ============================================================
$palD = @{
    'O' = $orange; 'Y' = $yellow; 'R' = $red; 'D' = $darkRed; 'W' = $window
}
$vD = @(
    '....OO....',
    '...OOOO...',
    '..OOOOOO..',
    '..OOOOOO..',
    '..OOWWOO..',
    '..OOOOOO..',
    '..OOOOOO..',
    '..OOOOOO..',
    '.OOOOOOOO.',
    'OO.OOOO.OO',
    'O..OOOO..O',
    '...YYYY...',
    '..YOOOY...',
    '...ROOR...',
    '....RR....',
    '....DD....'
)
Draw-Variant "variant_d" $vD $palD 4 $true

# ============================================================
# VARIANT E: Retro arcade - very blocky, big pixels
# ============================================================
$palE = @{
    'O' = $orange; 'Y' = $yellow; 'R' = $red; 'D' = $darkRed
}
$vE = @(
    '.OO.',
    'OOOO',
    'OOOO',
    'OOOO',
    'OOOO',
    'OOOO',
    'OOOO',
    'OOOO',
    '.YY.',
    'YOOY',
    '.RR.',
    '.DD.'
)
Draw-Variant "variant_e" $vE $palE 6 $true

# ============================================================
# VARIANT F: Sleek - narrow, tall, minimal fins
# ============================================================
$palF = @{
    'O' = $orange; 'Y' = $yellow; 'R' = $red; 'D' = $darkRed; 'W' = $window
}
$vF = @(
    '..O..',
    '.OOO.',
    '.OOO.',
    '.OOO.',
    '.OWO.',
    '.OOO.',
    '.OOO.',
    '.OOO.',
    '.OOO.',
    '.OOO.',
    'OOOOO',
    '..Y..',
    '.YOY.',
    '.ROR.',
    '..R..',
    '..D..'
)
Draw-Variant "variant_f" $vF $palF 4 $true

Write-Host ""
Write-Host "All variants generated in docs/ folder"
Write-Host "Open the docs folder to compare them all"
