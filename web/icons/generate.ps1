# 아주 정신 웹 아이콘 — iOS AppIcon(icon_1024.png) 과 동일 소스에서 리사이즈
Add-Type -AssemblyName System.Drawing

$outDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path (Split-Path $outDir -Parent) -Parent
$iosIcon = Join-Path $repoRoot 'ios\MoimTalk\Assets.xcassets\AppIcon.appiconset\icon_1024.png'
$androidLogo = Join-Path $repoRoot 'app\src\main\res\drawable\aumc_psy_logo.png'

$srcPath = if (Test-Path $iosIcon) { $iosIcon }
           elseif (Test-Path $androidLogo) { $androidLogo }
           else { throw "iOS icon not found: $iosIcon (or $androidLogo)" }

function Resize-IconBitmap([System.Drawing.Image]$src, [int]$size) {
    $bmp = New-Object System.Drawing.Bitmap $size, $size
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.DrawImage($src, 0, 0, $size, $size)
    $g.Dispose()
    return $bmp
}

$src = [System.Drawing.Image]::FromFile($srcPath)
Write-Host "Source: $srcPath ($($src.Width)x$($src.Height))"

$sizes = @{
    'favicon-16.png' = 16
    'favicon-32.png' = 32
    'apple-touch-icon.png' = 180
    'icon-192.png' = 192
    'icon-512.png' = 512
}

foreach ($name in $sizes.Keys) {
    $bmp = Resize-IconBitmap $src $sizes[$name]
    $bmp.Save((Join-Path $outDir $name), [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Host "Wrote $name"
}

$icon32 = Resize-IconBitmap $src 32
$h32 = $icon32.GetHicon()
$ico32 = [System.Drawing.Icon]::FromHandle($h32)
$fs = [System.IO.File]::Create((Join-Path $outDir 'favicon.ico'))
$ico32.Save($fs)
$fs.Close()
$icon32.Dispose()
$src.Dispose()
Write-Host 'Wrote favicon.ico'
