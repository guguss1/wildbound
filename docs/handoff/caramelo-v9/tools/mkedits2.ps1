param([string]$OutDir, [string]$Base, [string[]]$Only)
Set-Location "E:\juego roblox\wb-first-playable"
$g = "C:\Users\Agustina\AppData\Local\GitHubDesktop\app-3.6.5\resources\app\git\cmd\git.exe"
New-Item -ItemType Directory -Force $OutDir | Out-Null
$utf8 = New-Object System.Text.UTF8Encoding($false)
function Show($rev, $f) {
  $tmp = [System.IO.Path]::GetTempFileName()
  cmd /c "`"$g`" show ${rev}:$f > `"$tmp`" 2>nul"
  $t = [System.IO.File]::ReadAllText($tmp, $utf8); Remove-Item $tmp
  return $t.Replace("`r`n", "`n")
}
function Count($hay, $needle) { $n = 0; $i = 0; while (($i = $hay.IndexOf($needle, $i, [StringComparison]::Ordinal)) -ge 0) { $n++; $i++ }; return $n }
function JsonStr($s) {
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.Append('"')
  foreach ($ch in $s.ToCharArray()) {
    switch ($ch) {
      '"' { [void]$sb.Append('\"') } '\' { [void]$sb.Append('\\') }
      "`n" { [void]$sb.Append('\n') } "`t" { [void]$sb.Append('\t') } "`r" { [void]$sb.Append('\r') }
      default { if ([int]$ch -lt 32) { [void]$sb.Append(('\u{0:x4}' -f [int]$ch)) } else { [void]$sb.Append($ch) } }
    }
  }
  [void]$sb.Append('"'); return $sb.ToString()
}
$files = $Only
foreach ($f in $files) {
  $old = Show $Base $f; $new = Show 'HEAD' $f
  $done = $false
  foreach ($u in 2, 3, 5, 8, 12, 20) {
    $diff = (& $g -c core.quotepath=off diff "-U$u" $Base HEAD -- $f | Out-String)
    # git output via PowerShell is decoded with console codepage; re-read raw instead
    $tmp = [System.IO.Path]::GetTempFileName()
    cmd /c "`"$g`" diff -U$u $Base HEAD -- $f > `"$tmp`" 2>nul"
    $diff = [System.IO.File]::ReadAllText($tmp, $utf8).Replace("`r`n", "`n"); Remove-Item $tmp
    $edits = @(); $o = $null; $n = $null
    foreach ($line in $diff.Split("`n")) {
      if ($line.StartsWith('@@')) { if ($o -ne $null) { $edits += , @($o, $n) }; $o = New-Object System.Collections.ArrayList; $n = New-Object System.Collections.ArrayList; continue }
      if ($o -eq $null) { continue }
      if ($line.StartsWith('\')) { continue }
      if ($line.Length -eq 0) { continue }
      $c = $line.Substring(0, 1); $body = $line.Substring(1)
      if ($c -eq ' ') { [void]$o.Add($body); [void]$n.Add($body) } elseif ($c -eq '-') { [void]$o.Add($body) } elseif ($c -eq '+') { [void]$n.Add($body) }
    }
    if ($o -ne $null) { $edits += , @($o, $n) }
    $pairs = @(); $ok = $true; $sim = $old
    foreach ($e in $edits) {
      $os = ($e[0] -join "`n"); $ns = ($e[1] -join "`n")
      if ($os.Length -eq 0 -or (Count $sim $os) -ne 1) { $ok = $false; break }
      $idx = $sim.IndexOf($os, [StringComparison]::Ordinal)
      $sim = $sim.Substring(0, $idx) + $ns + $sim.Substring($idx + $os.Length)
      $pairs += , @($os, $ns)
    }
    if ($ok -and $sim.TrimEnd("`n") -eq $new.TrimEnd("`n")) {
      $json = '[' + (($pairs | ForEach-Object { '{"old_string":' + (JsonStr $_[0]) + ',"new_string":' + (JsonStr $_[1]) + '}' }) -join ',') + ']'
      $leaf = (Split-Path $f -Leaf) -replace '\.server\.luau$', '' -replace '\.client\.luau$', 'Client' -replace '\.luau$', ''
      [System.IO.File]::WriteAllText((Join-Path $OutDir "$leaf.json"), $json, $utf8)
      "{0} U{1} edits={2} chars={3}" -f $leaf, $u, $pairs.Count, $json.Length
      $done = $true; break
    }
  }
  if (-not $done) { "FAILED $f" }
}


