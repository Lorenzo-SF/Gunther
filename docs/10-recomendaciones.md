# Recomendaciones (no vinculantes)

Gunther es **agnóstico del modelo decisor** (D-72). Este documento solo recoge **hechos verificados** y criterios de elección. No sustituye a la evaluación con tu corpus: el decisor se activa solo si la supera.

## Familias de decisores (hechos verificados el 2026-10-25)

| Familia | Qué decide | Datos verificados | Límite que declara su fuente o su naturaleza |
| --- | --- | --- | --- |
| Estilo Arch-Router (Katanemo, 1,5 B) | Elige una **ruta** entre políticas que describes en lenguaje natural; responde `{"route": "..."}`; admite `other` | Existe en GGUF; licencia de Katanemo | El texto de licencia consultado (en otro modelo de la misma empresa) exige licencia aparte para empaquetarlo en un framework o gateway: Gunther no lo distribuye. La calidad en otros idiomas **no está verificada** |
| LLM pequeño con salida restringida | Clasifica la intención según una plantilla propia | El enrutador de NVIDIA (Apache 2.0) usa uno de 1,7 B para esa función | Depende del modelo y de tu plantilla |
| Estilo RouteLLM | Entre **dos** modelos: probabilidad de que gane el fuerte, con umbral calibrado | Código de referencia con licencia abierta | Es binario; los routers publicados no son GGUF |
| Clasificadores de categorías fijas (por ejemplo basados en mmBERT) | Una categoría de un conjunto cerrado | Apache 2.0; multilingüe declarado por su autor; 14 categorías | No decide rutas definidas por ti; encaja como capa `:embedding` o `Classifier` de terceros |

## Cómo elegir

1. Reúne tu corpus por idioma (SPEC §16.4).
2. Evalúa **dos o tres** candidatos con `Doctor.calibrate_router/2`.
3. Quédate con el que pasa la verificación en **todos** tus idiomas con menor p99.
4. Si ninguno pasa, el router sigue funcionando con reglas, embedding y fallback: no actives un decisor sin verificar.

## Dónde poner el modelo
- Un decisor `resident = true` ocupa memoria de forma permanente; el informe de calibración registra el dispositivo con el que se midió. La elección CPU frente a GPU la decide esa medición.
- Si el decisor corre en un nodo remoto, su latencia incluye la red y el proxy (mídelo en la calibración).

**Ningún modelo se recomienda como defecto.** Gunther no trae ni fija un modelo decisor; lo elige el operador con su evaluación (SPEC §6.11).
