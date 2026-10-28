defmodule Gunther.Decision do
  @moduledoc """
  La decisión del enrutador (SPEC §4.2, §6).

  `ranked` contiene **todos** los candidatos elegibles, ordenados: primero los
  que opinaron las capas, después el resto según `fallback_strategy`. `chosen`
  es el primero servible. El failover de §2.5 consume esta lista.

  ## Ejemplos

      iex> Gunther.Decision.new(%{chosen: :a, provider: :p, ranked: [:a, :b]})
      %Gunther.Decision{chosen: :a, provider: :p, node: nil, ranked: [:a, :b], reason: :fallback, layers_ran: [], candidates_per_layer: [], filtered: [], degraded: [], decision_model: nil, affinity: nil, consumer_rules_applied: [], global_rules_applied: [], trace_id: nil, duration_ms: 0, timestamp: nil}
  """

  @type reason :: :cache | :pin | :rule | :embedding | :llm | :fallback | :veto | :force
  @type layer :: :cache | :pin | :rule | :embedding | :llm | :fallback

  @type t :: %__MODULE__{
          chosen: atom(),
          provider: atom(),
          node: atom() | nil,
          ranked: [atom()],
          reason: reason(),
          layers_ran: [layer()],
          candidates_per_layer: [%{layer: layer(), before: non_neg_integer(), after: non_neg_integer()}],
          filtered: [%{model: atom(), reason: atom()}],
          degraded: [atom()],
          decision_model: %{id: atom(), kind: atom(), report_id: binary() | nil} | nil,
          affinity: %{model: atom(), applied: boolean()} | nil,
          consumer_rules_applied: [atom()],
          global_rules_applied: [atom()],
          trace_id: binary(),
          duration_ms: non_neg_integer(),
          timestamp: DateTime.t() | nil
        }

  @enforce_keys [:chosen, :provider]
  defstruct chosen: nil,
            provider: nil,
            node: nil,
            ranked: [],
            reason: :fallback,
            layers_ran: [],
            candidates_per_layer: [],
            filtered: [],
            degraded: [],
            decision_model: nil,
            affinity: nil,
            consumer_rules_applied: [],
            global_rules_applied: [],
            trace_id: "",
            duration_ms: 0,
            timestamp: nil

  @doc """
  Construye una decisión.

  ## Ejemplos

      iex> Gunther.Decision.new(%{chosen: :a, provider: :p, ranked: [:a]}).ranked
      [:a]
  """
  @spec new(map()) :: t()
  def new(attrs) do
    struct!(__MODULE__, attrs)
  end

  @doc """
  Los candidatos tras la decisión, en orden de preferencia.

  Es la lista que consume el failover de §2.5.

  ## Ejemplos

      iex> Gunther.Decision.new(%{chosen: :a, provider: :p, ranked: [:a, :b]}).candidates
      [:a, :b]
  """
  @spec candidates(t()) :: [atom()]
  def candidates(%__MODULE__{ranked: ranked}), do: ranked

  @doc """
  ¿La decisión está degradada?

  ## Ejemplos

      iex> Gunther.Decision.new(%{chosen: :a, provider: :p, degraded: [:failover]}).degraded?()
      true
  """
  @spec degraded?(t()) :: boolean()
  def degraded?(%__MODULE__{degraded: degraded}) when is_list(degraded), do: degraded != []
  def degraded?(%__MODULE__{degraded: degraded}) when is_boolean(degraded), do: degraded
end
