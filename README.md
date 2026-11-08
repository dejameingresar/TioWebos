# DiskGuardian

**Instalación rápida (como WinUtil):**
```powershell
irm https://raw.githubusercontent.com/dejameingresar/DiskGuardian/main/install.ps1 | iex
```

Después de instalar, abre una terminal y escribe `tiodisk` para abrir la GUI.

Vigilante de disco de bajo consumo para Windows. Detecta el proceso que satura el disco (por `% Disk Time`/latencia si los contadores funcionan, o por MB/s via CIM si estan rotos) y lo mata si se mantiene N minutos. No toca procesos de sistema.

## Requisitos
- Windows 10/11, PowerShell 5.1+
- Sin dependencias externas

## Uso rapido
```powershell
powershell -ExecutionPolicy Bypass -File .\DiskGuardian.ps1 -Once
```
Modo continuo:
```powershell
powershell -ExecutionPolicy Bypass -File .\DiskGuardian.ps1
```
Fondo:
```powershell
Start-Process powershell "-ExecutionPolicy Bypass -File C:\Users\TUUSUARIO\DiskGuardian\DiskGuardian.ps1" -WindowStyle Hidden
```

## Instalar como tarea (inicio de sesion)
```powershell
powershell -ExecutionPolicy Bypass -File .\Install.ps1
```

## Configuracion
Edita `config.json` (se crea desde `config.default.json`):
- `UmbralTotalMBs`, `UmbralProcMBs` (modo CIM)
- `UmbralPct`, `UmbralLatenciaMs` (modo contadores)
- `MinutosParaMatar`, `IntervaloSeg`, `LogPath`, `LogMaxMB`

## Log
`%TEMP%\disk-guardian.log` (rotacion automatica).

## Limitacion conocida
Si los contadores de rendimiento estan corruptos (error c0000bb8), el modo CIM mide throughput, no latencia. Para restaurar contadores: como admin `lodctr /R` + reinicio.

## Licencia
MIT
PS