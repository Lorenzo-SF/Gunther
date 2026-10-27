# F0 · Procedimientos de las puertas

Cada puerta es una pregunta binaria. Para cada una: qué se hace, criterio de paso, qué se registra y qué rama del SPEC se aplica. Los comandos de fabricante y de llama.cpp son los candidatos a probar; que existan y produzcan lo esperado es precisamente lo que cada puerta verifica.

## Política de ejecución (CIERRE-DP0.md §3)

Una puerta se cierra con un resultado registrado. Los resultados posibles son:

| Resultado | Significado                                                 | Qué se registra                                                     |
| --------- | ----------------------------------------------------------- | ------------------------------------------------------------------- |
| PASA      | Se ejecutó y la rama A aplica                               | Procedimiento, salida, rama A                                       |
| FALLA     | Se ejecutó y la rama B aplica                               | Procedimiento, salida, rama B                                       |
| BLOQUEADA | No se puede ejecutar todavía (falta hardware, binario, red) | Motivo, rama B provisional aplicada, fecha objetivo de re-ejecución |

Reglas:

- No se permite marcar una puerta como PASA sin haberla ejecutado.
- Una puerta BLOQUEADA aplica provisionalmente la rama B y se anota la fecha objetivo de re-ejecución (al cerrar F2, o la fase que la consuma).
- No se reabre una puerta cerrada salvo que aparezca evidencia nueva (nueva versión de la librería, cambio de hardware). La entrada anterior del registro se conserva.
- Las puertas que bloquean F1 (G-01, G-05, G-07, G-16, G-17, G-21, G-23) deben estar PASA o BLOQUEADA con rama B aplicada para abrir F1.

Orden recomendado de ejecución (CIERRE-DP0.md §3.5):

1.  G-01, G-17, G-05, G-07, G-16.
2.  G-06, G-06b, G-08, G-22, G-23, G-27.
3.  G-09, G-12, G-14, G-18.
4.  G-10, G-11 (si hay GPU).
5.  G-24, G-26, G-25.
6.  G-19, G-20 (si hay red).
7.  G-28 (depende de F0-02).
8.  G-15, G-29, G-30, G-31.
9.  G-02, G-03, G-04 (no bloquean F1 pero sí F5).

## Formato del registro (docs/13-registro-de-fases.md)

** ### G-nn — título ** - Fecha: AAAA-MM-DD ** - Entorno: SO, versión; Elixir/OTP; versiones exactas de las librerías o binarios ** - Procedimiento: pasos ejecutados (o enlace al script en probes/) ** - Salida: ruta del fichero con la salida íntegra ** - Resultado: PASA | FALLA | BLOQUEADA ** - Rama aplicada: A | B | B (provisional) ** - Cambios en SPEC: secciones tocadas (para la próxima revisión) \*\*

## Preparación común

1.  Crear probes/ (fuera del paquete publicado) con un proyecto Mix por familia de puertas.
2.  Fijar versiones exactas en mix.lock y en el registro.
3.  Un script por puerta; los resultados deben ser reproducibles con un solo comando.

## Puertas

### G-01 · Dependencias sin ciclos

Proyecto vacío con arrea, apero y trebejo; mix deps.tree. Pasa si resuelve sin ciclos ni conflictos. Falla ⇒ listar el conflicto y resolver con los mantenedores (rama B) antes de F2.

### G-02 · Umbrales por breaker en Arrea.CircuitBreaker

Leer la API de la versión fijada. Arrancar dos breakers con umbrales distintos y forzar fallos en ambos. Pasa si cada uno abre con su propio umbral. Falla ⇒ rama B: umbrales globales documentados, o evaluar el paquete resiliency con la matriz (umbrales por instancia, single-flight, mantenimiento, licencia, dependencias).

### G-03 · Half-open con una sola sonda

Abrir un breaker; esperar a half-open; lanzar N llamadas concurrentes. Pasa si solo una llega al servicio. Falla ⇒ breaker mínimo propio tras Gunther.Resilience.

### G-04 · Bulkhead y RateLimiter

Comprobar: fallo rápido al llenarse el bulkhead (sin encolar), y si el limitador admite peso por llamada. Pasa si ambas cosas. Falla en peso ⇒ solo rpm y aviso de Doctor.

### G-05 · Apero.Retry

Reintento solo si un predicado lo permite y respeto de un retraso indicado por el servicio. Falla ⇒ envoltorio en Gunther.Resilience.

### G-06 · SafeCommand

