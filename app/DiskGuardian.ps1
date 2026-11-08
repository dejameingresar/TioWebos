# DiskGuardian - vigilante de disco de bajo consumo (prototipo: SOLO disco)
# Detecta el proceso que satura el disco (por %/latencia si los contadores funcionan,
# o por MB/s via CIM si estan rotos) y lo mata si se mantiene N minutos.
# No toca procesos de sistema. Cierre graceful antes de matar. Todo queda en el log.
#
# Uso:
#   powershell -ExecutionPolicy Bypass -File .\DiskGuardian.ps1
#   powershell -ExecutionPolicy Bypass -File .\DiskGuardian.ps1 -ConfigPath .\config.json
#   powershell -ExecutionPolicy Bypass -File .\DiskGuardian.ps1 -Once
# Fondo:
#   Start-Process powershell "-ExecutionPolicy Bypass -File C:\...\DiskGuardian.ps1" -WindowStyle Hidden

param(
  [string]$ConfigPath = "",
  [switch]$Once,
  [switch]$DryRun
)

$ErrorActionPreference = "SilentlyContinue"

$DefaultConfig = @{
  UmbralTotalMBs    = 10       # MB/s totales para considerar saturacion (modo CIM)
  UmbralProcMBs     = 3        # MB/s del proceso dominante
  UmbralPct         = 85       # % Disk Time (modo contadores)
  UmbralLatenciaMs  = 100      # ms Avg Disk sec/Transfer (modo contadores)
  MinutosParaMatar  = 5        # minutos sostenidos antes de matar
  IntervaloSeg      = 30       # segundos entre chequeos
  LogMaxMB          = 5        # rotacion de log
  LogPath           = "%TEMP%\disk-guardian.log"
  Protegidos        = @()      # nombres extra que nunca se matan, ej: @('obs64.exe','idea64.exe')
}

function Load-Config($path) {
  $cfg = $DefaultConfig.Clone()
  if ($path -and (Test-Path $path)) {
    try {
      $j = Get-Content $path -Raw | ConvertFrom-Json
      foreach ($k in $j.PSObject.Properties.Name) {
        if ($cfg.ContainsKey($k)) { $cfg[$k] = $j.$k }
      }
    } catch {}
  }
  # LogPath portable: expande %VAR% y acepta vacio (= default)
  try {
    if ([string]::IsNullOrWhiteSpace($cfg.LogPath)) { $cfg.LogPath = $DefaultConfig.LogPath }
    $cfg.LogPath = [System.Environment]::ExpandEnvironmentVariables($cfg.LogPath)
  } catch {}
  if (-not $cfg.Protegidos) { $cfg.Protegidos = @() }
  return $cfg
}

$cfg = Load-Config $ConfigPath
$LogPath = $cfg.LogPath

$Criticos = @('system','registry','memory compression','smss.exe','csrss.exe','wininit.exe',
  'services.exe','lsass.exe','lsaiso.exe','winlogon.exe','dwm.exe','fontdrvhost.exe',
  'svchost.exe','sihost.exe','ctfmon.exe','explorer.exe','audiodg.exe','conhost.exe',
  'taskhostw.exe','idle','secure system','registry')

