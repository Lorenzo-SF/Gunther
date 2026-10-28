defmodule Gunther.Cancel do
  @moduledoc """
  Token de cancelación (SPEC §2.9, §4.5, D-42).

  Es un `atomics_ref` de un elemento, sin signo. `cancel/1` pone un `1`;
  `cancelled?/1` lee si vale `1`. Es **O(1)** y **válido entre procesos**: un
  token se puede pasar a un provider y cancelar desde otro proceso.

  ## Ejemplos

      iex> token = Gunther.Cancel.new()
      iex> Gunther.Cancel.cancelled?(token)
      false
      iex> Gunther.Cancel.cancel(token)
      :ok
      iex> Gunther.Cancel.cancelled?(token)
      true
  """

  @type t :: %__MODULE__{ref: :atomics.atomics_ref()}

  @enforce_keys [:ref]
  defstruct [:ref]

  @doc """
  Crea un token de cancelación nuevo, sin cancelar.
  """
  @spec new() :: t()
  def new do
    %__MODULE__{ref: :atomics.new(1, signed: false)}
  end

  @doc """
  Cancela el token. Es idempotente.
  """
  @spec cancel(t()) :: :ok
  def cancel(%__MODULE__{ref: ref}) do
    :atomics.put(ref, 1, 1)
    :ok
  end

  @doc """
  ¿Está cancelado el token?

  ## Ejemplos

      iex> token = Gunther.Cancel.new()
      iex> Gunther.Cancel.cancelled?(token)
      false
  """
  @spec cancelled?(t()) :: boolean()
  def cancelled?(%__MODULE__{ref: ref}) do
    :atomics.get(ref, 1) == 1
  end

  @doc """
  Devuelve una función de aridad 0 que consulta la cancelación.

  Es lo que recibe el provider en `opts.cancelled?` (SPEC §5.1).

  ## Ejemplos

      iex> token = Gunther.Cancel.new()
      iex> check = Gunther.Cancel.check_fun(token)
      iex> check.()
      false
  """
  @spec check_fun(t()) :: (-> boolean())
  def check_fun(%__MODULE__{} = token) do
    fn -> cancelled?(token) end
  end
end
