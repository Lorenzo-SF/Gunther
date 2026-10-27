# Guía de operación

Para quien despliega y configura Gunther. **Gunther no instala ni descarga nada**: ni binarios de engine ni modelos. Quien lo opera los instala y declara sus rutas.

## 1. Requisitos
Elixir 1.19, OTP 27 o 28; Linux, macOS ≥ 13 o WSL2 (Windows nativo no soportado). Un binario de `llama-server` compilado para tu backend (CUDA, Vulkan, ROCm o Metal) o CPU, y los modelos GGUF que vayas a usar.

## 2. Primer arranque
1. Copia `examples/gunther.example.toml` a `gunther.toml` y edítalo.
2. Declara el ejecutable en `[commands].allow` con `path` y, recomendado, `sha256`.
3. Declara `[[engines]]` y `[[models]]`.
4. Ejecuta `Gunther.Doctor.run/1` desde tu aplicación y corrige los `:fail` y `:warn`.
5. Arranca con `Gunther.start_link(config: "gunther.toml")` o cuelga `Gunther.child_spec/1` de tu árbol.

## 3. GPUs: identidad de dispositivos
- Con **un solo** GPU físico visible, Gunther lo identifica solo.
- Con varios GPUs, o con el mismo GPU visible por dos backends, `[[devices.map]]` es **obligatorio**. `Doctor` imprime la tabla candidata (nombre, descripción, total) para que la completes.
- En **memoria unificada** (Metal, APU, iGPU) debes fijar `max_mib` y `reserve_mib`: sin ellos el device queda inutilizable porque no hay un valor correcto por defecto.
- `placement.max_loaded_models` limita cuántos modelos cargados a la vez por máquina, además del límite de memoria. Con `0` solo manda la memoria.

## 4. Gestión de arranque y apagado
Un modelo local o de nodo se arranca cuando una petición lo necesita y no está cargado, y se descarga tras `engine.idle_unload_seconds` sin uso salvo que sea `resident = true`. Si no hay hueco, la política de `[refusal]` decide: `fail`, `wait` (espera a que se libere) o `degrade` (usa el siguiente candidato). `Gunther.stop/1` apaga los engines propios; con `keep_engines: true` los deja vivos, y al volver a arrancar Gunther los **readopta** solo si superan la verificación de identidad (SPEC §2.8).

## 5. Nodos remotos (el segundo PC)

### 5.1 Certificados con huella fijada
En cada máquina, un certificado autofirmado y su huella. Procedimiento propuesto (se valida en G-19):

```
openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes \
  -keyout pc2.key -out pc2.crt -days 365 -subj "/CN=pc2" \
  -addext "subjectAltName=IP:192.168.1.20"
openssl x509 -in pc2.crt -noout -fingerprint -sha256
chmod 600 pc2.key
```

Repite para el controlador (`pc1`). Intercambia **solo las huellas**: la del nodo va en `[[nodes]].pinned_server_cert_sha256` del controlador; la del controlador va en `allowed_clients` del nodo. Las claves privadas no salen de su máquina.

### 5.2 Configuración del nodo
Parte de `examples/gunther_node.example.toml`. Define `bind` (obligatorio), certificados, `allowed_clients`, la lista de ejecutables permitidos y los **perfiles**: cada perfil fija la ruta del modelo, el backend, el dispositivo y los límites. El controlador solo puede pedir un perfil por su id y ajustar los `allowed_overrides` dentro de sus máximos.

### 5.3 Rotación
1. Genera el certificado nuevo.
2. Añade su huella a la lista del otro lado (sin quitar la antigua).
3. Sustituye el certificado.
4. Quita la huella antigua.

### 5.4 Qué esperar
Si el nodo no responde (3 latidos perdidos con los valores por defecto), sus modelos salen del conjunto elegible y las peticiones van a otros candidatos. Al volver, el controlador readopta solo los engines suyos.

