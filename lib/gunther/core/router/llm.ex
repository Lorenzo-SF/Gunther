defmodule Gunther.Router.Llm do
  @moduledoc """
  La capa `:llm` del router (SPEC §6.1, §6.3, §6.11 y §6.12).

  Es la ultima capa blanda: la que llama a un **modelo de decision
  especializado** (D-68), no a un LLM de proposito general.

  ## Cuando corre

  - `router.llm = "never"`: la capa **no existe**.
  - `router.llm = "fallback"` (defecto): corre solo si las capas baratas no
    resolvieron.
  - `router.llm = "always"`: corre siempre, y su ranking se combina con el
    de las otras capas.

  ## Que ve

  Solo el `Gunther.DecisionView`: texto de autoria del caller con los roles de
  `context_roles`, truncado a `max_input_tokens` (control M2). Los resultados
  de tools, el contenido de RAG, la memoria y los mensajes `assistant` **no**
  entran: un documento recuperado no puede dirigir la decision.

  ## Que puede hacer

  Poco. Su salida se **intersecta** con el conjunto elegible (control M1):
  no puede anadir candidatos ni levantar vetos. Una etiqueta desconocida, una
  ruta `other` o una confianza baja son una **abstension** (control M4): la
  decision sigue con el fallback y nunca se adivina.

  ## Ejemplos

      iex> Gunther.Router.Llm.rank([], [], nil, %{})
      {:skip, :no_spec, []}
  """

  alias Gunther.Decision.Parse
  alias Gunther.Decision.Prompt
  alias Gunther.DecisionSpec
  alias Gunther.DecisionView
  alias Gunther.Router.Llm.Bulkhead

  # Caracteres por token para el truncado. Es una aproximacion: lo que se
  # trunca es un **limite** de seguridad, y truncar de mas es el lado
  # prudente.
  @chars_per_token 4

  @type outcome ::
          {:ok, [atom()], map()}
          | {:skip, atom(), [atom()]}

  @doc """
  Decide con el modelo de decision.

  Devuelve el ranking y la informacion de la decision (el modelo que opinó
  y el hash de lo que vio), o un `skip` con el motivo y los avisos.

  ## Ejemplos

      iex> Gunther.Router.Llm.rank([], [], nil, %{})
      {:skip, :no_spec, []}
  """
  @spec rank([map()], [map()], DecisionSpec.t() | nil, keyword()) :: outcome()
  def rank(candidates, messages, spec, opts) do
    case state(spec, opts) do
      {:skip, reason, degraded} ->
        {:skip, reason, degraded}

      :ok ->
        decide_with_model(candidates, messages, spec, opts)
    end
  end

  defp decide_with_model(candidates, messages, spec, opts) do
    view = view(messages, spec)
    prompt = Prompt.render(spec.prompt, spec, view)

    case call(prompt, spec, opts) do
      {:ok, content} -> parse_and_resolve(candidates, spec, content, view)
      {:error, :timeout} -> {:skip, :timeout, [:llm_timeout]}
      {:error, reason} -> {:skip, reason, [:classifier_error]}
    end
  end

  defp parse_and_resolve(candidates, spec, content, view) do
    case Parse.parse(spec.parse, spec, content) do
      {:ok, route} -> resolve(candidates, spec, route, view)
      {:error, reason} -> {:skip, reason, []}
    end
  end

  @doc """
  La informacion de la decision: el modelo que opinó y el hash de lo que
  vio (control M6).

  ## Ejemplos

      iex> Gunther.Router.Llm.info(%Gunther.DecisionSpec{id: :r, kind: :general_llm, model: :m}, "abc")
      %{id: :r, kind: :general_llm, report_id: nil, decision_input_sha256: "abc"}
  """
  @spec info(DecisionSpec.t(), binary()) :: map()
  def info(%DecisionSpec{} = spec, source_hash) do
    %{id: spec.id, kind: spec.kind, report_id: spec.report_id, decision_input_sha256: source_hash}
  end

  # El estado de la capa: sin spec no hay capa; sin verificar no acts.
  defp state(nil, _opts), do: {:skip, :no_spec, []}

  defp state(%DecisionSpec{} = spec, opts) do
    if DecisionSpec.verified?(spec) or Keyword.get(opts, :allow_unverified, false) do
      :ok
    else
      {:skip, :unverified, [:classifier_unverified]}
    end
  end

  # La vista de decision: lo unico que ve el decisor (M2).
  defp view(messages, %DecisionSpec{} = spec) do
    view = DecisionView.from_messages(messages, spec.context_roles)
    truncate(view, spec.max_input_tokens)
  end

  defp truncate(%DecisionView{} = view, max_tokens) do
    limit = max_tokens * @chars_per_token

    if String.length(view.text) <= limit do
      view
    else
      DecisionView.new(%{
        text: String.slice(view.text, 0, limit),
        roles: view.roles,
        truncated: true
      })
    end
  end

  # La llamada al modelo de decision, con el timeout y el bulkhead (M7).
  defp call(prompt, %DecisionSpec{} = spec, opts) do
    provider = Keyword.get(opts, :provider)
    model_id = Keyword.get(opts, :model_id) || spec.model
    timeout = Keyword.get(opts, :timeout_ms, 1_500)
    limit = spec.max_concurrency

    extra = if Keyword.has_key?(opts, :mock), do: [mock: Keyword.get(opts, :mock)], else: []

    with :ok <- Bulkhead.acquire(spec.id, limit, timeout),
         {:ok, result} <- invoke(provider, prompt, model_id, spec, timeout, extra) do
      Bulkhead.release(spec.id)
      content = Map.get(result, :content, "")

      if is_binary(content) do
        {:ok, content}
      else
        {:error, :invalid_output}
      end
    else
      {:error, :busy} -> {:error, :busy}
      {:error, reason} -> {:error, reason}
    end
  end

  defp invoke(nil, _prompt, _model_id, _spec, _timeout, _extra), do: {:error, :no_provider}

  defp invoke(provider, prompt, model_id, spec, timeout, extra) do
    task =
      Task.async(fn ->
        provider.chat(
          [%{role: :user, content: prompt}],
          Keyword.merge(
            [
              model_id: model_id,
              max_tokens: spec.max_output_tokens,
              temperature: spec.temperature,
              seed: spec.seed,
              timeout: timeout
            ],
            extra
          )
        )
      end)

    case Task.yield(task, timeout) do
      {:ok, result} ->
        Task.shutdown(task, :brutal_kill)
        result

      nil ->
        Task.shutdown(task, :brutal_kill)
        {:error, :timeout}

      {:exit, reason} ->
        {:error, reason}
    end
  end

  # La salida del decisor se intersecta con el conjunto elegible (M1).
  defp resolve(candidates, %DecisionSpec{} = spec, route, view) do
    case route_name(spec, route) do
      nil ->
        # Etiqueta desconocida: se ignora y se abstiene (M1, M4).
        {:skip, :invalid_output, []}

      :other ->
        # La ruta "other" sin destino: abstension (M4).
        {:skip, :abstain, []}

      name ->
        models = spec.routes[name].models
        eligible = Enum.filter(candidates, &(&1.alias in models))
        rest = Enum.reject(candidates, &(&1.alias in models))

        case eligible do
          [] ->
            # La ruta apunta a modelos que no son elegibles: abstension (M4).
            {:skip, :abstain, []}

          _eligible ->
            ranking = Enum.map(eligible ++ rest, & &1.alias)
            {:ok, ranking, info(spec, view.source_hash)}
        end
    end
  end

  # El nombre de la ruta. Se busca por su texto entre las rutas declaradas:
  # lo que dice el modelo **no crea atomos nuevos**, y una etiqueta que no
  # existe es una etiqueta desconocida (M1).
  #
  # El route es siempre una cadena: lo garantiza el contrato de `parse/3`.
  defp route_name(%DecisionSpec{} = spec, route) when is_binary(route) do
    if route == "other", do: other_route(spec), else: named_route(spec, route)
  end

  # La ruta con ese nombre, si la hay.
  defp named_route(spec, route) do
    Enum.find_value(spec.routes, fn {name, _route} ->
      if Atom.to_string(name) == route, do: name
    end)
  end

  # La ruta "other": o se abstiene, o apunta a otra ruta declarada.
  defp other_route(%DecisionSpec{other: :abstain}), do: :other

  defp other_route(%DecisionSpec{other: name} = spec) do
    if Map.has_key?(spec.routes, name), do: name, else: :other
  end
end
