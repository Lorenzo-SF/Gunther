defmodule Gunther.ErrorTest do
  use ExUnit.Case, async: true

  doctest Gunther.Error

  describe "new/3" do
    test "el retryable por defecto sale de la tabla de §4.13" do
      assert %Gunther.Error{retryable?: true} = Gunther.Error.new(:overloaded, "x")
      assert %Gunther.Error{retryable?: false} = Gunther.Error.new(:node_auth_failed, "x")
      assert %Gunther.Error{retryable?: false} = Gunther.Error.new(:tool_confirmation_required, "x")
    end

    test "los errores de backend son retryable por defecto false" do
      for code <- [:provider_error, :store_error, :embedder_error, :retriever_error, :tool_error, :command_failed] do
        assert %Gunther.Error{retryable?: false} = Gunther.Error.new(code, "x")
      end
    end

    test "acepta retry_after_ms, details y cause" do
      error =
        Gunther.Error.new(:rate_limited, "demasiado", retry_after_ms: 1500, details: %{limit: 10}, cause: :boom)

      assert error.retry_after_ms == 1500
      assert error.details == %{limit: 10}
      assert error.cause == :boom
    end
  end

  describe "http_status/1" do
    test "mapea los códigos de §4.13" do
      assert Gunther.Error.http_status(%Gunther.Error{code: :timeout, message: "x"}) == 504
      assert Gunther.Error.http_status(%Gunther.Error{code: :invalid_request, message: "x"}) == 400
      assert Gunther.Error.http_status(%Gunther.Error{code: :no_candidates, message: "x"}) == 503
      assert Gunther.Error.http_status(%Gunther.Error{code: :stream_interrupted, message: "x"}) == nil
      assert Gunther.Error.http_status(%Gunther.Error{code: :provider_error, message: "x"}) == nil
    end
  end

  describe "from/1" do
    test "un Gunther.Error pasa tal cual" do
      original = Gunther.Error.new(:timeout, "x")
      assert Gunther.Error.from(original) == original
    end

    test "un átomo conocido se convierte con ese código" do
      assert %Gunther.Error{code: :timeout, message: "timeout"} = Gunther.Error.from(:timeout)
    end

    test "un átomo desconocido es :internal_error y conserva la causa" do
      assert %Gunther.Error{code: :internal_error, cause: :inventado} = Gunther.Error.from(:inventado)
    end

    test "cualquier otra cosa es :internal_error" do
      assert %Gunther.Error{code: :internal_error, cause: %{a: 1}} = Gunther.Error.from(%{a: 1})
    end
  end

  describe "codes/0" do
    test "cubre todos los códigos que el SPEC lista" do
      codes = Gunther.Error.codes()

      for status <- [400, 402, 403, 404, 409, 410, 422, 429, 499, 500, 502, 503, 504] do
        assert Map.has_key?(codes, status), "falta el HTTP #{status}"
      end
    end

    test "el código :stream_interrupted no tiene HTTP" do
      refute :stream_interrupted in Gunther.Error.all_codes()
    end

    test "el código :classifier_error no tiene HTTP" do
      refute :classifier_error in Gunther.Error.all_codes()
    end

    test "no hay códigos duplicados entre secciones HTTP" do
      all = Gunther.Error.all_codes()
      assert length(all) == length(Enum.uniq(all))
    end
  end
end
