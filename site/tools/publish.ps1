# Копира страницата от site/ в частното хранилище за качване (stb-site) и го качва в GitHub.
# Hostinger изтегля stb-site в public_html/stb.
# Шрифтът Adys се взема от site/assets/fonts (локално, не е в публичното хранилище).
#
# Употреба:  powershell -ExecutionPolicy Bypass -File site\tools\publish.ps1 -Message "Описание на промяната"
param(
    [Parameter(Mandatory = $true)][string]$Message,
    [string]$Deploy = 'C:\Claude\stb-site',
    [switch]$NoPush
)
$ErrorActionPreference = 'Stop'
$site = Join-Path $PSScriptRoot '..'
if (-not (Test-Path (Join-Path $Deploy '.git'))) { throw "Липсва хранилище за качване: $Deploy (клонирайте itsorg-hub/stb-site)" }
$fonts = Get-ChildItem (Join-Path $site 'assets\fonts') -Filter 'ADYS-*.woff*' -ErrorAction SilentlyContinue
if (-not $fonts) { throw 'Липсват файловете на шрифта Adys в site\assets\fonts.' }

# Копиране без README и tools; .htaccess, README.md и .gitignore в целевото хранилище не се пипат.
$null = robocopy $site $Deploy /MIR /XD tools .git /XF README.md DESIGN.md .htaccess .gitignore
if ($LASTEXITCODE -ge 8) { throw "robocopy грешка: $LASTEXITCODE" }
# robocopy /MIR би изтрил README.md/.htaccess/.gitignore в целта; /XF ги пази.
Remove-Item (Join-Path $Deploy 'assets\fonts\README.md') -ErrorAction SilentlyContinue

# Версия на стиловете в адреса, за да не се показва стар кеширан файл (CDN и браузър).
$ver = Get-Date -Format 'yyyyMMddHHmmss'
$enc = New-Object Text.UTF8Encoding($false)
foreach ($h in (Get-ChildItem $Deploy -Filter '*.html' -Recurse | Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' })) {
    $t = [IO.File]::ReadAllText($h.FullName, $enc)
    $t2 = [regex]::Replace($t, 'assets/css/(style|design)\.css(\?v=\w+)?', "assets/css/`${1}.css?v=$ver")
    if ($t2 -ne $t) { [IO.File]::WriteAllText($h.FullName, $t2, $enc) }
}

Push-Location $Deploy
try {
    git add -A
    if (-not (git status --porcelain)) { 'Няма промени за качване.'; return }
    git commit -q -m $Message
    if (-not $NoPush) { git push -q origin main; 'Качено в GitHub. Hostinger ще обнови страницата при следващото изтегляне.' }
    else { 'Записано локално (без push).' }
} finally { Pop-Location }
