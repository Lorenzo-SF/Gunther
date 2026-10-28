defmodule Gunther.Provider.Mock do
  @moduledoc """
  Un provider de mentira (SPEC §5.14).

  Sirve para probar el motor sin un `llama-server` delante: responde
  instantly, **de forma determinista**, y respeta la cancelacion.

  ## Como se configura

  Por la propia llamada, en la opcion `:mock`:

      Gunther.Provider.Mock.chat(mensajes, mock: %{text: "hola"})

  Las opciones son:

    * `:text` — el texto de la respuesta. Por defecto, el ultimo mensaje de
      usuario, para que la respuesta corresponda a la peticion.
    * `:delay_ms` — quantos milisegundos esperar antes de responder. Sirve
      para probar la cancelacion (§5.14).
    * `:error` — si esta, el provider devuelve `{:error, reason}` en vez de
      responder. Por defecto `nil`.
    * `:usage` — el uso que se informa. Por defecto, una estimacion a partir
      de los caracteres de la peticion.

  ## Determinismo

  La misma peticion da siempre la misma respuesta: no hay reloj ni azar en
  ella. El `seed` que llegue en las opciones **no** cambia nada.

  ## Cancelacion

  Si `opts[:cancelled?]` dice que se cancelo, el provider devuelve
  `{:error, :cancelled}` **sin** responder. Con un `:delay_ms`, la espera se
  interrumpe en cuanto se cancela.

  ## Ejemplos

      iex> {:ok, result} = Gunther.Provider.Mock.chat([%{role: :user, content: "hola"}], [])
      iex> result.content
      "hola"
      iex> result.finish_reason
      :stop
  """

  @behaviour Gunther.Provider

  @impl Gunther.Provider
  def chat(messages, opts) do
    mock = mock(opts)

    with :ok <- validate_messages(messages),
         :ok <- wait(mock, opts) do
      case Map.get(mock, :error) do
        nil -> {:ok, build_result(messages, mock)}
        reason -> {:error, reason}
      end
    end
  end

  # La robustez del contrato (§5.14): una peticion mala se devuelve como
  # error, no se lanza.
  defp validate_messages(messages) when is_list(messages) and messages != [] do
    if Enum.all?(messages, &valid_message?/1) do
      :ok
    else
      {:error, :invalid_request}
    end
  end

  defp validate_messages(_other), do: {:error, :invalid_request}

  defp valid_message?(message) when is_map(message) do
    Map.get(message, :role) in [:user, :system, :assistant, :tool] and
      valid_content?(Map.get(message, :content))
  end

  defp valid_message?(_other), do: false

  defp valid_content?(content) when is_binary(content), do: true

  defp valid_content?(content) when is_list(content) do
    Enum.all?(content, &valid_content?/1)
  end

  defp valid_content?(_other), do: false

  @impl Gunther.Provider
  def stream(messages, opts, on_chunk) do
    mock = mock(opts)

    with :ok <- validate_messages(messages),
         :ok <- wait(mock, opts) do
      case Map.get(mock, :error) do
        nil ->
          result = build_result(messages, mock)
          on_chunk.(%{delta: result.content})
          on_chunk.(%{finish_reason: result.finish_reason})
          {:ok, result}

        reason ->
          {:error, reason}
      end
    end
  end

  @impl Gunther.Provider
  def embed(texts, opts) when is_list(texts) do
    mock = mock(opts)

    with :ok <- validate_texts(texts),
         :ok <- wait(mock, opts) do
      case Map.get(mock, :error) do
        nil -> {:ok, Enum.map(texts, &vector/1)}
        reason -> {:error, reason}
      end
    end
  end

  def embed(_texts, _opts), do: {:error, :invalid_request}

  defp validate_texts(texts) do
    if Enum.all?(texts, &is_binary/1) do
      :ok
    else
      {:error, :invalid_request}
    end
  end

  @impl Gunther.Provider
  def models, do: [:mock]

  @impl Gunther.Provider
  def capabilities(_model), do: [:tools, :structured_output, :streaming]

  @impl Gunther.Provider
  def modalities(_model), do: [:text]

  @impl Gunther.Provider
  def supports?(feature, _model) when feature in [:tools, :structured_output, :streaming] do
    true
  end

  def supports?(_feature, _model), do: false

  @impl Gunther.Provider
  def pricing(_model), do: nil

  @doc """
  El vector determinista de un texto.

  Los vectores no significan nada: son los mismos para el mismo texto, que
  es lo que necesita un test. La dimension es 8.

  ## Ejemplos

      iex> Gunther.Provider.Mock.vector("hola") == Gunther.Provider.Mock.vector("hola")
      true
  """
  @spec vector(binary()) :: [float()]
  def vector(text) when is_binary(text) do
    text
    |> :erlang.phash2(8)
    |> then(fn seed -> for(i <- 1..8, do: deterministic_value(seed, i)) end)
  end

  defp deterministic_value(seed, index) do
    value = :erlang.phash2({seed, index}, 1000)
    (value - 500) / 500
  end

  # La espera, interrumpible por la cancelacion.
  defp wait(mock, opts) do
    delay = Map.get(mock, :delay_ms, 0)
    cancelled? = Keyword.get(opts, :cancelled?)

    if delay <= 0 do
      check_cancelled(cancelled?)
    else
      sleep_cancellable(delay, cancelled?)
    end
  end

  # La espera va en tramos: entre un tramo y el siguiente se mira si se
  # cancelo. Sin esto, una llamada lenta solo se cancelaria al terminar, que
  # es justo lo que la cancelacion tiene que evitar.
  @sleep_slice_ms 10

  defp sleep_cancellable(remaining, cancelled?) when remaining > 0 do
    case check_cancelled(cancelled?) do
      {:error, :cancelled} ->
        {:error, :cancelled}

      :ok ->
        Process.sleep(min(remaining, @sleep_slice_ms))
        sleep_cancellable(remaining - min(remaining, @sleep_slice_ms), cancelled?)
    end
  end

  defp sleep_cancellable(_remaining, _cancelled?), do: :ok

  defp check_cancelled(nil), do: :ok

  defp check_cancelled(cancelled?) when is_function(cancelled?, 0) do
    if cancelled?.(), do: {:error, :cancelled}, else: :ok
  end

  defp check_cancelled(_other), do: :ok

  defp mock(opts) do
    case Keyword.get(opts, :mock, %{}) do
      map when is_map(map) -> map
      _other -> %{}
    end
  end

  defp build_result(messages, mock) do
    text = Map.get(mock, :text) || last_user_text(messages)

    %{
      content: text,
      reasoning: nil,
      tool_calls: nil,
      finish_reason: :stop,
      usage: Map.get(mock, :usage) || usage(messages, text),
      provider_request_id: nil,
      cost: nil
    }
  end

  defp last_user_text(messages) do
    messages
    |> Enum.reverse()
    |> Enum.find_value("", fn
      %{role: :user, content: content} when is_binary(content) -> content
      _other -> nil
    end)
  end

  # Una estimacion burda: caracteres entre cuatro.
  defp usage(messages, text) do
    input = messages |> Enum.map(&content_length/1) |> Enum.sum()
    output = String.length(text)

    %{input_tokens: div(input, 4), output_tokens: div(output, 4), total_tokens: div(input + output, 4)}
  end

  defp content_length(%{content: content}) when is_binary(content), do: String.length(content)
  defp content_length(_other), do: 0
end
