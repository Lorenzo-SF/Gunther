defmodule Gunther.Resource.Weight do
  @moduledoc """
  El peso calculado de un modelo: la KV cache y el total (SPEC §11.5, CE-24).

  ## La fórmula

      kv_bytes = Σ sobre capas con atención
                   n_ctx · n_head_kv[l] · ( key_length[l]·bytes(type_k)
                                          + value_length[l]·bytes(type_v) )

      peso_calculado_mib = ceil( (bytes_de_pesos_offloaded + kv_bytes
                                  + compute_buffer_mib·2^20) / 2^20 )

  ## Lo que el SPEC corrige de r5

  r5 fijaba `q8_0 = 1` byte por elemento y usaba una sola dimension por
  cabeza para claves y valores. Las dos cosas estan mal:

  - Los bytes por elemento de un tipo cuantizado **no** son 1: se guardan en
    bloques. Son `type_size / blck_size`, y salen de la tabla de ggml
    (`Gunther.Ggml.Type`).
  - La clave y el valor **tienen longitudes propias** (`key_length` y
    `value_length`), que no tienen por que ser iguales, y sus tipos de KV
    tambien (`type_k` y `type_v`).

  ## Donde la fórmula NO vale

  | Tipo de atención                              | Que hace Gunther                                          |
  | --------------------------------------------- | --------------------------------------------------------- |
  | Estandar (MHA o GQA)                          | Usa la fórmula; es exacta                                 |
  | Ventana deslizante (`sliding_window` presente) | Usa la fórmula y marca `upper_bound`                       |
  | MLA (`kv_lora_rank` presente)                 | `fit` obligatorio; si no, `vram_mb`; si no, `:memory_unknown` |
  | Recurrente o SSM                              | Igual que MLA                                             |

  ## Aritmetica exacta

  Los bytes por elemento son fracciones (`34/32`). La suma se hace en
  **escala 32** (enteros) y solo se divide al final, para que sumar treinta
  y dos capas no pierda precision.

  ## Ejemplos

      iex> Gunther.Resource.Weight.applicability(%{metadata: %{}})
      {:not_applicable, :unknown_attention_type}
  """

  alias Gunther.Ggml.Type
  alias Gunther.Gguf

  @type applicability :: :exact | :upper_bound | :not_applicable

  @type result :: %{
          n_layer: pos_integer(),
          n_head: pos_integer(),
          n_head_kv: pos_integer() | [pos_integer()],
          key_length: pos_integer() | [pos_integer()],
          value_length: pos_integer() | [pos_integer()],
          type_k: Type.t(),
          type_v: Type.t(),
          offloaded_bytes: non_neg_integer(),
          kv_bytes: float(),
          kv_mib: float(),
          weight_mib: non_neg_integer(),
          applicability: applicability(),
          reason: atom() | nil
        }

  @doc """
  Calcula el peso de un modelo.

  ## Opciones

    * `:n_ctx` — **obligatorio**. El contexto total (`--ctx-size`).
    * `:compute_buffer_mib` — **obligatorio**. La fórmula no lo puede
      deducir: lo dice la config del modelo.
    * `:type_k`, `:type_v` — el tipo de la KV cache. Por defecto `:f16`,
      que es lo que usa `llama-server` si no se dice otra cosa.
    * `:offloaded_bytes` — los bytes de los pesos que van a la GPU. Por
      defecto se calculan del GGUF.
    * `:swa_full` — si la caché SWA es de tamaño completo. Por defecto
      `true`, que es lo que hace `llama-server` por defecto.

  ## Ejemplos

      iex> Gunther.Resource.Weight.calculate(%Gunther.Gguf{}, [])
      {:error, :n_ctx_required}
  """
  @spec calculate(Gguf.t(), keyword()) :: {:ok, result()} | {:error, atom()}
  def calculate(%Gguf{} = gguf, opts) do
    n_ctx = required(opts, :n_ctx, :n_ctx_required)

    with {:ok, n_ctx} <- n_ctx,
         {:ok, compute_buffer_mib} <- required(opts, :compute_buffer_mib, :compute_buffer_required),
         {:ok, arch} <- architecture(gguf),
         {:ok, n_layer} <- integer_meta(gguf, "#{arch}.block_count"),
         {:ok, n_head} <- integer_meta(gguf, "#{arch}.attention.head_count"),
         {:ok, n_embd} <- integer_meta(gguf, "#{arch}.embedding_length"),
         {:ok, type_k} <- kv_type(Keyword.get(opts, :type_k, :f16)),
         {:ok, type_v} <- kv_type(Keyword.get(opts, :type_v, :f16)),
         {:ok, offloaded_bytes} <- offloaded_bytes(gguf, opts),
         {:ok, per_layer} <- per_layer(gguf, arch, n_layer, n_head, n_embd) do
      kv_bytes_x32 = kv_bytes_x32(n_ctx, per_layer, type_k, type_v)

      kv_bytes = kv_bytes_x32 / 32
      peso_bytes_x32 = offloaded_bytes * 32 + kv_bytes_x32 + compute_buffer_mib * 1_048_576 * 32
      weight_mib = div(peso_bytes_x32 + 32 * 1_048_576 - 1, 32 * 1_048_576)

      {applicability, reason} =
        if recurrent?(per_layer) do
          {:not_applicable, :ssm}
        else
          applicability(gguf, arch, Keyword.get(opts, :swa_full, true))
        end

      {:ok,
       %{
         n_layer: n_layer,
         n_head: n_head,
         n_head_kv: per_layer.n_head_kv,
         key_length: per_layer.key_length,
         value_length: per_layer.value_length,
         type_k: type_k,
         type_v: type_v,
         offloaded_bytes: offloaded_bytes,
         kv_bytes: kv_bytes,
         kv_mib: kv_bytes / 1_048_576,
         weight_mib: weight_mib,
         applicability: applicability,
         reason: reason
       }}
    end
  end

  @doc """
  El tipo de atención de un modelo, según sus claves.

  ## Ejemplos

      iex> Gunther.Resource.Weight.applicability(%{metadata: %{}})
      {:not_applicable, :unknown_attention_type}
  """
  @spec applicability(Gguf.t() | map(), String.t() | nil, boolean()) ::
          {applicability(), atom() | nil}
  def applicability(gguf, arch \\ nil, swa_full \\ true)

  def applicability(%{metadata: metadata}, _arch, swa_full) do
    cond do
      has_key?(metadata, ".attention.kv_lora_rank") -> {:not_applicable, :mla}
      has_key?(metadata, ".ssm.state_size") -> {:not_applicable, :ssm}
      not has_key?(metadata, ".attention.head_count") -> {:not_applicable, :unknown_attention_type}
      has_key?(metadata, ".attention.sliding_window") and not swa_full -> {:upper_bound, nil}
      true -> {:exact, nil}
    end
  end

  @doc """
  ¿La clave existe en la metadata, por sufijo?

  Las claves de GGUF llevan el prefijo de la arquitectura
  (`llama.attention.kv_lora_rank`), y el nombre de la arquitectura cambia
  entre modelos. Lo que importa es el **sufijo**.

  ## Ejemplos

      iex> Gunther.Resource.Weight.has_key?(%{"llama.attention.kv_lora_rank" => 1}, ".attention.kv_lora_rank")
      true
  """
  @spec has_key?(map(), String.t()) :: boolean()
  def has_key?(metadata, suffix) do
    Enum.any?(Map.keys(metadata), fn key ->
      key == suffix or String.ends_with?(key, suffix)
    end)
  end

  # --- la KV ------------------------------------------------------------

  # El resultado de la suma, en escala 32 (bytes multiplicados por 32).
  defp kv_bytes_x32(n_ctx, per_layer, type_k, type_v) do
    bytes_k = Type.bytes_per_element_x32(type_k)
    bytes_v = Type.bytes_per_element_x32(type_v)

    Enum.reduce(0..(per_layer.n_layer - 1), 0, fn layer, acc ->
      n_head_kv = value_at(per_layer.n_head_kv, layer)
      key_length = value_at(per_layer.key_length, layer)
      value_length = value_at(per_layer.value_length, layer)

      acc + n_ctx * n_head_kv * (key_length * bytes_k + value_length * bytes_v)
    end)
  end

  # Un valor por capa: si es una lista, el de esa capa; si es un escalar, el
  # mismo para todas. Es lo que hace llama.cpp con `get_key_or_arr`.
  defp value_at(value, _layer_index) when is_integer(value), do: value
  defp value_at(value, layer_index) when is_list(value), do: Enum.at(value, layer_index)

  # --- los parametros por capa -------------------------------------------

  defp per_layer(gguf, arch, n_layer, n_head, n_embd) do
    n_head_kv = maybe_meta(gguf, "#{arch}.attention.head_count_kv") || n_head
    key_length = maybe_meta(gguf, "#{arch}.attention.key_length") || div(n_embd, n_head)
    value_length = maybe_meta(gguf, "#{arch}.attention.value_length") || div(n_embd, n_head)

    if integers?(n_head_kv) and integers?(key_length) and integers?(value_length) do
      {:ok,
       %{
         n_layer: n_layer,
         n_head_kv: n_head_kv,
         key_length: key_length,
         value_length: value_length
       }}
    else
      {:error, :invalid_metadata}
    end
  end

  # Un valor por capa puede ser un entero o una lista de enteros.
  defp integers?(value) when is_integer(value), do: true

  defp integers?(values) when is_list(values),
    do: values != [] and Enum.all?(values, &is_integer/1)

  # `n_head_kv == 0` marca una capa recurrente: no hay KV que medir.
  defp recurrent?(per_layer) do
    case per_layer.n_head_kv do
      value when is_integer(value) -> value == 0
      values when is_list(values) -> Enum.any?(values, &(&1 == 0))
    end
  end

  # --- los pesos --------------------------------------------------------

  defp offloaded_bytes(%Gguf{tensors: tensors}, opts) do
    case Keyword.fetch(opts, :offloaded_bytes) do
      {:ok, bytes} when is_integer(bytes) and bytes >= 0 ->
        {:ok, bytes}

      _otherwise ->
        sum_tensor_bytes(tensors)
    end
  end

  defp sum_tensor_bytes(tensors) do
    result =
      Enum.reduce_while(tensors, 0, fn tensor, acc ->
        case Gguf.tensor_bytes(tensor) do
          {:ok, bytes} -> {:cont, acc + bytes}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)

    case result do
      {:error, reason} -> {:error, reason}
      total -> {:ok, total}
    end
  end

  # --- la metadata ------------------------------------------------------

  defp architecture(%Gguf{metadata: metadata}) do
    case Map.get(metadata, "general.architecture") do
      arch when is_binary(arch) -> {:ok, arch}
      _other -> {:error, :missing_metadata}
    end
  end

  defp integer_meta(%Gguf{metadata: metadata}, key) do
    case Map.get(metadata, key) do
      value when is_integer(value) -> {:ok, value}
      _other -> {:error, :missing_metadata}
    end
  end

  defp maybe_meta(%Gguf{metadata: metadata}, key) do
    case Map.get(metadata, key) do
      value when is_integer(value) -> value
      value when is_list(value) -> value
      _other -> nil
    end
  end

  defp kv_type(type) do
    if Type.known?(type) do
      {:ok, type}
    else
      {:error, :unknown_kv_type}
    end
  end

  defp required(opts, key, error) do
    case Keyword.fetch(opts, key) do
      {:ok, value} when is_integer(value) and value >= 0 -> {:ok, value}
      _other -> {:error, error}
    end
  end
end
