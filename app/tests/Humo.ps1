# Suite de pruebas de DiskGuardian (prototipo disco)
$ErrorActionPreference = "Stop"
$guardian = Join-Path $PSScriptRoot "..\DiskGuardian.ps1"
$gui = Join-Path $PSScriptRoot "..\DiskGuardianGUI.ps1"
$instalar = Join-Path $PSScriptRoot "..\Instalar.ps1"
$desinstalar = Join-Path $PSScriptRoot "..\Desinstalar.ps1"
foreach ($f in @($guardian, $gui, $instalar, $desinstalar)) {
  if (-not (Test-Path $f)) { throw "No se encontro $f" }
}

# 1. Sintaxis de todos los scripts
foreach ($f in @($guardian, $gui, $instalar, $desinstalar)) {
  $errs = $null; $toks = $null
  [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $f), [ref]$toks, [ref]$errs) | Out-Null
  if ($errs.Count -gt 0) { throw ("Errores de sintaxis en $f : " + ($errs | ForEach-Object { $_.Message } -join "; ")) }
}
Write-Host "OK sintaxis (4 scripts)"

# 2. GUI solo-disco: no debe referenciar CPU/RAM ni llamar funciones inexistentes
$gtxt = Get-Content $gui -Raw
foreach ($muerto in @("dgCpu","dgRam","btnKillCpu","btnKillRam","CpuTop","RamTop")) {
  if ($gtxt -match [regex]::Escape($muerto)) { throw "GUI aun referencia '$muerto' (debio salir en recorte solo-disco)" }
}
foreach ($fn in @("function Sync-GuardianState","function Find-GuardianProcess")) {
  if ($gtxt -notmatch [regex]::Escape($fn)) { throw "GUI no define '$fn'" }
}
Write-Host "OK GUI solo-disco"

# 3. Ejecucion -Once con config temporal (no depende de rutas quemadas)
$tmpCfg = Join-Path $env:TEMP "disk-guardian-test-cfg.json"
$tmpLog = Join-Path $env:TEMP "disk-guardian-test-ci.log"
if (Test-Path $tmpLog) { Remove-Item $tmpLog -Force }
@{ UmbralTotalMBs=10; UmbralProcMBs=3; UmbralPct=85; UmbralLatenciaMs=100;
   MinutosParaMatar=5; IntervaloSeg=30; LogMaxMB=5; LogPath=$tmpLog; Protegidos=@() } |
  ConvertTo-Json | Out-File -FilePath $tmpCfg -Encoding utf8
& powershell -ExecutionPolicy Bypass -File $guardian -Once -ConfigPath $tmpCfg 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { throw "DiskGuardian -Once fallo con codigo $LASTEXITCODE" }
if (-not (Test-Path $tmpLog)) { throw "No se genero log en $tmpLog" }
$cont = Get-Content $tmpLog -Raw
if ($cont -notmatch "Guardian iniciado") { throw "Log sin mensaje de inicio" }
Write-Host "OK -Once"

# 4. -DryRun -Once tambien termina 0 y no mata nada
& powershell -ExecutionPolicy Bypass -File $guardian -Once -DryRun -ConfigPath $tmpCfg 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { throw "DiskGuardian -Once -DryRun fallo con codigo $LASTEXITCODE" }
Write-Host "OK -DryRun"

Remove-Item $tmpCfg -Force -ErrorAction SilentlyContinue
Write-Host "OK suite"
