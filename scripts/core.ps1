$utf8 = New-Object System.Text.UTF8Encoding($false)
$skip='character','name','proverb','phrase','prefix','suffix','letter','symbol','contraction','infix'
$seen=@{}; $out=New-Object Collections.Generic.List[string]
foreach($l in ([IO.File]::ReadLines("$PWD\bg-lexicon.tsv",$utf8)|Select-Object -Skip 1)){
  $p=$l.Split("`t"); if($skip -contains $p[2] -or $p[1].Length -lt 2 -or $p[1] -match '[^а-яё-]'){continue}
  if(-not $seen.ContainsKey($p[1])){ $seen[$p[1]]=1; $out.Add("$($p[1])`t$($p[0])`t$($p[2])") }
  if($out.Count -ge 900){break}
}
[IO.File]::WriteAllLines("$PWD\core-words.tsv",$out,$utf8); $out.Count
