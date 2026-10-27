# ADR D-38 — Prompts versionados con plantillas EEx

- **Estado**: aceptada (propuesta P-11 del dueño)
- **Fecha**: 2026-10-25
- **Fuente**: SPEC §4.11, §4.2; respuesta del dueño P-11

## Contexto
`Gunther.Prompt.register(name, version, template)`, `render/3`, `list/0` y `delete/2`; una petición usa `prompt: {nombre, versión}`; un prompt inexistente es `:prompt_not_found`. El SPEC r6 no definía el motor de plantillas.

## Decisión
Motor: **EEx**. Las plantillas las escribe el **operador** (por configuración o con `Gunther.Prompt.register/3`), nunca el usuario final. Los `assigns` son datos, no funciones. Plantillas escritas por usuarios: v1.1 o posterior, con sandbox y una decisión nueva.

## Alternativas consideradas
Plantillas escritas por el usuario final: aplazadas a v1.1 o posterior (requieren sandbox).

## Consecuencias
**Matiz técnico que debe constar**: EEx evalúa expresiones de Elixir, así que una plantilla es **código de confianza del operador**, no un dato. La seguridad no descansa en que los `assigns` sean datos (que también lo son), sino en dos reglas: (1) solo el operador escribe plantillas; `Prompt.register/3` es API del operador y ninguna interfaz externa (gateway, MCP) la expone; (2) el contenido del usuario entra siempre como valor de un `assign`, **nunca concatenado en el texto de una plantilla antes de compilarla**.

## Verificación
F3 (registro y render); prueba que comprueba que ningún endpoint registra plantillas.

- **Puertas F0 de las que depende**: ninguna

## Cambios necesarios en el SPEC (r7)

| # | Sección | Cambio | Estado |
| --- | --- | --- | --- |
| I-21 | §4.11, §15 | Declarar EEx como motor, las dos reglas de seguridad de arriba y una amenaza nueva (plantilla de origen no confiable) en el modelo de amenazas | aplicada en r7 |
