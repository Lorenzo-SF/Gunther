# Proceso de desarrollo

## 1. Ramas, cambios y revisión

- Rama principal `main`, siempre verde. Trabajo en ramas `fNN/wp-nn-descripcion`.
- **Política de contribución externa** (D-73): no se aceptan cambios directos de terceros. Se propone abriendo un _issue_ (plantillas en `.github/ISSUE_TEMPLATE/`); el autor lo evalúa y, si le interesa, lo implementa y publica. Está en `CONTRIBUTING.md`.
- Commits con prefijo: `feat`, `fix`, `docs`, `test`, `refactor`, `chore`, y el identificador del paquete de trabajo: `feat(F3-07): validar salida estructurada`.
- Todo cambio pasa por revisión propia con la lista de §6 antes de fusionarse (el proyecto tiene un solo autor; la lista sustituye al segundo revisor).

## 2. Integración continua

Trabajos de `.github/workflows/ci.yml`:

| Trabajo                                 | Qué hace                                                                                              | Falla si                                                                                                                                                                               |
| --------------------------------------- | ----------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `build`                                 | Elixir 1.19 sobre OTP 27 y 28: `deps.get`, `compile --warnings-as-errors`, `format --check-formatted` | Hay avisos o formato                                                                                                                                                                   |
| `test`                                  | `mix test` con propiedades, contrato y cobertura                                                      | Falla algún test                                                                                                                                                                       |
| `boundaries`                            | `mix xref graph` de fronteras (SPEC §0.4) y `scripts/check_boundaries.sh` (SPEC §3.4 y §3.6)          | `Gunther.Core` referencia módulos opcionales; `System.cmd`, `:os.cmd` o `Port.open` fuera de `Gunther.Command`; `Arrea.`, `Apero.` o `Trebejo.` fuera de los cinco módulos de frontera |
| `docs-lint`                             | `scripts/doc_lint.sh` (SPEC §0.6)                                                                     | Cadenas prohibidas en el texto normativo                                                                                                                                               |
| `audit`                                 | `mix hex.audit` y la herramienta que decida G-23                                                      | Hay paquetes retirados o vulnerables                                                                                                                                                   |
| `weekly-deps` (semanal)                 | `mix deps.update` de las tres hermanas y tests de las puertas                                         | Una puerta cambia de resultado                                                                                                                                                         |
| `weekly-llama` (semanal, si hay runner) | Fixtures de `--list-devices` y puertas de llama.cpp contra la compilación fijada                      | Cambia un formato                                                                                                                                                                      |
| `weekly-mcp` (semanal)                  | Consulta el changelog oficial de MCP                                                                  | **Avisa**, no rompe la build                                                                                                                                                           |

## 3. Versionado y publicación

SemVer estricto (SPEC §4.14). Antes de `1.0.0`, `0.x` sin garantías. Cada versión: `CHANGELOG.md`, etiqueta de git, `mix hex.publish` tras `mix hex.build` y revisión de los ficheros que entran al paquete (sin claves, sin fixtures de hardware privados). El SPEC viaja en `extras`.

## 4. Gestión del SPEC

- Cada cambio de comportamiento: nueva revisión (`r8`, `r9`...) con tabla de cambios (Anexo D) y nota de qué fase lo origina.
- Las etiquetas \[V\], \[V5\], \[G\], \[P\], \[CE\] se actualizan con cada cambio.
- Una puerta que pasa o falla se registra en `docs/13-registro-de-fases.md` y se refleja en el SPEC.

## 5. ADR

Plantilla en `docs/08-decisiones/plantilla.md`. Una decisión nueva (algo que cambia el comportamiento observable o un contrato) exige ADR con estado `propuesta` → `aceptada` o `rechazada`. Un cierre de especificación (CE) no es decisión y no lleva ADR.

**Cierre de DP0.** El cierre de DP0 no se hizo ADR por ADR. Se hizo en un solo documento, `CIERRE-DP0.md`, que firma el dueño y que ratifica en bloque las 45 decisiones de D-48 a D-92 y cierra las preguntas Q-01 a Q-16. Ese documento es el ADR trail del cierre. Los ADRs individuales recogen, en su sección de notas, la ratificación y los matices que el dueño introdujo.

## 6. Lista de revisión de un paquete de trabajo

1.  ¿Coincide con la sección del SPEC que cubre, sin añadir ni quitar comportamiento?
2.  ¿Todos los errores son valores del catálogo de §4.13?
3.  ¿Toda ETS, cola y buffer tiene tope y comportamiento al llenarse? (N-02)
4.  ¿Toda espera tiene plazo? (N-04)
5.  ¿Todo proceso nuevo está supervisado y se limpia al cancelar? (N-03)
6.  ¿Ningún dato de usuario llega a un comando? ¿Se usa `Gunther.Command` para todo proceso?
7.  ¿Ningún secreto, prompt o argumento de tool en logs ni eventos?
8.  ¿Eventos de §13.1 emitidos y probados?
9.  ¿Config en el esquema, con validación y sin valor por defecto inventado?
10. ¿Documentación (`@moduledoc`, ejemplo) y `CHANGELOG.md`?
11. ¿Pasan los scripts de lint y fronteras?

## 7. Definición de cierre de fase

1.  Todos los AC de la fase en SPEC §19 ejecutados y verdes (con la salida guardada).
2.  Pruebas de la fase en CI.
3.  SPEC actualizado si hubo desviaciones.
4.  Fila añadida a `docs/13-registro-de-fases.md`: fecha de inicio y fin, AC ejecutados, desviaciones, decisiones nuevas.
5.  Tag `fNN-cerrada`.

## 8. Versionado del SPEC

El SPEC se revisa como `rN` (r8, r9...). Cada revisión la aprueba el dueño y fija en el Anexo D su tabla de cambios. Una fase no cierra con un SPEC que no refleje lo implementado.
