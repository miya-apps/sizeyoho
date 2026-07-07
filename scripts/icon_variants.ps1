# アイコンのイラストサイズ比較用バリエーション生成
# A=現行(幅700) / B=大きめ(幅790) / C=最大(幅860)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$root = 'c:\grow_app'
$srcPath = Join-Path $root 'assets\branding\app_icon_source.png'
$fontPath = Join-Path $root 'assets\fonts\ZenKakuGothicNew-Bold.ttf'

$src = [System.Drawing.Bitmap]::FromFile($srcPath)
$bg = $src.GetPixel(10, 10)
$bgBrush = New-Object System.Drawing.SolidBrush $bg

# イラストの外接矩形
$minX = 1024; $maxX = 0; $minY = 1024; $maxY = 0
for ($y = 0; $y -lt 715; $y += 2) {
  for ($x = 0; $x -lt 1024; $x += 2) {
    $p = $src.GetPixel($x, $y)
    $d = [Math]::Abs($p.R - $bg.R) + [Math]::Abs($p.G - $bg.G) + [Math]::Abs($p.B - $bg.B)
    if ($d -gt 40) {
      if ($x -lt $minX) { $minX = $x }
      if ($x -gt $maxX) { $maxX = $x }
      if ($y -lt $minY) { $minY = $y }
      if ($y -gt $maxY) { $maxY = $y }
    }
  }
}
$bw = $maxX - $minX; $bh = $maxY - $minY

$clean = New-Object System.Drawing.Bitmap 1024, 1024
$gc = [System.Drawing.Graphics]::FromImage($clean)
$gc.FillRectangle($bgBrush, 0, 0, 1024, 1024)
$gc.DrawImage($src, 0, 0, 1024, 1024)
$gc.FillRectangle($bgBrush, 0, 715, 1024, 309)
$gc.Dispose()

$pfc = New-Object System.Drawing.Text.PrivateFontCollection
$pfc.AddFontFile($fontPath)
$family = $pfc.Families[0]
$style = [System.Drawing.FontStyle]::Regular
if (-not $family.IsStyleAvailable($style)) { $style = [System.Drawing.FontStyle]::Bold }
$text = -join @([char]0x30B5, [char]0x30A4, [char]0x30BA, [char]0x4E88, [char]0x5831)
$textColor = [System.Drawing.Color]::FromArgb(255, 61, 68, 77)

function Make-Variant([int]$artW, [int]$artTop, [int]$fontPx, [int]$textY, [string]$outPath) {
  $bmp = New-Object System.Drawing.Bitmap 1024, 1024
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.FillRectangle($bgBrush, 0, 0, 1024, 1024)

  $artH = [int]($artW * $script:bh / $script:bw)
  $dstArt = New-Object System.Drawing.Rectangle ([int]((1024 - $artW) / 2)), $artTop, $artW, $artH
  $srcArt = New-Object System.Drawing.Rectangle $script:minX, $script:minY, $script:bw, $script:bh
  $g.DrawImage($script:clean, $dstArt, $srcArt, [System.Drawing.GraphicsUnit]::Pixel)

  $font = New-Object System.Drawing.Font($script:family, $fontPx, $script:style, [System.Drawing.GraphicsUnit]::Pixel)
  $brush = New-Object System.Drawing.SolidBrush $script:textColor
  $fmt = New-Object System.Drawing.StringFormat
  $fmt.Alignment = [System.Drawing.StringAlignment]::Center
  $g.DrawString($script:text, $font, $brush, 512, $textY, $fmt)
  $g.Dispose()
  $bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
  Write-Host "saved: $outPath"
}

Make-Variant 700 130 118 745 (Join-Path $root 'assets\branding\icon_variant_a.png')
Make-Variant 790 100 118 745 (Join-Path $root 'assets\branding\icon_variant_b.png')
Make-Variant 860 60 112 750 (Join-Path $root 'assets\branding\icon_variant_c.png')

$src.Dispose(); $clean.Dispose()
Write-Host 'done'
