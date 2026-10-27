# ADR D-91 — Precedencias entre D-01 a D-28 y r7

- **Estado**: propuesta (resuelta por delegación del dueño en r7)
- **Fecha**: 2026-10-26
- **Fuente**: SPEC Anexo B.3; resuelve J-00 a J-03, J-07, J-09 y J-10

## Contexto
Siete decisiones antiguas chocan con r6 en puntos concretos.

## Decisión
Prevalece r7 en: numeración de D-02 y D-02b (J-00); reparto en v1 y `locality` (J-01); ledger entero propio (J-02); versiones de Hex en producción (J-03); sin CLI (J-09); regla del agente con circuito abierto retirada (J-10). Para `Arrea.Resource` (J-07): ledger propio hasta que G-28 demuestre que existe y cumple los invariantes de §11.3, momento en que pasa a fachada.

## Alternativas consideradas
Mantener las decisiones antiguas (descartado: contradicen a r6 en puntos ya cerrados).

## Consecuencias
**Q-14**: el dueño debe confirmar si `Arrea.Resource` existe; hasta entonces rige la regla.

## Verificación
G-28.

- **Puertas F0 de las que depende**: G-28
