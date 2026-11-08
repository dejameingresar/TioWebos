# DiskGuardian GUI - interfaz WPF solo-DISCO (Win10 compatible)
# Prototipo: categoria disco unicamente. CPU/RAM pendientes.
# Uso: powershell -Sta -ExecutionPolicy Bypass -File .\DiskGuardianGUI.ps1
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$parent = Split-Path $root -Parent
$mainScript = Join-Path $root "DiskGuardian.ps1"
$installScript = Join-Path $root "Instalar.ps1"
$configPath = Join-Path $parent "config.json"
if (-not (Test-Path $configPath)) { $configPath = Join-Path $parent "config.default.json" }

$presets = @{
    "chill" = @{ UmbralTotalMBs=20; UmbralProcMBs=8; UmbralPct=90; UmbralLatenciaMs=200; MinutosParaMatar=10; IntervaloSeg=60 }
    "balance" = @{ UmbralTotalMBs=10; UmbralProcMBs=3; UmbralPct=85; UmbralLatenciaMs=100; MinutosParaMatar=5; IntervaloSeg=30 }
    "atrevido" = @{ UmbralTotalMBs=5; UmbralProcMBs=1.5; UmbralPct=70; UmbralLatenciaMs=50; MinutosParaMatar=2; IntervaloSeg=15 }
}

# Nombres que la GUI nunca ofrece matar (defensa en la capa manual)
$NombresSistemaGUI = @('system','registry','memory compression','smss.exe','csrss.exe','wininit.exe',
  'services.exe','lsass.exe','lsaiso.exe','winlogon.exe','dwm.exe','fontdrvhost.exe',
  'svchost.exe','sihost.exe','ctfmon.exe','explorer.exe','audiodg.exe','conhost.exe',
  'taskhostw.exe','idle','secure system','registry')

function Get-PerfSnapshot {
    $res = @{ Pct=0; LatMs=0; Top=@() }
    try {
        $d = Get-CimInstance Win32_PerfFormattedData_PerfDisk_PhysicalDisk -ErrorAction Stop | Where-Object { $_.Name -eq '_Total' } | Select-Object -First 1
        if ($d) { $res.Pct = [math]::Round($d.PercentDiskTime,1); $res.LatMs = [math]::Round($d.AvgDisksecPerTransfer*1000,1) }
    } catch {}
    # Una sola query de procesos, reutilizada para el top de I/O
    try {
        $procs = Get-CimInstance Win32_PerfFormattedData_PerfProc_Process -ErrorAction Stop |
            Where-Object { $_.Name -notin '_Total','Idle' -and $_.IDProcess -gt 0 } |
            Sort-Object IODataBytesPersec -Descending | Select-Object -First 8
        foreach ($p in $procs) {
            $gp = Get-Process -Id $p.IDProcess -ErrorAction SilentlyContinue
            $name = if ($gp) { $gp.ProcessName } else { $p.Name }
            $res.Top += [pscustomobject]@{ Name=$name; Pid=$p.IDProcess; MBs=[math]::Round($p.IODataBytesPersec/1MB,2) }
        }
    } catch {}
    return $res
}

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="TioWebos - Disco" Height="620" Width="820" WindowStartupLocation="CenterScreen">
  <ScrollViewer VerticalScrollBarVisibility="Auto">
  <StackPanel Margin="12">
    <TextBlock Text="TioWebos - Disco" FontSize="22" FontWeight="Bold" Margin="0,0,0,4"/>
    <TextBlock Text="Vigilante de disco interactivo (prototipo: solo disco)" Foreground="Gray" Margin="0,0,0,10"/>

    <GroupBox Header="1. Modo de guardia" Margin="0,0,0,10">
      <StackPanel>
        <RadioButton x:Name="rbChill" Content="De chill (suave)" Margin="0,2"/>
        <TextBlock Text="Umbrales altos, espera 10 min. Ideal si no quieres falsos positivos." FontSize="10" Foreground="Gray" Margin="20,0,0,6"/>
        <RadioButton x:Name="rbBalance" Content="Si le sabes al balance (normal)" Margin="0,2" IsChecked="True"/>
        <TextBlock Text="Equilibrio entre deteccion y paciencia. Recomendado." FontSize="10" Foreground="Gray" Margin="20,0,0,6"/>
        <RadioButton x:Name="rbAtrevido" Content="Atrevido (agresivo)" Margin="0,2"/>
        <TextBlock Text="Umbrales bajos, espera 2 min. Mata rapido. Usar con cuidado." FontSize="10" Foreground="Gray" Margin="20,0,0,6"/>
        <Button x:Name="btnHelp" Content="?" Width="30" HorizontalAlignment="Left" Margin="0,6,0,0"/>
      </StackPanel>
    </GroupBox>

    <GroupBox Header="2. Como lo quieres usar" Margin="0,0,0,10">
      <StackPanel Orientation="Horizontal">
        <Button x:Name="btnProbar" Content="Probar esta sesion" Width="160" Margin="0,0,8,0"/>
        <Button x:Name="btnPerma" Content="Activar permanentemente" Width="180" Margin="0,0,8,0"/>
        <TextBlock x:Name="txtEstado" Text="Estado: inactivo" VerticalAlignment="Center" Margin="10,0,0,0"/>
      </StackPanel>
    </GroupBox>

    <GroupBox Header="Estado del disco" Margin="0,0,0,10">
      <StackPanel Orientation="Horizontal">
        <TextBlock Text="Disco: " FontWeight="Bold"/>
        <TextBlock x:Name="txtPct" Text="0%" Width="60"/>
        <TextBlock Text="Latencia: " FontWeight="Bold" Margin="10,0,0,0"/>
        <TextBlock x:Name="txtLat" Text="0 ms" Width="80"/>
        <TextBlock x:Name="txtMode" Text="modo: perf WMI" Margin="10,0,0,0" Foreground="Gray"/>
      </StackPanel>
    </GroupBox>

    <GroupBox Header="Top procesos por I/O" Margin="0,0,0,10">
      <DataGrid x:Name="dgTop" AutoGenerateColumns="False" IsReadOnly="True" Height="150">
        <DataGrid.Columns>
          <DataGridTextColumn Header="Proceso" Binding="{Binding Name}" Width="*"/>
          <DataGridTextColumn Header="PID" Binding="{Binding Pid}" Width="80"/>
          <DataGridTextColumn Header="MB/s" Binding="{Binding MBs}" Width="80"/>
        </DataGrid.Columns>
      </DataGrid>
    </GroupBox>

    <GroupBox Header="Log" Margin="0,0,0,10">
      <TextBox x:Name="txtLog" IsReadOnly="True" VerticalScrollBarVisibility="Auto" Height="160" FontFamily="Consolas" FontSize="11"/>
    </GroupBox>

    <StackPanel Orientation="Horizontal">
      <Button x:Name="btnRefresh" Content="Refrescar" Width="90" Margin="0,0,6,0"/>
      <Button x:Name="btnStop" Content="Detener" Width="80" Margin="0,0,6,0"/>
      <Button x:Name="btnKill" Content="Matar seleccionado" Width="130" Margin="0,0,6,0"/>
      <CheckBox x:Name="chkDry" Content="DryRun" VerticalAlignment="Center" Margin="10,0,0,0"/>
    </StackPanel>
  </StackPanel>
  </ScrollViewer>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

