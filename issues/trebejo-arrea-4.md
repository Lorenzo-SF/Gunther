# `trebejo` fija `arrea ~> 3.1` e impide usar `arrea` 4.0.0

- **Repositorio afectado**: `Lorenzo-SF/trebejo`
- **Descubierto**: puerta G-17 de Gunther (2026-10-27), ver
  `docs/13-registro-de-fases.md` §G-17
- **Impacto en Gunther**: `mix.exs` fija `{:arrea, "~> 3.1"}`. Con `arrea 4.0.0`
  la dependencia no resuelve.
- **Estado**: abierto

## El problema

`arrea` 4.0.0 esta publicado en Hex (con `Arrea.Resource`, worker/queue y
telemetria). Pero `trebejo` 2.1.0 —la version publicada— declara
`{:arrea, "~> 3.1"}`, y su rama `main` declara lo mismo. Hex no puede
resolver `arrea 4.0.0` junto a `trebejo 2.1.0`: el unico `arrea` que cumple
las dos es 3.1.0.

La consecuencia no es teorica. `mix hex.outdated` en Gunther:

```
Dependency     Only      Current  Latest  Status
arrea                    3.1.0    4.0.0   Update not possible
```

## Por que importa

1. **`arrea` queda bloqueada en la 3.x para todo el ecosistema.** Cualquier
   proyecto que use `trebejo` (Gunther, y lo que venga) no puede subir a
   `arrea` 4.x aunque quiera.
2. **La insignia del README de `arrea` va dos versiones por detras.** Dice
   `version-3.0.0` cuando lo publicado es 4.0.0. Quien la mire (un
   mantenedor, un usuario).no sabe que existe una 4.x.
3. **El conflicto no es visible desde `arrea`.** Quien mantiene `arrea` no
   ve que su 4.0.0 no se puede usar con `trebejo`.

## Lo que se pide

En `trebejo`:

- Subir el requisito a `{:arrea, "~> 3.1 or ~> 4.0"}` (o `">= 3.1.0"`),
  segun lo que permita el codigo de `trebejo`.
- Si `trebejo` usa algo de `arrea` que **no** existe en 3.x, la version
  publicada que lo exige tiene que subir a `4.0.0` y Gunther tendra que
  subir su requisito en consecuencia.

En `arrea` (independiente de lo anterior):

- Actualizar la insignia del README a la version real publicada.

## Que se ha medido

- Hex publica `arrea` 4.0.0, 3.1.0, 3.0.0, 2.2.0, 2.1.0, 2.0.0 y 1.0.0.
- `trebejo` 2.1.0 en Hex declara `{:arrea, "~> 3.1", [hex: :arrea, repo:
  "hexpm", optional: false]}`.
- `mix hex.outdated` en Gunther: `arrea ... Update not possible`.
- `Arrea.CircuitBreaker` —la primitiva que §2.5 de Gunther necesita— es
  **identica** en 3.1.0 y 4.0.0. La unica novedad de 4.0.0 es
  `Arrea.Resource`, que Gunther no usa en v1 (ledger propio, D-48 y Q-14).

## Nota

`arrea` 4.0.0 **no** rompe a Gunther: la rama B de G-17 (fijar `~> 3.1`) esta
aplicada y cumple el `~> 3.0` del SPEC. El coste de no resolver esto es de
ecosistema, no de Gunther.
