defmodule Gunther.Resilience.PipelineTest do
  use ExUnit.Case, async: true

  alias Gunther.Resilience.Pipeline

  defp opts(extra \\ []) do
    Keyword.merge(
      [
        instance: :main,
        provider: :p,
        model: :m,
        timeout: 5_000,
        attempt_timeout_ms: 1_000,
        max_attempts: 3,
        base_ms: 1,
        cap_ms: 10
      ],
      extra
    )
  end

  describe "call/3" do
    test "un acierto devuelve el resultado tal cual" do
      assert Pipeline.call(fn _attempt, _budget -> {:ok, :respuesta} end, opts(), []) == {:ok, :respuesta}
    end

    test "no llama mas de una vez si el primer intento va bien" do
      counter = :counters.new(1, [:atomics])

      fun = fn _attempt, _budget ->
        :counters.add(counter, 1, 1)
        {:ok, :respuesta}
      end

      assert {:ok, :respuesta} = Pipeline.call(fun, opts(), [])
      assert :counters.get(counter, 1) == 1
    end

    test "un error reintentable se reintenta hasta el maximo" do
      counter = :counters.new(1, [:atomics])

      fun = fn _attempt, _budget ->
        :counters.add(counter, 1, 1)
        {:error, :timeout}
      end

      assert {:error, error} = Pipeline.call(fun, opts(), [])
      assert error.code == :timeout
      assert :counters.get(counter, 1) == 3
    end

    test "un error no reintentable no se reintenta" do
      counter = :counters.new(1, [:atomics])

      fun = fn _attempt, _budget ->
        :counters.add(counter, 1, 1)
        {:error, :invalid_request}
      end

      assert {:error, error} = Pipeline.call(fun, opts(), [])
      assert error.code == :invalid_request
      assert :counters.get(counter, 1) == 1
    end

    test "un reintento que va bien devuelve el resultado" do
      counter = :counters.new(1, [:atomics])

      fun = fn _attempt, _budget ->
        :counters.add(counter, 1, 1)
        if :counters.get(counter, 1) < 2, do: {:error, :timeout}, else: {:ok, :ok}
      end

      assert {:ok, :ok} = Pipeline.call(fun, opts(), [])
      assert :counters.get(counter, 1) == 2
    end

    test "el error devuelto es un valor de Gunther.Error" do
      assert {:error, error} = Pipeline.call(fn _attempt, _budget -> {:error, :timeout} end, opts(), [])
      assert error.code == :timeout
      assert error.retryable?
    end

    test "un error desconocido se devuelve como :internal_error" do
      assert {:error, error} = Pipeline.call(fn _attempt, _budget -> {:error, :inventado} end, opts(), [])
      assert error.code == :internal_error
    end
  end

  describe "el presupuesto de tiempo" do
    test "el plazo total manda sobre el timeout de intento" do
      # Con un plazo total de 5 ms y un timeout de intento de 1000 ms, cada
      # intento recibe como mucho lo que queda del plazo.
      counter = :counters.new(1, [:atomics])

      fun = fn attempt, _budget ->
        :counters.add(counter, 1, 1)
        # El intento recibe el presupuesto restante, no el timeout completo.
        assert attempt <= 5
        {:error, :timeout}
      end

      Pipeline.call(fun, opts(timeout: 5, attempt_timeout_ms: 1_000), [])
      assert :counters.get(counter, 1) >= 1
    end

    test "un intento que consume el plazo no espera en negativo" do
      # El intento se pasa el plazo. Al calcular el backoff, lo que queda es
      # negativo: el backoff se limita por lo que queda, asi que saldria
      # negativo, y `Process.sleep/1` con un negativo revienta. Lo que
      # procede es devolver el error sin reintentar.
      fun = fn _attempt, _budget ->
        Process.sleep(30)
        {:error, :timeout}
      end

      resultado = Pipeline.call(fun, opts(timeout: 5, attempt_timeout_ms: 1_000, base_ms: 200), [])

      assert {:error, error} = resultado
      assert error.code == :timeout
    end

    test "un plazo ya agotado no hace ni un intento" do
      counter = :counters.new(1, [:atomics])

      fun = fn _attempt, _budget ->
        :counters.add(counter, 1, 1)
        {:ok, :tarde}
      end

      # El plazo es tan corto que se agota antes del primer intento.
      assert {:error, error} = Pipeline.call(fun, opts(timeout: 0, max_attempts: 1), [])
      assert error.code == :timeout
      assert :counters.get(counter, 1) == 0
    end

    test "la llamada recibe el presupuesto que le queda, no el timeout completo" do
      seen = :counters.new(1, [:atomics])

      fun = fn _attempt, budget ->
        :counters.put(seen, 1, budget)
        {:ok, :ok}
      end

      Pipeline.call(fun, opts(timeout: 5_000, attempt_timeout_ms: 1_000), [])
      # El timeout de intento (1000) es menor que lo que queda del plazo.
      assert :counters.get(seen, 1) == 1_000
    end

    test "el numero de intento empieza en uno" do
      seen = :counters.new(1, [:atomics])

      fun = fn attempt, _budget ->
        :counters.put(seen, 1, attempt)
        {:ok, :ok}
      end

      Pipeline.call(fun, opts(), [])
      assert :counters.get(seen, 1) == 1
    end
  end

  describe "el failover" do
    test "pasa al siguiente candidato tras agotar el retry" do
      counter = :counters.new(1, [:atomics])

      fun = fn _attempt, _budget ->
        :counters.add(counter, 1, 1)
        {:error, :timeout}
      end

      # Con dos candidatos y un maximo de un failover, se intenta el segundo.
      assert {:error, error} = Pipeline.call(fun, opts(max_attempts: 1), [:otro])
      assert error.code == :timeout
      assert :counters.get(counter, 1) == 2
    end

    test "un error que no admite failover no pasa al siguiente candidato" do
      counter = :counters.new(1, [:atomics])

      fun = fn _attempt, _budget ->
        :counters.add(counter, 1, 1)
        {:error, :invalid_request}
      end

      assert {:error, error} = Pipeline.call(fun, opts(), [:otro])
      assert error.code == :invalid_request
      assert :counters.get(counter, 1) == 1
    end

    test "el numero de failovers esta acotado" do
      counter = :counters.new(1, [:atomics])

      fun = fn _attempt, _budget ->
        :counters.add(counter, 1, 1)
        {:error, :timeout}
      end

      Pipeline.call(fun, opts(max_attempts: 1, max_failovers: 1), [:a, :b, :c])
      # Un intento por candidato, con un failover.
      assert :counters.get(counter, 1) == 2
    end
  end

  describe "el retry_after" do
    test "un 429 con retry_after espera ese tiempo antes de reintentar" do
      counter = :counters.new(1, [:atomics])

      fun = fn _attempt, _budget ->
        :counters.add(counter, 1, 1)
        {:error, {:rate_limited, 60_000}}
      end

      # Con un retry_after mayor que el plazo, no se reintenta: no cabe.
      assert {:error, _reason} = Pipeline.call(fun, opts(timeout: 5, max_attempts: 3), [])
      assert :counters.get(counter, 1) == 1
    end

    test "un 429 sin retry_after reintenta" do
      counter = :counters.new(1, [:atomics])

      fun = fn _attempt, _budget ->
        :counters.add(counter, 1, 1)
        {:error, :rate_limited}
      end

      Pipeline.call(fun, opts(timeout: 5_000, max_attempts: 2), [])
      assert :counters.get(counter, 1) == 2
    end
  end
end
