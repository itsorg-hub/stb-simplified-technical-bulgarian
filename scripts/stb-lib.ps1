# Обща библиотека за скриптовете на STB. Зарежда се с: . "$PSScriptRoot\stb-lib.ps1"
# Изисква Windows PowerShell 5.1 или по-нов. Файлът е във формат UTF-8 с BOM.

$script:Utf8 = New-Object System.Text.UTF8Encoding($false)
$script:PackNames = @('mechanics', 'electrical', 'hydraulics', 'it', 'lifting', 'automation')

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
    # Връща клетките на всеки ред от таблица в Markdown (без разделителя).
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

function Get-StbPackFiles([string]$dictDir, [string[]]$domains) {
    if ($domains -contains 'all') { $domains = $script:PackNames }
    $files = New-Object Collections.Generic.List[object]
    foreach ($d in $domains) {
        $p = Join-Path (Join-Path $dictDir 'domains') "$d.md"
        if (-not (Test-Path $p)) { throw "Непознат пакет: $d (очаквани: $($script:PackNames -join ', '), all)" }
        $files.Add([pscustomobject]@{ Name = $d; Path = $p })
    }
    return $files.ToArray()
}

function Read-StbWordFile([string]$path) {
    # Връща думите и фразите от един файл с речник.
    $words = New-Object 'Collections.Generic.HashSet[string]'
    $phrases = New-Object Collections.Generic.List[string]
    $verbTable = $false
    foreach ($cells in Get-StbTableRows $path) {
        if ($cells[0] -match '^Несв') { $verbTable = $true; continue }
        if ($cells[0] -eq 'Дума' -or $cells[0] -eq 'Фраза' -or $cells[0] -eq 'Символ') { $verbTable = $false; continue }
        $cols = @($cells[0])
        if ($verbTable -and $cells.Count -gt 2) { $cols += $cells[2] }
        foreach ($c in $cols) {
            foreach ($alt in (($c -replace '\(.*?\)', '') -split '[,/]')) {
                $t = @(Get-StbCyrillicTokens $alt)
                if ($t.Count -gt 1) { $phrases.Add(($t -join ' ')) }
                foreach ($x in $t) { [void]$words.Add($x) }
            }
        }
    }
    return [pscustomobject]@{ Words = $words; Phrases = $phrases }
}

function Get-StbBlacklist([string]$dictDir) {
    # Неразрешени думи (само еднословните) от файл 05: дума -> замяна.
    $map = @{}
    $f = Get-ChildItem $dictDir -Filter '05-*.md' | Select-Object -First 1
    if (-not $f) { return $map }
    foreach ($cells in Get-StbTableRows $f.FullName) {
        if ($cells[0] -eq 'Неразрешена' -or $cells.Count -lt 3) { continue }
        foreach ($item in (($cells[0] -replace '\(.*?\)', '') -split '[,/]')) {
            $w = $item.Trim()
            if ($w -match '^\p{L}+$' -and $w -match '[Ѐ-ӿ]') { $map[(Get-StbNorm $w)] = $cells[2] }
        }
    }
    return $map
}

function Get-StbConflicts([string]$dictDir) {
    $set = New-Object 'Collections.Generic.HashSet[string]'
    $f = Join-Path $dictDir 'domains\conflicts.md'
    if (Test-Path $f) {
        foreach ($cells in Get-StbTableRows $f) {
            if ($cells[0] -eq 'Дума') { continue }
            foreach ($w in ($cells[0] -split "[,/]")) { if ($w.Trim()) { [void]$set.Add((Get-StbNorm $w.Trim())) } }
        }
    }
    return , $set
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

function Get-StbPhraseRegex([string]$phrase) {
    # Регулярен израз за фраза, който допуска промяна на окончанията.
    $parts = foreach ($w in ($phrase -split ' ')) {
        $stem = if ($w.Length -gt 5) { $w.Substring(0, $w.Length - 2) } else { $w }
        [regex]::Escape($stem) + '[\p{L}]*'
    }
    return '(?<![\p{L}])' + ($parts -join '\s+') + '(?![\p{L}])'
}

function Get-StbDictionary([string]$dictDir, [string[]]$domains) {
    # Зарежда ядрото и избраните пакети.
    $bl = Get-StbBlacklist $dictDir
    $approved = New-Object 'Collections.Generic.HashSet[string]'
    $phrases = New-Object 'Collections.Generic.HashSet[string]'
    $coreFiles = Get-ChildItem $dictDir -Filter '*.md' | Where-Object { $_.Name -match '^0[1-4]-' }
    $active = @($coreFiles | ForEach-Object { $_.FullName })
    $packs = @()
    if ($domains) { $packs = @(Get-StbPackFiles $dictDir $domains) }
    foreach ($p in $packs) { $active += $p.Path }
    foreach ($f in $active) {
        $r = Read-StbWordFile $f
        foreach ($p in $r.Phrases) { [void]$phrases.Add($p) }
        $inPhrase = New-Object 'Collections.Generic.HashSet[string]'
        foreach ($p in $r.Phrases) { foreach ($x in ($p -split ' ')) { [void]$inPhrase.Add($x) } }
        # Отделна дума от фраза не става разрешена сама, ако е неразрешена в ядрото.
        foreach ($w in $r.Words) { if (-not ($bl.ContainsKey($w) -and $inPhrase.Contains($w))) { [void]$approved.Add($w) } }
    }
    # Думи от пакети, които не са включени
    $other = @{}
    $activeNames = @($packs | ForEach-Object { $_.Name })
    foreach ($n in $script:PackNames) {
        if ($activeNames -contains $n) { continue }
        $p = Join-Path (Join-Path $dictDir 'domains') "$n.md"
        if (Test-Path $p) { foreach ($w in (Read-StbWordFile $p).Words) { if (-not $approved.Contains($w)) { $other[$w] = $n } } }
    }
    $rx = New-Object Collections.Generic.List[object]
    foreach ($p in $phrases) { $rx.Add([regex]::new((Get-StbPhraseRegex $p), 'IgnoreCase')) }
    # Основи на разрешените думи за форми, които липсват във forms.tsv (членни форми, мн. ч.)
    $stems = @{}
    foreach ($w in $approved) {
        $s = $w
        if ($s.Length -gt 4 -and $s -match '[аяоеи]$') { $s = $s.Substring(0, $s.Length - 1) }
        if ($s.Length -lt 4) { continue }
        $k = $s.Substring(0, 3)
        if (-not $stems.ContainsKey($k)) { $stems[$k] = New-Object Collections.Generic.List[string] }
        $stems[$k].Add($s)
    }
    return [pscustomobject]@{
        Stems = $stems; Approved = $approved; Blacklist = $bl; Forms = (Get-StbForms $dictDir); OtherPacks = $other
        PhraseRegex = $rx.ToArray(); Conflicts = (Get-StbConflicts $dictDir); ActivePacks = $packs.Count
    }
}

function Test-StbProbableForm($dict, [string]$t) {
    # Евристика: думата започва с основата на разрешена дума и има най-много 5 букви окончание.
    if ($t.Length -lt 5) { return $false }
    $k = $t.Substring(0, 3)
    if (-not $dict.Stems.ContainsKey($k)) { return $false }
    foreach ($s in $dict.Stems[$k]) { if ($t.StartsWith($s) -and (($t.Length - $s.Length) -le 5)) { return $true } }
    return $false
}
