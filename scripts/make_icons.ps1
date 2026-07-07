# アプリアイコン生成スクリプト
# 添付のイラスト（assets/branding/app_icon_source.png）からイラスト部分だけを
# 切り抜いて大きめに配置し、アプリと同じ書体（Zen Kaku Gothic New Bold）で
# 「サイズ予報」の文字を入れる。Web 用アイコン（favicon / 192 / 512 / maskable）も書き出す。
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$root = 'c:\grow_app'
$srcPath = Join-Path $root 'assets\branding\app_icon_source.png'
$fontPath = Join-Path $root 'assets\fonts\ZenMaruGothic-Bold.ttf'

$src = [System.Drawing.Bitmap]::FromFile($srcPath)
$bg = $src.GetPixel(10, 10)
$bgBrush = New-Object System.Drawing.SolidBrush $bg
Write-Host "background: R=$($bg.R) G=$($bg.G) B=$($bg.B) size=$($src.Width)x$($src.Height)"

# ── イラストの外接矩形を求める（元画像の文字より上の領域だけ走査） ──
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
Write-Host "artwork bbox: ($minX,$minY)-($maxX,$maxY)"
$bw = $maxX - $minX; $bh = $maxY - $minY

# 元画像の文字・キラキラを背景色で消したクリーン版
$clean = New-Object System.Drawing.Bitmap 1024, 1024
$gc = [System.Drawing.Graphics]::FromImage($clean)
$gc.FillRectangle($bgBrush, 0, 0, 1024, 1024)
$gc.DrawImage($src, 0, 0, 1024, 1024)
$gc.FillRectangle($bgBrush, 0, 715, 1024, 309)
$gc.Dispose()

# アプリと同じ書体を読み込む
$pfc = New-Object System.Drawing.Text.PrivateFontCollection
$pfc.AddFontFile($fontPath)
$family = $pfc.Families[0]
Write-Host "font family: $($family.Name)"
$style = [System.Drawing.FontStyle]::Regular
if (-not $family.IsStyleAvailable($style)) { $style = [System.Drawing.FontStyle]::Bold }
# 「サイズ予報」（ps1 の文字コード差異で化けないよう、コードポイントで指定）
$text = -join @([char]0x30B5, [char]0x30A4, [char]0x30BA, [char]0x4E88, [char]0x5831)

# ── 1) ワードマーク版（切り抜いたイラストを大きく＋文字入れ） ──
$bmp = New-Object System.Drawing.Bitmap 1024, 1024
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.FillRectangle($bgBrush, 0, 0, 1024, 1024)

# イラスト：幅 790px に拡大して上部中央へ（B案）
$artW = 790
$artH = [int]($artW * $bh / $bw)
$dstArt = New-Object System.Drawing.Rectangle ([int]((1024 - $artW) / 2)), 100, $artW, $artH
$srcArt = New-Object System.Drawing.Rectangle $minX, $minY, $bw, $bh
$g.DrawImage($clean, $dstArt, $srcArt, [System.Drawing.GraphicsUnit]::Pixel)

# 文字：イラストの下に大きめに
$font = New-Object System.Drawing.Font($family, 118, $style, [System.Drawing.GraphicsUnit]::Pixel)
$textBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 61, 68, 77))
$fmt = New-Object System.Drawing.StringFormat
$fmt.Alignment = [System.Drawing.StringAlignment]::Center
$g.DrawString($text, $font, $textBrush, 512, 745, $fmt)
$g.Dispose()

$wordmarkPath = Join-Path $root 'assets\branding\app_icon_wordmark.png'
$bmp.Save($wordmarkPath, [System.Drawing.Imaging.ImageFormat]::Png)
Write-Host "saved: $wordmarkPath"

# ── 2) イラストのみ版（ホーム画面アイコン向け。文字なし・中央寄せ） ──
# 倍率が小さいほどイラストが大きく写る（1.12 = 余白ひかえめで大きく表示）
$side = [int]([Math]::Max($bw, $bh) * 1.12)
$cx = [int](($minX + $maxX) / 2); $cy = [int](($minY + $maxY) / 2)

$art = New-Object System.Drawing.Bitmap 1024, 1024
$g2 = [System.Drawing.Graphics]::FromImage($art)
$g2.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g2.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g2.FillRectangle($bgBrush, 0, 0, 1024, 1024)
$srcRect = New-Object System.Drawing.Rectangle ($cx - [int]($side / 2)), ($cy - [int]($side / 2)), $side, $side
$dstRect = New-Object System.Drawing.Rectangle 0, 0, 1024, 1024
$g2.DrawImage($clean, $dstRect, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
$g2.Dispose()
$artPath = Join-Path $root 'assets\branding\app_icon_art.png'
$art.Save($artPath, [System.Drawing.Imaging.ImageFormat]::Png)
Write-Host "saved: $artPath"

# ── 3) Web 用アイコンへ書き出し ──
function Save-Resized([System.Drawing.Bitmap]$image, [int]$size, [string]$path) {
  $r = New-Object System.Drawing.Bitmap $size, $size
  $gr = [System.Drawing.Graphics]::FromImage($r)
  $gr.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $gr.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $gr.DrawImage($image, 0, 0, $size, $size)
  $gr.Dispose()
  $r.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
  $r.Dispose()
  Write-Host "saved: $path"
}

# 通常アイコン・favicon はイラストのみ版（小さくても図柄が読める）
Save-Resized $art 192 (Join-Path $root 'web\icons\Icon-192.png')
Save-Resized $art 512 (Join-Path $root 'web\icons\Icon-512.png')
Save-Resized $art 32  (Join-Path $root 'web\favicon.png')
# maskable（Android の円形マスク）は外周が切られるためイラストのみ版
Save-Resized $art 192 (Join-Path $root 'web\icons\Icon-maskable-192.png')
Save-Resized $art 512 (Join-Path $root 'web\icons\Icon-maskable-512.png')

$src.Dispose(); $clean.Dispose(); $bmp.Dispose(); $art.Dispose()
Write-Host 'done'
