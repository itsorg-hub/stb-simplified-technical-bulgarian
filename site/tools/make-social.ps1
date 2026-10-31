# Генерира изображения за социалните мрежи (Facebook) за STB: контурен образ, заглавие и адрес на страницата.
# Изисква Windows PowerShell 5.1 (System.Drawing) и файловете на шрифта Adys (ADYS-Bold.ttf, ADYS-Medium.ttf, ADYS-Regular.ttf).
# Шрифтът е лицензиран отделно и не е в хранилището. Подава се папка с TTF файловете.
#
# Употреба:
#   powershell -ExecutionPolicy Bypass -File site\tools\make-social.ps1 -FontDir C:\път\до\шрифта -OutDir site\social
param(
    [Parameter(Mandatory = $true)][string]$FontDir,
    [string]$OutDir = (Join-Path $PSScriptRoot '..\social'),
    [string]$Version = 'v0.6',
    [string]$Url = 'it-s.org/stb'
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$pfc = New-Object System.Drawing.Text.PrivateFontCollection
foreach ($n in 'ADYS-Bold', 'ADYS-Medium', 'ADYS-Regular') {
    $p = Join-Path $FontDir "$n.ttf"
    if (-not (Test-Path $p)) { throw "Липсва шрифт: $p" }
    $pfc.AddFontFile((Resolve-Path $p).Path)
}
function Get-Fam([string]$like) { foreach ($f in $pfc.Families) { if ($f.Name -like $like) { return $f } } return $pfc.Families[0] }
$famBold = Get-Fam '*Bold*'; $famMed = Get-Fam '*Medium*'; $famReg = Get-Fam '*Regular*'
function F($fam, [single]$px, $style = [System.Drawing.FontStyle]::Regular) { New-Object System.Drawing.Font($fam, $px, $style, [System.Drawing.GraphicsUnit]::Pixel) }

function C([int]$a, [int]$r, [int]$g, [int]$b) { [System.Drawing.Color]::FromArgb($a, $r, $g, $b) }
$cyan = C 255 56 189 248; $blue = C 255 109 124 255; $violet = C 255 176 124 255

function Get-RoundedPath([single]$x, [single]$y, [single]$w, [single]$h, [single]$r) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $r * 2
    $p.AddArc($x, $y, $d, $d, 180, 90); $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90); $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $p.CloseFigure(); return $p
}

function Draw-Glow($g, [single]$cx, [single]$cy, [single]$rx, [single]$ry, $color) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddEllipse($cx - $rx, $cy - $ry, $rx * 2, $ry * 2)
    $br = New-Object System.Drawing.Drawing2D.PathGradientBrush($path)
    $br.CenterColor = $color
    $br.SurroundColors = @([System.Drawing.Color]::FromArgb(0, $color.R, $color.G, $color.B))
    $g.FillPath($br, $path); $br.Dispose(); $path.Dispose()
}

# Детерминиран шум (същият като в make-contours.mjs)
function New-Harmonics {
    $s = [uint64]20260
    $next = { $script:seed = ($script:seed * 1664525 + 1013904223) % 4294967296; return $script:seed / 4294967296.0 }
    $script:seed = [uint64]20260
    $h = @()
    for ($i = 0; $i -lt 5; $i++) { $h += [pscustomobject]@{ k = $i + 2; a = 0.16 / ($i + 1.2); p = (& $next) * 2 * [Math]::PI } }
    return $h
}
$harm = New-Harmonics

