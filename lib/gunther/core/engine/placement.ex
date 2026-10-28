defmodule Gunther.Engine.Placement do
  @moduledoc """
  El semaforo de colocacion: **un proceso por nodo** (SPEC §11.4).

  ## Que serializa y por que

  El arranque de un engine en un nodo hace `resync` (re-medir la memoria
  libre) y despues `reserve` (tomar la memoria). Si dos arranques
  concurrentes miden a la vez, los dos ven la misma memoria libre y ambos
  reservan: la suma reservada pasa de la que hay. El semaforo serializa esas
  dos operaciones **por nodo**.

  Un nodo ocupado **no bloquea a los demas**: hay un proceso por nodo, no un
  semaforo global.

  ## No usa `:global.trans/3`

  Gunther es un solo controlador por instancia (§11.4): un `GenServer` por
  nodo basta. La logica entre varios controladores sobre un mismo nodo la
  resuelve la autoridad del ledger del nodo (§18.5), no este semaforo.

  ## El turno

  El turno se concede al proceso que lo pide, y **lo ejecuta en su propio
  proceso**: si ese proceso muere con el turno tomado, el semaforo lo libera
  (lo detecta con un monitor) y el siguiente entra. Si el que **espera** en la
  cola muere, su peticion se descarta: no se ejecuta nunca.

  ## Ejemplos

      iex> Gunther.Engine.Placement.with_node("nodo", fn -> :hecho end)
      {:ok, :hecho}
  """

  @behaviour GenServer

  alias Gunther.Error

  @registry Gunther.Engine.Placement.Registry

  @type node_name :: String.t() | atom()

  @type result :: term()

  @doc """
  Ejecuta `fun` bajo el semaforo del nodo.

  ## Opciones

    * `:timeout_ms` — el tiempo maximo para **conseguir el turno** (por
      defecto 30_000). El turno se pide antes de ejecutar `fun`; si no llega,
      el resultado es `{:error, %Error{code: :timeout}}`.

  ## Ejemplos

      iex> Gunther.Engine.Placement.with_node("nodo", fn -> :hecho end)
      {:ok, :hecho}
  """
  @spec with_node(node_name(), (-> result()), keyword()) :: {:ok, result()} | {:error, Error.t()}
  def with_node(node, fun, opts \\ []) when is_function(fun, 0) do
    timeout = Keyword.get(opts, :timeout_ms, 30_000)

    with {:ok, pid} <- ensure(node),
         :ok <- acquire(pid, timeout) do
      try do
        {:ok, fun.()}
      after
        release(pid)
      end
    end
  end

  @doc """
  Libera el turno del nodo.

  Se llama solo al terminar `with_node/3` (con un `after`). Es publica para
  el caso de que el turno se haya tomado a mano.
  """
  @spec release(pid()) :: :ok
  def release(pid) when is_pid(pid) do
    GenServer.cast(pid, :release)
  end

  # --- el proceso del nodo ----------------------------------------------

  # El proceso del nodo, arrancado bajo demanda si no existe.
  defp ensure(node) do
    case Registry.lookup(@registry, node) do
      [{pid, _value}] ->
        {:ok, pid}

      [] ->
        case Gunther.Engine.Placement.Supervisor.start_child({__MODULE__, node}) do
          {:ok, pid} ->
            {:ok, pid}

          {:error, {:already_started, pid}} ->
            {:ok, pid}

          {:error, reason} ->
            {:error,
             Error.new(:internal_error, "no se puede arrancar el semaforo del nodo",
               details: %{node: node},
               cause: reason
             )}
        end
    end
  end

  # Pedir el turno. `GenServer.call/3` con timeout: si el turno no llega a
  # tiempo, el error es un valor.
  defp acquire(pid, timeout) do
    GenServer.call(pid, {:acquire, self()}, timeout)
  catch
    :exit, {:timeout, _call} ->
      {:error, Error.new(:timeout, "el turno de colocacion del nodo no llego a tiempo")}
  end

  # --- el proceso -------------------------------------------------------

  @doc false
  @spec child_spec(node_name()) :: Supervisor.child_spec()
  def child_spec(node) do
    %{
      id: {__MODULE__, node},
      start: {__MODULE__, :start_link, [node]},
      type: :worker
    }
  end

  @doc false
  @spec start_link(node_name()) :: GenServer.on_start()
  def start_link(node) do
    GenServer.start_link(__MODULE__, node, name: via(node))
  end

  @doc false
  @spec via(node_name()) :: {:via, Registry, {module(), node_name()}}
  def via(node), do: {:via, Registry, {@registry, node}}

  @doc false
  @impl GenServer
  def init(node) do
    {:ok, %{node: node, holder: nil, monitor: nil, queue: :queue.new()}}
  end

  @doc false
  @impl GenServer
  def handle_call({:acquire, pid}, from, state) do
    cond do
      state.holder == nil ->
        {:reply, :ok, take(state, pid)}

      state.holder == pid ->
        # El mismo proceso pide dos veces: no se le da un segundo turno, pero
        # no es un error (reentrante).
        {:reply, :ok, state}

      true ->
        # El turno esta ocupado: la peticion espera en la cola.
        {:noreply, %{state | queue: :queue.in({pid, from}, state.queue)}}
    end
  end

  @doc false
  @impl GenServer
  def handle_cast(:release, state) do
    {:noreply, advance(state)}
  end

  @doc false
  @impl GenServer
  def handle_info({:DOWN, ref, :process, pid, _reason}, state) do
    if state.monitor != nil and ref == state.monitor do
      # El titular del turno se ha ido: el turno se libera.
      {:noreply, advance(%{state | holder: nil, monitor: nil})}
    else
      # Era uno de los que esperaba: su peticion se descarta.
      {:noreply, %{state | queue: :queue.filter(&(elem(&1, 0) != pid), state.queue)}}
    end
  end

  def handle_info(_message, state), do: {:noreply, state}

  # --- internos ---------------------------------------------------------

  # El turno pasa al pid indicado.
  defp take(state, pid) do
    %{state | holder: pid, monitor: Process.monitor(pid)}
  end

  # Libera el turno y se lo da al siguiente de la cola, si sigue vivo.
  defp advance(state) do
    state = %{state | holder: nil, monitor: nil}

    case :queue.out(state.queue) do
      {{:value, {pid, from}}, queue} ->
        if Process.alive?(pid) do
          GenServer.reply(from, :ok)
          take(%{state | queue: queue}, pid)
        else
          advance(%{state | queue: queue})
        end

      {:empty, _queue} ->
        state
    end
  end
end