(a) Con un .zshrc que tarde en ejecutarse, medir la latencia de un comando corto con y sin las opciones de shell; (b) comprobar que bloquea rm -rf / y acepta nvidia-smi --query-gpu=memory.free --format=csv. Pasa si no carga la config del shell o puede desactivarse, y las reglas distinguen los dos casos. Falla ⇒ fijar shell, vaciar el entorno y ajustar reglas.

### G-06b · Firmas de Trebejo.Proc

Listar y señalar un proceso de prueba; lsof de un puerto. Falla ⇒ capa fina propia dentro de Gunther.Command.

### G-07 · TOML en Apero.Conf

Cargar el gunther.example.toml completo (examples/). Pasa si el resultado coincide con el esperado, incluidas tablas anidadas y arrays de tablas. Falla ⇒ dependencia directa de un parser de TOML (elegirlo con criterio de mantenimiento y licencia).

### G-08 · Matriz del Spawner

Para la línea base Port y cada candidato: ejecutar los tests de R1 a R8 del SPEC §3.4 con un proceso de prueba que escribe en stdout y stderr, ignora stdin y sigue vivo si su padre muere. Registrar una tabla candidato × requisito. Pasa si algún candidato cumple R1 a R8 con versión publicada en los últimos 24 meses y licencia OSI. Falla ⇒ línea base con las consecuencias del SPEC §3.4.

### G-09 · llama-fit-params

Comprobar que el binario existe en la compilación fijada, su salida (formato analizable) y su comportamiento con -ngl fijado. Comparar la reserva calculada con la memoria que ocupa el engine tras cargar. Pasa si existe y su salida es analizable. Falla ⇒ --fit on en el arranque y reserva por fórmula o por vram_mb.

### G-10 · Analizador de --list-devices

En cada backend disponible, grabar la salida íntegra como fixture (ver 03-estrategia-de-pruebas.md) y ejecutar el analizador del SPEC §11.7. Registrar el nombre exacto de los devices de ROCm y Metal. Pasa por backend si el analizador extrae nombre, descripción, total y libre de todas las líneas. Falla ⇒ detector de fabricante para ese backend.

### G-11 · Herramientas de fabricante

Candidatos: nvidia-smi --query-gpu=uuid,name,memory.total,memory.used,memory.free --format=csv,noheader,nounits y nvidia-smi --query-compute-apps=pid,used_memory --format=csv,noheader,nounits; rocm-smi o amd-smi (opciones de identidad única y de procesos); para Vulkan, la utilidad que dé un identificador del dispositivo. Verificar si dan identidad física y atribución por proceso. Falla ⇒ [[devices.map]] obligatorio y regla de quiescencia (SPEC §11.3).

### G-12 · Funciones de llama-server

Con la compilación fijada, probar por petición: (a) restricción de salida por esquema JSON o gramática y el nombre del campo; (b) logprobs; (c) tokenización exacta; (d) reutilización de caché de prompt con el mismo prefijo (medir tokens evaluados en la segunda llamada); (e) la lista de rutas que el proxy de nodo debe permitir. Falla en cada punto ⇒ la rama B de esa fila (SPEC Anexo C.2).

### G-13 · Línea de comandos de un PID

Linux: leer /proc/<pid>/cmdline. macOS: ps -ww -o args= -p <pid>. Con un proceso de argumentos largos. Pasa si el texto es íntegro. Falla ⇒ sin adopción: se mata por PID, puerto e identidad HTTP y se arranca limpio.

### G-14 · Cabecera GGUF y tipos de ggml

Para modelos de referencia de cada tipo de atención (estándar, ventana deslizante, MLA, recurrente): leer las claves de la cabecera y comparar la fórmula con el tamaño de KV que informa el servidor al cargar (log). Extraer tamaño_de_bloque / elementos_por_bloque de los tipos cuantizados. Pasa por tipo de atención si la fórmula coincide tras redondear a MiB. Falla ⇒ el tipo queda «no válido» (SPEC §11.5).

### G-15 · MCP 2026-07-28

Procedimiento: contra la especificación oficial y un servidor y cliente de referencia, comprobar el método de descubrimiento de versión, el método de liveness y la regla de framing de stdio. Criterio de paso: los tres comportamientos coinciden con la especificación de 2026-07-28. Registro: formato común de este documento. Rama: si falla, tools/list como liveness y framing por líneas con reensamblado.

### G-16 · Nombre en Hex

Comprobar que gunther está libre. Falla ⇒ otro nombre de paquete; el namespace no cambia.