$txtPct = $window.FindName("txtPct")
$txtLat = $window.FindName("txtLat")
$txtMode = $window.FindName("txtMode")
$dgTop = $window.FindName("dgTop")
$txtLog = $window.FindName("txtLog")
$btnRefresh = $window.FindName("btnRefresh")
$btnStop = $window.FindName("btnStop")
$btnKill = $window.FindName("btnKill")
$chkDry = $window.FindName("chkDry")
$btnProbar = $window.FindName("btnProbar")
$btnPerma = $window.FindName("btnPerma")
$txtEstado = $window.FindName("txtEstado")
$btnHelp = $window.FindName("btnHelp")
$rbChill = $window.FindName("rbChill")
$rbBalance = $window.FindName("rbBalance")
$rbAtrevido = $window.FindName("rbAtrevido")

$guardianJob = $null

function Find-GuardianProcess {
    try {
        $procs = Get-CimInstance Win32_Process -ErrorAction Stop |
            Where-Object { $_.Name -match '^(powershell|pwsh)(\.exe)?$' -and $_.CommandLine -match 'DiskGuardian\.ps1' }
        if ($procs) { return ($procs | Select-Object -First 1) }
    } catch {}
    return $null
}

function Sync-GuardianState {
    $p = Find-GuardianProcess
    if ($p) { $txtEstado.Text = "Estado: activo (PID $($p.ProcessId))" }
    elseif ($script:guardianJob -and -not $script:guardianJob.HasExited) { $txtEstado.Text = "Estado: activo (PID $($script:guardianJob.Id))" }
    else { $txtEstado.Text = "Estado: inactivo" }
}

function Get-SelectedMode {
    if ($rbChill.IsChecked) { return "chill" }
    if ($rbAtrevido.IsChecked) { return "atrevido" }
    return "balance"
}

function Apply-ModeToConfig {
    $m = Get-SelectedMode
    $p = $presets[$m]
    $cfg = @{
        UmbralTotalMBs = $p.UmbralTotalMBs
        UmbralProcMBs = $p.UmbralProcMBs
        UmbralPct = $p.UmbralPct
        UmbralLatenciaMs = $p.UmbralLatenciaMs
        MinutosParaMatar = $p.MinutosParaMatar
        IntervaloSeg = $p.IntervaloSeg
        LogMaxMB = 5
        LogPath = "%TEMP%\disk-guardian.log"
        Protegidos = @()
    }
    # No pisar Protegidos que el usuario ya haya personalizado
    try {
        if (Test-Path $configPath) {
            $prev = Get-Content $configPath -Raw | ConvertFrom-Json
            if ($prev.Protegidos) { $cfg.Protegidos = $prev.Protegidos }
        }
    } catch {}
    $cfg | ConvertTo-Json | Out-File -FilePath $configPath -Encoding utf8
    $txtMode.Text = "modo: $m"
}

