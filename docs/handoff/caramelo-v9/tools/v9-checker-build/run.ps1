$src = Get-Content -Raw (Join-Path $PSScriptRoot 'Geo.cs')
Add-Type -TypeDefinition $src -Language CSharp
try { [Geo]::Run() } catch { [Geo]::Out.ToString(); $_.Exception.InnerException.ToString() }
"FAILS: " + [Geo]::Fails
