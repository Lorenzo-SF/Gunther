defmodule Gunther.Guardrail do
  @moduledoc """
  Un filtro de entrada o salida (SPEC §5.10, §16).

  `check/3` devuelve `:ok`, `{:veto, reason}` o `{:modify, new_content}`.

  ## Ejemplos

      iex> Gunther.Guardrail.default_mode()
      :closed
  """

  @callback check(kind :: :input | :output, content :: binary(), ctx :: map()) ::
              :ok | {:veto, term()} | {:modify, binary()}

  @doc """
  El modo por defecto ante un fallo del guardrail.

  `:closed` es «dejar pasar» y `:open` es «bloquear» (SPEC §16.2).

  ## Ejemplos

      iex> Gunther.Guardrail.default_mode()
      :closed
  """
  @spec default_mode() :: :closed | :open
  def default_mode, do: :closed
end
