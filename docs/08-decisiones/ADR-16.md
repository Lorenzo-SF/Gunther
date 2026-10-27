# ADR D-16 — La verdad de la VRAM: Arrea mide, Gunther consume y decide

- **Estado**: aceptada
- **Decidida**: 2026-10-18, por el dueño (recomendación del agente, aceptada).
- **Fuente**: README original de `08-decisiones` (decidido hasta 2026-10-21; `main` 398a1b9)

- **Sustituida por D-48** (ledger de recursos propio de Gunther) **y por D-65** (identidad física del device). Se conserva el texto original.

## Contexto
**Por qué**: medir pertenece al componente que posee el recurso. Dos verdades
que se contradigan (Gunther diciendo una cosa, Arrea otra) es el fallo que ya
se tuvo con el refusal de VRAM. `Arrea.Resource` tiene capacidad (megas
enteros) y cuota (decimal) con identidad del titular: eso es exactamente lo
que un knapsack de GPU necesita, y Gunther no tiene por qué reimplementarlo.

## Decisión
**Qué**: la medida física de la VRAM (y de la capacidad) la produce **Arrea**
(`Arrea.Resource`, que ya existe desde la fase 2 y hoy no tiene consumidor):
Arrea corre el motor, conoce el PID, lee `/proc` o `nvidia-smi`. Gunther la
**consume** para enrutar y colocar, y no mide por su cuenta. La columna `SLOT`
de `gunther status` deja de deducirse del número de puerto y pasa a leer la
medida real (`Gunther.Detector.LlamaCpp` ya la produce por PID).

## Alternativas consideradas
El documento original no recoge alternativas descartadas para esta decisión.

## Consecuencias
**No se aplica hacia atrás**: `Arrea.Resource` está mergeado y publicado; su
forma no tiene vocabulario de Gunther (el titular es opaco). La regla rige lo
que entra desde ahora.

**Desbloquea**: P-4 (verdad de la VRAM), P-6 (varias GPUs), 8b (scheduler).

## Verificación
El documento original no define una verificación específica; ver las puertas F0.

- **Puertas F0 de las que depende**: G-11 (vía D-65)
