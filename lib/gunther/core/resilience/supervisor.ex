defmodule Gunther.Resilience.Supervisor do
  @moduledoc """
  Los breakers, bulkheads y rate limiters por provider y modelo (SPEC §2.3).

  Los nombres internos de Arrea los traduce `Gunther.Resilience` (G-02). Todos
  los nombres llevan el prefijo `{Gunther, instancia, ...}` para que dos
  instancias en la misma VM no se pisen (SPEC §2.7).

  Es un `DynamicSupervisor`: cada breaker, bulkhead o limiter se arranca bajo
  demanda.
  """

  use DynamicSupervisor

  alias Gunther.Resilience

  @doc """
  Arranca el supervisor de resiliencia.
  """
  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts \\ []) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl DynamicSupervisor
  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Arranca el breaker de un provider, si no existe.

  ## Ejemplos

      iex> {:ok, pid} = Gunther.Resilience.Supervisor.ensure_breaker(:openai, %{})
      iex> is_pid(pid)
      true
  """
  @spec ensure_breaker(atom(), map()) :: {:ok, pid()} | {:error, term()}
  def ensure_breaker(provider, config) do
    Resilience.ensure_breaker(provider, config)
  end
end
