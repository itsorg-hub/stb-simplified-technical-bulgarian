# STB проверка на текст. Проверява текст срещу правилата и речника на STB v0.1.
#
# Употреба:
#   powershell -ExecutionPolicy Bypass -File scripts\stb-check.ps1 -Path текст.md
#   powershell -ExecutionPolicy Bypass -File scripts\stb-check.ps1 -Text "Затегнете гайката."
#   ... -Kind description   (описание: до 25 думи; по подразбиране procedure: до 20 думи)
#
# Резултатът е списък със забележки: ГРЕШКА (нарушено правило), ПРЕДУПРЕЖДЕНИЕ (изисква преценка от човек).
# Автоматично се проверяват само правилата, които могат да се разпознаят по формата на текста.
# Правила 2.3, 3.5 и 3.6 (отбелязани със ⚠) се маркират само като предупреждение.
# Изходен код: 1 при поне една ГРЕШКА, иначе 0.
param(
    [string]$Path,
    [string]$Text,
    [ValidateSet('procedure', 'description')][string]$Kind = 'procedure',
    [string[]]$Domain = @(),
    [string]$DictDir = (Join-Path $PSScriptRoot '..\dictionary'),
    [switch]$NoVocabulary
)
. "$PSScriptRoot\stb-lib.ps1"
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}

if (-not $Text -and $Path) { $Text = [IO.File]::ReadAllText($Path, $script:Utf8) }
if (-not $Text) { throw 'Подайте -Path или -Text.' }

$dict = Get-StbDictionary $DictDir $Domain
$approved = $dict.Approved; $forms = $dict.Forms; $blacklist = $dict.Blacklist
$limit = if ($Kind -eq 'procedure') { 20 } else { 25 }

$numberWords = @('нула','два','две','три','четири','пет','шест','седем','осем','девет','десет','сто','хиляда')
$reported = @('бил','била','било','били')
$pronouns = @('той','тя','то','те','го','я','ги','му','ѝ','им','него','нея','тях','ѝ')
$relatives = @('който','която','което','които')
$vague = @('около','приблизително','почти')
$stepStart = @('ако','когато','докато','не','преди','след','опасност','предупреждение','внимание','забележка')

$findings = New-Object Collections.Generic.List[object]
function Add-Finding($sev, $rule, $sent, $msg) {
    $findings.Add([pscustomobject]@{ Ниво = $sev; Правило = $rule; Изречение = $sent; Забележка = $msg })
}

