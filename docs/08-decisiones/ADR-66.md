# ADR D-66 — Nodos remotos gestionados

- **Estado**: aceptada (DP0, r8)
- **Fecha**: 2026-10-25
- **SPEC**: SPEC-000-GUNTHER r6

## Contexto
El dueño quiere gestionar un engine de otro PC como si fuera interno.

## Decisión
Agente de nodo propio con API de control sobre HTTPS y mTLS con huella fijada; plano de datos mediado por el agente; ledger autoritativo en el nodo con leases de TTL relativo. Se descarta el backend RPC de llama.cpp.

## Alternativas consideradas
Distribución de Erlang (descartada: concede ejecución arbitraria). Backend RPC (descartado: sin autenticación y con vulnerabilidades de ejecución remota). SSH con comandos (descartado: viola D-67). Solo proveedor externo sin gestión (se mantiene como modo `external`).

## Consecuencias
Una superficie de red y una pila TLS que auditar; un salto adicional dentro del nodo, acotado por N-07.

## Verificación
G-19, G-20; F15.

- **Puertas F0 de las que depende**: G-19, G-20
