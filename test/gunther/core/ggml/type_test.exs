defmodule Gunther.Ggml.TypeTest do
  use ExUnit.Case, async: true

  alias Gunther.Ggml.Type

  describe "la tabla de tipos (G-14)" do
    test "los bytes por elemento son los de la tabla de ggml, no 1" do
      # Un tipo cuantizado guarda 32 elementos en un bloque: los bytes por
      # elemento son type_size / blck_size, no 1.
      assert Type.bytes_per_element(:q8_0) == 34 / 32
      assert Type.bytes_per_element(:q5_1) == 24 / 32
      assert Type.bytes_per_element(:q5_0) == 22 / 32
      assert Type.bytes_per_element(:q4_1) == 20 / 32
      assert Type.bytes_per_element(:q4_0) == 18 / 32
    end

    test "los tipos sin cuantizar tienen bytes por elemento enteros" do
      assert Type.bytes_per_element(:f32) == 4.0
      assert Type.bytes_per_element(:f16) == 2.0
      assert Type.bytes_per_element(:bf16) == 2.0
    end

    test "el tamano de bloque y el tamano de tipo son los de la fuente" do
      assert Type.type_size(:q8_0) == 34
      assert Type.blck_size(:q8_0) == 32

      assert Type.type_size(:q4_0) == 18
      assert Type.type_size(:q4_1) == 20
      assert Type.type_size(:q5_0) == 22
      assert Type.type_size(:q5_1) == 24

      assert Type.type_size(:f32) == 4
      assert Type.blck_size(:f32) == 1
    end
  end

  describe "los identificadores numericos" do
    test "son los del enum ggml_type" do
      # Los numeros vienen de `enum ggml_type` en ggml/include/ggml.h. Si
      # upstream inserta un tipo en medio, este test falla y hay que
      # actualizarlo: el numero esta en el fichero del modelo, no en el
      # codigo.
      assert Type.id(:f32) == 0
      assert Type.id(:f16) == 1
      assert Type.id(:q4_0) == 2
      assert Type.id(:q4_1) == 3
      assert Type.id(:q5_0) == 6
      assert Type.id(:q5_1) == 7
      assert Type.id(:q8_0) == 8
      assert Type.id(:bf16) == 30
    end

    test "un identificador desconocido no se inventa" do
      assert Type.from_id(999) == {:error, :unknown_type}
      # Los huecos del enum (Q4_2 = 4, Q4_3 = 5) estan vacios upstream.
      assert Type.from_id(4) == {:error, :unknown_type}
      assert Type.from_id(5) == {:error, :unknown_type}
    end

    test "ida y vuelta" do
      for type <- [:f32, :f16, :bf16, :q4_0, :q4_1, :q5_0, :q5_1, :q8_0] do
        assert {:ok, ^type} = Type.from_id(Type.id(type))
      end
    end
  end

  describe "la aritmetica exacta" do
    test "los bytes por elemento en escala 32 son enteros" do
      # La formula de la KV multiplica por bytes por elemento, y el
      # resultado tiene que ser exacto: 34/32 no se puede representar con
      # flotantes sin perder precision al sumar miles de capas.
      for type <- [:f32, :f16, :bf16, :q4_0, :q4_1, :q5_0, :q5_1, :q8_0] do
        assert is_integer(Type.bytes_per_element_x32(type))
      end

      assert Type.bytes_per_element_x32(:q8_0) == 34
      assert Type.bytes_per_element_x32(:q4_0) == 18
      assert Type.bytes_per_element_x32(:f32) == 128
      assert Type.bytes_per_element_x32(:f16) == 64
    end

    test "el tamano de fila coincide con el de ggml_row_size" do
      # ggml_row_size(type, ne) = type_size * ne / blck_size, con la
      # asercion de que ne es multiplo del tamano de bloque.
      assert Type.row_size(:q4_0, 32) == 18
      assert Type.row_size(:q4_0, 64) == 36
      assert Type.row_size(:f16, 128) == 256
      assert Type.row_size(:f32, 128) == 512
    end

    test "una fila que no es multiplo del bloque es un error, como la asercion de ggml" do
      assert Type.row_size(:q4_0, 30) == {:error, :not_a_multiple_of_block}
    end
  end

  describe "un tipo que no esta en la tabla" do
    test "un tipo que no existe no tiene bytes por elemento" do
      assert Type.bytes_per_element(:iq4_nl) == nil
      assert Type.known?(:iq4_nl) == false
      assert Type.known?(:q8_0) == true
    end
  end
end
