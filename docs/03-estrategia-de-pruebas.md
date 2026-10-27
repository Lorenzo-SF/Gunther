# Estrategia de pruebas

## 1. Capas

| Capa        | Herramienta                                                              | Qué cubre                                                                                                               | Obligatoria desde |
| ----------- | ------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------- | ----------------- |
| Unitarias   | ExUnit                                                                   | Funciones y módulos                                                                                                     | F1                |
| Propiedades | StreamData                                                               | Ledger (invariantes SPEC §11.3), `Gunther.Cache` (tope y LRU), `Selector`, presupuesto, truncado de resultados de tools | F1                |
| Contrato    | `Gunther.ContractTest`                                                   | Todo behaviour (SPEC §5.14), incluido el control de cancelación y, para `Classifier`, el respeto del `DecisionSpec`     | F3                |
| Integración | ExUnit con `llama-server` real, servidores simulados y MCP de referencia | Engines, providers, MCP, nodos                                                                                          | F3                |
| Fuzz        | StreamData y corpus propios                                              | Parser GGUF, framing JSON-RPC, TOML, regex de reglas, cabeceras del gateway                                             | F2, F13, F16      |
| Caos        | Scripts que matan procesos, cortan red y ralentizan providers            | N-05, N-13, §18.9                                                                                                       | F6, F15, F16      |
| Carga       | Benchee más generador de peticiones                                      | N-01, N-07, N-15                                                                                                        | F4, F15, F18, F16 |
| Documento   | `scripts/doc_lint.sh`                                                    | N-09                                                                                                                    | F0                |

## 2. Doble de pruebas

- `Gunther.Testing.Provider.Mock`: guion de respuestas, errores y latencias; incluye casos de streaming con errores antes y después del commit.
- `Gunther.Testing.FakeGPU`: devuelve devices y mediciones guionizadas (incluidos `free > total`, memoria unificada, atribución por proceso y su ausencia).
- `Gunther.Testing.FakeNode`: agente de nodo en proceso.
- Resolver DNS falso para las pruebas de SSRF.

## 3. Hardware y fixtures

| Backend | Cómo se prueba                                                         | Estado a declarar                        |
| ------- | ---------------------------------------------------------------------- | ---------------------------------------- |
| CUDA    | Fixtures de `--list-devices` y `nvidia-smi`; prueba real si hay equipo | «validado en hardware» o «solo fixtures» |
| ROCm    | Ídem con `rocm-smi`/`amd-smi`                                          | Ídem                                     |
| Vulkan  | Ídem                                                                   | Ídem                                     |
| Metal   | Ídem                                                                   | Ídem                                     |
| CPU     | Siempre real                                                           | —                                        |

**Grabar un fixture**: ejecutar `<binario> --list-devices` y guardar la salida **íntegra** en `test/fixtures/list_devices/<backend>-<compilacion>.txt`; igual con las herramientas de fabricante en `test/fixtures/vendor/`. Cada fixture lleva su cabecera con fecha, SO, controlador y versión de la compilación. Un fixture sin esa cabecera no se admite.

**Documentación por backend**: la documentación pública declara por backend «validado en hardware real» o «validado solo con fixtures». No se escribe «soportado» sin una de las dos.

## 4. Casos obligatorios por requisito (resumen)

La lista completa son los AC de SPEC §19. Los casos que más fácilmente se olvidan:

1.  `free > total` en un device ⇒ `usable: false`.
2.  Dos backends que ven el mismo GPU con `[[devices.map]]` ausente ⇒ `:unmapped`.
3.  `kill -9` de la VM con un engine vivo ⇒ nueva VM sin VRAM retenida y sin matar procesos ajenos.
4.  PID reutilizado por otro programa ⇒ no se le envían señales.
5.  Stream que falla antes y después del primer chunk.
6.  Abandono de `stream!` ⇒ ningún proceso vivo pasado `cancel_grace_ms`.
7.  302 hacia la dirección de metadatos de nube desde un servidor MCP.
8.  Documento recuperado que contiene instrucciones ⇒ no entra en la `DecisionView`.
9.  Decisor con buen acierto global y mal acierto en un idioma requerido ⇒ no se verifica.
10. Cambio de un byte en un snapshot de agente firmado ⇒ rechazo.
11. Nodo con certificado distinto o huella no listada ⇒ `:node_auth_failed`.
12. Dos controladores pidiendo la misma memoria de un nodo ⇒ el segundo recibe `no_room`.
13. **Reglas por consumer con veto del `default_model`** (M-01, Q-15): un consumer que se veta a sí mismo su `default_model` y no tiene otro candidato devuelve `:no_candidates` con `:consumer_veto`; un veto incondicional cuyo `target` casa con el `default_model` es `config_error` al cargar.
14. **Aislamiento entre consumers** (T-15): las reglas de un consumer no afectan a las peticiones de otro consumer, aunque compartan `default_model`.
15. **Nombre de regla duplicado** (M-01): dos reglas con el mismo `name` en el espacio combinado son `config_error` al cargar.

## 5. Criterios de cobertura

La cobertura de líneas se mide, pero **no es criterio de cierre** (una cifra de cobertura no demuestra los AC). El criterio de cierre son los AC de la fase y los casos obligatorios de §4.
