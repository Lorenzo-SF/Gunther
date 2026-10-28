defmodule Gunther.DecisionSpec do
  @moduledoc """
  La definición completa de un modelo de decisión (SPEC §6.11).

  Se declara en `[[decision_models]]`.

  ## Ejemplos

      iex> spec = Gunther.DecisionSpec.new(%{id: :router_pref, kind: :preference_router, model: :arch_router})
      iex> spec.max_output_tokens
      32
  """

  @type t :: %__MODULE__{
          id: atom(),
          kind: :preference_router | :win_rate_binary | :general_llm,
          model: atom(),
          routes: %{optional(atom()) => %{description: binary(), models: [atom()]}},
          other: :abstain | atom(),
          win_rate: %{strong: atom(), weak: atom(), threshold: float()} | nil,
          output: {:json_schema, map()} | {:grammar, binary()} | nil,
          max_input_tokens: pos_integer(),
          max_output_tokens: pos_integer(),
          temperature: float(),
          seed: integer(),
          confidence: :logprobs | :none,
          min_confidence: float() | nil,
          resident: boolean(),
          device: :auto | :cpu | binary(),
          context_roles: [:user | :system],
          context_turns: pos_integer(),
          prompt: {:builtin, atom()} | {:module, module()},
          parse: {:builtin, atom()} | {:module, module()},
          require_eval: boolean(),
          eval: map(),
          verification: :unverified | :active | :failed,
          report_id: binary() | nil,
          max_concurrency: pos_integer()
        }

  @enforce_keys [:id, :kind, :model]
  defstruct id: nil,
            kind: :preference_router,
            model: nil,
            routes: %{},
            other: :abstain,
            win_rate: nil,
            output: nil,
            max_input_tokens: 2048,
            max_output_tokens: 32,
            temperature: 0.0,
            seed: 0,
            confidence: :none,
            min_confidence: nil,
            resident: false,
            device: :auto,
            context_roles: [:user],
            context_turns: 1,
            prompt: {:builtin, :preference_router},
            parse: {:builtin, :json_route},
            require_eval: true,
            eval: %{},
            verification: :unverified,
            report_id: nil,
            max_concurrency: 1

  @doc """
  Construye un `DecisionSpec` con los defectos de §6.11.

  ## El estado de verificacion

  `:unverified` es el estado de partida: un modelo de decision no acts hasta
  que hay un informe de evaluacion que lo verifique (§6.11). `:active` es
  verificado, `:failed` es que el informe no cumple los umbrales.

  ## Ejemplos

      iex> Gunther.DecisionSpec.new(%{id: :x, kind: :general_llm, model: :m}).temperature
      0.0
  """
  @spec new(map() | keyword()) :: t()
  def new(attrs) when is_map(attrs) or is_list(attrs) do
    struct!(__MODULE__, Map.new(attrs))
  end

  @doc """
  Si el modelo de decision puede actuar (§6.11).

  Solo un modelo `:active` actua, salvo que el operador admita actuar sin
  verificar (`router.allow_unverified`).

  ## Ejemplos

      iex> spec = %Gunther.DecisionSpec{id: "d1", kind: :preference_router, model: "m1", verification: :active}
      iex> Gunther.DecisionSpec.verified?(spec)
      true

      iex> spec = %Gunther.DecisionSpec{id: "d1", kind: :preference_router, model: "m1", verification: :unverified}
      iex> Gunther.DecisionSpec.verified?(spec)
      false
  """
  @spec verified?(t()) :: boolean()
  def verified?(%__MODULE__{verification: verification}), do: verification == :active
end