function Es-Sistema($nombre, $ruta, $ProcId) {
  if ($ProcId -le 4) { return $true }
  if ([string]::IsNullOrEmpty($nombre)) { return $true }
  if ($Criticos -contains $nombre.ToLower()) { return $true }
  foreach ($p in $cfg.Protegidos) {
    if ($nombre.ToLower() -eq ([string]$p).ToLower()) { return $true }
  }
  if ([string]::IsNullOrEmpty($ruta)) { return $true }
  $rl = $ruta.ToLower()
  if ($rl.StartsWith($env:SystemRoot.ToLower())) { return $true }
  if ($rl.Contains('\windowsapps\')) { return $true }
  return $false
}

function Write-Log($msg) {
  $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $msg"
  try {
    if (Test-Path $LogPath) {
      $sz = (Get-Item $LogPath).Length / 1MB
      if ($sz -gt $cfg.LogMaxMB) {
        $bak = $LogPath + ".old"
        if (Test-Path $bak) { Remove-Item $bak -Force }
        Rename-Item $LogPath $bak -Force
      }
    }
    $line | Out-File -FilePath $LogPath -Append -Encoding utf8
  } catch {}
  Write-Host $line
}

# Cierre graceful: pide cierre normal, espera 8s, y solo entonces fuerza.
function Stop-ProcesoSuave($ProcId) {
  try {
    $pr = Get-Process -Id $ProcId -ErrorAction Stop
    try { $pr.CloseMainWindow() | Out-Null } catch {}
    if ($pr.WaitForExit(8000)) { return "cerrado-graceful" }
  } catch {}
  Stop-Process -Id $ProcId -Force -ErrorAction Stop
  return "forzado"
}

function Test-PerfWMI {
  try {
    $d = Get-CimInstance Win32_PerfFormattedData_PerfDisk_PhysicalDisk -ErrorAction Stop | Where-Object { $_.Name -eq '_Total' }
    if ($null -eq $d) { return $false }
    return $true
  } catch { return $false }
}

$UsePerfWMI = Test-PerfWMI

function Get-SnapshotCIM {
  $s = @{}
  try {
    foreach ($p in (Get-CimInstance Win32_Process -ErrorAction Stop)) {
      $total = 0
      try { $total = [double]$p.ReadTransferCount + [double]$p.WriteTransferCount } catch {}
      $s[$p.ProcessId] = @{ Name=$p.Name; Path=$p.ExecutablePath; Total=$total }
    }
  } catch {}
  return $s
}

function Get-PerfSnapshot {
  $res = @{ Pct=0; LatMs=0; Top=@() }
  try {
    $d = Get-CimInstance Win32_PerfFormattedData_PerfDisk_PhysicalDisk -ErrorAction Stop | Where-Object { $_.Name -eq '_Total' } | Select-Object -First 1
    if ($d) {
      $res.Pct = [math]::Round($d.PercentDiskTime,1)
      $res.LatMs = [math]::Round($d.AvgDisksecPerTransfer*1000,1)
    }
  } catch {}
  try {
    $procs = Get-CimInstance Win32_PerfFormattedData_PerfProc_Process -ErrorAction Stop |
      Where-Object { $_.Name -notin '_Total','Idle' -and $_.IDProcess -gt 0 } |
      Sort-Object IODataBytesPersec -Descending | Select-Object -First 3
    foreach ($p in $procs) {
      $gp = Get-Process -Id $p.IDProcess -ErrorAction SilentlyContinue
      $path = if ($gp) { $gp.Path } else { $null }
      $name = if ($gp) { $gp.ProcessName + '.exe' } else { $p.Name }
      $res.Top += [pscustomobject]@{ Name=$name; Pid=$p.IDProcess; Path=$path; Cooked=$p.IODataBytesPersec }
    }
  } catch {}
  return $res
}

# Registra un cheque sostenido. Clave = nombre+PID: si el PID cambia, el conteo reinicia.
function Add-Cheque($clave, $ProcId) {
  if (-not $historial.ContainsKey($clave)) { $historial[$clave] = @{ Veces=1; Pid=$ProcId } }
  else { $historial[$clave].Veces++; $historial[$clave].Pid = $ProcId }
  foreach ($k in @($historial.Keys)) { if ($k -ne $clave) { $historial.Remove($k) } }
  return $historial[$clave].Veces
}

function Invoke-Matar($nombre, $ProcId, $detalle) {
  if ($DryRun) {
    Write-Log "DRYRUN: habria matado $nombre PID $ProcId. $detalle"
    return
  }
  try {
    if ($ProcId -gt 0) {
      $modo = Stop-ProcesoSuave $ProcId
      Write-Log "MATADO $nombre PID $ProcId ($modo) tras $($cfg.MinutosParaMatar)min. $detalle"
    }
  } catch {
    Write-Log ("NO SE PUDO MATAR " + $nombre + " PID " + $ProcId + ": " + $_.Exception.Message)
  }
}

# Estado sostenido por proceso (clave nombre+PID)
$historial = @{}
$necesarias = [math]::Ceiling(($cfg.MinutosParaMatar*60)/$cfg.IntervaloSeg)

Write-Log "Guardian iniciado. Modo=$(if($UsePerfWMI){'perf WMI'}else{'CIM deltas (mide I/O total, no solo disco)'}). Umbrales: total>$($cfg.UmbralTotalMBs)MB/s proc>$($cfg.UmbralProcMBs)MB/s pct>$($cfg.UmbralPct)% lat>$($cfg.UmbralLatenciaMs)ms. Matar tras $($cfg.MinutosParaMatar)min ($necesarias cheques). Intervalo $($cfg.IntervaloSeg)s. DryRun=$DryRun"

if ($Once) {
  if ($UsePerfWMI) {
    $r = Get-PerfSnapshot
    Write-Log "SNAPSHOT pct=$($r.Pct)% lat=$($r.LatMs)ms topCount=$($r.Top.Count)"
    foreach ($t in $r.Top) { Write-Log ("  " + $t.Name + " PID " + $t.Pid + " " + [math]::Round($t.Cooked/1MB,2) + "MB/s") }
  } else {
    $s = Get-SnapshotCIM
    Write-Log "SNAPSHOT procesos=$($s.Count)"
  }
  exit 0
}

$prev = Get-SnapshotCIM
while ($true) {
  Start-Sleep -Seconds $cfg.IntervaloSeg

  if ($UsePerfWMI) {
    $r = Get-PerfSnapshot
    $saturado = ($r.Pct -ge $cfg.UmbralPct) -or ($r.LatMs -ge $cfg.UmbralLatenciaMs)
    $topTxt = if ($r.Top) { ($r.Top | ForEach-Object { '{0}={1}MB/s' -f $_.Name,[math]::Round($_.Cooked/1MB,2) }) -join ' ' } else { '(sin actividad)' }
    if (-not $saturado) { $historial.Clear(); continue }
    # proceso dominante: primer top
    $g = if ($r.Top) { $r.Top[0] } else { $null }
    $gName = if ($g) { $g.Name } else { $null }
    if (-not $gName) { $historial.Clear(); continue }
    $gPid = if ($g) { $g.Pid } else { 0 }
    $gPath = if ($g) { $g.Path } else { $null }
    if (Es-Sistema $gName $gPath $gPid) {
      Write-Log "SATURADO pct=$($r.Pct)% lat=$($r.LatMs)ms pero es SISTEMA/protegido ($gName): $topTxt"
      $historial.Clear()
      continue
    }
    $clave = "$gName#$gPid"
    $v = Add-Cheque $clave $gPid
    Write-Log "SATURADO pct=$($r.Pct)% lat=$($r.LatMs)ms culpable=$gName PID $gPid ($v/$necesarias): $topTxt"
    if ($v -ge $necesarias) {
      Invoke-Matar $gName $gPid "pct=$($r.Pct)% lat=$($r.LatMs)ms"
      $historial.Remove($clave)
    }
  } else {
    $curr = Get-SnapshotCIM
    $tasas = @()
    $totalBs = 0
    foreach ($procId in $curr.Keys) {
      if (-not $prev.ContainsKey($procId)) { continue }
      $d = $curr[$procId].Total - $prev[$procId].Total
      if ($d -lt 0) { $d = 0 }
      $bs = $d / $cfg.IntervaloSeg
      $totalBs += $bs
      if ($bs -gt 0) { $tasas += [pscustomobject]@{ Pid=$procId; Name=$curr[$procId].Name; Path=$curr[$procId].Path; Bs=$bs } }
    }
    $prev = $curr
    $totalMBs = [math]::Round($totalBs/1MB,2)
    $top = $tasas | Sort-Object Bs -Descending | Select-Object -First 3
    $topTxt = if ($top) { ($top | ForEach-Object { '{0}(PID {1})={2}MB/s' -f $_.Name,$_.Pid,[math]::Round($_.Bs/1MB,2) }) -join ' ' } else { '(sin actividad)' }
    if ($totalMBs -lt $cfg.UmbralTotalMBs) { $historial.Clear(); continue }
    if (-not $top -or (($top[0].Bs/1MB) -lt $cfg.UmbralProcMBs)) {
      Write-Log "SATURADO total=${totalMBs}MB/s pero disperso (nadie domina): $topTxt"
      continue
    }
    $g = $top[0]
    $gMBs = [math]::Round($g.Bs/1MB,2)
    $base = $g.Name
    if (Es-Sistema $g.Name $g.Path $g.Pid) {
      Write-Log "SATURADO total=${totalMBs}MB/s pero es SISTEMA/protegido ($base PID $($g.Pid)): $topTxt"
      continue
    }
    $clave = "$base#$($g.Pid)"
    $v = Add-Cheque $clave $g.Pid
    Write-Log "SATURADO total=${totalMBs}MB/s culpable=$base PID $($g.Pid) ${gMBs}MB/s ($v/$necesarias): $topTxt"
    if ($v -ge $necesarias) {
      Invoke-Matar $base $g.Pid "a ${gMBs}MB/s. Total=${totalMBs}MB/s"
      $historial.Remove($clave)
    }
  }
}
