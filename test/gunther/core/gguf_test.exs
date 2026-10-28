defmodule Gunther.GgufTest do
  use ExUnit.Case, async: true

  alias Gunther.Gguf
  alias Gunther.TestSupport.GgufBuilder

  describe "la cabecera" do
    test "un GGUF valido se parsea" do
      header =
        GgufBuilder.build(
          [
            {"llama.block_count", GgufBuilder.value(4)},
            {"llama.embedding_length", GgufBuilder.value(2048)}
          ],
          [{"token_embd.weight", [2048, 32_000], 1, 0}]
        )

      assert {:ok, gguf} = Gguf.parse(header)
      assert gguf.version == 3
      assert gguf.tensor_count == 1
      assert gguf.alignment == 32
    end

    test "la metadata se lee con su tipo" do
      header =
        GgufBuilder.build(
          [
            {"llama.block_count", {:u32, 4}},
            {"general.name", {:string, "un modelo"}},
            {"llama.attention.head_count", {:u32, 8}},
            {"general.quantization_version", {:u32, 2}},
            {"tokenizer.ggml.no_bos", {:bool, true}},
            {"llama.rope.dimension_count", {:u32, 64}},
            {"llama.expert_count", {:u32, 8}}
          ],
          []
        )

      assert {:ok, gguf} = Gguf.parse(header)

      assert gguf.metadata["llama.block_count"] == 4
      assert gguf.metadata["general.name"] == "un modelo"
      assert gguf.metadata["llama.attention.head_count"] == 8
      assert gguf.metadata["tokenizer.ggml.no_bos"] == true
    end

    test "los arrays se leen como listas" do
      header =
        GgufBuilder.build(
          [
            {"llama.attention.head_count", {:array, 4, [{:u32, 32}, {:u32, 32}, {:u32, 16}, {:u32, 16}]}}
          ],
          []
        )

      assert {:ok, gguf} = Gguf.parse(header)
      assert gguf.metadata["llama.attention.head_count"] == [32, 32, 16, 16]
    end

    test "los tensor infos se leen con sus dimensiones y su tipo" do
      header =
        GgufBuilder.build(
          [],
          [
            {"token_embd.weight", [2048, 32_000], 1, 0},
            {"blk.0.attn_q.weight", [2048, 2048], 8, 1024}
          ]
        )

      assert {:ok, gguf} = Gguf.parse(header)
      assert length(gguf.tensors) == 2

      [first, second] = gguf.tensors
      assert first.name == "token_embd.weight"
      assert first.dims == [2048, 32_000]
      assert first.type == 1
      assert first.offset == 0

      assert second.name == "blk.0.attn_q.weight"
      assert second.type == 8
      assert second.offset == 1024
    end

    test "un tensor con el tipo desconocido no se inventa" do
      header = GgufBuilder.build([], [{"pesos", [16], 999, 0}])
      assert {:ok, gguf} = Gguf.parse(header)
      assert [%{type: 999}] = gguf.tensors
    end
  end

  describe "los errores" do
    test "un fichero que no es GGUF se rechaza" do
      assert {:error, :bad_magic} = Gguf.parse("NOPE" <> <<0::size(64)>>)
    end

    test "una cabecera truncada se rechaza, no revienta" do
      header = GgufBuilder.build([{"llama.block_count", GgufBuilder.value(4)}], [])

      for cut <- 1..(byte_size(header) - 1) do
        truncated = binary_part(header, 0, cut)
        assert {:error, reason} = Gguf.parse(truncated)
        assert reason in [:truncated, :bad_magic, :bad_version, :invalid_value_type]
      end
    end

    test "una version que no se conoce se rechaza" do
      header = <<"GGUF", 99::little-unsigned-32, 0::little-unsigned-64, 0::little-unsigned-64>>
      assert {:error, :bad_version} = Gguf.parse(header)
    end

    test "un tipo de valor desconocido se rechaza" do
      # magic, version, tensor_count, kv_count, y una clave con tipo 99
      header =
        <<"GGUF", 3::little-unsigned-32, 0::little-unsigned-64, 1::little-unsigned-64, 1::little-unsigned-64, "k",
          99::little-unsigned-32>>

      assert {:error, :invalid_value_type} = Gguf.parse(header)
    end
  end

  describe "el fuzz" do
    test "un binario cualquiera no revienta el parser" do
      # El parser es propio (SPEC §11.5) y lee ficheros que no controla
      # Gunther: tiene que devolver un error, no levantar.
      for _attempt <- 1..200 do
        bytes = :crypto.strong_rand_bytes(:rand.uniform(64))

        case Gguf.parse(bytes) do
          {:ok, _gguf} -> :ok
          {:error, reason} -> assert is_atom(reason)
        end
      end
    end
  end
end
