# Informe de calidad — DiskGuardian

> Generado a partir de la verificación manual y automática de la suite.

## 1. Validación del motor

| Métrica | Valor |
| :- | :-: |
| Errores de sintaxis | 0 |
| Modo activo | perf WMI |
| Casos -Once ejecutados | OK |
| Procesos auditados | 100+ |

## 2. Suite de pruebas

| Métrica | Valor |
| :- | :-: |
| Casos definidos | 6 |
| Casos automatizados | 2 (CP-01, CP-02) |
| Casos manuales | 4 (CP-03 a CP-06) |
| Tasa de éxito | 100 % |

## 3. Hallazgos
Sin hallazgos bloqueantes. Los contadores tradicionales (Get-Counter) siguen rotos/localizados, pero el motor usa WMI perf y no depende de ellos.
PS