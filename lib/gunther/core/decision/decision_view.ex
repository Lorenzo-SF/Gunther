defmodule Gunther.DecisionView do
  @moduledoc """
  La **única** entrada que ve un modelo de decisión (SPEC §6.12, control M2).

  Solo texto de autoría del caller con los roles de `context_roles`, truncado
  a `max_input_tokens`.

  **Excluye** resultados de tools, contenido de RAG, memoria KV, mensajes
  `assistant` y contenido MCP. Esto evita que un documento recuperado dirija
  la decisión.

  ## Ejemplos

      iex> view = Gunther.DecisionView.new(text: "hola", roles: [:user])
      iex> view.text
      "hola"
  """

  @type t :: %__MODULE__{
          text: binary(),
          roles: [:user | :system],
          truncated: boolean(),
          source_hash: binary()
        }

  @enforce_keys [:text, :roles]
  defstruct [:text, :roles, truncated: false, source_hash: ""]

  @doc """
  Construye una vista de decisión.

  ## Opciones

    * `:text` — el texto ya filtrado por rol
    * `:roles` — los roles incluidos
    * `:truncated` — si se truncó a `max_input_tokens`

  ## Ejemplos

      iex> Gunther.DecisionView.new(text: "x", roles: [:user]).roles
      [:user]
  """
  @spec new(map()) :: t()
  def new(attrs) do
    text = Map.get(attrs, :text, "")

    struct!(__MODULE__, Map.put(attrs, :source_hash, hash(text)))
  end

  @doc """
  Filtra unos mensajes según los roles permitidos y construye la vista.

  Los mensajes `assistant`, `tool` y el contenido de RAG o MCP **no** entran.

  ## Ejemplos

      iex> messages = [%{role: :user, content: "hola"}, %{role: :assistant, content: "adios"}]
      iex> Gunther.DecisionView.from_messages(messages, [:user]).text
      "hola"
  """
  @spec from_messages([map()], [:user | :system]) :: t()
  def from_messages(messages, roles) when is_list(messages) do
    allowed = MapSet.new(roles)

    text =
      messages
      |> Enum.filter(fn message -> MapSet.member?(allowed, Map.get(message, :role)) end)
      |> Enum.map_join("\n", &content_to_text(Map.get(&1, :content, "")))
      |> String.trim()

    new(text: text, roles: roles)
  end

  defp content_to_text(content) when is_binary(content), do: content

  defp content_to_text(parts) when is_list(parts) do
    parts
    |> Enum.filter(&(is_map(&1) and Map.get(&1, :type) == :text))
    |> Enum.map_join("\n", &Map.get(&1, :text, ""))
  end

  defp content_to_text(_content), do: ""

  @doc """
  El hash de lo que vio el modelo (control M6, `decision_input_sha256`).

  ## Ejemplos

      iex> Gunther.DecisionView.from_messages([%{role: :user, content: "hola"}], [:user]).source_hash
      "a948904f2f0f479b8"
  """
  @spec hash(binary()) :: binary()
  def hash(text) do
    :sha256
    |> :crypto.hash(text)
    |> Base.encode16(case: :lower)
    |> binary_part(0, 16)
  end
end