function Draw-Contours($g, [single]$cx, [single]$cy, [single]$scale, [single]$alphaMul, $clip) {
    $g.SetClip($clip)
    $rings = 26; $N = 56
    for ($i = 0; $i -lt $rings; $i++) {
        $t = $i / ($rings - 1)
        $r = (26 + $t * 400) * $scale
        $alpha = [int](255 * (1 - 0.62 * $t) * $alphaMul)
        $width = [single]((2.1 - 0.9 * $t) * $scale * 1.5)
        $pts = New-Object 'System.Drawing.PointF[]' $N
        for ($j = 0; $j -lt $N; $j++) {
            $th = ($j / $N) * 2 * [Math]::PI
            $m = 0.0
            foreach ($hh in $harm) { $m += $hh.a * [Math]::Sin($hh.k * $th + $hh.p + $t * 1.6) }
            $rr = $r * (1 + $m * (0.35 + 0.65 * $t))
            $pts[$j] = New-Object System.Drawing.PointF(($cx + $rr * [Math]::Cos($th) * 1.05), ($cy + $rr * [Math]::Sin($th) * 0.92))
        }
        $rect = New-Object System.Drawing.RectangleF(($cx - $r), ($cy - $r), (2 * $r), (2 * $r))
        $lb = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, (C $alpha 56 189 248), (C $alpha 176 124 255), 45.0)
        $cb = New-Object System.Drawing.Drawing2D.ColorBlend(3)
        $cb.Positions = @(0.0, 0.5, 1.0)
        $cb.Colors = @((C $alpha 56 189 248), (C $alpha 109 124 255), (C $alpha 176 124 255))
        $lb.InterpolationColors = $cb
        $pen = New-Object System.Drawing.Pen($lb, $width)
        $g.DrawClosedCurve($pen, $pts, 0.5, [System.Drawing.Drawing2D.FillMode]::Alternate)
        $pen.Dispose(); $lb.Dispose()
    }
    Draw-Glow $g $cx $cy (46 * $scale) (46 * $scale) (C 235 143 219 255)
    $g.FillEllipse([System.Drawing.Brushes]::White, ($cx - 7 * $scale), ($cy - 7 * $scale), (14 * $scale), (14 * $scale))
    $g.ResetClip()
}

function Draw-Spaced($g, [string]$text, $font, $brush, [single]$x, [single]$y, [single]$spacing) {
    $fmt = [System.Drawing.StringFormat]::GenericTypographic
    $fmt.FormatFlags = $fmt.FormatFlags -bor [System.Drawing.StringFormatFlags]::MeasureTrailingSpaces
    foreach ($ch in $text.ToCharArray()) {
        $s = [string]$ch
        $g.DrawString($s, $font, $brush, $x, $y, $fmt)
        $x += $g.MeasureString($s, $font, 2000, $fmt).Width + $spacing
    }
    return $x
}

function Draw-Pill($g, [string]$text, $font, [single]$x, [single]$y, [single]$padX, [single]$h) {
    $fmt = [System.Drawing.StringFormat]::GenericTypographic
    $tw = $g.MeasureString($text, $font, 2000, $fmt).Width
    $w = $tw + 2 * $padX
    $path = Get-RoundedPath $x $y $w $h ($h / 2)
    $rect = New-Object System.Drawing.RectangleF($x, $y, $w, $h)
    $lb = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, $cyan, (C 255 127 140 255), 0.0)
    $g.FillPath($lb, $path)
    $dark = New-Object System.Drawing.SolidBrush((C 255 4 18 27))
    $g.DrawString($text, $font, $dark, ($x + $padX), ($y + ($h - $font.Size) / 2 - 2), $fmt)
    $dark.Dispose(); $lb.Dispose(); $path.Dispose()
    return $w
}

function New-Canvas([int]$w, [int]$h) {
    $bmp = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBicubic'
    $g.PixelOffsetMode = 'HighQuality'; $g.TextRenderingHint = 'AntiAliasGridFit'
    $g.Clear((C 255 4 5 10))
    # Фонови светлини като на страницата
    Draw-Glow $g ($w * 0.98) ($h * 1.05) ($w * 0.75) ($h * 0.75) (C 150 104 62 255)
    Draw-Glow $g 0 (-$h * 0.1) ($w * 0.6) ($h * 0.6) (C 56 56 189 248)
    return @{ bmp = $bmp; g = $g }
}

