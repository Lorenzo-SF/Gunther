# ADR D-89 — Colocación y medida: reserva, reintento, capas y fuente única

- **Estado**: aceptada (DP0, r8)
- **Fecha**: 2026-10-26
- **Fuente**: SPEC §11.1, §11.3; resuelve J-12 a J-16 (D-27, D-28)

## Contexto
D-27 y D-28 definían la reserva en tres estados, el reintento en otro device, el entero de capas y una sola fuente de medida por backend; el SPEC r6 usaba otra formulación.

## Decisión
Se adoptan D-27 y D-28 sobre la base de r6: reserva `reservada` → `arrancada` (se mide y se corrige al alza con warning `:reserve_exceeded`) → `liberada`; reintento en otro device `usable` donde quepa; capas **enteras** (de `llama-fit-params` o de la fórmula, nunca `-1`) con `--fit on` como red; `--device` con el nombre del motor más `--split-mode none` y `--main-gpu`; convenciones A (la del motor) y B (la del sistema, con `overhead_mib` calibrado y procedencia registrada) sin mezclar nunca fuentes en un device. Se mantiene el margen de reserva de r6 (1024 MiB, el de `--fit-target`).

## Alternativas consideradas
Mantener r6 (descartado: perdía las mediciones del dueño en D-27 y D-28). Reservar el peso real sin margen (descartado: sin margen, un error de cálculo se convierte en OOM).

## Consecuencias
Las medidas del dueño adelantan G-09, G-10 y G-11, pero **no las sustituyen**: siguen siendo puertas.

## Verificación
G-09, G-10, G-11, G-14; F2, F6.

- **Puertas F0 de las que depende**: G-09, G-10, G-11, G-14
