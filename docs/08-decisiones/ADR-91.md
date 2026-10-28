# ADR D-91 — Precedencias entre D-01 a D-28 y r8

- **Estado**: aceptada (DP0, r8; Q-14)
- **Fecha**: 2026-10-26
- **Fuente**: SPEC r8 Anexo B.3; resuelve J-00 a J-03, J-07, J-09 y J-10

- Nota (r8, Q-14): J-07 (¿existe `Arrea.Resource`?) queda cerrado. `Arrea.Resource` **existe en `main` según la medición del dueño (D-13); su publicación en Hex está pendiente de G-28** (D-13). La condición para que el ledger propio pase a fachada se actualiza: no es «que exista» (existe), sino «que con su API pública actual permita implementar `foreign` y `available` de §11.3 sin duplicar medidas ni introducir acoplamiento». G-28 puede proponer la fachada en una fase posterior; no bloquea F1.

## Contexto

Siete decisiones antiguas chocan con el SPEC en puntos concretos. En r7 se resolvieron como J-00 a J-03, J-07, J-09 y J-10. En r8 el dueño cerró Q-14, que era la última pregunta abierta sobre J-07.

## Decisión

Prevalece el SPEC vigente en: numeración de D-02 y D-02b (J-00); reparto en v1 y `locality` (J-01); ledger entero propio (J-02); versiones de Hex en producción (J-03); sin CLI (J-09); regla del agente con circuito abierto retirada (J-10). Para `Arrea.Resource` (J-07): `Arrea.Resource` existe en `main` según la medición del dueño (D-13); su publicación en Hex está pendiente de G-28; el ledger se queda propio en v1; G-28 puede proponer fachada con la condición de §1.4 del SPEC r8.

## Alternativas consideradas

Mantener las decisiones antiguas (descartado: contradicen al SPEC en puntos ya cerrados).

## Consecuencias

**Q-14 cerrada.** `Arrea.Resource` existe en `main` según la medición del dueño (D-13); su publicación en Hex está pendiente de G-28. El ledger es propio en v1 (D-48). La condición para que pase a fachada es «que `Arrea.Resource`, con su API pública actual, permita implementar `foreign` y `available` de §11.3 sin duplicar medidas ni introducir acoplamiento». G-28 puede proponer la fachada en una fase posterior.

## Verificación

G-28 (fachada opcional). Las invariantes del ledger propio se verifican con pruebas de propiedades (F2-06).

- **Puertas F0 de las que depende**: G-28
