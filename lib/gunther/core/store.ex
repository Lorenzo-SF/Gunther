defmodule Gunther.Store do
  @moduledoc """
  Almacena los chunks del RAG (SPEC §5.9).

  Sin `search_by_text`, las estrategias `:lexical` e `:hybrid` (§8.2) no se
  pueden implementar. SQLite lo cubre con FTS5; Postgres con `tsvector`;
  `Memory` con un BM25 en proceso.

  ## Filtros

  Igualdad y rango obligatorios; el resto, opcional. Un store que no soporte
  un operador pedido devuelve `{:error, :unsupported_filter}`, **no** ignora
  el filtro.

  ## Ejemplos

      iex> Gunther.Store.supports_filter?(%{source: "x"})
      true
  """

  @callback put(id :: binary(), chunks :: [map()], metadata :: map()) :: :ok | {:error, term()}
  @callback fetch(id :: binary()) :: {:ok, map()} | {:error, term()}
  @callback search_by_vector(vector :: [float()], opts :: keyword()) :: {:ok, [map()]} | {:error, term()}
  @callback search_by_metadata(filter :: map(), opts :: keyword()) :: {:ok, [map()]} | {:error, term()}
  @callback search_by_text(query :: binary(), opts :: keyword()) :: {:ok, [map()]} | {:error, term()}
  @callback content_hashes(doc_id :: binary()) :: {:ok, %{binary() => binary()}} | {:error, term()}
  @callback stream(opts :: keyword()) :: Enumerable.t()
  @callback delete(id :: binary()) :: :ok | {:error, term()}

  @optional_callbacks search_by_text: 2

  @doc """
  ¿El store soporta este filtro?

  Igualdad y rango son obligatorios en todo store; `{:in, _}` y
  `{:contains, _}` son opcionales.

  ## Ejemplos

      iex> Gunther.Store.supports_filter?(%{source: "x"})
      true

      iex> Gunther.Store.supports_filter?(%{date: {:>=, "2026-01-01"}})
      true
  """
  @spec supports_filter?(map()) :: boolean()
  def supports_filter?(filter) when is_map(filter) do
    Enum.all?(filter, fn {_key, value} -> supports_operator?(value) end)
  end

  defp supports_operator?(value) when is_binary(value) or is_number(value) or is_boolean(value), do: true
  defp supports_operator?({op, _value}) when op in [:>=, :<=, :>, :<, :eq, :in, :contains], do: true
  defp supports_operator?(_value), do: false
end
