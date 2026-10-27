defmodule Gunther.SessionStore do
  @moduledoc """
  Persistencia de las sesiones (SPEC §5.13).

  `load/1`, `save/2`, `delete/1` y `list/0`.

  ## Referencia

  `Memory` (ETS, defecto) y `Disk` (`Apero.File`, escritura atómica). El mismo
  contrato sirve para el `AgentStore` de §10.1 con el snapshot opaco de CE-07.

  ## Ejemplos

      iex> Gunther.SessionStore.name_for(:default, "chat")
      "default:chat"
  """

  @callback load(name :: binary()) :: {:ok, map()} | {:error, term()}
  @callback save(name :: binary(), session :: map()) :: :ok | {:error, term()}
  @callback delete(name :: binary()) :: :ok | {:error, term()}
  @callback list() :: [binary()]

  @doc """
  El nombre con espacio de nombres de una sesión (CE-30).

  Las sesiones tienen espacio de nombres por consumer: dos consumers pueden
  usar el mismo nombre sin verse.

  ## Ejemplos

      iex> Gunther.SessionStore.name_for(:default, "chat")
      "default:chat"
  """
  @spec name_for(atom(), binary()) :: binary()
  def name_for(consumer, name) when is_atom(consumer) and is_binary(name) do
    "#{consumer}:#{name}"
  end
end
