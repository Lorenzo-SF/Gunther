# Glosario

| Término | Significado |
| --- | --- |
| **AC** | Criterio de aceptación de una fase (SPEC §19) |
| **ADR** | Registro de una decisión (`docs/08-decisiones/`) |
| **Backend (GPU)** | CUDA, Vulkan, ROCm, Metal (o CPU) con que se compila un engine |
| **CE** | Cierre de especificación: detalle que faltaba en una decisión ya tomada |
| **Controlador** | Máquina donde corre Gunther completo |
| **Decisor / modelo de decisión** | Modelo especializado que ordena candidatos (SPEC §6.11) |
| **Device** | Slot de memoria con identidad física (`physical_id`) |
| **Engine** | Proceso que sirve un modelo (p. ej. `llama-server`) |
| **Foreign** | Memoria de un device ocupada por procesos que no son de Gunther |
| **G-nn** | Puerta F0: hecho no verificado con test y ramas diseñadas |
| **Lease** | Reserva de capacidad con TTL en el ledger de un nodo |
| **Nodo** | Otra máquina cuyo engine gestiona Gunther |
| **Ranking** | Lista ordenada de candidatos de una decisión |
| **Refusal** | Política cuando no hay capacidad: fail, wait, degrade |
| **Skill** | Lo que sabe hacer un modelo (taxonomía cerrada) |
| **[V] / [V5] / [G] / [P]** | Verificado hoy / verificado en r5 / puerta / propuesta |
| **Coral** | Infraestructura integrada de Gunther más la base para organizar grupos de agentes (SPEC §22) |
| **Modalidad** | Plantilla que produce un plan de coral (`:hive`, `:teamwork`, propias) |
| **Plan** | Estructura de datos única que describe roles, pizarra y pasos |
| **Pizarra** | Memoria compartida de una ejecución de la coral |
| **Mesa camilla** | Nombre anterior de la mente colmena (son el mismo concepto) |
| **Mente colmena** | Modalidad `:hive` de la coral |
| **Rol / Miembro** | Perfil de un participante / agente en ejecución que lo desempeña |
| **Contexto portable** | Resumen incremental, hechos fijados y últimos turnos para cambiar de modelo sin reenviar todo |
| **Lease** | Reserva de capacidad con TTL en el ledger de un nodo |
| **Reconciliación** | Comprobar al arrancar qué engines vivos son de esta instancia (marca, identidad HTTP) |
| **Bulkhead** | Límite de concurrencia que falla rápido al llenarse |
| **Breaker** | Corta las llamadas a un provider que falla |
| **Prompt injection** | Instrucciones hostiles dentro del contenido que lee el modelo |
| **Rerouting attack** | Ataque que redirige a un router hacia un modelo concreto |
