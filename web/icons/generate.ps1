# 아주 정신 웹 아이콘 생성 — 방목록 3버튼(전체공지·병실·학술) 톤
Add-Type -AssemblyName System.Drawing

function Get-RoundedRect($x, $y, $w, $h, $r) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddArc($x, $y, $r, $r, 180, 90)
    $path.AddArc($x + $w - $r, $y, $r, $r, 270, 90)
    $path.AddArc($x + $w - $r, $y + $h - $r, $r, $r, 0, 90)
    $path.AddArc($x, $y + $h - $r, $r, $r, 90, 90)
    $path.CloseFigure()
    return $path
}

function New-MoimIconBitmap([int]$size) {
    $bmp = New-Object System.Drawing.Bitmap $size, $size
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $g.Clear([System.Drawing.Color]::FromArgb(255, 18, 18, 18))

    $margin = [int][Math]::Round($size * 0.11)
    $gap = [int][Math]::Round($size * 0.016)
    $segW = [int][Math]::Floor(($size - 2 * $margin - 2 * $gap) / 3)
    $top = [int][Math]::Round($size * 0.22)
    $h = [int][Math]::Round($size * 0.56)
    $r = [int][Math]::Round($size * 0.055)
    $colors = @('#b5651d', '#ea7317', '#4a6fa5')
    $x = $margin
    foreach ($hex in $colors) {
        $brush = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml($hex))
        $path = Get-RoundedRect $x $top $segW $h $r
        $g.FillPath($brush, $path)
        $brush.Dispose(); $path.Dispose()
        $x += $segW + $gap
    }

    # 상단 라벨 없이 3색 바만 — 작은 favicon 에서도 선명 (SVG 에는 글자 포함)
    $g.Dispose()
    return $bmp
}

$outDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$sizes = @{
    'favicon-16.png' = 16
    'favicon-32.png' = 32
    'apple-touch-icon.png' = 180
    'icon-192.png' = 192
    'icon-512.png' = 512
}

foreach ($name in $sizes.Keys) {
    $bmp = New-MoimIconBitmap $sizes[$name]
    $path = Join-Path $outDir $name
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Host "Wrote $name"
}

# favicon.ico (16 + 32)
$icon32 = New-MoimIconBitmap 32
$icon16 = New-MoimIconBitmap 16
$h32 = $icon32.GetHicon()
$h16 = $icon16.GetHicon()
$ico32 = [System.Drawing.Icon]::FromHandle($h32)
$icoPath = Join-Path $outDir 'favicon.ico'
$fs = [System.IO.File]::Create($icoPath)
$ico32.Save($fs)
$fs.Close()
$icon32.Dispose(); $icon16.Dispose()
Write-Host 'Wrote favicon.ico'
