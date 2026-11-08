# TioWebos desinstalador: revierte TODO lo que install.ps1 / Instalar.ps1 crean.
# Uso: powershell -ExecutionPolicy Bypass -File .\Desinstalar.ps1
param(
  [string]$InstallDir = ""
)
$ErrorActionPreference = "SilentlyContinue"
if ([string]::IsNullOrWhiteSpace($InstallDir)) { $InstallDir = Join-Path $env:LOCALAPPDATA "TioWebos" }

# 1. Matar guardianes en ejecucion (powershell y pwsh)
try {
  $gs = Get-CimInstance Win32_Process -ErrorAction Stop |
    Where-Object { $_.Name -match '^(powershell|pwsh)(\.exe)?$' -and $_.CommandLine -match 'DiskGuardian\.ps1' }
  foreach ($g in $gs) { Stop-Process -Id $g.ProcessId -Force -ErrorAction SilentlyContinue }
  if ($gs) { Write-Host "Guardian detenido ($($gs.Count))." }
} catch {}

# 2. Quitar acceso directo de Startup
$startup = [Environment]::GetFolderPath('Startup')
$lnk = Join-Path $startup "TioWebos.lnk"
if (Test-Path $lnk) { Remove-Item $lnk -Force; Write-Host "Quitado: $lnk" }

# 3. Quitar shims globales
$shimDir = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps"
foreach ($s in @("tiowebos.cmd","tiodisk.cmd")) {
  $p = Join-Path $shimDir $s
  if (Test-Path $p) { Remove-Item $p -Force; Write-Host "Quitado: $p" }
}

# 4. Borrar carpeta de instalacion
if (Test-Path $InstallDir) { Remove-Item -Path $InstallDir -Recurse -Force; Write-Host "Borrado: $InstallDir" }

# 5. Restos de rutas viejas (versiones anteriores del proyecto)
foreach ($old in @("$env:LOCALAPPDATA\DiskGuardian", "C:\Users\$env:USERNAME\DiskGuardian")) {
  if ($old -ne $InstallDir -and (Test-Path $old)) { Remove-Item -Path $old -Recurse -Force; Write-Host "Borrado resto viejo: $old" }
}

Write-Host "Desinstalado."
