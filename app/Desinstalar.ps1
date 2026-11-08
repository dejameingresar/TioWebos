param([string]$InstallDir = "C:\Users\$env:USERNAME\DiskGuardian")
$ErrorActionPreference = "SilentlyContinue"
Unregister-ScheduledTask -TaskName "DiskGuardian" -Confirm:$false
Remove-Item -Path $InstallDir -Recurse -Force
Write-Host "Desinstalado."
PS