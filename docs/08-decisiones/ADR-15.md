# ADR D-15 — El scheduler: round-robin justo por defecto, prioridad como peso

- **Estado**: aceptada
- **Decidida**: 2026-10-18, por el dueño (recomendación del agente, aceptada).
- **Fuente**: README original de `08-decisiones` (decidido hasta 2026-10-21; `main` 398a1b9)

- Nombre actual del «scheduler» de esta decisión: Selector (D-53).
- Resuelta en r7 (D-87, J-08). Choque original: D-15 define `[consumer.X] priority = N` y envejecimiento; el SPEC r6 §5.8 menciona «la prioridad como peso» pero no define esa clave ni el envejecimiento, y no hay secciones `[consumer.X]` (ver D-09).

## Contexto
**Por qué**: el enrutado es el producto y el scheduler es una extensión
(`02-orden` §2). Construir una cola con prioridad real antes de tener varios
consumidores reales es adelantarse: los consumidores ya se identifican
(`[consumer.X]`), y la equidad evita la inanición. El caso de VIP estricto
(como un servicio que factura por rpm) se cubre con el peso opcional, no con
una cola distinta.

## Decisión
**Qué**: el scheduler (8b, aparcado) usa **round-robin justo** por defecto y
una **prioridad como peso opcional por consumidor** (`[consumer.X] priority = N`)
que solo rompe empates cuando dos consumidores quieren el mismo destino, con
envejecimiento para que un VIP no mate al resto. No se construye la «línea de
cajas» completa (FIFO con VIP estricto) hasta que la mesa camilla (fase 9)
muestre que el envejecimiento no basta.

## Alternativas consideradas
**Se dejó de hacer**: la cola FIFO con VIP estricto, el scheduler como fase
bloqueante, y el `rest_for_one` (D-19).

## Consecuencias
**Desbloquea**: 8b (scheduler), y con él la Fase 10 (agentes multi-modelo) y
P-4/P-6 (verdad de la VRAM y varias GPUs).

## Verificación
El documento original no define una verificación específica; ver las puertas F0.

- **Puertas F0 de las que depende**: ninguna
