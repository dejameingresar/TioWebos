# TioWebos installer (one-liner):
# irm https://raw.githubusercontent.com/dejameingresar/TioWebos/main/install.ps1 | iex
$ErrorActionPreference = "Stop"
$repo = "dejameingresar/TioWebos"
$branch = "main"
$base = "https://raw.githubusercontent.com/$repo/$branch"
$installDir = Join-Path $env:LOCALAPPDATA "TioWebos"
$files = @(
  "app\DiskGuardian.ps1",
  "app\DiskGuardianGUI.ps1",
  "config.default.json"
)
foreach ($f in $files) {
    $dest = Join-Path $installDir $f
    $dir = Split-Path $dest -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $url = "$base/$($f -replace '\\','/')"
    try {
        Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
    } catch {
        Write-Host "No se pudo descargar $f : $($_.Exception.Message)"
    }
}
# config.json
$cfgDest = Join-Path $installDir "config.json"
if (-not (Test-Path $cfgDest)) {
    $cfgSrc = Join-Path $installDir "config.default.json"
    if (Test-Path $cfgSrc) { Copy-Item $cfgSrc $cfgDest -Force }
}
# Startup shortcut (permanent activation)
$startup = [Environment]::GetFolderPath('Startup')
$shortcutPath = Join-Path $startup "TioWebos.lnk"
$wsh = New-Object -ComObject WScript.Shell
$sc = $wsh.CreateShortcut($shortcutPath)
$sc.TargetPath = "powershell.exe"
$sc.Arguments = "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$installDir\app\DiskGuardian.ps1`" -ConfigPath `"$installDir\config.json`""
$sc.WorkingDirectory = $installDir
$sc.Save()
# tiowebos shim (renamed from tiodisk)
$shimDir = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps"
if (-not (Test-Path $shimDir)) { New-Item -ItemType Directory -Path $shimDir -Force | Out-Null }
$shim = Join-Path $shimDir "tiowebos.cmd"
$shimContent = "@echo off`r`npowershell -Sta -ExecutionPolicy Bypass -File `"$installDir\app\DiskGuardianGUI.ps1`" %*"
Set-Content -Path $shim -Value $shimContent -Encoding ASCII
# Remove old tiodisk shim if present
$oldShim = Join-Path $shimDir "tiodisk.cmd"
if (Test-Path $oldShim) { Remove-Item $oldShim -Force }
Write-Host "TioWebos instalado en: $installDir"
Write-Host "Activacion permanente: $shortcutPath"
Write-Host "Comando global: tiowebos"
$gui = Join-Path $installDir "app\DiskGuardianGUI.ps1"
if (Test-Path $gui) {
    Start-Process powershell -ArgumentList "-Sta -ExecutionPolicy Bypass -File `"$gui`""
}
PS