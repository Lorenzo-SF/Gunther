defmodule Gunther.Detector.Fabricante do
  @moduledoc """
  El detector de **fabricante**: la convencion B de la medida (SPEC §11.7).

  ## Que es

  El detector del motor (`Detector.LlamaCpp`) da los devices **como los ve
  el motor**: `CUDA0`, `Vulkan0`, `ROCm0`, `MTL0`. Ese es el nombre del motor,
  no la identidad fisica: la misma GPU puede aparecer con dos nombres
  distintos, y un `CUDA0` no dice cual es.

  Este detector da la **identidad fisica** y la **atribucion por proceso**,
  con la herramienta del fabricante:

  | Backend  | Identidad fisica                     | Atribucion por proceso                                |
  | -------- | ------------------------------------ | ----------------------------------------------------- |
  | CUDA     | UUID de `nvidia-smi --query-gpu=uuid` | `nvidia-smi --query-compute-apps=pid,used_memory`     |
  | ROCm     | id unico de `rocm-smi` o `amd-smi`    | `rocm-smi` o `amd-smi`                                |
  | Vulkan   | no hay id neutral: **mapeo obligatorio** en `[[devices]]` | no (`attribution: :none`)   |
  | Metal    | `metal:0` sintetico                  | no                                                   |

  ## Por que el emparejamiento es obligatorio

  Un device usa **una sola fuente de medida** (D-28, D-89): la `capacity` y
  la `free` tienen que salir de la **misma** herramienta. Por eso no se
  mezclan los datos de aqui con los del detector del motor: cada detector
  entrega su lista, y el emparejamiento entre el nombre del motor y la
  identidad fisica lo hace la configuracion (`[[devices]]`), que es donde
  esta escrito y por tanto se puede revisar (G-11).

  ## Los comandos

  Se ejecutan por `Gunther.Command`, que es la unica puerta de ejecucion
  (§3.4), y por tanto con **lista de permitidos**.

  ## Ejemplos

      iex> Gunther.Detector.Fabricante.devices(backend: :vulkan)
      {:ok, []}
  """

  @behaviour Gunther.Detector

  alias Gunther.Error

  @type backend :: :cuda | :rocm | :vulkan | :metal

  @impl Gunther.Detector
  def devices(opts) do
    case Keyword.get(opts, :backend, :cuda) do
      :cuda -> nvidia_devices(opts)
      :rocm -> rocm_devices(opts)
      backend when backend in [:vulkan, :metal] -> {:ok, []}
      other -> {:error, Error.new(:config_error, "backend de fabricante desconocido: #{inspect(other)}")}
    end
  end

  @impl Gunther.Detector
  def measure(physical_id, opts) do
    case Keyword.get(opts, :backend, :cuda) do
      :cuda -> nvidia_measure(physical_id, opts)
      :rocm -> rocm_measure(physical_id, opts)
      backend when backend in [:vulkan, :metal] -> {:error, :device_not_found}
      _other -> {:error, :device_not_found}
    end
  end

  # --- CUDA: nvidia-smi --------------------------------------------------

  defp nvidia_devices(opts) do
    case run(
           "nvidia-smi",
           ["--query-gpu=index,name,uuid,memory.total,memory.free", "--format=csv,noheader,nounits"],
           opts
         ) do
      {:ok, output} ->
        devices =
          output
          |> String.split("\n", trim: true)
          |> Enum.map(&parse_nvidia_line/1)
          |> Enum.reject(&is_nil/1)
          |> Enum.map(fn device ->
            Map.put(device, :attribution, :per_process)
          end)

        {:ok, devices}

      {:error, error} ->
        {:error, error}
    end
  end

  # Una linea de `nvidia-smi --format=csv`:
  #   0, NVIDIA GeForce RTX 5080 Laptop GPU, GPU-1234-5678, 15109, 12000
  defp parse_nvidia_line(line) do
    case parse_csv(line) do
      [index, name, uuid, total, free] ->
        %{
          physical_id: uuid,
          name: name,
          description: name,
          backend: :cuda,
          backend_name: "CUDA",
          kind: :discrete,
          index: String.to_integer(index),
          capacity_mib: String.to_integer(total),
          free_mib: String.to_integer(free),
          usable: true,
          reason: nil,
          attribution: :none
        }

      _other ->
        nil
    end
  end

  defp nvidia_measure(physical_id, opts) do
    with {:ok, devices} <- nvidia_devices(opts),
         {:ok, device} <- find_device(devices, physical_id),
         {:ok, processes} <- nvidia_processes(opts) do
      {:ok,
       %{
         total_mib: device.capacity_mib,
         free_mib: device.free_mib,
         attribution: :per_process,
         source: :system,
         processes: processes
       }}
    end
  end

  # Los procesos que usan la GPU: los que no son engines de Gunther son
  # memoria ajena (§11.3).
  defp nvidia_processes(opts) do
    case run(
           "nvidia-smi",
           ["--query-compute-apps=pid,used_memory", "--format=csv,noheader,nounits"],
           opts
         ) do
      {:ok, output} ->
        processes =
          output
          |> String.split("\n", trim: true)
          |> Enum.map(&parse_process_line/1)
          |> Enum.reject(&is_nil/1)

        {:ok, processes}

      {:error, error} ->
        {:error, error}
    end
  end

  # Una linea de `nvidia-smi --query-compute-apps`: `1234, 2048`.
  defp parse_process_line(line) do
    case parse_csv(line) do
      [pid, mib] ->
        %{pid: String.to_integer(pid), mib: String.to_integer(mib)}

      _other ->
        nil
    end
  end

  # --- ROCm: rocm-smi ----------------------------------------------------

  defp rocm_devices(opts) do
    case run("rocm-smi", ["--showmeminfo", "vram", "--json"], opts) do
      {:ok, output} ->
        devices =
          output
          |> parse_rocm_json()
          |> Enum.map(fn device ->
            device
            |> Map.put(:backend, :rocm)
            |> Map.put(:backend_name, "ROCm")
            |> Map.put(:kind, :discrete)
            |> Map.put(:attribution, :per_process)
          end)

        {:ok, devices}

      {:error, error} ->
        {:error, error}
    end
  end

  # El JSON de `rocm-smi --showmeminfo vram` trae una entrada por GPU. La
  # forma exacta no esta verificada (G-11): se lee lo que se puede y se
  # ignoran las claves que no se Reconocen.
  defp parse_rocm_json(output) do
    case Jason.decode(output) do
      {:ok, %{"card0" => card}} when is_map(card) ->
        total = get_number(card, ["VRAM Total Memory (B)", "vram total memory (b)"])
        used = get_number(card, ["VRAM Total Used Memory (B)", "vram total used memory (b)"])
        free = get_number(card, ["VRAM Total Free Memory (B)", "vram total free memory (b)"])

        free_mib = free || if total && used, do: div(total - used, 1024 * 1024), else: nil

        [
          %{
            physical_id: Map.get(card, "Unique ID") || Map.get(card, "Device ID") || "rocm0",
            name: Map.get(card, "Card series") || Map.get(card, "Card model") || "ROCm",
            description: Map.get(card, "Card series") || "ROCm",
            index: 0,
            capacity_mib: total && div(total, 1024 * 1024),
            free_mib: free_mib,
            usable: true,
            reason: nil,
            attribution: :none
          }
        ]

      _other ->
        []
    end
  end

  defp get_number(map, keys) do
    Enum.find_value(keys, fn key ->
      case Map.get(map, key) do
        value when is_integer(value) -> value
        value when is_float(value) -> trunc(value)
        _other -> nil
      end
    end)
  end

  defp rocm_measure(physical_id, opts) do
    with {:ok, devices} <- rocm_devices(opts),
         {:ok, device} <- find_device(devices, physical_id) do
      {:ok,
       %{
         total_mib: device.capacity_mib,
         free_mib: device.free_mib,
         attribution: :per_process,
         source: :system,
         processes: nil
       }}
    end
  end

  # --- comunes -----------------------------------------------------------

  defp find_device(devices, physical_id) do
    case Enum.find(devices, &(&1.physical_id == physical_id)) do
      nil -> {:error, :device_not_found}
      device -> {:ok, device}
    end
  end

  # La ejecucion: por `Gunther.Command` (la unica puerta), con lista de
  # permitidos. El `:runner` permite probarlo sin la herramienta instalada.
  defp run(cmd, args, opts) do
    result =
      case Keyword.get(opts, :runner) do
        runner when is_function(runner, 3) ->
          runner.(cmd, args, opts)

        _other ->
          Gunther.Command.run(cmd, args,
            allow: Keyword.get(opts, :allow, []),
            timeout_ms: Keyword.get(opts, :timeout_ms, 30_000)
          )
      end

    # El runner y el comando devuelven la misma forma; aqui se normaliza.
    case result do
      {:ok, %{stdout: output}} -> {:ok, output}
      {:ok, output} when is_binary(output) -> {:ok, output}
      {:error, error} -> {:error, error}
    end
  end

  # Un CSV con comillas: el nombre de la GPU puede traer comas dentro
  # (`"NVIDIA GeForce RTX 5080, Laptop GPU"`), y ahi la coma **no** separa
  # campos. Se recorre la linea campo a campo, respetando las comillas.
  defp parse_csv(line) do
    {fields, current, _in_quotes} =
      line
      |> String.to_charlist()
      |> Enum.reduce({[], [], false}, fn char, {fields, current, in_quotes} ->
        cond do
          char == ?" ->
            {fields, [char | current], not in_quotes}

          char == ?, and not in_quotes ->
            {fields ++ [List.to_string(Enum.reverse(current))], [], in_quotes}

          true ->
            {fields, [char | current], in_quotes}
        end
      end)

    Enum.map(fields ++ [List.to_string(Enum.reverse(current))], &clean_field/1)
  end

  defp clean_field(field) do
    field
    |> String.trim()
    |> String.trim("\"")
  end
end
