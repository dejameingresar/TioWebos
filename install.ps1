# DiskGuardian installer (one-liner):
# irm https://raw.githubusercontent.com/dejameingresar/DiskGuardian/main/install.ps1 | iex
$ErrorActionPreference = "Stop"
$repo = "dejameingresar/DiskGuardian"
$branch = "main"
$base = "https://raw.githubusercontent.com/$repo/$branch"
$installDir = Join-Path $env:LOCALAPPDATA "DiskGuardian"
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
$gui = Join-Path $installDir "app\DiskGuardianGUI.ps1"
if (Test-Path $gui) {
    # Crear comando global 'tiodisk' (como 'hermes')
    $shimDir = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps"
    if (-not (Test-Path $shimDir)) { New-Item -ItemType Directory -Path $shimDir -Force | Out-Null }
    $shim = Join-Path $shimDir "tiodisk.cmd"
    $content = "@echo off`r`npowershell -Sta -ExecutionPolicy Bypass -File `"$installDir\app\DiskGuardianGUI.ps1`" %*"
    Set-Content -Path $shim -Value $content -Encoding ASCII
    Write-Host "Comando 'tiodisk' instalado. Abre una nueva terminal y escribe: tiodisk"
    Start-Process powershell -ArgumentList "-Sta -ExecutionPolicy Bypass -File `"$gui`""
} else {
    Write-Host "GUI no disponible."
}
PS