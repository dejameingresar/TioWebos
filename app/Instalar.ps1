# Instalador de DiskGuardian (tarea programada al iniciar sesion)
param(
  [string]$InstallDir = "C:\Users\$env:USERNAME\DiskGuardian",
  [string]$ConfigPath = ""
)
$ErrorActionPreference = "Stop"
if (-not (Test-Path $InstallDir)) { New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null }
Copy-Item -Path "$PSScriptRoot\DiskGuardian.ps1" -Destination "$InstallDir\DiskGuardian.ps1" -Force
if ($ConfigPath -and (Test-Path $ConfigPath)) {
  Copy-Item -Path $ConfigPath -Destination "$InstallDir\config.json" -Force
} elseif (-not (Test-Path "$InstallDir\config.json")) {
  Copy-Item -Path "$PSScriptRoot\config.default.json" -Destination "$InstallDir\config.json" -Force
}
$taskName = "DiskGuardian"
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$InstallDir\DiskGuardian.ps1`" -ConfigPath `"$InstallDir\config.json`""
$trigger = New-ScheduledTaskTrigger -AtLogOn
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null
Write-Host "Instalado. Tarea '$taskName' creada. Inicia al iniciar sesion."
Write-Host "Para arrancar ahora: Start-ScheduledTask -TaskName $taskName"
PS