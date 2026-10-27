# Hoja de ruta posterior a 1.0 (no comprometida)

| Elemento | Condición para entrar |
| --- | --- |
| Colmena y voces (v1.1) | Criterio de promoción del SPEC §10.2 |
| Detector de idioma y regla `{lang: _}` | Aparece como behaviour con contrato y pruebas |
| Referencia de `:win_rate_binary` | Un modelo evaluable con la verificación de §6.11 |
| Reparto de tensores de un modelo entre máquinas | Una alternativa con autenticación y sin las exposiciones del backend RPC de llama.cpp; hoy **excluido** |
| Backends SYCL y OpenCL | Datos de uso habitual; se añaden implementando `Detector` |
| Modo con autoridad certificadora propia para nodos | Necesidad real con más de dos nodos |
| Soporte de peticiones multironda de MCP (`input_required`) | Necesidad real |
| Engines contenerizados (`Trebejo.Docker`) | Necesidad real |
| `Arrea.Resource` como base del ledger | Existe y supera los tests de invariantes |
| `Cache.Completions` (retirada de v1 por D-44) | Decisión nueva con clave, TTL, condiciones de uso y aislamiento por consumer |
| Classifier de consulta del RAG (A1) | Verificación por resultado: `recall@5` con límite inferior de Wilson frente a «siempre `hybrid`»; no clasifica consultas redactadas por el modelo |
| `MemoryStore` persistente y `[rag] store_backend = "shared"` | Contrato de persistencia para la memoria KV |
| Plantillas de prompt escritas por el usuario final | Sandbox y decisión nueva (D-38) |
| La coral (F18 a F22) | Aprobación del dueño de D-74 a D-86 y los ganchos G1 a G9 en v1 |
| ADR de D-01 a D-47 | Ya escritos (D-01 a D-28 desde el documento original; D-29 a D-47 desde el SPEC) |
