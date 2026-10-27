# ADR D-48 — Ledger de recursos propio

- **Estado**: propuesta
- **Fecha**: 2026-10-25
- **SPEC**: SPEC-000-GUNTHER r6

## Contexto
r4 daba por hecho `Arrea.Resource` como ledger de VRAM. La documentación pública consultada por r5 no lo muestra, y un ledger de capacidad fija obliga a modelar la memoria ajena como un titular más.

## Decisión
El ledger es de Gunther (`Gunther.Resource.Ledger`): ETS con `GenServer`, indexado por `{nodo, physical_id}`, con `foreign` y `available` definidos en SPEC §11.3.

## Alternativas consideradas
Adoptar `Arrea.Resource` si existiera (descartado en v1 por no estar verificado y por el desajuste de dominio). Ledger sin memoria ajena (descartado: sobrecompromiso).

## Consecuencias
Un módulo más que mantener; control total de invariantes. Si `Arrea.Resource` existe y supera los tests de invariantes, el módulo puede pasar a fachada.

## Verificación
Pruebas de propiedades del ledger (F2-06).

- **Puertas F0 de las que depende**: ninguna: no depende de un hecho externo (la puerta sobre `Arrea.Resource` se retiró en r6)
