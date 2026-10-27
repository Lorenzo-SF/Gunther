# ADR D-03 — La capacidad en megas enteros, la cuota en decimal

- **Estado**: aceptada
- **Decidida**: 2026-10-10, al escribir `Arrea.Resource`.
- **Fuente**: README original de `08-decisiones` (decidido hasta 2026-10-21; `main` 398a1b9)

- Resuelta en r7 (D-91, J-02). Choque original: D-03 describe `Arrea.Resource` (capacidad entera y cuota decimal con tolerancia). El SPEC r6 usa un ledger propio (D-48, §11.3) y solo conserva «`quota` es 0, nunca `:infinity`», sin definir un eje decimal. Además, D-03 y D-13 dan por existente y publicado `Arrea.Resource`, mientras que D-48 se apoya en que no figura en la documentación pública consultada por r5. El dueño debe confirmar cuál de las dos premisas es la correcta.

## Contexto
Un solo eje decimal no vale: el byte es una unidad, no *la* unidad, y con
decimales la aritmética devolvía `0.19999999999999998` de margen y rechazaba un
modelo que cabía.

## Decisión
**Qué**: `capacity` entera, `quota` decimal con tolerancia.

## Alternativas consideradas
**Se dejó de hacer**: nada. Se hizo de una: capacidad entera (exacto, sin
tolerancia) y cuota decimal (con tolerancia y redondeo al publicar).

## Consecuencias
El documento original no recoge consecuencias adicionales.

## Verificación
El documento original no define una verificación específica; ver las puertas F0.

- **Puertas F0 de las que depende**: ninguna
