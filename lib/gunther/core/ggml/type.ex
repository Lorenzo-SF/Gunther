defmodule Gunther.Ggml.Type do
  @moduledoc """
  La tabla de tipos de ggml que la KV cache puede usar (SPEC §11.5, G-14).

  ## Por que existe

  La fórmula de la KV cache (§11.5) multiplica por los **bytes por elemento**
  del tipo de la caché. El error de r5 era fijar `q8_0 = 1` byte por
  elemento: los tipos cuantizados de ggml **se almacenan en bloques**, y los
  bytes por elemento son `type_size / blck_size`, no 1.

  Los valores no están inventados: salen de `ggml/src/ggml-common.h` de
  llama.cpp, donde cada bloque se define por sus campos.

      q4_0: d (2 bytes) + qs[16]                    = 18 bytes / 32 elementos
      q4_1: d (2) + m (2) + qs[16]                   = 20 bytes / 32 elementos
      q5_0: d (2) + qh[4] + qs[16]                  = 22 bytes / 32 elementos
      q5_1: d (2) + m (2) + qh[4] + qs[16]          = 24 bytes / 32 elementos
      q8_0: d (2) + qs[32]                          = 34 bytes / 32 elementos

  ## Solo los tipos de la KV

  La tabla no es el `enum ggml_type` completo: son los tipos que
  `--cache-type-k` y `--cache-type-v` pueden pedir, que es lo único que la
  fórmula necesita. Los demas tipos de ggml (cuantizaciones k-quant, IQ,
  TQ, MXFP4) no aparecen en la KV cache, asi que no tienen bytes por
  elemento **para este proposito** y se consideran desconocidos.

  ## Aritmetica exacta

  `bytes_per_element/1` devuelve un flotante (`34 / 32`), que es lo legible.
  Para sumar miles de capas, `bytes_per_element_x32/1` devuelve los mismos
  bytes **multiplicados por 32**, siempre enteros: la aritmetica es exacta
  y no acumula error de coma flotante.

  ## Ejemplos

      iex> Gunther.Ggml.Type.bytes_per_element(:q8_0)
      1.0625

      iex> Gunther.Ggml.Type.bytes_per_element_x32(:q8_0)
      34
  """

  @type t :: :f32 | :f16 | :bf16 | :q8_0 | :q5_1 | :q5_0 | :q4_1 | :q4_0

  # {tipo, id del enum ggml_type, type_size en bytes, blck_size}
  #
  # El id es el numero que va en el fichero del modelo y en la cabecera
  # GGUF. upstream dice "always add types at the end of the enum to keep
  # backward compatibility", asi que estos numeros no se mueven.
  @table [
    {:f32, 0, 4, 1},
    {:f16, 1, 2, 1},
    {:q4_0, 2, 18, 32},
    {:q4_1, 3, 20, 32},
    {:q5_0, 6, 22, 32},
    {:q5_1, 7, 24, 32},
    {:q8_0, 8, 34, 32},
    {:bf16, 30, 2, 1}
  ]

  @by_name Map.new(@table, fn {name, id, size, blck} -> {name, {id, size, blck}} end)
  @by_id Map.new(@table, fn {name, id, size, blck} -> {id, {name, size, blck}} end)

  @doc """
  Los tipos que la KV cache puede usar.

  ## Ejemplos

      iex> Gunther.Ggml.Type.types()
      [:f32, :f16, :q4_0, :q4_1, :q5_0, :q5_1, :q8_0, :bf16]
  """
  @spec types() :: [t()]
  def types, do: Enum.map(@table, fn {name, _id, _size, _blck} -> name end)

  @doc """
  ¿Es un tipo de la tabla?

  ## Ejemplos

      iex> Gunther.Ggml.Type.known?(:q8_0)
      true

      iex> Gunther.Ggml.Type.known?(:iq4_nl)
      false
  """
  @spec known?(atom()) :: boolean()
  def known?(type), do: Map.has_key?(@by_name, type)

  @doc """
  El identificador numerico del tipo (`enum ggml_type`).

  ## Ejemplos

      iex> Gunther.Ggml.Type.id(:q8_0)
      8
  """
  @spec id(t()) :: non_neg_integer()
  def id(type) do
    case Map.fetch(@by_name, type) do
      {:ok, {id, _size, _blck}} -> id
      :error -> raise ArgumentError, "tipo ggml desconocido: #{inspect(type)}"
    end
  end

  @doc """
  El tipo a partir de su identificador numerico.

  Un identificador que no esta en la tabla **no se inventa**: devuelve
  `:unknown_type`, que en la fórmula significa «no aplicable».

  ## Ejemplos

      iex> Gunther.Ggml.Type.from_id(8)
      {:ok, :q8_0}

      iex> Gunther.Ggml.Type.from_id(999)
      {:error, :unknown_type}
  """
  @spec from_id(integer()) :: {:ok, t()} | {:error, :unknown_type}
  def from_id(id) when is_integer(id) do
    case Map.fetch(@by_id, id) do
      {:ok, {name, _size, _blck}} -> {:ok, name}
      :error -> {:error, :unknown_type}
    end
  end

  @doc """
  El tamano del bloque en bytes (`type_size` de ggml).

  ## Ejemplos

      iex> Gunther.Ggml.Type.type_size(:q8_0)
      34
  """
  @spec type_size(t()) :: pos_integer()
  def type_size(type) do
    {_id, size, _blck} = fetch!(type)
    size
  end

  @doc """
  Cuantos elementos caben en un bloque (`blck_size` de ggml).

  ## Ejemplos

      iex> Gunther.Ggml.Type.blck_size(:q8_0)
      32
  """
  @spec blck_size(t()) :: pos_integer()
  def blck_size(type) do
    {_id, _size, blck} = fetch!(type)
    blck
  end

  @doc """
  Los bytes por elemento, como flotante.

  `nil` si el tipo no esta en la tabla.

  ## Ejemplos

      iex> Gunther.Ggml.Type.bytes_per_element(:f16)
      2.0

      iex> Gunther.Ggml.Type.bytes_per_element(:q4_0)
      0.5625
  """
  @spec bytes_per_element(t()) :: float() | nil
  def bytes_per_element(type) do
    case Map.fetch(@by_name, type) do
      {:ok, {_id, size, blck}} -> size / blck
      :error -> nil
    end
  end

  @doc """
  Los bytes por elemento **multiplicados por 32**, siempre enteros.

  Es la forma exacta de la aritmetica: `34/32` no se puede sumar miles de
  veces sin perder precision.

  ## Ejemplos

      iex> Gunther.Ggml.Type.bytes_per_element_x32(:q4_0)
      18
  """
  @spec bytes_per_element_x32(t()) :: non_neg_integer() | nil
  def bytes_per_element_x32(type) do
    case Map.fetch(@by_name, type) do
      {:ok, {_id, size, blck}} -> div(size * 32, blck)
      :error -> nil
    end
  end

  @doc """
  El tamano en bytes de una fila de `ne` elementos.

  Es `ggml_row_size(type, ne)` de ggml: `type_size * ne / blck_size`. ggml
  **aserta** que `ne` es multiplo del tamano de bloque, y aqui eso es un
  error, no una asercion que revienta el proceso.

  ## Ejemplos

      iex> Gunther.Ggml.Type.row_size(:q4_0, 32)
      18

      iex> Gunther.Ggml.Type.row_size(:q4_0, 30)
      {:error, :not_a_multiple_of_block}
  """
  @spec row_size(t(), non_neg_integer()) ::
          non_neg_integer() | {:error, :not_a_multiple_of_block | :unknown_type}
  def row_size(type, ne) when is_integer(ne) and ne >= 0 do
    case Map.fetch(@by_name, type) do
      :error ->
        {:error, :unknown_type}

      {:ok, {_id, size, blck}} ->
        if rem(ne, blck) == 0 do
          div(size * ne, blck)
        else
          {:error, :not_a_multiple_of_block}
        end
    end
  end

  defp fetch!(type) do
    case Map.fetch(@by_name, type) do
      {:ok, entry} -> entry
      :error -> raise ArgumentError, "tipo ggml desconocido: #{inspect(type)}"
    end
  end
end
