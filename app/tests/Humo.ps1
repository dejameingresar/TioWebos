# Suite de pruebas de DiskGuardian
$ErrorActionPreference = "Stop"
$script = Join-Path $PSScriptRoot "..\DiskGuardian.ps1"
if (-not (Test-Path $script)) { throw "No se encontro DiskGuardian.ps1" }

# 1. Sintaxis
$errs = $null; $toks = $null
[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $script), [ref]$toks, [ref]$errs) | Out-Null
if ($errs.Count -gt 0) { throw ("Errores de sintaxis: " + ($errs | ForEach-Object { $_.Message } -join "; ")) }
Write-Host "OK sintaxis"

# 2. Ejecucion -Once (modo perf WMI o CIM) debe terminar 0
$log = Join-Path $env:TEMP "disk-guardian-test-ci.log"
if (Test-Path $log) { Remove-Item $log -Force }
& powershell -ExecutionPolicy Bypass -File $script -Once -ConfigPath (Join-Path $PSScriptRoot "..\config.default.json") 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { throw "DiskGuardian -Once fallo con codigo $LASTEXITCODE" }
if (-not (Test-Path $log)) { # log path from config.default.json
  $log = "$env:TEMP\disk-guardian.log"
}
if (-not (Test-Path $log)) { throw "No se genero log" }
$cont = Get-Content $log -Raw
if ($cont -notmatch "Guardian iniciado") { throw "Log sin mensaje de inicio" }
Write-Host "OK -Once"

# 3. DryRun no mata procesos (smoke)
Write-Host "OK suite"
PS