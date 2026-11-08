# DiskGuardian GUI - interfaz WPF estilo WinUtil
# Uso: powershell -Sta -ExecutionPolicy Bypass -File .\DiskGuardianGUI.ps1
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$mainScript = Join-Path $root "DiskGuardian.ps1"
$configPath = Join-Path (Split-Path $root -Parent) "config.json"
if (-not (Test-Path $configPath)) { $configPath = Join-Path (Split-Path $root -Parent) "config.default.json" }

function Get-PerfSnapshot {
    $res = @{ Pct=0; LatMs=0; Top=@() }
    try {
        $d = Get-CimInstance Win32_PerfFormattedData_PerfDisk_PhysicalDisk -ErrorAction Stop | Where-Object { $_.Name -eq '_Total' } | Select-Object -First 1
        if ($d) { $res.Pct = [math]::Round($d.PercentDiskTime,1); $res.LatMs = [math]::Round($d.AvgDisksecPerTransfer*1000,1) }
    } catch {}
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
        Title="DiskGuardian" Height="620" Width="760" WindowStartupLocation="CenterScreen">
  <Grid Margin="10">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>
    <StackPanel Grid.Row="0" Orientation="Horizontal" Margin="0,0,0,8">
      <TextBlock Text="Disco: " FontWeight="Bold"/>
      <TextBlock x:Name="txtPct" Text="0%" Width="60"/>
      <TextBlock Text="Latencia: " FontWeight="Bold" Margin="10,0,0,0"/>
      <TextBlock x:Name="txtLat" Text="0 ms" Width="80"/>
      <TextBlock x:Name="txtMode" Text="modo: perf WMI" Margin="10,0,0,0" Foreground="Gray"/>
    </StackPanel>
    <GroupBox Grid.Row="1" Header="Top procesos por I/O" Margin="0,0,0,8">
      <DataGrid x:Name="dgTop" AutoGenerateColumns="False" IsReadOnly="True" Height="180">
        <DataGrid.Columns>
          <DataGridTextColumn Header="Proceso" Binding="{Binding Name}" Width="*"/>
          <DataGridTextColumn Header="PID" Binding="{Binding Pid}" Width="80"/>
          <DataGridTextColumn Header="MB/s" Binding="{Binding MBs}" Width="80"/>
        </DataGrid.Columns>
      </DataGrid>
    </GroupBox>
    <GroupBox Grid.Row="2" Header="Log">
      <TextBox x:Name="txtLog" IsReadOnly="True" VerticalScrollBarVisibility="Auto" FontFamily="Consolas" FontSize="11"/>
    </GroupBox>
    <StackPanel Grid.Row="3" Orientation="Horizontal" Margin="0,8,0,0">
      <Button x:Name="btnRefresh" Content="Refrescar" Width="90" Margin="0,0,6,0"/>
      <Button x:Name="btnStart" Content="Iniciar guardian" Width="110" Margin="0,0,6,0"/>
      <Button x:Name="btnStop" Content="Detener" Width="80" Margin="0,0,6,0"/>
      <Button x:Name="btnKill" Content="Matar seleccionado" Width="130" Margin="0,0,6,0"/>
      <CheckBox x:Name="chkDry" Content="DryRun" VerticalAlignment="Center" Margin="10,0,0,0"/>
    </StackPanel>
  </Grid>
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
$btnStart = $window.FindName("btnStart")
$btnStop = $window.FindName("btnStop")
$btnKill = $window.FindName("btnKill")
$chkDry = $window.FindName("chkDry")

$guardianJob = $null

function Update-UI {
    $r = Get-PerfSnapshot
    $txtPct.Text = "$($r.Pct)%"
    $txtLat.Text = "$($r.LatMs) ms"
    $dgTop.ItemsSource = $r.Top
    # tail log
    $logPath = "$env:TEMP\disk-guardian.log"
    if (Test-Path $logPath) {
        $lines = Get-Content $logPath -Tail 40
        $txtLog.Text = ($lines -join "`r`n")
        $txtLog.ScrollToEnd()
    }
}

$btnRefresh.Add_Click({ Update-UI })

$btnStart.Add_Click({
    $args = "-ExecutionPolicy Bypass -File `"$mainScript`""
    if ($chkDry.IsChecked) { $args += " -DryRun" }
    $script:guardianJob = Start-Process powershell -ArgumentList $args -WindowStyle Hidden -PassThru
    [System.Windows.MessageBox]::Show("Guardian iniciado (PID $($script:guardianJob.Id)).")
})

$btnStop.Add_Click({
    if ($script:guardianJob -and -not $script:guardianJob.HasExited) {
        Stop-Process -Id $script:guardianJob.Id -Force
        [System.Windows.MessageBox]::Show("Guardian detenido.")
    } else {
        [System.Windows.MessageBox]::Show("No hay guardian en ejecucion.")
    }
})

$btnKill.Add_Click({
    $sel = $dgTop.SelectedItem
    if (-not $sel) { [System.Windows.MessageBox]::Show("Selecciona un proceso."); return }
    try {
        Stop-Process -Id $sel.Pid -Force -ErrorAction Stop
        [System.Windows.MessageBox]::Show("Proceso $($sel.Name) (PID $($sel.Pid)) terminado.")
        Update-UI
    } catch {
        [System.Windows.MessageBox]::Show("No se pudo matar: $($_.Exception.Message)")
    }
})

$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromSeconds(3)
$timer.Add_Tick({ Update-UI })
$timer.Start()

Update-UI
$window.ShowDialog() | Out-Null
if ($timer) { $timer.Stop() }
PS