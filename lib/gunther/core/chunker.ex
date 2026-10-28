defmodule Gunther.Chunker do
  @moduledoc """
  Trocea documentos (SPEC §5.3).

  `max_chunk_bytes/0` es un callback **opcional**: si el chunker acota el
  tamaño de sus chunks, lo declara; lo usa `rag_query` para derivar el tope
  de `top_k` (SPEC §8.8).

  ## Ejemplos

      iex> Gunther.Chunker.max_chunk_bytes()
      nil
  """

  @callback chunk(content :: binary(), opts :: keyword()) ::
              {:ok, [%{content: binary(), metadata: map(), parent_id: term()}]} | {:error, term()}
  @callback max_chunk_bytes() :: pos_integer() | nil

  @optional_callbacks max_chunk_bytes: 0

  @doc """
  El tamaño máximo de chunk que declara el chunker, o `nil`.

  ## Ejemplos

      iex> Gunther.Chunker.max_chunk_bytes()
      nil
  """
  @spec max_chunk_bytes() :: pos_integer() | nil
  def max_chunk_bytes, do: nil
end
