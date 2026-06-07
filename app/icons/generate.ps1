# Android 런처 아이콘 — iOS AppIcon(icon_1024.png) 과 동일 소스
Add-Type -AssemblyName System.Drawing

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path (Split-Path $scriptDir -Parent) -Parent
$resRoot = Join-Path $repoRoot 'app\src\main\res'
$iosIcon = Join-Path $repoRoot 'ios\MoimTalk\Assets.xcassets\AppIcon.appiconset\icon_1024.png'

if (-not (Test-Path $iosIcon)) {
    throw "iOS icon not found: $iosIcon"
}

function Resize-Png([System.Drawing.Image]$src, [int]$size, [string]$path) {
    $bmp = New-Object System.Drawing.Bitmap $size, $size
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.DrawImage($src, 0, 0, $size, $size)
    $g.Dispose()
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Host "Wrote $path ($size)"
}

$src = [System.Drawing.Image]::FromFile($iosIcon)
Write-Host "Source: $iosIcon ($($src.Width)x$($src.Height))"

# adaptive-icon foreground (108dp @ xxxhdpi)
Resize-Png $src 432 (Join-Path $resRoot 'drawable\ic_launcher_fg.png')

$mipmaps = @{
    'mipmap-mdpi'    = 48
    'mipmap-hdpi'    = 72
    'mipmap-xhdpi'   = 96
    'mipmap-xxhdpi'  = 144
    'mipmap-xxxhdpi' = 192
}

foreach ($folder in $mipmaps.Keys) {
    $size = $mipmaps[$folder]
    $dir = Join-Path $resRoot $folder
    Resize-Png $src $size (Join-Path $dir 'ic_launcher.png')
    Resize-Png $src $size (Join-Path $dir 'ic_launcher_round.png')
}

$src.Dispose()
Write-Host 'Done.'
