# Ejemplo mínimo de Gunther

Este directorio contiene el **ejemplo ejecutable más pequeño posible**: una aplicación Mix que arranca Gunther con un único provider `Mock`, envía un mensaje y muestra la respuesta.

Sirve para tres cosas:

1.  **Ver la forma del API** sin tener que leer el SPEC entero.
2.  **Probar la build** sin configurar un provider real.
3.  **Servir de plantilla** para el primer proyecto real.

## Estado

**Esqueleto completo. La implementación ejecutable se completa en F3** (provider `Mock` y `ContractTest`). Mientras tanto, este README muestra la forma exacta que tendrá.

## Contenido esperado al cerrar F3

```
examples/minimal/
├── mix.exs
├── config/
│   └── gunther.toml
└── lib/
    ├── minimal.ex
    └── minimal/
        └── application.ex
```

## `gunther.toml`

```toml
[gunther]
instance_id = "minimal"
state_dir = "./state"

[consumers.default]
default_model = "mock"

[[models]]
alias = "mock"
provider = "mock"
model_id = "mock-model"
locality = "local"
capabilities = ["code"]
modalities = ["text"]
context_window = 4096
max_output_tokens = 256
max_concurrency = 1
resident = false
exclusive = false
pricing = { input_per_mtok_micros = 0, output_per_mtok_micros = 0 }

[providers.mock]
module = "Gunther.Provider.Mock"
```

## `lib/minimal/application.ex`

```elixir
defmodule Minimal.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Gunther, config: "config/gunther.toml"}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Minimal.Supervisor)
  end
end
```

## `lib/minimal.ex`

```elixir
defmodule Minimal do
  @moduledoc """
  Ejemplo mínimo de Gunther: un mensaje, una respuesta.
  """

  def run do
    case Gunther.chat("Hola, Gunther") do
      {:ok, response} ->
        IO.puts("Modelo: #{response.model}")
        IO.puts("Respuesta: #{response.content}")
        IO.puts("Degradado: #{response.degraded}")
        IO.puts("Coste: #{response.cost.total_micros} micro-dólares")
        :ok

      {:error, error} ->
        IO.puts(:stderr, "Error: #{error.code}")
        {:error, error}
    end
  end
end
```

## Cómo ejecutarlo (cuando F3 esté cerrado)

```bash
cd examples/minimal
mix deps.get
mix run -e 'Minimal.run()'
```

## Qué demuestra

- Que `Gunther.start_link/1` arranca con una config TOML.
- Que `Gunther.chat/2` acepta un `binary()` como mensaje.
- Que la respuesta es un `%Gunther.Response{}` con `content`, `model`, `degraded` y `cost`.
- Que los errores son valores (`%Gunther.Error{}`), no excepciones.

## Qué NO demuestra

- Streaming: ver `docs/06-guia-de-operacion.md` §9.
- Tool-calling: ver `docs/06-guia-de-operacion.md` §9 y `SPEC §9`.
- RAG: ver `docs/06-guia-de-operacion.md` §9 y `SPEC §8`.
- Nodos remotos: ver `docs/06-guia-de-operacion.md` §5 y `SPEC §18`.
- Coral: ver `SPEC §22` (post-1.0).

Para un ejemplo completo, ver `examples/` cuando se añadan más en fases posteriores.
