# ADR D-25 — El breaker de los agentes sin nombre

- **Estado**: aceptada
- **Decidida**: 2026-10-19, por el dueño.
- **Fuente**: README original de `08-decisiones` (decidido hasta 2026-10-21; `main` 398a1b9)

## Contexto
```elixir
cond do
  name != nil and Crashes.count(name, now()) >= budget -> {:stop, :crash_budget_exceeded}
  name != nil -> ... Breakers.load(name) ...          # el circuito
  true -> init_state(name, opts)                      # sin nombre: ni presupuesto ni circuito
end
```

Tercera opción, la correcta: **darle identidad derivada** —`{módulo, hash de
las opciones}` o el `goal`— para que caiga en la misma puerta que los
nombrados. Evita el caso raro de tener que decir «los agentes anónimos son
los que cuelgan».

## Decisión
**Qué**: `restart: :transient` ya está en los dos `child_spec` (D-20). La
pregunta real no era «breaker o transient» — ambas ya conviven — sino que **un
agente sin nombre se salta las dos puertas** (presupuesto de crashes y
circuito), porque no tiene dónde persistir nada:

## Alternativas consideradas
**Si se prefiere que sigan sin protección**, queda escrito como decisión
explícita: «un agente anónimo no tiene identidad y aceptamos que un cuelgue
suyo lo mate». Lo que no puede ser es que siga siendo una pregunta abierta
mientras el código parece protegerlo.

## Consecuencias
**Desbloquea**: P-9 última mitad.

## Verificación
El documento original no define una verificación específica; ver las puertas F0.

- **Puertas F0 de las que depende**: ninguna
