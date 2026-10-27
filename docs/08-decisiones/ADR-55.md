# ADR D-55 — La caché de decisiones guarda solo el ranking puro

- **Estado**: propuesta
- **Fecha**: 2026-10-25
- **SPEC**: SPEC-000-GUNTHER r6

## Contexto
Cachear una decisión que ya incorpora «el modelo X estaba libre» es incorrecto pasados unos minutos.

## Decisión
Se cachea lo que producen reglas, embedding y decisor; la disponibilidad se reevalúa siempre. La clave incluye la firma de requisitos y el hash del catálogo.

## Alternativas consideradas
Cachear la decisión final (descartado).

## Consecuencias
Una lectura de caché no implica servir el mismo destino.

## Verificación
F4-03.

- **Puertas F0 de las que depende**: ninguna: es una decisión de diseño sin hecho externo
