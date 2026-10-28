defmodule Gunther.Engine.Placer do
  @moduledoc """
  Decide en qué device se carga un modelo (SPEC §11.4, D-53).

  ## Los pasos

  1. Reúne los devices candidatos: el `device` fijado en el modelo, o todos
     los `usable` compatibles con el backend del binario del engine.
  2. Para cada uno, bajo el semaforo del nodo (`Gunther.Engine.Placement`):
     `resync`, calcula `reserved_mib` y comprueba si cabe.
  3. Si cabe **y** no se supera `placement.max_loaded_models` (§14.1),
     `{:ok, device_key}`. Si no cabe, y se permite expulsar, elige victimas y
     reintenta; si no, `{:error, :no_room}`.
  4. Sin devices, `:no_gpu`; si no se pudo medir, `:memory_unknown`; si el
     device existe pero no es usable, `:device_unusable`.

  ## El orden de preferencia

  El de `placement.prefer` (lista de ids de nodo, `"local"` para la maquina
  del controlador) en el orden dado; dentro del mismo nodo, el de mayor
  `available`; desempate por `physical_id` (orden alfabetico). Sin
  `placement.prefer`, el orden es: local primero.

  ## La reserva

      reserved_mib = ceil(peso_calculado_mib) + engine.vram_margin_mib

  El margen por defecto es 1024 MiB, que es el margen por defecto de
  `--fit-target` en `llama-server`.

  ## Ejemplos

      iex> model = %{alias: "m", device: nil, reserved_mib: 100, exclusive: false, resident: false}
      iex> Gunther.Engine.Placer.place(model, [])
      {:error, :no_gpu}
  """

  @type device :: %{
          physical_id: String.t(),
          node: atom(),
          backend: atom(),
          usable: boolean(),
          available_mib: non_neg_integer() | nil,
          reason: atom() | nil
        }

  @type model :: %{
          alias: String.t(),
          device: String.t() | nil,
          reserved_mib: non_neg_integer(),
          exclusive: boolean(),
          resident: boolean()
        }

  @type device_key :: {atom(), String.t()}

  @default_margin_mib 1024

  @doc """
  Coloca un modelo.

  ## Opciones

    * `:prefer` — lista de ids de nodo, en el orden de preferencia.
    * `:max_loaded_models` — el tope por conteo (§14.1). `0` = sin tope.
    * `:loaded` — mapa de nodo a modelos ya cargados.
    * `:margin_mib` — el margen `vram_margin_mib`. Por defecto 1024.

  ## Ejemplos

      iex> model = %{alias: "m", device: nil, reserved_mib: 100, exclusive: false, resident: false}
      iex> Gunther.Engine.Placer.place(model, [])
      {:error, :no_gpu}
  """
  @spec place(model(), [device()], keyword()) ::
          {:ok, device_key()} | {:error, :no_gpu | :no_room | :memory_unknown | :device_unusable}
  def place(model, devices, opts \\ []) when is_list(devices) do
    reserved = reserved_mib(model, opts)

    case candidates(model, devices) do
      [] ->
        # Sin devices es :no_gpu. Pero si hay devices y ninguno se puede
        # usar (o el device fijado no existe), es :device_unusable: la
        # diferencia importa para el reintento en otro device (D-89).
        if devices == [] and is_nil(Map.get(model, :device)) do
          {:error, :no_gpu}
        else
          {:error, :device_unusable}
        end

      candidates ->
        ordered = order(candidates, opts)

        if some_unmeasured?(ordered) do
          # Hay devices sin medir: no se puede saber si caben.
          {:error, :memory_unknown}
        else
          place_in(ordered, model, reserved, opts)
        end
    end
  end

  @doc """
  La reserva de un modelo: su peso mas el margen.
  """
  @spec reserved_mib(model(), keyword()) :: non_neg_integer()
  def reserved_mib(model, opts \\ []) do
    margin = Keyword.get(opts, :margin_mib, @default_margin_mib)
    model.reserved_mib + margin
  end

  # --- los candidatos ----------------------------------------------------

  # El device fijado en el modelo, o todos los usables.
  defp candidates(model, devices) do
    case Map.get(model, :device) do
      nil -> Enum.filter(devices, & &1.usable)
      physical_id -> find_usable(physical_id, devices)
    end
  end

  # El device fijado, si esta y se puede usar.
  defp find_usable(physical_id, devices) do
    case Enum.find(devices, &(&1.physical_id == physical_id)) do
      nil -> []
      device -> if device.usable, do: [device], else: []
    end
  end

  # El orden: primero el nodo, luego la memoria libre, luego el nombre.
  defp order(devices, opts) do
    prefer = Keyword.get(opts, :prefer, [])

    devices
    |> Enum.group_by(& &1.node)
    |> Enum.sort_by(fn {node, _devices} -> node_rank(node, prefer) end)
    |> Enum.flat_map(fn {_node, node_devices} ->
      Enum.sort_by(node_devices, &{-available_or_zero(&1), &1.physical_id})
    end)
  end

  # `prefer` manda; sin `prefer`, el local va primero.
  defp node_rank(node, []), do: if(node == :local, do: 0, else: 1)

  defp node_rank(node, prefer) do
    case Enum.find_index(prefer, &(to_string(node) == &1)) do
      nil -> 1_000_000
      index -> index
    end
  end

  defp available_or_zero(device), do: device.available_mib || 0

  # --- la colocacion -----------------------------------------------------

  defp place_in([], _model, _reserved, _opts), do: {:error, :no_room}

  defp place_in([device | rest], model, reserved, opts) do
    cond do
      is_nil(device.available_mib) ->
        {:error, :memory_unknown}

      device.available_mib < reserved ->
        place_in(rest, model, reserved, opts)

      over_count_limit?(device, opts) ->
        place_in(rest, model, reserved, opts)

      true ->
        {:ok, {device.node, device.physical_id}}
    end
  end

  # El tope por conteo (D-71): cuantos modelos pueden estar cargados a la
  # vez en cada nodo. Los `resident` cuentan.
  # Hay devices sin medir: no se puede saber si caben.
  defp some_unmeasured?(devices) do
    Enum.any?(devices, &is_nil(&1.available_mib)) and
      not Enum.all?(devices, &is_nil(&1.available_mib))
  end

  defp over_count_limit?(device, opts) do
    max_loaded = Keyword.get(opts, :max_loaded_models, 0)

    if max_loaded == 0 do
      false
    else
      loaded = Map.get(Keyword.get(opts, :loaded, %{}), device.node, [])
      length(loaded) >= max_loaded
    end
  end
end
