# ADR D-04 — El ejemplo de la GPU parecía mal y no lo estaba

- **Estado**: aceptada
- **Decidida**: 2026-10-10.
- **Fuente**: README original de `08-decisiones` (decidido hasta 2026-10-21; `main` 398a1b9)

- `Detector.LlamaCpp` se llama hoy `Detector.LlamaCpp` (D-59, D-65).

## Contexto
**El dueño**: *«puede que haya que contar con la KV cache y otros archivos que
hacen falta para que funcione»*.

Tenía razón. El ejemplo **no está mal, está incompleto**: un modelo no ocupa
solo sus pesos, también la caché KV y los ficheros auxiliares, y con 2,2 GB de
margen no llega.

**Lo que salió de ahí** y que es lo reutilizable:

> Si `N/A` se convierte en `0`, el planificador dice *«no cabe»* con un número
> inventado. Si se convierte en el total, dice *«hay sitio»* y lanza un modelo que
> no entra. **Un `0` y un `total` son los dos extremos del mismo fallo: decir con
> seguridad algo que no se sabe.**

Por eso `Detector.LlamaCpp` devuelve `usable: false` con las cifras a `nil`:
**un planificador tiene que poder distinguir "no hay sitio" de "no lo sé", y esa
diferencia tiene que estar en el tipo**, no en la cabeza de quien lee.

## Decisión
**Qué**: yo afirmé que el ejemplo de `@moduledoc` de `Bulkhead` —"un modelo de
12 GB y otro de 1,8 no caben en 16 GB"— tenía la cuenta mal, porque 12 + 1,8 =
13,8.

## Alternativas consideradas
El documento original no recoge alternativas descartadas para esta decisión.

## Consecuencias
El documento original no recoge consecuencias adicionales.

## Verificación
El documento original no define una verificación específica; ver las puertas F0.

- **Puertas F0 de las que depende**: G-10
