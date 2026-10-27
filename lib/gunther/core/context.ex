defmodule Gunther.Context do
  @moduledoc """
  El sobre único de contexto de una petición (SPEC §4.2, §22.3, gancho G2).

  Sin `:context` explícito, Gunther crea uno por defecto. Si el contexto y las
  opciones discrepan, **ganan las opciones explícitas** (SPEC §4.2).

  ## Qué lleva

  - `:consumer` — el consumer que pide
  - `:session` — la sesión activa
  - `:memory` — si se lee y escribe la memoria KV
  - `:rag` — si se inyecta contexto del RAG
  - `:tools` — si se habilitan las tools
  - `:guardrails` — si se aplican los guardrails
  - `:trace` — si se incluye la traza
  - `:compaction` — la estrategia de compactación

  ## Ejemplos

      iex> Gunther.Context.new()
      %Gunther.Context{consumer: :default, session: nil, memory: true, rag: nil, tools: nil, guardrails: true, trace: false, compaction: nil, decision: :auto, require: nil, options: %{}}
  """

  @type t :: %__MODULE__{
          consumer: atom(),
          session: binary() | nil,
          memory: boolean(),
          rag: map() | nil,
          tools: [String.t()] | nil,
          guardrails: boolean(),
          trace: boolean(),
          compaction: atom() | nil,
          decision: :auto | :none,
          require: map() | nil,
          options: map()
        }

  defstruct consumer: :default,
            session: nil,
            memory: true,
            rag: nil,
            tools: nil,
            guardrails: true,
            trace: false,
            compaction: nil,
            decision: :auto,
            require: nil,
            options: %{}

  @doc """
  Crea un contexto con los defectos del SPEC.

  ## Ejemplos

      iex> Gunther.Context.new().consumer
      :default
  """
  @spec new(map()) :: t()
  def new(attrs \\ %{}) do
    struct!(__MODULE__, attrs)
  end

  @doc """
  Aplica las opciones explícitas sobre un contexto.

  **Ganan las opciones explícitas** (SPEC §4.2).

  ## Ejemplos

      iex> context = Gunther.Context.new()
      iex> Gunther.Context.merge_options(context, consumer: :otro).consumer
      :otro
  """
  @spec merge_options(t(), keyword()) :: t()
  def merge_options(%__MODULE__{} = context, opts) do
    %{
      context
      | consumer: Keyword.get(opts, :consumer, context.consumer),
        session: Keyword.get(opts, :session, context.session),
        memory: Keyword.get(opts, :memory, context.memory),
        rag: Keyword.get(opts, :rag, context.rag),
        tools: Keyword.get(opts, :tools, context.tools),
        guardrails: Keyword.get(opts, :guardrails, context.guardrails),
        trace: Keyword.get(opts, :trace, context.trace),
        compaction: Keyword.get(opts, :compaction, context.compaction),
        decision: Keyword.get(opts, :decision, context.decision),
        require: Keyword.get(opts, :require, context.require)
    }
  end
end
