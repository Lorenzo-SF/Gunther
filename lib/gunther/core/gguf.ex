defmodule Gunther.Gguf do
  @moduledoc """
  Parser de la cabecera GGUF (SPEC §11.5, G-14).

  ## Por que propio

  La fórmula de la KV cache (§11.5) lee los parametros del modelo de la
  cabecera GGUF: cuantas capas, cuantos cabezas de atencion, cuantos cabezas
  de KV, y las longitudes de clave y valor. Esos numeros estan **en el
  fichero**, y el fichero lo escribe otro programa: leerlos con una
  biblioteca ajena seria confiar en su version, no en los datos.

  ## Formato

  Version 3 del formato GGUF, en orden little-endian:

      "GGUF"          4 bytes
      version         uint32
      tensor_count    uint64
      kv_count        uint64
      kv              kv_count veces: clave, tipo, valor
      tensor_infos    tensor_count veces: nombre, n_dims, dims, tipo, offset
      alignment       uint64

  ## Lo que no hace

  No lee los **datos** de los tensores: solo la cabecera. Y no adivina: un
  magic que no es `GGUF`, una version desconocida o una cabecera truncada
  devuelven un error, nunca una excepcion. El parser lee ficheros que no
  controla Gunther.

  ## Ejemplos

      iex> Gunther.Gguf.parse("no soy un gguf")
      {:error, :bad_magic}
  """

  alias Gunther.Ggml.Type

  @type value ::
          integer()
          | float()
          | boolean()
          | String.t()
          | [value()]

  @type tensor_info :: %{
          name: String.t(),
          dims: [pos_integer()],
          type: non_neg_integer(),
          offset: non_neg_integer()
        }

  @type t :: %__MODULE__{
          version: non_neg_integer(),
          tensor_count: non_neg_integer(),
          metadata: %{String.t() => value()},
          tensors: [tensor_info()],
          alignment: non_neg_integer()
        }

  defstruct [:version, :tensor_count, :metadata, :tensors, :alignment]

  @magic "GGUF"
  @supported_versions [2, 3]

  # enum gguf_metadata_value_type
  @u8 0
  @i8 1
  @u16 2
  @i16 3
  @u32 4
  @i32 5
  @f32 6
  @bool 7
  @string 8
  @array 9
  @u64 10
  @i64 11
  @f64 12

  @doc """
  Parsea una cabecera GGUF.

  ## Ejemplos

      iex> Gunther.Gguf.parse("nope")
      {:error, :bad_magic}
  """
  @spec parse(binary()) :: {:ok, t()} | {:error, atom()}
  def parse(binary) when is_binary(binary) do
    with {:ok, {magic, binary}} <- take(4, binary),
         :ok <- check_magic(magic),
         {:ok, {<<version::little-unsigned-32>>, binary}} <- take(4, binary),
         :ok <- check_version(version),
         {:ok, {<<tensor_count::little-unsigned-64>>, binary}} <- take(8, binary),
         {:ok, {<<kv_count::little-unsigned-64>>, binary}} <- take(8, binary),
         {:ok, {metadata, binary}} <- read_metadata(kv_count, binary, %{}),
         {:ok, {tensors, binary}} <- read_tensors(tensor_count, binary, []),
         {:ok, {<<alignment::little-unsigned-64>>, _binary}} <- take(8, binary) do
      {:ok,
       %__MODULE__{
         version: version,
         tensor_count: tensor_count,
         metadata: metadata,
         tensors: tensors,
         alignment: alignment
       }}
    end
  end

  def parse(_other), do: {:error, :not_a_binary}

  @doc """
  Lee un valor entero de la metadata.

  `nil` si la clave no existe. Las claves de la metadata son cadenas.

  ## Ejemplos

      iex> gguf = %Gunther.Gguf{metadata: %{"a" => 4}}
      iex> Gunther.Gguf.get_integer(gguf, "a")
      4
  """
  @spec get_integer(t(), String.t()) :: integer() | nil
  def get_integer(%__MODULE__{metadata: metadata}, key) do
    case Map.get(metadata, key) do
      value when is_integer(value) -> value
      _other -> nil
    end
  end

  @doc """
  Los bytes que ocupa un tensor, como los calcula ggml.

  Es `ggml_nbytes`: el tamaño del bloque por la primera dimension, mas el
  resto de las filas.

      ggml_nbytes = ne[0] * nb[0] / blck_size + Σ (ne[i] - 1) * nb[i]

  con `nb[0] = type_size` y `nb[i] = nb[i-1] * ne[i-1]`.

  Un tipo que no esta en la tabla de ggml **no se inventa**: devuelve
  `:unknown_tensor_type`.

  ## Ejemplos

      iex> Gunther.Gguf.tensor_bytes(%{dims: [2048, 32000], type: 1})
      {:ok, 131072000}
  """
  @spec tensor_bytes(tensor_info()) ::
          {:ok, non_neg_integer()}
          | {:error, :unknown_tensor_type | :not_a_multiple_of_block}
  def tensor_bytes(%{dims: dims, type: type_id}) do
    case Type.from_id(type_id) do
      {:error, :unknown_type} ->
        {:error, :unknown_tensor_type}

      {:ok, type} ->
        type_size = Type.type_size(type)
        blck = Type.blck_size(type)

        if Enum.any?(dims, &(&1 < blck or rem(&1, blck) != 0)) and blck > 1 do
          {:error, :not_a_multiple_of_block}
        else
          {:ok, nbytes(dims, type_size, blck)}
        end
    end
  end

  # ggml_nbytes, con la misma aritmetica que ggml.c.
  defp nbytes(dims, type_size, blck) do
    ne = dims ++ List.duplicate(1, 4 - length(dims))
    [n0, n1, n2, n3] = ne

    nb0 = type_size
    nb1 = type_size * div(n0, blck)
    nb2 = nb1 * n1
    nb3 = nb2 * n2

    if blck == 1 do
      type_size + (n0 - 1) * nb0 + (n1 - 1) * nb1 + (n2 - 1) * nb2 + (n3 - 1) * nb3
    else
      div(n0 * type_size, blck) + (n1 - 1) * nb1 + (n2 - 1) * nb2 + (n3 - 1) * nb3
    end
  end

  @doc """
  ¿Existe la clave en la metadata?

  ## Ejemplos

      iex> gguf = %Gunther.Gguf{metadata: %{"a" => 4}}
      iex> Gunther.Gguf.has_key?(gguf, "a")
      true
  """
  @spec has_key?(t(), String.t()) :: boolean()
  def has_key?(%__MODULE__{metadata: metadata}, key), do: Map.has_key?(metadata, key)

  # --- la cabecera ------------------------------------------------------

  defp check_magic(@magic), do: :ok
  defp check_magic(_other), do: {:error, :bad_magic}

  defp check_version(version) when version in @supported_versions, do: :ok
  defp check_version(_other), do: {:error, :bad_version}

  # --- la metadata ------------------------------------------------------

  defp read_metadata(0, rest, acc), do: {:ok, {acc, rest}}

  defp read_metadata(count, rest, acc) when count > 0 do
    with {:ok, {key, rest}} <- read_string(rest),
         {:ok, {type, rest}} <- read_u32(rest),
         {:ok, {value, rest}} <- read_value(type, rest) do
      read_metadata(count - 1, rest, Map.put(acc, key, value))
    end
  end

  defp read_value(@u8, rest) do
    with {:ok, {<<v::little-unsigned-8>>, rest}} <- take(1, rest), do: {:ok, {v, rest}}
  end

  defp read_value(@i8, rest) do
    with {:ok, {<<v::little-signed-8>>, rest}} <- take(1, rest),
         do: {:ok, {v, rest}}
  end

  defp read_value(@u16, rest) do
    with {:ok, {<<v::little-unsigned-16>>, rest}} <- take(2, rest),
         do: {:ok, {v, rest}}
  end

  defp read_value(@i16, rest) do
    with {:ok, {<<v::little-signed-16>>, rest}} <- take(2, rest),
         do: {:ok, {v, rest}}
  end

  defp read_value(@u32, rest) do
    with {:ok, {<<v::little-unsigned-32>>, rest}} <- take(4, rest),
         do: {:ok, {v, rest}}
  end

  defp read_value(@i32, rest) do
    with {:ok, {<<v::little-signed-32>>, rest}} <- take(4, rest),
         do: {:ok, {v, rest}}
  end

  defp read_value(@f32, rest) do
    with {:ok, {<<v::little-float-32>>, rest}} <- take(4, rest),
         do: {:ok, {v, rest}}
  end

  defp read_value(@bool, rest) do
    case take(1, rest) do
      {:ok, {v, rest}} -> {:ok, {v != <<0>>, rest}}
      error -> error
    end
  end

  defp read_value(@string, rest), do: read_string(rest)

  defp read_value(@array, rest) do
    with {:ok, {type, rest}} <- read_u32(rest),
         {:ok, {count, rest}} <- read_u64(rest) do
      read_array(count, type, rest, [])
    end
  end

  defp read_value(@u64, rest) do
    with {:ok, {<<v::little-unsigned-64>>, rest}} <- take(8, rest),
         do: {:ok, {v, rest}}
  end

  defp read_value(@i64, rest) do
    with {:ok, {<<v::little-signed-64>>, rest}} <- take(8, rest),
         do: {:ok, {v, rest}}
  end

  defp read_value(@f64, rest) do
    with {:ok, {<<v::little-float-64>>, rest}} <- take(8, rest),
         do: {:ok, {v, rest}}
  end

  defp read_value(_unknown, _rest), do: {:error, :invalid_value_type}

  defp read_array(0, _type, rest, acc), do: {:ok, {Enum.reverse(acc), rest}}

  defp read_array(count, type, rest, acc) when count > 0 do
    with {:ok, {value, rest}} <- read_value(type, rest) do
      read_array(count - 1, type, rest, [value | acc])
    end
  end

  defp read_string(binary) do
    with {:ok, {len, rest}} <- read_u64(binary) do
      take(len, rest)
    end
  end

  # --- los tensor infos -------------------------------------------------

  defp read_tensors(0, rest, acc), do: {:ok, {Enum.reverse(acc), rest}}

  defp read_tensors(count, rest, acc) when count > 0 do
    with {:ok, {name, rest}} <- read_string(rest),
         {:ok, {n_dims, rest}} <- read_u32(rest),
         {:ok, {dims, rest}} <- read_dims(n_dims, rest, []),
         {:ok, {type, rest}} <- read_u32(rest),
         {:ok, {offset, rest}} <- read_u64(rest) do
      tensor = %{name: name, dims: dims, type: type, offset: offset}
      read_tensors(count - 1, rest, [tensor | acc])
    end
  end

  defp read_dims(0, rest, acc), do: {:ok, {Enum.reverse(acc), rest}}

  defp read_dims(count, rest, acc) when count > 0 do
    with {:ok, {dim, rest}} <- read_u64(rest) do
      read_dims(count - 1, rest, [dim | acc])
    end
  end

  # --- primitivas -------------------------------------------------------

  defp read_u32(binary) do
    with {:ok, {<<v::little-unsigned-32>>, rest}} <- take(4, binary),
         do: {:ok, {v, rest}}
  end

  defp read_u64(binary) do
    with {:ok, {<<v::little-unsigned-64>>, rest}} <- take(8, binary),
         do: {:ok, {v, rest}}
  end

  defp take(n, binary) when byte_size(binary) >= n do
    <<part::binary-size(n), rest::binary>> = binary
    {:ok, {part, rest}}
  end

  defp take(_n, _binary), do: {:error, :truncated}
end
