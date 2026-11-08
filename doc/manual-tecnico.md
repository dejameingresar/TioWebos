# Manual técnico — DiskGuardian

## Arquitectura
- `DiskGuardian.ps1`: motor. Detecta modo (perf WMI o CIM deltas), vigila saturación sostenida y mata el proceso dominante no-sistema.
- `config.default.json`: umbrales e intervalos.
- `Install.ps1` / `Uninstall.ps1`: tarea programada al inicio de sesión.
- `tests/run.ps1`: suite de pruebas.
- `calidad/Plan-de-Pruebas.md`, `doc/informe-calidad.md`.

## Modo perf WMI
Usa `Win32_PerfFormattedData_PerfDisk_PhysicalDisk` y `Win32_PerfFormattedData_PerfProc_Process`. Independiente del idioma del SO.

## Modo CIM deltas (fallback)
Mide MB/s por proceso con `Win32_Process.Read/WriteTransferCount`. No mide latencia.

## Seguridad
Lista de procesos críticos + rutas bajo SystemRoot/WindowsApps + PIDs <=4 nunca se matan.
PS