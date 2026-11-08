# TioWebos

Programa de optimizacion para Windows (secciones: Disco, CPU, RAM).

**Instalación rápida (como WinUtil):**
```powershell
irm https://raw.githubusercontent.com/dejameingresar/DiskGuardian/main/install.ps1 | iex
```

## Abrir desde cualquier lugar

Después de instalar, abre PowerShell o CMD en cualquier carpeta y escribe:

```powershell
tiodisk
```

Se abre la GUI. El guardian puede quedar corriendo en segundo plano aunque cierres la ventana.

Vigilante de disco de bajo consumo para Windows. Detecta el proceso que satura el disco (por `% Disk Time`/latencia si los contadores funcionan, o por MB/s via CIM si estan rotos) y lo mata si se mantiene N minutos. No toca procesos de sistema.

## Requisitos
- Windows 10/11, PowerShell 5.1+
- Sin dependencias externas

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