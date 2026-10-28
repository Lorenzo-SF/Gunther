defmodule Gunther.ContextTest do
  use ExUnit.Case, async: true

  alias Gunther.Context

  describe "new/1" do
    test "el defecto es el consumer por defecto" do
      context = Context.new()

      assert context.consumer == :default
      assert context.session == nil
      assert context.memory == true
      assert context.guardrails == true
      assert context.trace == false
      assert context.compaction == nil
      assert context.decision == :auto
      assert context.require == nil
      assert context.options == %{}
    end

    test "acepta un mapa y una keyword list" do
      assert Context.new(%{consumer: :c1}).consumer == :c1
      assert Context.new(consumer: :c1).consumer == :c1
    end

    test "lo que se pasa se conserva" do
      context = Context.new(%{consumer: :c1, session: "s", trace: true, options: %{a: 1}})

      assert context.consumer == :c1
      assert context.session == "s"
      assert context.trace == true
      assert context.options == %{a: 1}
    end
  end
end
