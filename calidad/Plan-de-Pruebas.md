# Plan de pruebas — DiskGuardian

## 1. Alcance
Valida sintaxis, ejecucion en modo `-Once`, deteccion de saturacion y no eliminacion de procesos de sistema.

## 2. Casos

| ID | Caso | Esperado |
| :- | :- | :- |
| CP-01 | Parseo de sintaxis de DiskGuardian.ps1 | 0 errores |
| CP-02 | Ejecucion `DiskGuardian.ps1 -Once` | codigo 0 y log con "Guardian iniciado" |
| CP-03 | Modo perf WMI disponible | "Modo=perf WMI" en log |
| CP-04 | Deteccion de saturacion (umbral 1%) | registra culpable y cheques |
| CP-05 | No mata procesos de sistema | Es-Sistema devuelve true para svchost, lsass, etc. |
| CP-06 | DryRun no ejecuta Stop-Process | log contiene "DRYRUN" y no "MATADO" |

## 3. Trazabilidad
Casos implementados en `tests/run.ps1` (CP-01, CP-02). CP-03 a CP-06 verificados manualmente en sesion.
PS