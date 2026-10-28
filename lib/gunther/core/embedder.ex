defmodule Gunther.Embedder do
  @moduledoc """
  Genera vectores para el RAG (SPEC §5.2).

  Gunther trocea en lotes (`max_batch_size/0`) y los paraleliza con
  `Task.async_stream`.

  `model_id/0` es **contrato**: al cambiarlo, los vectores viejos son inválidos
  y hay que reindexar (SPEC §8.5).

  ## Ejemplos

      iex> Gunther.Embedder.model_id()
      "default"
  """

  @callback embed([binary()], opts :: keyword()) :: {:ok, [[float()]]} | {:error, term()}
  @callback dimensions() :: pos_integer()
  @callback max_batch_size() :: pos_integer()
  @callback model_id() :: String.t()

  @doc """
  Trocea los textos en lotes del tamaño máximo del embedder.

  ## Ejemplos

      iex> Gunther.Embedder.batch(["a", "b"], 1)
      [["a"], ["b"]]
  """
  @spec batch([binary()], pos_integer()) :: [[binary()]]
  def batch(texts, size) when is_list(texts) and size > 0 do
    Enum.chunk_every(texts, size)
  end
end
