# ADR D-78 — Mensajería nativa de OTP; Arrea como anfitrión opcional

- **Estado**: aceptada (DP0, r8)
- **Fecha**: 2026-10-26
- **Fuente**: SPEC §22.7, §22.15

## Contexto
El dueño señala que los workers, el leader y el monitor de Arrea tienen comunicación bidireccional nativa de OTP y que su arquitectura se parece a la de los agentes. Lo verificado en el README de `arrea` 3.1.0 y 4.0.0: eventos del Leader sin filtro de suscripción, mensajes entre workers por átomo, workers efímeros, configuración y registros globales; el código fuente no se ha podido inspeccionar.

## Decisión
La coral implementa `Run`, `Member` y `Monitor` propios con paso de mensajes de OTP, en estrella por defecto, con buzones acotados y correlación petición-respuesta, y con la misma **forma** de eventos y mensajes que Arrea. Arrea será anfitrión opcional de los miembros si G-28 demuestra que cumple R-A1 a R-A5.

## Alternativas consideradas
Depender ya de Arrea para la mensajería (descartado de momento: requisitos no documentados). Sin relación con Arrea (descartado: duplica trabajo).

## Consecuencias
Se proponen a Arrea evoluciones sin cambiar su dominio (D-86).

## Verificación
G-28; F22.

- **Puertas F0 de las que depende**: G-28
