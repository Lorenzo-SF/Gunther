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
          eval: map()
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
            eval: %{}

  @doc """
  Construye un `DecisionSpec` con los defectos de §6.11.

  ## Ejemplos

      iex> Gunther.DecisionSpec.new(%{id: :x, kind: :general_llm, model: :m}).temperature
      0.0
  """
  @spec new(map()) :: t()
  def new(attrs) do
    struct!(__MODULE__, attrs)
  end
end
