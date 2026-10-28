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

  # El orden de la union de atomos es el que canoniza dialyzer (alfabetico):
  # escribida al reves, el contrato `t()` no se reconoce como el mismo tipo
  # que el que infiere el constructor, y dialyzer marca la llamada como
  # imposible.
  @type t :: %__MODULE__{
          roles: [:system | :user],
          source_hash: binary(),
          text: binary(),
          truncated: boolean()
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
  @spec new(map() | keyword()) :: t()
  def new(attrs) when is_map(attrs) or is_list(attrs) do
    # Se aceptan las dos formas: un mapa y una keyword list. El constructor se
    # documenta como `map()`, y `new(text: "x", roles: [:user])` entrega una
    # keyword list: convertirla aqui es lo que hace que el contrato del
    # llamante se cumpla de verdad, y no solo en el tipo.
    attrs = Map.new(attrs)

    text = Map.fetch!(attrs, :text)
    roles = Map.fetch!(attrs, :roles)
    truncated = Map.get(attrs, :truncated, false)

    validate_text!(text)
    validate_roles!(roles)
    validate_truncated!(truncated)

    # La struct se construye de forma explicita, no con `struct!/2`: el
    # constructor dinamico devuelve un `struct()` generico, y el contrato
    # promete esta struct concreta.
    %__MODULE__{
      text: text,
      roles: roles,
      truncated: truncated,
      source_hash: hash(text)
    }
  end

  # El texto de la vista es lo que ve el decisor: tiene que ser una cadena.
  # La validacion no transforma el valor (transformarlo impediria a dialyzer
  # probar el tipo del contrato), solo lo comprueba.
  defp validate_text!(text) when is_binary(text), do: :ok

  defp validate_text!(other) do
    raise ArgumentError, "el texto de una vista de decision es una cadena, no #{inspect(other)}"
  end

  defp validate_truncated!(truncated) when is_boolean(truncated), do: :ok

  defp validate_truncated!(other) do
    raise ArgumentError, "`truncated` es un booleano, no #{inspect(other)}"
  end

  # Los roles de la vista se validan al construirla. El moduledoc promete que
  # el contenido `assistant`, de tools, de RAG y de MCP no entra: si el
  # constructor aceptara cualquier rol, esa promesa dependeria del que
  # llama, y bastaria un `[:assistant]` para romperla en silencio.
  defp validate_roles!(roles) do
    Enum.each(roles, fn
      role when role in [:user, :system] ->
        :ok

      other ->
        raise ArgumentError,
              "los roles de una vista de decision son :user y :system, no #{inspect(other)}"
    end)
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

    new(%{text: text, roles: roles})
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
