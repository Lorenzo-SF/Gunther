defmodule Gunther.Retriever do
  @moduledoc """
  Busca chunks relevantes (SPEC §5.4).

  `opts` trae `:store`, `:embedder`, `:top_k`, `:filter` y `:min_score`.

  ## Ejemplos

      iex> Gunther.Retriever.top_k_default()
      5
  """

  @callback search(query :: binary(), opts :: keyword()) :: {:ok, [map()]} | {:error, term()}

  @doc """
  El número de resultados por defecto.

  ## Ejemplos

      iex> Gunther.Retriever.top_k_default()
      5
  """
  @spec top_k_default() :: pos_integer()
  def top_k_default, do: 5
end
