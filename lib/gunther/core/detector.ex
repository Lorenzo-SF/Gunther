defmodule Gunther.Detector do
  @moduledoc """
  Detecta los devices de memoria y los mide (SPEC §5.12, D-59, D-65, D-69).

  ## Device

      %{
        physical_id: binary(),
        name: binary(),
        backend: :cuda | :vulkan | :rocm | :metal | :cpu,
        backend_name: binary(),
        kind: :discrete | :unified,
        capacity_mib: n,
        free_mib: n | nil,
        usable: boolean(),
        reason: atom() | nil
      }

  ## Ejemplos

      iex> Gunther.Detector.usable?(%{capacity_mib: 100, free_mib: 200})
      false
  """

  @type device :: %{
          physical_id: binary(),
          name: binary(),
          backend: :cuda | :vulkan | :rocm | :metal | :cpu,
          backend_name: binary(),
          kind: :discrete | :unified,
          capacity_mib: non_neg_integer(),
          free_mib: non_neg_integer() | nil,
          usable: boolean(),
          reason: atom() | nil
        }

  @callback devices(opts :: keyword()) :: {:ok, [device()]} | {:error, term()}
  @callback measure(physical_id :: binary()) ::
              {:ok,
               %{
                 total_mib: non_neg_integer(),
                 free_mib: non_neg_integer(),
                 attribution: :per_process | :none,
                 source: :engine | :system,
                 processes: [%{pid: integer(), mib: non_neg_integer()}] | nil
               }}
              | {:error, term()}

  @doc """
  ¿Un device es usable?

  `free > total` ⇒ **no** es usable (SPEC §19, F2-AC). Es un caso real
  documentado en CUDA.

  ## Ejemplos

      iex> Gunther.Detector.usable?(%{capacity_mib: 100, free_mib: 200})
      false

      iex> Gunther.Detector.usable?(%{capacity_mib: 100, free_mib: 50})
      true
  """
  @spec usable?(map()) :: boolean()
  def usable?(%{capacity_mib: total, free_mib: free}) when is_integer(free) and is_integer(total) do
    free <= total
  end

  def usable?(%{free_mib: nil}), do: true
  def usable?(_device), do: true
end