function Update-UI {
    $r = Get-PerfSnapshot
    $txtPct.Text = "$($r.Pct)%"
    $txtLat.Text = "$($r.LatMs) ms"
    $dgTop.ItemsSource = $r.Top
    $logPath = "$env:TEMP\disk-guardian.log"
    if (Test-Path $logPath) {
        $lines = Get-Content $logPath -Tail 40
        $txtLog.Text = ($lines -join "`r`n")
        $txtLog.ScrollToEnd()
    }
}

$btnRefresh.Add_Click({ Update-UI })
Sync-GuardianState

$btnHelp.Add_Click({
    $msg = "De chill: umbrales altos, espera 10 min. Casi no mata nada.`n`n" +
           "Si le sabes al balance: valores por defecto, equilibrio.`n`n" +
           "Atrevido: umbrales bajos, espera 2 min. Mata rapido. Usar con cuidado."
    [System.Windows.MessageBox]::Show($msg, "Modos de guardia")
})

$btnProbar.Add_Click({
    $ya = Find-GuardianProcess
    if ($ya -or ($script:guardianJob -and -not $script:guardianJob.HasExited)) {
        [System.Windows.MessageBox]::Show("Ya hay un guardian corriendo. Detenlo antes de iniciar otro.")
        Sync-GuardianState
        return
    }
    Apply-ModeToConfig
    $txtEstado.Text = "Estado: probando esta sesion (en segundo plano)"
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = "-ExecutionPolicy Bypass -File `"$mainScript`" -ConfigPath `"$configPath`"" + $(if ($chkDry.IsChecked) { " -DryRun" } else { "" })
    $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    $psi.CreateNoWindow = $true
    $psi.UseShellExecute = $false
    $proc = [System.Diagnostics.Process]::Start($psi)
    $script:guardianJob = $proc
    Sync-GuardianState
    [System.Windows.MessageBox]::Show("Guardian iniciado en segundo plano (PID $($proc.Id)). Se mantiene aunque cierres esta ventana.")
})

$btnPerma.Add_Click({
    Apply-ModeToConfig
    if (Test-Path $installScript) {
        Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$installScript`" -ConfigPath `"$configPath`""
        $txtEstado.Text = "Estado: activado permanente"
        [System.Windows.MessageBox]::Show("Activacion permanente creada. Se iniciara al arrancar Windows.")
    } else {
        [System.Windows.MessageBox]::Show("No se encontro Instalar.ps1")
    }
})

$btnStop.Add_Click({
    $p = Find-GuardianProcess
    if ($p) {
        try { Stop-Process -Id $p.ProcessId -Force -ErrorAction Stop } catch {}
        $txtEstado.Text = "Estado: detenido"
        [System.Windows.MessageBox]::Show("Guardian detenido.")
    } elseif ($script:guardianJob -and -not $script:guardianJob.HasExited) {
        Stop-Process -Id $script:guardianJob.Id -Force
        $txtEstado.Text = "Estado: detenido"
        [System.Windows.MessageBox]::Show("Guardian detenido.")
    } else {
        [System.Windows.MessageBox]::Show("No hay guardian en ejecucion.")
    }
    Sync-GuardianState
})

$btnKill.Add_Click({
    $sel = $dgTop.SelectedItem
    if (-not $sel) { [System.Windows.MessageBox]::Show("Selecciona un proceso."); return }
    $nm = "$($sel.Name)".ToLower()
    if ($NombresSistemaGUI -contains $nm -or $nm -eq "powershell" -or $nm -eq "pwsh") {
        [System.Windows.MessageBox]::Show("'$($sel.Name)' parece de sistema o es una consola. No lo mato por seguridad.")
        return
    }
    $r = [System.Windows.MessageBox]::Show("Terminar '$($sel.Name)' (PID $($sel.Pid))?`nGuarda tu trabajo antes.", "Confirmar", "YesNo", "Warning")
    if ($r -ne "Yes") { return }
    try {
        $pr = Get-Process -Id $sel.Pid -ErrorAction Stop
        try { $pr.CloseMainWindow() | Out-Null } catch {}
        if (-not $pr.WaitForExit(8000)) { Stop-Process -Id $sel.Pid -Force -ErrorAction Stop }
        [System.Windows.MessageBox]::Show("Proceso $($sel.Name) (PID $($sel.Pid)) terminado.")
        Update-UI
    } catch {
        $errMsg = $_.Exception.Message
        [System.Windows.MessageBox]::Show("No se pudo matar: $errMsg")
    }
})
$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromSeconds(5)
$timer.Add_Tick({ Update-UI })
$timer.Start()

Update-UI
$window.ShowDialog() | Out-Null
if ($timer) { $timer.Stop() }
