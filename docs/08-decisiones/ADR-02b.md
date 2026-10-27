# ADR D-02b — `exclusive` es una propiedad del destino, no un interruptor

- **Estado**: aceptada
- **Decidida**: 2026-10-11, por el dueño.
- **Fuente**: README original de `08-decisiones` (decidido hasta 2026-10-21; `main` 398a1b9)

- **Numeración**: en el SPEC r6, D-02 es la taxonomía cerrada de skills y esta decisión (`exclusive`) pasa a D-02b. En el documento original, D-02 es esta.

## Contexto
El diseño anterior era un interruptor global con tres modos
(`one_for_all` / `rest_for_one` / `one_for_one`). Se cayó por una razón
concreta: **quien tiene tres APIs y una GPU tiene que elegir un modo para los
cuatro, y cualquier elección es mala para tres de ellos.**

```toml
[model.coder]
exclusive = true     # si lo tiene uno, no caben dos
[model.embedder]
exclusive = false    # una API: no se estorba con nadie
```

**El defecto es `false`** y el schema **no lo exige**: exigirlo sería obligar a
declarar "esto no es exclusivo" para no usar la cola, que es al revés. El
defecto tiene que ser el aburrido y el que no toca la cola.

## Decisión
**Qué**: no hay enum de modos. Hay una propiedad por destino.

## Alternativas consideradas
**Se dejó de hacer**: `rest_for_one` **no está implementado ni stubeado**. Solo
tendría sentido cuando existiera un destino que pueda soltar el turno antes de
terminar. Y de los dos modos seriales (`one_for_all` y `rest_for_one`) solo
existe el primero, porque con peticiones de una vez **son el mismo resultado**:

```
cola con A, B, C esperando

one_for_all  :  A entra -> sale -> B entra -> sale -> C entra.   FIN
rest_for_one :  A entra -> sale -> B entra -> sale -> C entra.   FIN
                                        ↑
              A ha vuelto AL FINAL, pero ya no hay a quien darle turno
```

**El fallo que la evitó**: no invocar un "quantum" para forzar que se diferencien.
En una GPU **no se puede cortar una inferencia a medias** —la mitad del trabajo ya
está hecho—, así que el quantum habría sido unconcepto sin caso de uso.

## Consecuencias
El documento original no recoge consecuencias adicionales.

## Verificación
El documento original no define una verificación específica; ver las puertas F0.

- **Puertas F0 de las que depende**: ninguna
