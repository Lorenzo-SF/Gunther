# ADR D-11 — Lo que NO se decidió, y por eso está escrito

- **Estado**: aceptada
- **Decidida**: no consta en el documento original
- **Fuente**: README original de `08-decisiones` (decidido hasta 2026-10-21; `main` 398a1b9)

- Estado de las seis preguntas con el SPEC r6: (1) refusal → D-09 y SPEC §6.9 (defecto: ver D-09); (2) memoria compartida → D-22; (3) verdad de la VRAM → D-16, sustituida por D-48 y D-65; (4) `Provider` → D-17; (5) camino de librería → D-18; (6) el LLM como clasificador → D-68 y D-72 (verificación por evaluación con corpus).

## Contexto
Estas las encontró el proceso, y **ninguna se ha cerrado**:

| # | Pregunta | Dónde |
|---|---|---|
| 1 | ¿Cuando algo no cabe, `fail`, `wait` o `degrade`? **Configurable**, pero el defecto no está puesto | `06-capacidad-y-politica` §4 |
| 2 | ¿La memoria compartida comparte historial o solo patrones? | `docs/README.md` |
| 3 | ¿Quién escribe la verdad de la VRAM? Hoy la **lee**; escribirla sigue sin dueño | `docs/README.md` |
| 4 | ¿`Gunther.Provider` es un registro o una lista cerrada? | `docs/README.md` |
| 5 | ¿El camino de librería entra en las fases, o se queda fuera? | `docs/README.md` |
| 6 | ¿El LLM entra como clasificador? **No se puede saber**: no hay métrica de qué fracción resolvió el motor estático | `01-inventario` §"lo que falta" |

**La 6 es la que bloquea a la 5**: `DISENO-MOTOR` §10 pone un tribunal antes de
meter el LLM — *"si la política resuelve el 97%, el LLM se llama el 3% y es ruido
caro. Si es el 60%, **el motor estático está mal hecho** y hay que arreglarlo
antes de meter un modelo"*. **Y esa métrica no existe: no hay telemetría de
decisiones por capa.** Es lo más pequeño que falta y decide lo más gordo que
queda.

## Decisión
(ver Contexto)

## Alternativas consideradas
El documento original no recoge alternativas descartadas para esta decisión.

## Consecuencias
El documento original no recoge consecuencias adicionales.

## Verificación
El documento original no define una verificación específica; ver las puertas F0.

- **Puertas F0 de las que depende**: ninguna
