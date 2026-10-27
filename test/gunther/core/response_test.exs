defmodule Gunther.ResponseTest do
  use ExUnit.Case, async: true

  doctest Gunther.Response

  describe "new/1" do
    test "calcula degraded a partir de los warnings" do
      response =
        Gunther.Response.new(%{
          content: "x",
          model: :m,
          provider: :p,
          warnings: [%{code: :failover, message: "m", details: %{}}]
        })

      assert response.degraded
    end

    test ":context_compacted, :guardrail_modified y :empty_response NO degradan" do
      for code <- [:context_compacted, :guardrail_modified, :empty_response] do
        response =
          Gunther.Response.new(%{
            content: "x",
            model: :m,
            provider: :p,
            warnings: [%{code: code, message: "m", details: %{}}]
          })

        refute response.degraded, "#{code} no debe degradar"
      end
    end

    test "respeta un degraded:true explícito" do
      response = Gunther.Response.new(%{content: "x", model: :m, provider: :p, degraded: true})
      assert response.degraded
    end
  end

  describe "degrades?/1" do
    test "reconoce los ocho códigos que degradan" do
      for code <- Gunther.Response.degrading_codes() do
        assert Gunther.Response.degrades?([%{code: code, message: "m", details: %{}}])
      end
    end

    test "una lista vacía no degrada" do
      refute Gunther.Response.degrades?([])
    end
  end
end
