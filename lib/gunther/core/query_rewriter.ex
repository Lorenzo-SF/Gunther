defmodule Gunther.QueryRewriter do
  @moduledoc """
  Reescribe una consulta en varias (SPEC §5.6).

  Necesita un clasificador o un modelo registrado. Sin rewriter, la consulta
  original se usa tal cual.

  ## Ejemplos

      iex> Gunther.QueryRewriter.enabled?()
      false
  """

  @callback rewrite(query :: binary(), opts :: keyword()) :: {:ok, [binary()]} | {:error, term()}

  @doc """
  ¿Hay rewriter activo?

  ## Ejemplos

      iex> Gunther.QueryRewriter.enabled?()
      false
  """
  @spec enabled?() :: boolean()
  def enabled?, do: false
end
