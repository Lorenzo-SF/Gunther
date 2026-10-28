defmodule Gunther.TestSupport.GgufBuilder do
  @moduledoc """
  Constructor de cabeceras GGUF para los tests.

  No es un escritor de ficheros completos: escribe la **cabecera** (magic,
  version, metadata y tensor infos), que es lo que el parser de Gunther
  necesita. Los datos de los tensores no se escriben.

  Los tipos de valor son los de `enum gguf_metadata_value_type` de
  `ggml/include/gguf.h`.
  """

  @type value ::
          {:u8, non_neg_integer()}
          | {:i8, integer()}
          | {:u16, non_neg_integer()}
          | {:i16, integer()}
          | {:u32, non_neg_integer()}
          | {:i32, integer()}
          | {:f32, float()}
          | {:bool, boolean()}
          | {:string, String.t()}
          | {:u64, non_neg_integer()}
          | {:i64, integer()}
          | {:f64, float()}
          | {:array, non_neg_integer(), [value()]}

  @doc """
  Escribe una cabecera GGUF v3.

  `metadata` es una lista de `{clave, value}`; `tensors` es una lista de
  `{nombre, dims, tipo_ggml, offset}`.

  ## Ejemplos

      iex> header = Gunther.TestSupport.GgufBuilder.build([{"llama.block_count", {:u32, 4}}], [])
      iex> binary_part(header, 0, 4)
      "GGUF"
  """
  @spec build([{String.t(), value()}], [{String.t(), [pos_integer()], non_neg_integer(), non_neg_integer()}]) ::
          binary()
  def build(metadata, tensors) do
    magic = "GGUF"
    version = 3

    kv = Enum.map(metadata, fn {key, value} -> [string(key), encode_value(value)] end)

    tensor_infos =
      Enum.map(tensors, fn {name, dims, type, offset} ->
        [
          string(name),
          <<length(dims)::little-unsigned-32>>,
          Enum.map(dims, &<<&1::little-unsigned-64>>),
          <<type::little-unsigned-32>>,
          <<offset::little-unsigned-64>>
        ]
      end)

    IO.iodata_to_binary([
      magic,
      <<version::little-unsigned-32>>,
      <<length(tensors)::little-unsigned-64>>,
      <<length(metadata)::little-unsigned-64>>,
      kv,
      tensor_infos,
      <<32::little-unsigned-64>>
    ])
  end

  @doc """
  El valor de metadata tal y como lo escribe GGUF.

  Los enteros pequeños van como `u32` salvo que se pida otra cosa, que es lo
  que hacen los conversores reales.
  """
  @spec value(integer() | String.t() | boolean() | float()) :: value()
  def value(int) when is_integer(int) and int >= 0, do: {:u32, int}
  def value(int) when is_integer(int), do: {:i32, int}
  def value(str) when is_binary(str), do: {:string, str}
  def value(bool) when is_boolean(bool), do: {:bool, bool}
  def value(float) when is_float(float), do: {:f32, float}

  defp string(str) do
    <<byte_size(str)::little-unsigned-64>> <> str
  end

  defp bool_byte(true), do: 1
  defp bool_byte(false), do: 0

  defp encode_value({:u8, v}), do: <<0::little-unsigned-32, v::little-unsigned-8>>
  defp encode_value({:i8, v}), do: <<1::little-unsigned-32, v::little-signed-8>>
  defp encode_value({:u16, v}), do: <<2::little-unsigned-32, v::little-unsigned-16>>
  defp encode_value({:i16, v}), do: <<3::little-unsigned-32, v::little-signed-16>>
  defp encode_value({:u32, v}), do: <<4::little-unsigned-32, v::little-unsigned-32>>
  defp encode_value({:i32, v}), do: <<5::little-unsigned-32, v::little-signed-32>>
  defp encode_value({:f32, v}), do: <<6::little-unsigned-32, v::little-float-32>>
  defp encode_value({:bool, v}), do: <<7::little-unsigned-32, bool_byte(v)::little-unsigned-8>>
  defp encode_value({:string, v}), do: <<8::little-unsigned-32>> <> string(v)
  defp encode_value({:u64, v}), do: <<10::little-unsigned-32, v::little-unsigned-64>>
  defp encode_value({:i64, v}), do: <<11::little-unsigned-32, v::little-signed-64>>
  defp encode_value({:f64, v}), do: <<12::little-unsigned-32, v::little-float-64>>

  defp encode_value({:array, type, values}) do
    [
      <<9::little-unsigned-32>>,
      <<type::little-unsigned-32>>,
      <<length(values)::little-unsigned-64>>,
      # En un array, el tipo va **una vez**, en la cabecera del array. Los
      # elementos se escriben sin su propio tag.
      Enum.map(values, &encode_array_element(&1, type))
    ]
  end

  # El valor de un elemento de array, sin el tag de tipo.
  defp encode_array_element({:u8, v}, _t), do: <<v::little-unsigned-8>>
  defp encode_array_element({:i8, v}, _t), do: <<v::little-signed-8>>
  defp encode_array_element({:u16, v}, _t), do: <<v::little-unsigned-16>>
  defp encode_array_element({:i16, v}, _t), do: <<v::little-signed-16>>
  defp encode_array_element({:u32, v}, _t), do: <<v::little-unsigned-32>>
  defp encode_array_element({:i32, v}, _t), do: <<v::little-signed-32>>
  defp encode_array_element({:f32, v}, _t), do: <<v::little-float-32>>
  defp encode_array_element({:bool, v}, _t), do: <<bool_byte(v)::little-unsigned-8>>
  defp encode_array_element({:string, v}, _t), do: string(v)
  defp encode_array_element({:u64, v}, _t), do: <<v::little-unsigned-64>>
  defp encode_array_element({:i64, v}, _t), do: <<v::little-signed-64>>
  defp encode_array_element({:f64, v}, _t), do: <<v::little-float-64>>
end
