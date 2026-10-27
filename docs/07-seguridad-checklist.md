# Lista de seguridad (se ejecuta en F16 y antes de cada versión)

Cada punto referencia la amenaza del SPEC §15.2 y su prueba.

| # | Comprobación | Amenaza | Cómo |
| --- | --- | --- | --- |
| 1 | Ninguna clave, prompt ni argumento de tool aparece en logs ni eventos de una petición completa | T-05 | Prueba de búsqueda de la clave sembrada |
| 2 | `ArgsBuilder` no emite `--rpc` ni el flag de herramientas de agente de `llama-server`; rechaza `extra_args` no permitidos | T-04, T-08 | Pruebas con entradas hostiles |
| 3 | Un engine local escucha solo en loopback y exige clave; la clave viaja por entorno, no por argv | T-09 | Prueba de bind y de acceso sin clave |
| 4 | Cambiar el binario permitido (ruta, inodo o hash) impide el lanzamiento | T-04 | Prueba |
| 5 | Redirección 3xx, DNS múltiple y rangos privados rechazados en el cliente MCP | T-03 | Resolver falso |
| 6 | Gateway fuera de loopback sin clave y TLS no arranca | T-06 | Prueba de arranque |
| 7 | Nodo: huella desconocida, TLS 1.2, certificado caducado y overrides fuera de rango rechazados | T-07 | Pruebas de F15 |
| 8 | Un byte alterado en sesión, snapshot de agente o `engines.json` se rechaza | T-12 | Prueba |
| 9 | `binary_to_term` siempre con `[:safe]` | T-12 | Grep en CI |
| 10 | `mix hex.audit` y la herramienta de G-23 sin hallazgos | T-13 | CI |
| 11 | `[[engines]].min_build` configurado y `Doctor` falla con una compilación menor | T-14 | Prueba |
| 12 | Parser GGUF sometido a fuzz sin cuelgues ni lecturas fuera de rango | T-14 | Fuzz |
| 13 | Sesiones, memoria y caché aislados por consumer | T-15 | Prueba |
| 14 | `DecisionView` no contiene contenido de RAG, tools, memoria, MCP ni mensajes `assistant` | T-01, T-02 | Prueba |
| 15 | Corpus adversario y de inyección ejecutados y archivados | T-01, T-02 | Informes |
| 16 | Sin `.env` cargado por defecto | T-05 | Prueba |
| 17 | Permisos de ficheros de claves de mTLS comprobados por `Doctor` | T-07 | Prueba |
| 18 | `SECURITY.md` vigente y canal de aviso privado de vulnerabilidades configurado | — | Revisión |
| 19 | Ningún endpoint registra plantillas de prompt; el contenido de usuario no se concatena en plantillas | T-25 | Prueba |
| 20 | Logs sin valores de usuario concatenados al mensaje | T-16 | Prueba |
