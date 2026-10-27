defmodule Gunther.Catalog do
  @moduledoc """
  El catálogo de modelos, providers y nodos (SPEC §4.4).

  Un snapshot **inmutable** y versionado. `reload/0` reconstruye desde la
  configuración activa; si la nueva configuración no valida, **se conserva el
  snapshot anterior** (SPEC §4.4).
  """

  alias Gunther.Config
  alias Gunther.Error

  @type model_info :: %{
          alias: atom(),
          provider: atom(),
          model_id: String.t(),
          locality: :local | :lan | :cloud,
          node: String.t() | nil,
          capabilities: [atom()],
          modalities: [atom()],
          context_window: pos_integer(),
          max_concurrency: pos_integer(),
          tags: [atom()]
        }

  @type t :: %{
          version: non_neg_integer(),
          models: %{optional(atom()) => model_info()},
          providers: %{optional(atom()) => map()},
          nodes: %{optional(String.t()) => map()}
        }

  @doc """
  Construye un catálogo a partir de una configuración validada.

  ## Ejemplos

      iex> {:ok, config} = Gunther.Config.load(%{gunther: %{instance_id: "main"}})
      iex> catalog = Gunther.Catalog.build(config)
      iex> catalog.version
      1
  """
  @spec build(Config.t()) :: t()
  def build(%Config{} = config) do
    models =
      config.models
      |> Enum.map(fn model ->
        {model.alias,
         %{
           alias: model.alias,
           provider: model.provider,
           model_id: model.model_id,
           locality: model.locality,
           node: model.node,
           capabilities: model.capabilities,
           modalities: model.modalities,
           context_window: model.context_window,
           max_concurrency: model.max_concurrency,
           tags: model.tags
         }}
      end)
      |> Map.new()

    nodes = Map.new(config.nodes, &{&1.id, &1})

    %{
      version: 1,
      models: models,
      providers: config.providers,
      nodes: nodes
    }
  end

  @doc """
  Los alias de modelo del catálogo, en orden alfabético.
  """
  @spec list(t()) :: [atom()]
  def list(%{models: models}) do
    models
    |> Map.keys()
    |> Enum.sort()
  end

  @doc """
  La ficha de un modelo.

  ## Ejemplos

      iex> {:ok, config} = Gunther.Config.load(%{gunther: %{instance_id: "main"}})
      iex> catalog = Gunther.Catalog.build(config)
      iex> Gunther.Catalog.get(catalog, :no_existe)
      :error
  """
  @spec get(t(), atom()) :: {:ok, model_info()} | :error
  def get(%{models: models}, alias_name) do
    case Map.fetch(models, alias_name) do
      {:ok, model} -> {:ok, model}
      :error -> :error
    end
  end

  @doc """
  El hash del catálogo, que forma parte de la clave de la caché de
  decisiones (SPEC §6.5).

  Cubre modelos, providers, nodos, **reglas (globales y de consumer)**,
  `DecisionSpec`s y su estado de verificación.
  """
  @spec hash(t(), Config.t() | nil) :: binary()
  def hash(%{} = catalog, config \\ nil) do
    parts = [
      catalog.models |> Map.keys() |> Enum.sort(),
      catalog.providers |> Map.keys() |> Enum.sort(),
      catalog.nodes |> Map.keys() |> Enum.sort()
    ]

    parts = parts ++ config_parts(config)

    parts
    |> :erlang.term_to_binary()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp config_parts(nil), do: []

  defp config_parts(%Config{} = config) do
    [
      config.rules |> Enum.map(& &1.name) |> Enum.sort(),
      config.consumers
      |> Enum.flat_map(fn {name, consumer} -> [name | Enum.map(consumer.rules, & &1.name)] end)
      |> Enum.sort(),
      config.decision_models |> Enum.map(& &1.id) |> Enum.sort()
    ]
  end

  @doc """
  Recarga el catálogo desde la configuración activa.

  En error, conserva el snapshot anterior (SPEC §4.4).
  """
  @spec reload(GenServer.server()) :: :ok | {:error, Error.t()}
  def reload(server \\ __MODULE__) do
    GenServer.call(server, :reload)
  end
end
