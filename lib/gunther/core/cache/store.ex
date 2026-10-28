defmodule Gunther.Cache.Store do
  @moduledoc """
  El contrato de la caché de decisiones (SPEC §6.5).

  La caché guarda **solo el ranking puro**: la lista de alias que las capas
  blandas elegiron, en su orden. La disponibilidad (breaker, bulkhead, ledger,
  estado de nodo) **no** se cachea: se reevalúa en cada petición.

  La implementación de referencia es `Gunther.Cache.Decisions`. El router
  acepta cualquier módulo que cumpla este contrato, para que la capa
  `:cache` se pueda probar sin un proceso global.
  """

  @typedoc "La clave de la caché: el hash de la forma canónica de §6.5."
  @type key :: binary()

  @typedoc "El ranking cacheado: los alias elegibles, en orden."
  @type ranking :: [atom()]

  @doc """
  Lee un ranking cacheado.
  """
  @callback get(key()) :: {:ok, ranking()} | :error

  @doc """
  Guarda un ranking.
  """
  @callback put(key(), ranking()) :: :ok
end
