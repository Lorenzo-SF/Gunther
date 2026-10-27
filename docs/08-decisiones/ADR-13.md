# ADR D-13 — La frontera con Arrea: lo que Arrea usa, o lo que piden dos

- **Estado**: aceptada
- **Decidida**: 2026-10-16, por el dueño.
- **Fuente**: README original de `08-decisiones` (decidido hasta 2026-10-21; `main` 398a1b9)

- Resuelta por regla en r7 (D-91, J-07; ver Q-14). Choque original: D-13 afirma que `Arrea.Resource` existe (23 KB, tests, en `main` desde 2026-10-10, publicado); el SPEC r6 (D-48, §3.2) lo trata como no verificado. Ver también D-03.

## Contexto
La decisión resuelve una contradicción que estaba abierta entre tres documentos:
`00-arrea` §5 lista «abstracción de agente» como carencia, `05-agentes` §5.2
proponía `Arrea.Agent` y `02-orden` fase 10 ya lo daba por hecho («`Arrea.Agent`
(en Arrea)»). Se resolvió midiendo, y las cuatro medidas van juntas:

| Hecho | Medición |
|---|---|
| `Arrea.Agent` ha existido | **no**: cero `agent.ex` en el repo hermano, en toda su historia |
| `Arrea.Resource` existe | **sí**: 23 KB, tests y property test, en `main` desde el 2026-10-10 (fase 2 ✅; D-03, D-05), publicado |
| Consumidores de `Arrea.Resource` hoy | **ninguno**: en Gunther solo se le cita en tres `@moduledoc`; en Arrea solo está registrado en el supervisor |
| Consumidores de Arrea | cuatro: trebejo, gunther, botica, delfos (`ARCHITECTURE.md`) |

El behaviour nace en **Gunther**. Un contrato con un solo consumidor y **cero
implementaciones dentro de Arrea** se congela antes de que nadie lo haya probado
— el de §5.2 nació de *leer* `Gunther.Agent.loop/7`, y ese bucle no cerró hasta
#87. La fila de `Resource` es el precio ya pagado de adelantarse: 23 KB que hoy
no usa nadie. **El chasis no adivina lo que va a ser de todos; lo posee cuando
ya lo es.**

## Decisión
**Qué**: algo sube a Arrea si Arrea lo necesita **para sí**, o si lo pide un
**segundo consumidor**. Si solo lo necesita Gunther, se queda en Gunther.

## Alternativas consideradas
**Se dejó de hacer**: la F5.1 como PR en `Lorenzo-SF/arrea` con su CI, la F5.2
esperando un merge que este repo no controla, y `Arrea.Agent` /
`Arrea.Agent.Supervisor` como ficheros **[PROPUESTO]** del repo hermano.

## Consecuencias
**Por qué rectificar no va a costar caro**: Gunther consume Arrea de su `main`
con `override: true` (D-05). El día que haya segundo consumidor, extraer el
behaviour es *mover un módulo*, no una release de Hex.

**No se aplica hacia atrás**: `Arrea.Resource` está mergeado y publicado, su
forma no tiene vocabulario de Gunther (el titular es opaco) y la fase 2 está
cerrada. La regla rige lo que entra **desde ahora**; lo que queda de este lado es
**usar** la cuenta —la admisión—, no reescribirla.

**La frase que resume todo**:
> A Arrea sube lo que Arrea usa para sí, o lo que piden dos. Lo que solo
> necesita uno, vive con quien lo necesita.

## Verificación
El documento original no define una verificación específica; ver las puertas F0.

- **Puertas F0 de las que depende**: G-01
