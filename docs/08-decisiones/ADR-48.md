# ADR D-48 — Ledger de recursos propio

- **Estado**: aceptada (DP0, r8; Q-14)
- **Fecha**: 2026-10-25
- **SPEC**: SPEC-000-GUNTHER r8 §3.2, §11.3

- Nota (r8, Q-14): `Arrea.Resource` **existe en `main` según la medición del dueño (D-13); su publicación en Hex está pendiente de G-28** (D-13: 23 KB, tests, `main` desde 2026-10-10). La vacilación de r5 era de búsqueda, no de existencia. El ledger se queda propio en v1 por la semántica de §11.3 (`foreign` por proceso, `available` con quiescencia, memoria unificada), que `Arrea.Resource` no tiene y envolver cuesta más que mantenerlo. G-28 puede proponer una fachada en una fase posterior, con la condición de §1.4 del SPEC r8.

## Contexto

r4 daba por hecho `Arrea.Resource` como ledger de VRAM. r5 no lo encontró en la documentación pública. En r8 el dueño confirma que existe en `main` según la medición del dueño (D-13); su publicación en Hex está pendiente de G-28 (Q-14), pero el ledger se queda propio en v1 por el desajuste de dominio: `Arrea.Resource` no tiene la semántica de `foreign` por proceso, `available` con quiescencia ni memoria unificada que §11.3 necesita.

## Decisión

El ledger es de Gunther (`Gunther.Resource.Ledger`): ETS con `GenServer`, indexado por `{nodo, physical_id}`, con `foreign` y `available` definidos en SPEC §11.3. `Arrea.Resource` se puede adoptar como capa base en una fase posterior si, con su API pública actual, permite implementar `foreign` y `available` de §11.3 sin duplicar medidas ni introducir acoplamiento (G-28); entonces `Gunther.Resource.Ledger` pasa a fachada.

## Alternativas consideradas

Adoptar `Arrea.Resource` directamente en v1 (descartado: el desajuste de dominio cuesta más que mantener el módulo propio). Ledger sin memoria ajena (descartado: sobrecompromiso).

## Consecuencias

Un módulo más que mantener; control total de invariantes. Si `Arrea.Resource`, con su API pública actual, permite implementar `foreign` y `available` de §11.3 sin duplicar medidas, el módulo puede pasar a fachada en una fase posterior. No bloquea F1.

## Verificación

Pruebas de propiedades del ledger (F2-06).

- **Puertas F0 de las que depende**: ninguna. La existencia de `Arrea.Resource` se cerró en Q-14; G-28 sigue siendo la puerta que decide si puede sustituir al ledger propio como fachada.