# Разделяне на абзаци и изречения
$paragraphs = [regex]::Split($Text, '(?:\r?\n){2,}')
$sentNo = 0
foreach ($par in $paragraphs) {
    $sentencesInPar = 0
    foreach ($rawLine in ($par -split '\r?\n')) {
        $line = $rawLine.Trim()
        if (-not $line -or $line -match '^(#|\||```|---)') { continue }
        $isStep = $line -match '^\s*\d+\.\s+'
        $line = $line -replace '^\s*(\d+\.|[-*•])\s+', ''
        # Защита на десетични числа и съкращения срещу разделяне на изречения
        $safe = [regex]::Replace($line, '(\d)[.,](\d)', '$1_$2')
        $sentences = [regex]::Split($safe, '(?<=[.!?])\s+') | Where-Object { $_.Trim() }
        $firstInLine = $true
        foreach ($s in $sentences) {
            $sentNo++; $sentencesInPar++
            $orig = $s.Replace('_', ',')
            $short = if ($orig.Length -gt 45) { $orig.Substring(0, 45) + '…' } else { $orig }
            $tag = "${sentNo}: $short"
            $tokens = Get-StbCyrillicTokens $orig
            $words = @($orig -split '\s+' | Where-Object { $_ -match '[\p{L}\d]' })

            # 4.1 дължина
            if ($words.Count -gt $limit) { Add-Finding 'ГРЕШКА' '4.1' $tag "Изречението има $($words.Count) думи (максимум $limit)." }
            # 4.6 точка и запетая
            if ($orig -match ';') { Add-Finding 'ГРЕШКА' '4.6' $tag 'Точка и запетая. Пишете две изречения.' }
            # 4.10 и/или
            if ($orig -match '\bи\s*/\s*или\b') { Add-Finding 'ГРЕШКА' '4.10' $tag 'Не използвайте „и/или".' }
            # 8.1 пунктуация
            if ($orig -match '…|\.\.\.') { Add-Finding 'ГРЕШКА' '8.1' $tag 'Не използвайте многоточие.' }
            if ($orig -match '!' -and $orig -notmatch '^(ОПАСНОСТ|ПРЕДУПРЕЖДЕНИЕ|ВНИМАНИЕ)') { Add-Finding 'ГРЕШКА' '8.1' $tag 'Удивителна е позволена само в предупреждения.' }
            # 4.7 скоби
            foreach ($m in [regex]::Matches($orig, '\(([^)]*)\)')) {
                $inner = $m.Groups[1].Value.Trim()
                $wc = @($inner -split '\s+' | Where-Object { $_ }).Count
                if ($wc -gt 2 -and $inner -notmatch '^(вижте|вж)') { Add-Finding 'ПРЕДУПРЕЖДЕНИЕ' '4.7' $tag 'Скобите са само за препратки и мерни единици.' }
            }
            # 2.1 инструкция: повелително, 2 л. мн.
            if ($Kind -eq 'procedure' -and $isStep -and $firstInLine -and $tokens.Count -gt 0) {
                $first = $tokens[0]
                if ($first -notmatch '(ете|йте)$' -and $stepStart -notcontains $first) {
                    Add-Finding 'ГРЕШКА' '2.1' $tag 'Стъпката трябва да започва с глагол в повелително наклонение, 2 л. мн. ч.'
                }
            }
            $firstInLine = $false
            # 4.2 две команди в едно изречение
            if ($orig -match '\b\p{L}+(ете|йте)\b[^.]*\sи\s+\p{L}+(ете|йте)\b') { Add-Finding 'ГРЕШКА' '4.2' $tag 'Две команди със „и" в едно изречение. Пишете две изречения.' }
            # 4.5 условие пред действие
            for ($i = 2; $i -lt $tokens.Count; $i++) {
                if ($tokens[$i] -eq 'ако') { Add-Finding 'ПРЕДУПРЕЖДЕНИЕ' '4.5' $tag 'Условието („ако") трябва да стои преди действието.'; break }
            }
            # 2.9 деепричастие
            foreach ($t in $tokens) { if ($t -match '(айки|яйки|ейки)$') { Add-Finding 'ГРЕШКА' '2.9' $tag "Деепричастие «$t». Пишете отделно изречение." } }
            # 2.4 преизказ
            foreach ($t in $tokens) { if ($reported -contains $t) { Add-Finding 'ГРЕШКА' '2.4' $tag "Преизказна форма «$t»." } }
            # 7.1 числа с думи
            foreach ($t in $tokens) { if ($numberWords -contains $t) { Add-Finding 'ГРЕШКА' '7.1' $tag "Числото «$t» се пише с цифри." } }
            # 7.5 приблизителност
            foreach ($t in $tokens) { if ($vague -contains $t) { Add-Finding 'ГРЕШКА' '7.5' $tag "«$t» без числова граница." } }
            # 2.6 / 2.5 „се"
            if ($tokens -contains 'се') { Add-Finding 'ПРЕДУПРЕЖДЕНИЕ' '2.5/2.6' $tag 'Има «се". Проверете дали не е страдателен залог или безлична команда.' }
            # 3.5 ⚠ и 3.6 ⚠
            foreach ($t in $tokens) { if ($relatives -contains $t) { Add-Finding 'ПРЕДУПРЕЖДЕНИЕ' '3.5 ⚠' $tag "«$t»: потвърдете, че сочи към едно съществително." } }
            foreach ($t in ($tokens | Where-Object { $pronouns -contains $_ } | Select-Object -Unique)) { Add-Finding 'ПРЕДУПРЕЖДЕНИЕ' '3.6 ⚠' $tag "Местоимение «$t»: потвърдете, че е ясно за какво се отнася." }
            # Речник
            if (-not $NoVocabulary) {
                $vtext = Get-StbNorm $orig
                foreach ($rx in $dict.PhraseRegex) { $vtext = $rx.Replace($vtext, ' ') }
                foreach ($t in (@(Get-StbCyrillicTokens $vtext) | Select-Object -Unique)) {
                    $lemma = if ($forms.ContainsKey($t)) { $forms[$t] } else { $t }
                    if ($approved.Contains($t) -or $approved.Contains($lemma)) {
                        if ($dict.ActivePacks -gt 1 -and ($dict.Conflicts.Contains($t) -or $dict.Conflicts.Contains($lemma))) {
                            Add-Finding 'ПРЕДУПРЕЖДЕНИЕ' '1.6' $tag "«$t» е двусмислена между области. Уточнете (вж. dictionary/domains/conflicts.md)."
                        }
                        continue
                    }
                    if ($blacklist.ContainsKey($t)) { Add-Finding 'ГРЕШКА' '1.1' $tag "Неразрешена дума «$t». Замяна: $($blacklist[$t])"; continue }
                    if ($blacklist.ContainsKey($lemma)) { Add-Finding 'ГРЕШКА' '1.1' $tag "Неразрешена дума «$t» (форма на «$lemma»). Замяна: $($blacklist[$lemma])"; continue }
                    if ($dict.OtherPacks.ContainsKey($lemma)) { Add-Finding 'ПРЕДУПРЕЖДЕНИЕ' '1.1' $tag "«$t» е от пакет «$($dict.OtherPacks[$lemma])», който не е включен (-Domain)."; continue }
                    if (Test-StbProbableForm $dict $t) { continue }
                    Add-Finding 'ПРЕДУПРЕЖДЕНИЕ' '1.1' $tag "«$t» не е в речника."
                }
            }        }
    }
    if ($sentencesInPar -gt 6) { Add-Finding 'ГРЕШКА' '5.1' "абзац" "Абзацът има $sentencesInPar изречения (максимум 6)." }
}

if ($findings.Count -eq 0) { 'Няма забележки.'; exit 0 }
$findings | Format-Table -AutoSize -Wrap | Out-String -Width 200
$err = @($findings | Where-Object { $_.Ниво -eq 'ГРЕШКА' }).Count
$warn = @($findings | Where-Object { $_.Ниво -eq 'ПРЕДУПРЕЖДЕНИЕ' }).Count
"Грешки: $err · Предупреждения: $warn"
if ($err -gt 0) { exit 1 } else { exit 0 }
