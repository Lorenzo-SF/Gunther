# ADR D-31 — Framework sin CLI

- **Estado**: aceptada (DP0, r8)
- **Fecha**: 2026-10-25
- **Fuente**: SPEC r8 §1.1, §4.12

## Contexto

Las primeras versiones de Gunther (r4, Candil) tenían una CLI (`gunther run`, `gunther status`, `gunther stop`). La CLI se retiró por cuatro razones concretas:

1.  **Duplicaba la API de Elixir.** Todo lo que hacía la CLI (`Gunther.start_link/1`, `Gunther.chat/2`, `Gunther.stop/1`) ya estaba en la API. La CLI era un wrapper.
2.  **No se puede invocar desde dentro de un proceso Elixir.** El caso de uso principal de Gunther es integrarlo en otra aplicación (un gateway, un agente, un servicio). Una CLI no se puede llamar desde ahí; la API sí.
3.  **Superficie de ataque adicional.** Cada comando de la CLI es un punto de entrada que hay que autenticar, validar y probar. La API de Elixir ya está protegida por el runtime de la VM.
4.  **Duplicaba los tests.** Cada funcionalidad había que probarla dos veces: por la CLI y por la API. D-10 exige que cada fase se cierre por ejecución real; duplicar los tests multiplica el coste.

## Decisión

**Gunther es un framework y no tiene CLI** (§1.1). Toda capacidad operativa se ofrece como función de Elixir:

- `Gunther.start_link/1` y `Gunther.stop/1` para el ciclo de vida.
- `Gunther.chat/2`, `Gunther.stream/3`, `Gunther.embed/2` para inferencia.
- `Gunther.Doctor.run/1` para diagnóstico (es una **función**, no un comando).
- `Gunther.Gateway` y `Gunther.MCP.Server` **no están en el árbol** de supervisión: los arranca la aplicación del usuario.

Quien quiera una línea de comandos la construye sobre la API. El caso "quiero usar Gunther desde fuera de Elixir" lo cubre `Gunther.Gateway` (HTTP) y `Gunther.MCP.Server` (MCP).

## Alternativas consideradas

- **CLI propia** (`gunther` como ejecutable): descartada por las cuatro razones de contexto.
- **CLI generada** a partir de la API: descartada porque las librerías Elixir no generan CLIs sin código adicional, y el resultado no es mejor que la API directa.
- **CLI mínima solo para `Doctor`**: descartada porque `Doctor.run/1` es suficiente y no hay demanda real de un comando separado.
- **CLI como fase 12** (lo que decía D-18): descartada en r7 (J-09) porque contradice D-31 y porque la CLI no aporta nada que la API no tenga.

## Consecuencias

- El diagnóstico se invoca desde la aplicación anfitriona (`Gunther.Doctor.run/1`).
- El gateway y el servidor MCP se arrancan explícitamente (no están en el árbol de Gunther).
- Un usuario que quiera una CLI la construye; no se le da una que duplique la API.
- Se elimina la "fase 12" del plan de desarrollo (D-18).

## Verificación

- F1-10 (`Doctor` como función).
- Revisión de código: ningún `System.argv/0` ni módulo `Mix.Tasks.*` en `lib/`.

- **Puertas F0 de las que depende**: ninguna
