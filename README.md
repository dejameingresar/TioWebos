# TioWebos

Vigilante de disco de bajo consumo para Windows (prototipo: **solo disco**, CPU/RAM pendientes).

**Instalación rápida (como WinUtil):**
```powershell
irm https://raw.githubusercontent.com/dejameingresar/TioWebos/main/install.ps1 | iex
```
Solo sesion actual, sin arranque automatico:
```powershell
iex "& { $(irm https://raw.githubusercontent.com/dejameingresar/TioWebos/main/install.ps1) } -NoStartup"
```

## Abrir desde cualquier lugar

Después de instalar, abre PowerShell o CMD en cualquier carpeta y escribe:

```powershell
tiowebos
```

Se abre la GUI. El guardian puede quedar corriendo en segundo plano aunque cierres la ventana.

Detecta el proceso que satura el disco (por `% Disk Time`/latencia si los contadores funcionan, o por MB/s via CIM si estan rotos) y lo mata si se mantiene N minutos. No toca procesos de sistema ni los de tu lista `Protegidos`. Antes de matar intenta cierre graceful (8 s) y solo entonces fuerza.

## Requisitos
- Windows 10/11, PowerShell 5.1+
- Sin dependencias externas

## Configuracion
Edita `config.json` (se crea desde `config.default.json`):
- `UmbralTotalMBs`, `UmbralProcMBs` (modo CIM)
- `UmbralPct`, `UmbralLatenciaMs` (modo contadores)
- `MinutosParaMatar`, `IntervaloSeg`, `LogPath` (acepta `%VAR%`, ej `%TEMP%`), `LogMaxMB`
- `Protegidos`: nombres que nunca se matan, ej `["obs64.exe", "idea64.exe"]`

## Desinstalar
```powershell
powershell -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\TioWebos\app\Desinstalar.ps1"
```
Quita el guardian en ejecucion, el arranque automatico, el comando `tiowebos` y la carpeta.

## Log
`%TEMP%\disk-guardian.log` (rotacion automatica).

## Limitacion conocida
Si los contadores de rendimiento estan corruptos (error c0000bb8), el modo CIM mide I/O total, no solo disco. Para restaurar contadores: como admin `lodctr /R` + reinicio.

## Licencia
MIT
