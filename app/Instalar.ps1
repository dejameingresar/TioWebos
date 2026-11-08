# TioWebos installer (permanent activation via Startup folder)
param(
  [string]$InstallDir = "C:\Users\$env:USERNAME\AppData\Local\TioWebos",
  [string]$ConfigPath = ""
)
$ErrorActionPreference = "Stop"
$src = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path $src -Parent
if (-not (Test-Path $InstallDir)) { New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null }
if (-not (Test-Path "$InstallDir\app")) { New-Item -ItemType Directory -Path "$InstallDir\app" -Force | Out-Null }
Copy-Item -Path "$src\DiskGuardian.ps1" -Destination "$InstallDir\app\DiskGuardian.ps1" -Force
Copy-Item -Path "$src\DiskGuardianGUI.ps1" -Destination "$InstallDir\app\DiskGuardianGUI.ps1" -Force
if ($ConfigPath -and (Test-Path $ConfigPath)) {
  Copy-Item -Path $ConfigPath -Destination "$InstallDir\config.json" -Force
} elseif (-not (Test-Path "$InstallDir\config.json")) {
  $def = Join-Path $root "config.default.json"
  if (Test-Path $def) { Copy-Item -Path $def -Destination "$InstallDir\config.json" -Force }
}
$startup = [Environment]::GetFolderPath('Startup')
$shortcutPath = Join-Path $startup "TioWebos.lnk"
$wsh = New-Object -ComObject WScript.Shell
$sc = $wsh.CreateShortcut($shortcutPath)
$sc.TargetPath = "powershell.exe"
$sc.Arguments = "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$InstallDir\app\DiskGuardian.ps1`" -ConfigPath `"$InstallDir\config.json`""
$sc.WorkingDirectory = $InstallDir
$sc.Save()
Write-Host "Instalado permanentemente. Se iniciara al arrancar Windows."
Write-Host "Acceso directo creado en: $shortcutPath"
PS