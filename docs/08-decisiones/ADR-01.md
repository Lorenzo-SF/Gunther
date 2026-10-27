# ADR D-01 — El centro de gravedad: el enrutado, no la GPU

- **Estado**: aceptada
- **Decidida**: 2026-10-11, por el dueño.
- **Fuente**: README original de `08-decisiones` (decidido hasta 2026-10-21; `main` 398a1b9)

- Nombre actual del «scheduler» de esta decisión: Selector (reparto) y Placer (colocación), D-53.
- Resuelta en r7 (D-91, J-01). Choque original: D-01 aparca el scheduler («la 8b · Scheduler no está en el plan») y distingue los destinos `:local`, `:remote` y `:external`. El SPEC r6 incluye el reparto en v1 (D-41, D-53: Selector + Placer) y clasifica los destinos con `locality` (`local | lan | cloud`) y `node` (§6.8, §18). Hay que decir qué parte de D-01 sigue vigente.

## Contexto
El plan anterior tenía como fases 1-4 "que mi máquina funcione bien":
behaviours, motor local, VRAM, scheduler. Un usuario que **solo llama a APIs**
se salta las cuatro. Y el diseño del motor de decisión
(`04-modulos/01-routing-y-ciclo-vida/DISENO-MOTOR.md`) menciona
`vram`/`gpu`/`cuda`/`device` **0 veces**, mientras que el router ya
distingue los tres tipos de destino (`:local`, `:remote`, `:external`).

**Medida**:

| | |
|---|---|
| Menciones de GPU en el diseño del motor | **0** |
| Menciones de `provider`/`remote`/`precio` | 2 |

## Decisión
**Qué**: la fase 4 pasa a ser la política de turnos y el trabajo local se aparca.

## Alternativas consideradas
**Se dejó de hacer**: la 8b · Scheduler no está en el plan. Está en
[`07-local-aparcado`](../07-local-aparcado/) con lo que hay y lo que falta.

## Consecuencias
**La frase que resume todo**:
> El centro de gravedad de Gunther es el enrutado. La inferencia local es un
> backend más.

## Verificación
El documento original no define una verificación específica; ver las puertas F0.

- **Puertas F0 de las que depende**: ninguna
