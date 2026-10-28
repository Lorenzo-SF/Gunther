defmodule Gunther.Detector.LlamaCpp do
  @moduledoc """
  Parsea la salida de `llama-server --list-devices` (SPEC §5.12, §11.2, D-59).

  ## El formato, medido en la fuente

  `common_print_available_devices()` en `common/arg.cpp` imprime:

      printf("Available devices:\\n");
      ...
      printf("  %s: %s (%zu MiB, %zu MiB free)\\n", name, description, total / MiB, free / MiB);

  El `name` es el que da cada backend, con el indice detras:

    * `CUDA0`, `CUDA1`... (`GGML_CUDA_NAME` = `"CUDA"`)
    * `ROCm0`... (`GGML_CUDA_NAME` = `"ROCm"` cuando `GGML_USE_HIP`; ROCm
      no tiene backend propio: compila los mismos `.cu` que CUDA)
    * `Vulkan0`... (`GGML_VK_NAME` = `"Vulkan"`)
    * `MTL0`, `MTL1`... (Metal: `"%s%d", "MTL", device`)
    * `MUSA0`... (MUSA, igual que CUDA con `GGML_USE_MUSA`)

  Los devices de CPU **no** aparecen: la funcion los filtra.

  La `description` es texto libre: el nombre del modelo de la GPU. Con
  devices virtuales, el backend anade `" (dev p<fisico>/v<virtual>)"`, asi
  que la descripcion **puede contener parentesis**.

  ## Lo que la salida NO dice

  Nada de "unified memory", "shared" o "system memory" aparece en la
  descripcion de ningun backend. Que un device sea de memoria unificada
  (una iGPU de Vulkan, un UMA de CUDA, el Metal de un Mac) **no se deduce
  de aqui**: lo declara la config de Gunther o lo calibra `Doctor`.

  ## Los casos limite que hay que saber

    * `free == total` es normal: Vulkan sin `VK_EXT_memory_budget` no sabe
      restar lo usado.
    * `total == 0` y `free == 0` aparece cuando la memoria no se pudo leer
      (`cudaMemGetInfo` fallo, Metal en macOS antiguo). Un device sin
      memoria declarada no es usable.
    * La memoria se divide entre los devices virtuales que comparten una
      GPU fisica.

  ## Lo que no hace

  No decide si un device se usa: eso lo dice la config de Gunther
  (`kind`, `convention`, `overhead_mib`). Este modulo **mide**; la config
  **declara**. Un backend que no se reconoce se devuelve con
  `usable: false` y `reason: :unknown_backend`: no se adivina.

  ## Ejemplos

      iex> Gunther.Detector.LlamaCpp.parse("Available devices:\\n  (none)\\n")
      {:ok, []}
  """

  @header "Available devices:"

  # El prefijo del nombre del device es el backend. El indice va detras.
  @backends %{
    "CUDA" => :cuda,
    "ROCm" => :rocm,
    "MUSA" => :musa,
    "Vulkan" => :vulkan,
    "MTL" => :metal,
    "SYCL" => :sycl,
    "RPC" => :rpc,
    "CPU" => :cpu
  }

  @device_regex ~r/^\s{2}(?<name>[^:]+):\s+(?<description>.*?)\s+\((?<total>\d+) MiB, (?<free>\d+) MiB free\)$/

  @type device :: %{
          physical_id: String.t(),
          name: String.t(),
          description: String.t(),
          backend: atom(),
          backend_name: String.t(),
          capacity_mib: non_neg_integer(),
          free_mib: non_neg_integer(),
          usable: boolean(),
          reason: atom() | nil
        }

  @doc """
  Parsea la salida de `--list-devices`.

  ## Ejemplos

      iex> Gunther.Detector.LlamaCpp.parse("Available devices:\\n  (none)\\n")
      {:ok, []}
  """
  @spec parse(String.t()) :: {:ok, [device()]} | {:error, :not_a_device_list}
  def parse(output) when is_binary(output) do
    lines = String.split(output, "\n", trim: true)

    if List.first(lines) == @header do
      {:ok, lines |> Enum.drop(1) |> Enum.map(&parse_line/1) |> Enum.reject(&is_nil/1)}
    else
      {:error, :not_a_device_list}
    end
  end

  @doc """
  Parsea una linea de device.

  `nil` si la linea no tiene el formato (se ignora, no se inventa).

  ## Ejemplos

      iex> Gunther.Detector.LlamaCpp.parse_line("  CUDA0: NVIDIA (100 MiB, 50 MiB free)").backend
      :cuda
  """
  @spec parse_line(String.t()) :: device() | nil
  def parse_line(line) do
    case Regex.named_captures(@device_regex, line) do
      nil ->
        nil

      captures ->
        name = captures["name"]
        total = String.to_integer(captures["total"])
        free = String.to_integer(captures["free"])
        {backend_name, backend} = backend_of(name)

        cond do
          is_nil(backend) ->
            %{
              physical_id: name,
              name: name,
              description: captures["description"],
              backend: :unknown,
              backend_name: backend_name,
              capacity_mib: total,
              free_mib: free,
              usable: false,
              reason: :unknown_backend
            }

          free > total ->
            %{
              physical_id: name,
              name: name,
              description: captures["description"],
              backend: backend,
              backend_name: backend_name,
              capacity_mib: total,
              free_mib: free,
              usable: false,
              reason: :free_gt_total
            }

          total == 0 ->
            # La memoria no se pudo leer (`cudaMemGetInfo` fallo, Metal en
            # macOS antiguo). Sin memoria declarada no se reserva nada.
            %{
              physical_id: name,
              name: name,
              description: captures["description"],
              backend: backend,
              backend_name: backend_name,
              capacity_mib: total,
              free_mib: free,
              usable: false,
              reason: :no_memory_reported
            }

          true ->
            %{
              physical_id: name,
              name: name,
              description: captures["description"],
              backend: backend,
              backend_name: backend_name,
              capacity_mib: total,
              free_mib: free,
              usable: true,
              reason: nil
            }
        end
    end
  end

  @doc """
  El backend de un nombre de device.

  ## Ejemplos

      iex> Gunther.Detector.LlamaCpp.backend_of("CUDA0")
      {"CUDA", :cuda}

      iex> Gunther.Detector.LlamaCpp.backend_of("Exotic0")
      {"Exotic", nil}
  """
  @spec backend_of(String.t()) :: {String.t(), atom() | nil}
  def backend_of(name) do
    base = String.replace(name, ~r/\d+$/, "")

    {base, Map.get(@backends, base)}
  end
end
