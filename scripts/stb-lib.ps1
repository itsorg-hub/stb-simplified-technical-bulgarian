# Обща библиотека за скриптовете на STB. Зарежда се с: . "$PSScriptRoot\stb-lib.ps1"
# Изисква Windows PowerShell 5.1 или по-нов. Файлът е във формат UTF-8 с BOM.

$script:Utf8 = New-Object System.Text.UTF8Encoding($false)

function Get-StbNorm([string]$s) {
    # Малки букви, без ударения (U+0300, U+0301), "ѝ" става "и".
    $d = $s.Normalize([Text.NormalizationForm]::FormD).Replace([string][char]0x300, '').Replace([string][char]0x301, '')
    return $d.Normalize([Text.NormalizationForm]::FormC).ToLower()
}

function Get-StbCyrillicTokens([string]$s) {
    # Връща думите, които съдържат поне една кирилска буква.
    $out = New-Object Collections.Generic.List[string]
    foreach ($m in [regex]::Matches($s, '[\p{L}̀́]+(?:-[\p{L}]+)*')) {
        if ($m.Value -match '[Ѐ-ӿ]') { $out.Add((Get-StbNorm $m.Value)) }
    }
    return $out.ToArray()
}

function Get-StbTableRows([string]$file) {
    # Връща клетките на всеки ред от таблица в Markdown (без заглавния ред и разделителя).
    $rows = New-Object Collections.Generic.List[object]
    foreach ($line in [IO.File]::ReadLines($file, $script:Utf8)) {
        if ($line -notmatch '^\|') { continue }
        if ($line -match '^\|\s*-') { continue }
        $cells = $line.Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() }
        if ($cells.Count -lt 2) { continue }
        $rows.Add($cells)
    }
    return $rows.ToArray()
}

function Get-StbApprovedLemmas([string]$dictDir) {
    # Разрешени думи от файлове 01–04 (първата колонка; при глаголите и формите за повелително).
    $set = New-Object 'Collections.Generic.HashSet[string]'
    foreach ($f in Get-ChildItem $dictDir -Filter '*.md' | Where-Object { $_.Name -match '^0[1-4]-' }) {
        foreach ($cells in Get-StbTableRows $f.FullName) {
            $head = $cells[0]
            if ($head -eq 'Дума' -or $head -match '^Несв' -or $head -eq 'Фраза' -or $head -eq 'Символ') { continue }
            $cols = @($head)
            if ($f.Name -like '02-*' -and $cells.Count -gt 2) { $cols += $cells[2] }
            foreach ($c in $cols) {
                foreach ($t in Get-StbCyrillicTokens ($c -replace '\(.*?\)', '')) { [void]$set.Add($t) }
            }
        }
    }
    return , $set
}

function Get-StbBlacklist([string]$dictDir) {
    # Неразрешени думи (само еднословните) от файл 05: дума -> замяна.
    $map = @{}
    $f = Join-Path $dictDir '05-неразрешени-думи.md'
    if (-not (Test-Path $f)) { return $map }
    foreach ($cells in Get-StbTableRows $f) {
        if ($cells[0] -eq 'Неразрешена' -or $cells.Count -lt 3) { continue }
        $head = ($cells[0] -replace '\(.*?\)', '')
        foreach ($item in ($head -split '[,/]')) {
            $w = $item.Trim()
            if ($w -match '^\p{L}+$' -and $w -match '[Ѐ-ӿ]') { $map[(Get-StbNorm $w)] = $cells[2] }
        }
    }
    return $map
}

function Get-StbForms([string]$dictDir) {
    # Таблица форма -> лема от dictionary/forms.tsv (ако съществува).
    $map = @{}
    $f = Join-Path $dictDir 'forms.tsv'
    if (Test-Path $f) {
        foreach ($l in [IO.File]::ReadLines($f, $script:Utf8)) {
            $p = $l.Split("`t")
            if ($p.Count -ge 2) { $map[$p[0]] = $p[1] }
        }
    }
    return $map
}