function Render-Facebook([int]$W, [int]$H, [string]$layout, [string]$file) {
    $cv = New-Canvas $W $H; $g = $cv.g; $bmp = $cv.bmp
    $m = if ($layout -eq 'wide') { 26 } else { 30 }
    $panel = Get-RoundedPath $m $m ($W - 2 * $m) ($H - 2 * $m) 30
    $pb = New-Object System.Drawing.SolidBrush((C 235 7 8 14))
    $g.FillPath($pb, $panel)
    $edge = New-Object System.Drawing.Pen((C 36 255 255 255), 1.5)
    $g.DrawPath($edge, $panel)

    if ($layout -eq 'wide') {
        Draw-Contours $g ($W * 0.79) ($H * 0.52) 0.74 0.95 $panel
        $x = 90; $y = 78
        $titleSize = 88; $subSize = 32; $statSize = 24
    } else {
        Draw-Contours $g ($W * 0.62) ($H * 0.74) 1.0 0.9 $panel
        $x = 90; $y = 98
        $titleSize = 104; $subSize = 38; $statSize = 28
    }

    $white = New-Object System.Drawing.SolidBrush((C 255 243 245 251))
    $muted = New-Object System.Drawing.SolidBrush((C 255 170 177 197))
    $cyanB = New-Object System.Drawing.SolidBrush($cyan)
    $accent = New-Object System.Drawing.SolidBrush($cyan)
    $fmt = [System.Drawing.StringFormat]::GenericTypographic

    # Горен надпис с линия
    $lineBr = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.RectangleF($x, $y, 34, 3)), $cyan, $violet, 0.0)
    $g.FillRectangle($lineBr, $x, ($y + 9), 34, 3)
    $null = Draw-Spaced $g ("ОТВОРЕН ПРОЕКТ · $Version · НЕОФИЦИАЛНА ПУБЛИКАЦИЯ") (F $famMed 17) $muted ($x + 50) $y 2.4

    # Заглавие
    $fT = F $famBold $titleSize
    $ty = $y + 58
    $g.DrawString('Един термин.', $fT, $white, $x, $ty, $fmt)
    $line2 = 'Едно значение'
    $g.DrawString($line2, $fT, $white, $x, ($ty + $titleSize * 1.04), $fmt)
    $w2 = $g.MeasureString($line2, $fT, 3000, $fmt).Width
    $g.DrawString('.', $fT, $cyanB, ($x + $w2), ($ty + $titleSize * 1.04), $fmt)

    # Подзаглавие
    $sy = $ty + $titleSize * 2.2 + 8
    $g.DrawString('STB — Опростен технически български', (F $famMed $subSize), $white, $x, $sy, $fmt)
    $g.DrawString('Контролиран български за техническа документация', (F $famReg ($subSize * 0.66)), $muted, $x, ($sy + $subSize * 1.32), $fmt)

    # Числа
    $py = $sy + $subSize * 2.55
    $null = Draw-Spaced $g '58 правила  ·  над 900 думи  ·  10 области' (F $famMed $statSize) $white $x $py 0.8

    # Адрес и фирма
    $uy = $H - $m - 74
    $null = Draw-Pill $g $Url (F $famBold ($statSize + 2)) $x $uy 28 50
    $g.DrawString('Innovative Technology Solutions', (F $famReg 19), $muted, ($x + 230), ($uy + 13), $fmt)
    if ($layout -eq 'square') { $g.DrawString('CC BY-SA 4.0 · MIT · GitHub', (F $famReg 19), $muted, ($W - $m - 330), ($uy + 13), $fmt) }

    $bmp.Save($file, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
    "Записано: $file"
}

Render-Facebook 1200 630 'wide' (Join-Path $OutDir 'stb-facebook-1200x630.png')
Render-Facebook 1080 1080 'square' (Join-Path $OutDir 'stb-facebook-1080x1080.png')
