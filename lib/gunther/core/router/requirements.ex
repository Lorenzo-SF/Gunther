defmodule Gunther.Router.Requirements do
  @moduledoc """
  La firma de requisitos de una peticion (SPEC §6.5).

  La firma es la parte de la clave de la cache que dice **que pide la
  peticion**: las modalidades presentes, las herramientas, el
  `response_format`, las skills pedidas y el `rag`.

  Dos peticiones con la misma firma piden lo mismo: la cache puede servirles
  el mismo ranking. Si cambian los requisitos, la clave cambia y el ranking
  se recalcula.

  ## La forma canonica

  Las listas se ordenan y se quitan los duplicados, y los atomos se pasan a
  cadena: `[:b, :a]` y `["a", "b"]` son la misma firma. Los booleanos se
  quedan como booleanos, porque `rag = true` y `rag = "true"` no son lo
  mismo.

  ## Ejemplos

      iex> Gunther.Router.Requirements.signature(%{tools: [:b, :a]})
      %{tools: ["a", "b"]}
  """

  @doc """
  La firma canonica de unos requisitos.

  ## Ejemplos

      iex> Gunther.Router.Requirements.signature(%{rag: true, tools: [:a, :a]})
      %{rag: true, tools: ["a"]}
  """
  @spec signature(map()) :: map()
  def signature(requirements) when is_map(requirements) do
    # Las claves se conservan tal cual: los requisitos los escribe el
    # codigo, no el usuario. Lo que se canoniza son los valores.
    Map.new(requirements, fn {key, value} -> {key, canonical(value)} end)
  end

  @doc """
  La firma canonica de una peticion, tal y como la ve el router.

  Los requisitos salen de la peticion: las modalidades que aparecen en los
  mensajes, las herramientas que se ofrecen, el formato de respuesta, las
  skills que se piden y si hay `rag`.

  ## Ejemplos

      iex> Gunther.Router.Requirements.signature(%{rag: false, tools: []})
      %{rag: false, tools: []}
  """
  @spec signature(map(), keyword()) :: map()
  def signature(requirements, request) when is_map(requirements) and is_list(request) do
    merged =
      requirements
      |> Map.put_new(:modalities, modalities(request))
      |> Map.put_new(:tools, Keyword.get(request, :tools, []))
      |> Map.put_new(:response_format, Keyword.get(request, :response_format, nil))
      |> Map.put_new(:skills, Keyword.get(request, :skills, []))
      |> Map.put_new(:rag, Keyword.get(request, :rag, false))

    signature(merged)
  end

  # Las modalidades que aparecen en los mensajes.
  defp modalities(request) do
    request
    |> Keyword.get(:messages, [])
    |> Enum.flat_map(fn message -> message |> Map.get(:modalities, []) |> List.wrap() end)
    |> Enum.uniq()
  end

  defp canonical(value) when is_list(value) do
    value
    |> Enum.map(&to_string/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp canonical(value) when is_boolean(value) or is_nil(value) or is_number(value), do: value

  defp canonical(value) when is_atom(value), do: to_string(value)

  defp canonical(value) when is_binary(value), do: value

  defp canonical(value), do: value
end
