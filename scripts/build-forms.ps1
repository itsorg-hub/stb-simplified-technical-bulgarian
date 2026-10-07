# Строи dictionary/forms.tsv: всички словоформи на разрешените думи, взети от данните на Wiktionary (kaikki.org).
# Данните на Wiktionary са под CC BY-SA 4.0. Вж. NOTICE.md.
#
# Употреба:
#   1. Свалете https://kaikki.org/dictionary/Bulgarian/kaikki.org-dictionary-Bulgarian.jsonl в sources\kaikki-bulgarian.jsonl
#   2. powershell -ExecutionPolicy Bypass -File scripts\build-forms.ps1
param(
    [string]$Kaikki = (Join-Path $PSScriptRoot '..\sources\kaikki-bulgarian.jsonl'),
    [string]$DictDir = (Join-Path $PSScriptRoot '..\dictionary')
)
. "$PSScriptRoot\stb-lib.ps1"
$ErrorActionPreference = 'Stop'
if (-not (Test-Path $Kaikki)) { throw "Липсва файл: $Kaikki" }

$lemmas = Get-StbApprovedLemmas $DictDir
$pairs = New-Object 'Collections.Generic.HashSet[string]'
foreach ($l in $lemmas) { [void]$pairs.Add("$l`t$l") }

foreach ($line in [IO.File]::ReadLines($Kaikki, $script:Utf8)) {
    $m = [regex]::Match($line, '"word": "([^"]+)"')
    if (-not $m.Success) { continue }
    $w = Get-StbNorm $m.Groups[1].Value
    if (-not $lemmas.Contains($w)) { continue }
    $e = $line | ConvertFrom-Json
    foreach ($f in $e.forms) {
        $t = $f.form
        if (-not $t -or $t -match '\s' -or $t -eq '-' -or $t -match '^(no-table|bg-)') { continue }
        if ($f.tags -contains 'romanization') { continue }
        if ($t -notmatch '[Ѐ-ӿ]') { continue }
        [void]$pairs.Add("$(Get-StbNorm $t)`t$w")
    }
}
$sorted = $pairs | Sort-Object
[IO.File]::WriteAllLines((Join-Path $DictDir 'forms.tsv'), $sorted, $script:Utf8)
"Записани форми: $($sorted.Count)"