## 6. El modelo decisor
1. Instala el modelo que elijas y decláralo en `[[models]]`.
2. Declara `[[decision_models]]`: `kind`, `routes` con descripciones en lenguaje natural y los modelos de cada ruta, `required_languages`, y, si el modelo necesita otra plantilla o parser, tus módulos en `prompt` y `parse`.
3. **Construye el corpus** (SPEC §16.4): activa `router.capture` si quieres partir de tráfico real (se guarda solo en tu máquina), etiqueta casos a mano, y opcionalmente genera casos sintéticos y adversarios con las funciones de `Gunther.Eval.Corpus`.
4. Ejecuta `Gunther.Doctor.calibrate_router/2`. El decisor se activa solo si supera la línea base con confianza del 95 % en **todos** tus idiomas requeridos y con casos adversarios.
5. Cualquier cambio del modelo, de las rutas o de la especificación invalida el informe y hay que repetir la calibración.
6. Sin decisor verificado, el router funciona con reglas, embedding verificado y fallback.

## 7. Seguridad mínima antes de exponer nada
- Gateway: loopback por defecto. Fuera de loopback exige clave de API y TLS.
- Claves de API de providers solo por variables de entorno.
- No actives `gunther.dotenv` salvo que sepas lo que cargas.
- Las tools importadas de MCP piden confirmación por defecto: no lo relajes sin motivo.
- Revisa `docs/07-seguridad-checklist.md`.

## 8. Diagnóstico por código de error

| Código | Qué significa | Qué mirar |
| --- | --- | --- |
| `:no_room` | No cabe el modelo en ningún device | `Gunther.Nodes.list/0`, memoria libre, `max_loaded_models` |
| `:device_unusable` | Device sin medición fiable | `Doctor`: `:unmapped`, `:inconsistent_report`, `:unified_needs_limit`, `:foreign_unknown` |
| `:memory_unknown` | No se pudo calcular el peso | Tipo de atención no válido para la fórmula; falta `vram_mb` o `fit` |
| `:no_candidates` | Reglas o filtros dejan el conjunto vacío | `Decision.filtered` con `trace: true` |
| `:refused_capacity` / `:refused_timeout` | Sin capacidad con la política elegida | `[refusal]` |
| `:node_unreachable` | Latidos perdidos | Red, certificado, agente de nodo |
| `:node_auth_failed` | Huella o certificado no coinciden | Listas de huellas en ambos lados |
| `:invalid_structured_output` | El modelo no produjo la forma pedida tras los reintentos | Modelo, esquema, `structured.max_retries` |
| `:tool_confirmation_required` | Una tool exige aprobación | `opts.approve_tools` o agente con HITL |
| `:classifier_unverified` (aviso) | Decisor sin informe válido | Repite la calibración (§6) |
| `:stream_interrupted` | El stream falló tras el primer chunk | Provider o nodo |
| `:budget_exceeded` | La estimación supera el presupuesto | `opts.budget`, `max_tokens` |

## 9. Consumers, RAG y recorrido mínimo (r7)
**Consumers**: cada uno se declara en `[consumers.<id>]` con `default_model` (obligatorio) y, si quieres, `priority`.
**RAG**: `rag_query` se registra sola como tool; con más de un consumer, `Doctor` avisa porque el índice es común y la tool es `:auto` (cámbiala a `:confirm` con `tools.permissions` si no quieres eso). Calibra el umbral con `Doctor.calibrate_rag/2` (F1@5); sin calibrar funciona con `min_score = 0.0`. `store_backend = "shared"` no está disponible en v1.
**Recorrido mínimo**: (1) `gunther.toml` con un `[[models]]` externo o local y un `[consumers.default]`; (2) `Gunther.start_link(config: "gunther.toml")`; (3) `Gunther.chat("hola")`; (4) `Gunther.Doctor.run/1` para ver el estado. Se completa con un ejemplo ejecutable en F3.
