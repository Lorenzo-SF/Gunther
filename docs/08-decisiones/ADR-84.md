# ADR D-84 — Planes dinámicos (`expand`)

- **Estado**: aceptada (DP0, r8)
- **Fecha**: 2026-10-26
- **Fuente**: SPEC §22.5.3

- Resuelta por delegación (valor por defecto de SPEC §21, reversible): Q-12 (`expand` incluido y apagado por defecto; la coral no se expone por el gateway en v1.1).

## Contexto
Un responsable humano reparte el trabajo en tiempo de ejecución; el dueño quiere poder expresar cualquier flujo.

## Decisión
Paso `expand`: un rol devuelve un fragmento de plan como datos, validado con las mismas reglas, restringido a roles, tools y modelos ya declarados y contado contra los límites del padre. Desactivado por defecto (`coral.allow_dynamic_plans`).

## Alternativas consideradas
Planes siempre estáticos (limita la generalidad); fragmentos con código (descartado: ejecución arbitraria).

## Consecuencias
Amplía la superficie de ataque (T-18).

## Verificación
F19.

- **Puertas F0 de las que depende**: ninguna
