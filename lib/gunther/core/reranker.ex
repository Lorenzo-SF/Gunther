defmodule Gunther.Reranker do
  @moduledoc """
  Reordena los resultados de una búsqueda (SPEC §5.5).

  Opcional: si no hay reranker, el orden del retriever se conserva.

  ## Ejemplos

      iex> Gunther.Reranker.enabled?()
      false
  """

  @callback rerank(query :: binary(), hits :: [map()], opts :: keyword()) ::
              {:ok, [map()]} | {:error, term()}

  @doc """
  ¿Hay reranker activo?

  ## Ejemplos

      iex> Gunther.Reranker.enabled?()
      false
  """
  @spec enabled?() :: boolean()
  def enabled?, do: false
end
