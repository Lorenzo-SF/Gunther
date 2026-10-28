defmodule Gunther.Resource.WeightTest do
  use ExUnit.Case, async: true

  alias Gunther.Resource.Weight
  alias Gunther.TestSupport.GgufBuilder

  # Una cabecera GGUF con los parametros de un modelo de referencia.
  # `arch` es el prefijo de las claves, como en los ficheros reales
  # ("general.architecture" -> "llama" -> "llama.block_count").
  defp model(opts \\ []) do
    arch = Keyword.get(opts, :arch, "llama")
    n_layer = Keyword.get(opts, :n_layer, 32)
    n_head = Keyword.get(opts, :n_head, 32)
    n_embd = Keyword.get(opts, :n_embd, 2048)

    metadata = [
      {"general.architecture", {:string, arch}},
      {"#{arch}.block_count", {:u32, n_layer}},
      {"#{arch}.embedding_length", {:u32, n_embd}},
      {"#{arch}.attention.head_count", {:u32, n_head}},
      {"#{arch}.context_length", {:u32, 4096}}
    ]

    metadata =
      case Keyword.get(opts, :n_head_kv) do
        nil -> metadata
        value -> metadata ++ [{"#{arch}.attention.head_count_kv", {:u32, value}}]
      end

    metadata =
      case Keyword.get(opts, :key_length) do
        nil -> metadata
        value -> metadata ++ [{"#{arch}.attention.key_length", {:u32, value}}]
      end

    metadata =
      case Keyword.get(opts, :value_length) do
        nil -> metadata
        value -> metadata ++ [{"#{arch}.attention.value_length", {:u32, value}}]
      end

    metadata =
      case Keyword.get(opts, :extra) do
        nil -> metadata
        extra -> metadata ++ extra
      end

    tensors = Keyword.get(opts, :tensors, [{"token_embd.weight", [2048, 32_000], 1, 0}])

    header = GgufBuilder.build(metadata, tensors)
    {:ok, gguf} = Gunther.Gguf.parse(header)
    gguf
  end

  describe "la KV cache de un modelo con atencion estandar" do
    test "el tamano es el de la formula" do
      # 32 capas, 4096 de contexto, 32 cabezas de KV, clave y valor de 64
      # elementos en f16 (2 bytes):
      #   32 * 4096 * 32 * (64*2 + 64*2) = 1.073.741.824 bytes = 1024 MiB
      gguf = model()

      assert {:ok, result} =
               Weight.calculate(gguf,
                 n_ctx: 4096,
                 compute_buffer_mib: 512,
                 offloaded_bytes: 0
               )

      assert result.kv_bytes == 1_073_741_824
      assert result.kv_mib == 1024.0
      assert result.applicability == :exact
    end

    test "con GQA la KV es mas pequena" do
      # 8 cabezas de KV en vez de 32: la cuarta parte.
      gguf = model(n_head_kv: 8)

      assert {:ok, result} =
               Weight.calculate(gguf,
                 n_ctx: 4096,
                 compute_buffer_mib: 512,
                 offloaded_bytes: 0
               )

      assert result.kv_mib == 256.0
    end

    test "si no hay head_count_kv, se usa head_count" do
      # Es lo que hace llama.cpp: `n_head_kv_arr = n_head_arr` por defecto.
      gguf = model()

      assert {:ok, result} =
               Weight.calculate(gguf,
                 n_ctx: 4096,
                 compute_buffer_mib: 512,
                 offloaded_bytes: 0
               )

      assert result.n_head_kv == 32
      assert result.kv_mib == 1024.0
    end

    test "si no hay key_length, sale de embedding_length / head_count" do
      # 2048 / 32 = 64
      gguf = model()

      assert {:ok, result} =
               Weight.calculate(gguf,
                 n_ctx: 4096,
                 compute_buffer_mib: 512,
                 offloaded_bytes: 0
               )

      assert result.key_length == 64
      assert result.value_length == 64
    end

    test "el tipo de la KV cambia el resultado" do
      gguf = model()

      assert {:ok, f16} =
               Weight.calculate(gguf,
                 n_ctx: 4096,
                 compute_buffer_mib: 512,
                 offloaded_bytes: 0,
                 type_k: :f16,
                 type_v: :f16
               )

      assert {:ok, q8} =
               Weight.calculate(gguf,
                 n_ctx: 4096,
                 compute_buffer_mib: 512,
                 offloaded_bytes: 0,
                 type_k: :q8_0,
                 type_v: :q8_0
               )

      # q8_0 ocupa 34/32 = 1,0625 bytes por elemento; f16 ocupa 2. La
      # cache cuantizada ocupa la mitad, con un 6,25% mas que el "1 byte
      # por elemento" que fijaba r5.
      assert q8.kv_bytes == f16.kv_bytes * 34 / 64
      assert q8.kv_mib == 1024.0 * 34 / 64
      assert q8.kv_mib == 544.0
    end

    test "la clave y el valor se pueden medir por separado" do
      # K en f16 y V en q8_0: no es lo mismo que las dos iguales.
      gguf = model()

      assert {:ok, result} =
               Weight.calculate(gguf,
                 n_ctx: 4096,
                 compute_buffer_mib: 512,
                 offloaded_bytes: 0,
                 type_k: :f16,
                 type_v: :q8_0
               )

      assert result.kv_bytes == 32 * 4096 * 32 * (64 * 2 + 64 * 34 / 32)
    end
  end

  describe "el peso total" do
    test "suma los pesos, la KV y el buffer de computacion" do
      gguf = model()

      assert {:ok, result} =
               Weight.calculate(gguf,
                 n_ctx: 4096,
                 compute_buffer_mib: 512,
                 offloaded_bytes: 2 * 1024 * 1024 * 1024
               )

      # 2048 MiB de pesos + 1024 MiB de KV + 512 MiB de buffer = 3584 MiB
      assert result.weight_mib == 3584
    end

    test "redondea hacia arriba" do
      gguf = model()

      assert {:ok, result} =
               Weight.calculate(gguf,
                 n_ctx: 4096,
                 compute_buffer_mib: 1,
                 offloaded_bytes: 1
               )

      # 1 byte de pesos + 1024 MiB de KV + 1 MiB de buffer = 1025 MiB y
      # algo: el redondeo va hacia arriba.
      assert result.weight_mib == 1026
    end

    test "sin compute_buffer_mib no se puede calcular" do
      # La formula no lo puede deducir: es obligatorio en la config.
      gguf = model()

      assert {:error, :compute_buffer_required} =
               Weight.calculate(gguf, n_ctx: 4096, offloaded_bytes: 0)
    end

    test "sin n_ctx no se puede calcular" do
      gguf = model()

      assert {:error, :n_ctx_required} =
               Weight.calculate(gguf, compute_buffer_mib: 512, offloaded_bytes: 0)
    end
  end

  describe "los tipos de atencion donde la formula no vale" do
    test "MLA no es valida: la KV es un latente, no clave y valor" do
      gguf = model(extra: [{"llama.attention.kv_lora_rank", {:u32, 512}}])

      assert {:ok, result} =
               Weight.calculate(gguf,
                 n_ctx: 4096,
                 compute_buffer_mib: 512,
                 offloaded_bytes: 0
               )

      assert result.applicability == :not_applicable
      assert result.reason == :mla
    end

    test "SSM no es valida: hay estado, no KV por capa" do
      gguf = model(extra: [{"llama.ssm.state_size", {:u32, 128}}])

      assert {:ok, result} =
               Weight.calculate(gguf,
                 n_ctx: 4096,
                 compute_buffer_mib: 512,
                 offloaded_bytes: 0
               )

      assert result.applicability == :not_applicable
      assert result.reason == :ssm
    end

    test "la ventana deslizante es exacta, porque swa_full es el defecto de llama-server" do
      gguf = model(extra: [{"llama.attention.sliding_window", {:u32, 512}}])

      assert {:ok, result} =
               Weight.calculate(gguf,
                 n_ctx: 4096,
                 compute_buffer_mib: 512,
                 offloaded_bytes: 0
               )

      # Medido en `llama_context_params` (llama-context.cpp): `swa_full` es
      # `true` por defecto, y con el cache SWA de tamano completo la formula
      # es exacta.
      assert result.applicability == :exact
      assert result.reason == nil
      assert result.kv_mib == 1024.0
    end

    test "sin swa_full la ventana deslizante es una cota superior" do
      gguf = model(extra: [{"llama.attention.sliding_window", {:u32, 512}}])

      assert {:ok, result} =
               Weight.calculate(gguf,
                 n_ctx: 4096,
                 compute_buffer_mib: 512,
                 offloaded_bytes: 0,
                 swa_full: false
               )

      # La formula da el tamano completo, que es MAYOR que la cache SWA
      # real: es una cota superior, no una medida.
      assert result.applicability == :upper_bound
      assert result.reason == nil
    end
  end

  describe "los parametros por capa" do
    test "head_count_kv puede ser un array" do
      # Es lo que hace llama.cpp con `get_key_or_arr`: un escalar repetido
      # o un array de una entrada por capa.
      gguf =
        model(
          n_layer: 2,
          extra: [
            {"llama.attention.head_count_kv", {:array, 4, [{:u32, 32}, {:u32, 8}]}}
          ]
        )

      assert {:ok, result} =
               Weight.calculate(gguf,
                 n_ctx: 4096,
                 compute_buffer_mib: 512,
                 offloaded_bytes: 0
               )

      # Capa 0: 32 cabezas -> 32 MiB. Capa 1: 8 cabezas -> 8 MiB.
      assert result.kv_mib == 40.0
    end
  end

  describe "los bytes de los pesos" do
    test "se calculan del GGUF si no se pasan" do
      # Un tensor f16 de 2048 x 32_000 son 2048 * 32_000 * 2 bytes.
      gguf = model(tensors: [{"token_embd.weight", [2048, 32_000], 1, 0}])

      assert {:ok, result} =
               Weight.calculate(gguf, n_ctx: 4096, compute_buffer_mib: 0)

      assert result.offloaded_bytes == 2048 * 32_000 * 2
    end

    test "un tensor de tipo desconocido no se inventa" do
      gguf = model(tensors: [{"pesos", [16], 999, 0}])

      assert {:error, :unknown_tensor_type} =
               Weight.calculate(gguf, n_ctx: 4096, compute_buffer_mib: 0)
    end
  end

  describe "un modelo incompleto" do
    test "sin block_count no se puede calcular" do
      header = GgufBuilder.build([{"general.architecture", {:string, "llama"}}], [])
      {:ok, gguf} = Gunther.Gguf.parse(header)

      assert {:error, :missing_metadata} =
               Weight.calculate(gguf, n_ctx: 4096, compute_buffer_mib: 512)
    end

    test "sin general.architecture no se sabe que claves buscar" do
      header = GgufBuilder.build([{"llama.block_count", {:u32, 4}}], [])
      {:ok, gguf} = Gunther.Gguf.parse(header)

      assert {:error, :missing_metadata} =
               Weight.calculate(gguf, n_ctx: 4096, compute_buffer_mib: 512)
    end
  end
end
