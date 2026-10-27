# Registro de fases y puertas

Se rellena al cerrar cada fase y cada puerta (formato en `04-f0-puertas.md`). Los tiempos medidos aquí son los únicos datos válidos para planificar fases posteriores.

## Fases

| Fase    | Inicio     | Fin            | AC ejecutados (enlace a la salida)                                                                                 | Desviaciones | Decisiones nuevas                                                             |
| ------- | ---------- | -------------- | ------------------------------------------------------------------------------------------------------------------ | ------------ | ----------------------------------------------------------------------------- |
| **DP0** | 2026-10-20 | **2026-10-26** | Aprobación de D-48 a D-92 (45 ADRs); cierre de Q-01 a Q-16; política de F0 fijada. Ver `CIERRE-DP0.md` §1, §2 y §3 | Ninguna      | Ninguna (las notas de Q-14 y Q-15 se aplican en r8; no son decisiones nuevas) |
| **DP1** | pendiente  |                |                                                                                                                    |              |                                                                               |
| **DP2** | pendiente  |                |                                                                                                                    |              |                                                                               |
| **DP3** | pendiente  |                |                                                                                                                    |              |                                                                               |
| **DP4** | pendiente  |                |                                                                                                                    |              |                                                                               |
| **F0**  | pendiente  |                |                                                                                                                    |              |                                                                               |
| **F1**  | pendiente  |                |                                                                                                                    |              |                                                                               |
| **F2**  | pendiente  |                |                                                                                                                    |              |                                                                               |
| **F3**  | pendiente  |                |                                                                                                                    |              |                                                                               |
| **F4**  | pendiente  |                |                                                                                                                    |              |                                                                               |
| **F5**  | pendiente  |                |                                                                                                                    |              |                                                                               |
| **F6**  | pendiente  |                |                                                                                                                    |              |                                                                               |
| **F7**  | pendiente  |                |                                                                                                                    |              |                                                                               |
| **F8**  | pendiente  |                |                                                                                                                    |              |                                                                               |
| **F9**  | pendiente  |                |                                                                                                                    |              |                                                                               |
| **F10** | pendiente  |                |                                                                                                                    |              |                                                                               |
| **F11** | pendiente  |                |                                                                                                                    |              |                                                                               |
| **F12** | pendiente  |                |                                                                                                                    |              |                                                                               |
| **F13** | pendiente  |                |                                                                                                                    |              |                                                                               |
| **F14** | pendiente  |                |                                                                                                                    |              |                                                                               |
| **F15** | pendiente  |                |                                                                                                                    |              |                                                                               |
| **F16** | pendiente  |                |                                                                                                                    |              |                                                                               |
| **F18** | pendiente  |                |                                                                                                                    |              |                                                                               |
| **F19** | pendiente  |                |                                                                                                                    |              |                                                                               |
| **F20** | pendiente  |                |                                                                                                                    |              |                                                                               |
| **F21** | pendiente  |                |                                                                                                                    |              |                                                                               |
| **F22** | pendiente  |                |                                                                                                                    |              |                                                                               |

**Nota sobre F17.** La colmena, que era F17 en r5/r6, se sustituye por F18 a F22 (la coral) en r7 y r8. La numeración original se conserva como referencia histórica; no hay una F17 activa.

## Puertas

### Plantilla de una puerta

```
### G-nn — título
- Fecha:            AAAA-MM-DD
- Entorno:          SO, versión; Elixir/OTP; versiones exactas de las librerías o binarios
- Procedimiento:    pasos ejecutados (o enlace al script en probes/)
- Salida:           ruta del fichero con la salida íntegra
- Resultado:        PASA | FALLA | BLOQUEADA
- Rama aplicada:    A | B | B (provisional)
- Cambios en SPEC:  secciones tocadas (para la próxima revisión)
```

### Plantilla de una fase

```
### Fnn
- Inicio / Fin / AC ejecutados (enlace) / Desviaciones / Decisiones nuevas
```

## Resumen de puertas

A fecha 2026-10-26 no hay ninguna puerta registrada. Todas las puertas G-01 a G-31 se ejecutarán en F0 según la política de `CIERRE-DP0.md` §3. La matriz de referencia está en `15-matriz-de-puertas.md`.

## Puertas bloqueantes para F1

Las puertas que bloquean F1 son G-01, G-05, G-07, G-16, G-17, G-21 y G-23 (`CIERRE-DP0.md` §3.4). F1 no se abre hasta que estén `PASA` o `BLOQUEADA con rama B aplicada`.

## Puertas que bloquean F5

G-02, G-03, G-04, G-05 (`CIERRE-DP0.md` §3.5, punto 9). No bloquean F1.
