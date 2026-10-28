defmodule Gunther.Telemetry.Bridge do
  @moduledoc """
  Puente selectivo de telemetría (SPEC §3.5).

  Reenvía **solo** los eventos de Arrea y Apero que Gunther necesita, con
  prefijo `[:gunther, ...]`. El resto de eventos de Arrea y Apero siguen
  disponibles bajo su propio prefijo: no se reenvía nada por defecto.

  ## Mapeo

  | Origen | Destino |
  | ------ | ------- |
  | `[:arrea, :circuit_breaker, :open]` | `[:gunther, :breaker, :opened]` |
  | `[:arrea, :validation, :failed]` | `[:gunther, :command, :blocked]` |

  ## Eventos propios

  - `[:gunther, :cache, :hit | :miss | :evict]`
  - `[:gunther, :router, :cache_hit | :cache_miss]`

  El prefijo `[:gunther, :coral, ...]` queda **reservado** (G6): lo usa la
  coral en v1.1 y este módulo no lo emite. **Ademas, no se puede usar por
  error**: un puente arrancado con ese prefijo **se niega a arrancar**. Una
  reserva que se puede ocupar sin querer no es una reserva.
  """

  use GenServer

  require Logger

  @doc """
  Arranca el puente. Es idempotente: si ya hay uno, no arranca otro.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    prefix = Keyword.get(opts, :prefix, [:gunther])

    # El prefijo reservado se comprueba **antes** de arrancar: arrancar un
    # proceso que va a morir es un crash, y un crash por una configuracion
    # prohibida no dice que hacer. El error es un valor (§4.13).
    if reserved?(prefix) do
      {:error, {:reserved_prefix, prefix}}
    else
      case GenServer.start_link(__MODULE__, opts, name: name) do
        {:ok, pid} -> {:ok, pid}
        {:error, {:already_started, pid}} -> {:ok, pid}
      end
    end
  end

  @impl GenServer
  def init(opts) do
    prefix = Keyword.get(opts, :prefix, [:gunther])

    if reserved?(prefix) do
      # La reserva de G6 no es una recomendacion: es un limite.
      {:stop, {:reserved_prefix, prefix}}
    else
      attach(prefix)
    end
  end

  # El prefijo reservado de la coral (G6).
  @reserved_prefix [:gunther, :coral]

  @doc """
  Si un prefijo es el reservado de la coral (G6).

  ## Ejemplos

      iex> Gunther.Telemetry.Bridge.reserved?([:gunther, :coral])
      true

      iex> Gunther.Telemetry.Bridge.reserved?([:gunther, :cache])
      false
  """
  @spec reserved?(list()) :: boolean()
  def reserved?(@reserved_prefix), do: true
  def reserved?(prefix) when is_list(prefix), do: List.starts_with?(prefix, @reserved_prefix)
  def reserved?(_prefix), do: false

  defp attach(prefix) do
    :telemetry.attach_many(
      "gunther-bridge",
      [
        [:arrea, :circuit_breaker, :open],
        [:arrea, :validation, :failed]
      ],
      &__MODULE__.handle_event/4,
      %{prefix: prefix}
    )

    {:ok, %{prefix: prefix}}
  end

  @impl GenServer
  def terminate(_reason, _state) do
    :telemetry.detach("gunther-bridge")
    :ok
  end

  @doc false
  @spec handle_event([atom()], map(), map(), map()) :: :ok
  def handle_event([:arrea, :circuit_breaker, :open], _measurements, metadata, config) do
    :telemetry.execute(
      [:gunther, :breaker, :opened],
      %{},
      Map.put(metadata, :prefix, config.prefix)
    )
  end

  @spec handle_event([atom()], map(), map(), map()) :: :ok
  def handle_event([:arrea, :validation, :failed], _measurements, metadata, config) do
    :telemetry.execute(
      [:gunther, :command, :blocked],
      %{},
      Map.put(metadata, :prefix, config.prefix)
    )
  end

  @spec handle_event([atom()], map(), map(), map()) :: :ok
  def handle_event(_event, _measurements, _metadata, _config), do: :ok

  @doc """
  Emite un evento de caché con el hash de la clave, nunca el valor.

  ## Ejemplos

      iex> Gunther.Telemetry.Bridge.cache_event(:hit, :una_clave)
      :ok
  """
  @spec cache_event(:hit | :miss | :evict, term()) :: :ok
  def cache_event(kind, key) do
    :telemetry.execute(
      [:gunther, :cache, kind],
      %{},
      %{key_hash: hash(key)}
    )
  end

  @doc """
  Emite un evento de la caché de decisiones.
  """
  @spec router_cache_event(:cache_hit | :cache_miss, term()) :: :ok
  def router_cache_event(kind, key) do
    :telemetry.execute(
      [:gunther, :router, kind],
      %{},
      %{key_hash: hash(key)}
    )
  end

  defp hash(key) do
    key
    |> :erlang.term_to_binary()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
    |> binary_part(0, 16)
  rescue
    _other -> "unhashable"
  end
end
