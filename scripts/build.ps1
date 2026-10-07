$ErrorActionPreference='Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)
function Norm($s){ $s.Normalize([Text.NormalizationForm]::FormD).Replace([string][char]0x300,"").Replace([string][char]0x301,"").Normalize([Text.NormalizationForm]::FormC).ToLower() }
$freq=@{}; $i=0
foreach($l in [IO.File]::ReadLines("$PWD\sources\bg_50k.txt",$utf8)){ $i++; $p=$l.Split(' '); if(-not $freq.ContainsKey($p[0])){$freq[$p[0]]=@($i,[long]$p[1])} }
$gl=@{}; $f2l=@{}
foreach($l in [IO.File]::ReadLines("$PWD\sources\kaikki-bulgarian.jsonl",$utf8)){
  $e=$l|ConvertFrom-Json; $w=Norm $e.word; $pos=$e.pos
  $g=@(); foreach($s in $e.senses){ if($s.tags -contains 'form-of' -or $s.tags -contains 'alt-of'){continue}; foreach($x in $s.glosses){$g+=$x} }
  if($g.Count -eq 0){continue}
  $k="$w`t$pos"
  if(-not $gl.ContainsKey($k)){$gl[$k]=New-Object Collections.Generic.List[string]}
  foreach($x in ($g|Select-Object -First 3)){ if(-not $gl[$k].Contains($x)){$gl[$k].Add($x)} }
  $forms=@($w); foreach($f in $e.forms){ $t=$f.form; if($t -and $t -notmatch ' ' -and $t -ne '-' -and $t -notmatch '^(no-table|bg-)' -and ($f.tags -notcontains 'romanization')){ $forms+=(Norm $t) } }
  foreach($fm in $forms){ if(-not $f2l.ContainsKey($fm)){$f2l[$fm]=New-Object Collections.Generic.HashSet[string]}; [void]$f2l[$fm].Add($k) }
}
$best=@{}
foreach($w in $freq.Keys){ if($f2l.ContainsKey($w)){ foreach($k in $f2l[$w]){ $r=$freq[$w][0]; $c=$freq[$w][1]; if(-not $best.ContainsKey($k) -or $r -lt $best[$k][0]){$best[$k]=@($r,$c)} } } }
$rows=$best.GetEnumerator()|Sort-Object {$_.Value[0]}
$tsv=New-Object Collections.Generic.List[string]; $md=New-Object Collections.Generic.List[string]
$tsv.Add("rank`tlemma`tpos`tfreq`tgloss_en")
$md.Add("# Български лексикон (честота + Wiktionary)`n`nИзточници: честотен списък OpenSubtitles (hermitdave/FrequencyWords, CC-BY-SA 4.0) и данни от Wiktionary чрез kaikki.org (CC-BY-SA). Ранг = най-ранната форма на думата в честотния списък. Значенията са на английски (така са във Wiktionary).`n`n| ранг | дума | част на речта | честота | значение (EN) |`n|---|---|---|---|---|")
foreach($r in $rows){ $p=$r.Key.Split("`t"); $g=($gl[$r.Key] -join '; ')
  $tsv.Add("$($r.Value[0])`t$($p[0])`t$($p[1])`t$($r.Value[1])`t$g")
  $md.Add("| $($r.Value[0]) | $($p[0]) | $($p[1]) | $($r.Value[1]) | $($g.Replace('|','/')) |") }
[IO.File]::WriteAllLines("$PWD\bg-lexicon.tsv",$tsv,$utf8); [IO.File]::WriteAllLines("$PWD\bg-lexicon.md",$md,$utf8)
"$($gl.Count) lemma-pos; $($rows.Count) matched"
