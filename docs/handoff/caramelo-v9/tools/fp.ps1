param([string]$Rev = 'HEAD', [string[]]$Files)
Set-Location "E:\juego roblox\wb-first-playable"
$g = (Get-ChildItem "C:\Users\Agustina\AppData\Local\GitHubDesktop\app-*\resources\app\git\cmd\git.exe" | Select-Object -Last 1).FullName
$utf8 = New-Object System.Text.UTF8Encoding($false)
foreach ($f in $Files) {
  $tmp = [System.IO.Path]::GetTempFileName()
  cmd /c "`"$g`" show ${Rev}:$f > `"$tmp`" 2>nul"
  $t = [System.IO.File]::ReadAllText($tmp, $utf8); Remove-Item $tmp
  $t = $t.Replace("`r`n", "`n").TrimEnd("`n")
  $bytes = $utf8.GetBytes($t)
  [long]$a = 1; [long]$b = 0
  foreach ($x in $bytes) { $a = ($a + $x) % 65521; $b = ($b + $a) % 65521 }
  "{0} {1} len={2} adler={3}" -f $Rev, $f, $bytes.Length, (($b * 65536) + $a)
}