### G-17 · Versiones de arrea

Comparar tags publicados con la insignia 3.0.0 del README. Falla ⇒ fijar la versión real.

### G-18 · Plantilla de decisión

Con el modelo que el operador elija para la prueba: reproducir los ejemplos de su ficha. Pasa si da las rutas esperadas con la plantilla incorporada. Falla ⇒ plantilla personalizada (es configuración: SPEC §6.11).

### G-19 · mTLS con huella fijada

Generar dos certificados autofirmados (procedimiento en 06-guia-de-operacion.md); un servidor Bandit con verify_peer y comprobación de huella del cliente; un cliente Finch con comprobación de huella del servidor. Casos: certificados correctos, huella desconocida, TLS 1.2 ofrecido (debe rechazarse), certificado caducado. Registrar también lo que concede la distribución de Erlang a un nodo conectado. Falla ⇒ capa propia de verificación con verify_fun.

### G-20 · Proxy sin búfer

Proxy de Bandit hacia un servidor SSE; medir el momento de llegada de cada chunk al cliente frente a su emisión. Pasa si no se agrupan. Falla ⇒ conexión directa con TLS del engine (requiere compilación con soporte SSL).

### G-21 · Apero.Llm.\*

Leer la API vigente; decidir solapamiento. Falla ⇒ Gunther no los usa.

### G-22 · Clientes HTTP/SSE para LLM

Candidatos de la comunidad Elixir. Criterios: mantenimiento reciente, licencia, streaming SSE, cancelación, control de TLS, tamaño de dependencias. Tabla candidato × criterio. Ganador ⇒ transporte; ninguno ⇒ cliente propio sobre Finch.

### G-23 · Auditoría de dependencias

Evaluar herramientas de auditoría de vulnerabilidades además de mix hex.audit. Pasa si hay una mantenida y compatible. Falla ⇒ solo mix hex.audit.

### G-24 · sqlite-vec desde Elixir

Cargar sqlite-vec con el binding de SQLite de Elixir; insertar y buscar vectores; escrituras concurrentes con el modo de registro anticipado. Pasa si se carga la extensión y las búsquedas devuelven el vecino exacto. Falla ⇒ vectores en tabla normal puntuados en proceso.

### G-25 · pgvector y tsvector

Con el cliente de Postgres de Elixir: tipos de vector, índice, búsqueda por texto. Falla ⇒ Postgres sin vectores nativos o fuera de v1.

### G-26 · FTS5

Comprobar que el SQLite del binding tiene FTS5. Falla ⇒ léxico BM25 en proceso.

### G-27 · SDK de MCP existentes

Matriz con los criterios de G-22 más cobertura de 2026-07-28 y control de SSRF, sobre snodo, hermes_mcp y otros. Pasa si uno cumple. Falla ⇒ transporte propio.

### G-28 · Arrea como anfitrión

Leer el código de Arrea.Leader, Worker, Monitor y el pool de la versión elegida; comprobar R-A1 a R-A5 (SPEC §22.15); leer el registro de cambios de 4.0.0; comprobar si existe Arrea.Resource y en qué versión. Pasa si cumple los cinco requisitos. Falla ⇒ implementación propia (D-78) y las propuestas A-1 a A-8 al autor de Arrea.

Nota (Q-14, r8). Arrea.Resource existe y está publicado (D-13). G-28 no vuelve a comprobar la existencia; comprueba si, con su API pública actual, permite implementar foreign y available de §11.3 sin duplicar medidas. G-28 no bloquea F1.

### G-29 · Caché de prompt

Por cada provider usado y por llama-server: comprobar si se informa cached_input, qué condiciones la conservan o la invalidan (cambio de modelo, TTL, recarga del engine). Pasa por provider con un comportamiento reproducible. Falla ⇒ router.affinity = "off".

### G-30 · Continuidad al cambiar de modelo

Corpus multiturno con sondas sobre hechos fijados y un cambio de modelo en medio; comparar resend y portable con el intervalo de Wilson. Falla ⇒ on_switch = "resend".

### G-31 · DSL

Propiedad: la misma definición por datos, TOML y macros da un Plan idéntico; los errores del DSL llevan fichero y línea. Falla ⇒ solo datos y TOML.

## Cierre de F0

1.  Todas las puertas con registro.
2.  r8 del SPEC con las ramas aplicadas.
3.  CI con weekly-deps, weekly-llama y weekly-mcp configurados.
4.  ADR que cambien de estado: propuestas dependientes de una puerta pasan a aceptada o a revisión.
