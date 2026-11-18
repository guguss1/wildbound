[System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::InvariantCulture
$src = Get-Content -Raw (Join-Path $PSScriptRoot 'Geo9.cs')
Add-Type -TypeDefinition $src -Language CSharp
try { [Geo]::Run() } catch { [Geo]::Out.ToString(); $_.Exception.ToString() }
"FAILS: " + [Geo]::Fails
