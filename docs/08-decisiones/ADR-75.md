# ADR D-75 — Un solo plan; tres vías; condiciones cerradas

- **Estado**: aceptada (DP0, r8)
- **Fecha**: 2026-10-26
- **Fuente**: SPEC §22.5, §22.10

- Resuelta por delegación (valor por defecto de SPEC §21, reversible): Q-11 (datos, TOML y DSL de Elixir a la vez en F20; el DSL sigue sujeto a G-31).

## Contexto
El dueño pide un DSL que permita configurar las modalidades y crear otras. Un DSL de código y una configuración declarativa tienden a divergir.

## Decisión
Todo lo que define una coral se reduce a un **`Plan`** (datos). Hay tres vías que producen el mismo plan: datos puros, TOML y DSL de Elixir (azúcar sobre datos). Las condiciones usan un lenguaje **cerrado**; las funciones propias solo existen en definiciones por código y se rechazan en TOML.

## Alternativas consideradas
Un DSL como única vía (descartado: no es declarativo ni validable sin compilar); TOML con funciones por nombre (descartado: ejecución de código desde configuración).

## Consecuencias
El DSL no puede expresar nada que los datos no expresen. El mismo plan por las tres vías debe ser idéntico.

## Verificación
G-31; F20.

- **Puertas F0 de las que depende**: G-31
