# ADR D-18 — El camino de librería: fuera de las fases

- **Estado**: aceptada
- **Decidida**: 2026-10-18, por el dueño (recomendación del agente, aceptada).
- **Fuente**: README original de `08-decisiones` (decidido hasta 2026-10-21; `main` 398a1b9)

- Resuelta en r7 (D-91, J-09). Choque original: D-18 (y D-17) sitúan el CLI en su propia fase (12); D-31 y SPEC §1.1 establecen que Gunther no tiene CLI.

## Contexto
**Por qué**: tratar la librería como fase confunde «entregable» con
«fundamento». El gateway (fase 8) existe precisamente para que procesos que
no son Elixir usen Gunther, pero la librería es la base.

## Decisión
**Qué**: la librería (`lib/gunther/`) no es una fase: es el sustrato sobre el
que se construye todo (el behaviour, los agentes, el router). El CLI es el
empaquetado y tiene su propia fase (12). Lo que merece una fase es la
**documentación pública** (ExDoc ya se genera) y la **estabilidad del
contrato** (`@type result/0` y compañía, cerrado en F5.0).

## Alternativas consideradas
El documento original no recoge alternativas descartadas para esta decisión.

## Consecuencias
El documento original no recoge consecuencias adicionales.

## Verificación
El documento original no define una verificación específica; ver las puertas F0.

- **Puertas F0 de las que depende**: ninguna
