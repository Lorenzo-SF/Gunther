defmodule Gunther.Command do
  @moduledoc """
  La **única** puerta de ejecución de procesos (SPEC §3.4, §3.6).

  ## Dos modos, una sola puerta

  | Modo  | API                      | Mecanismo                                                                                                       |
  | ----- | ------------------------ | --------------------------------------------------------------------------------------------------------------- |
  | Corto | `run(cmd, args, opts)`   | `Trebejo.SafeCommand`, `/bin/sh`, timeout real                                                                  |
  | Largo | `spawn(cmd, args, opts)` | Valida con las mismas reglas; ejecutable de la **lista de permitidos**; abre el proceso **sin shell** (`Spawner`) |

  ## Lista de permitidos (CE-18)

  Cada entrada de `[commands].allow` es `{name, path, sha256?}`.

  - Al arrancar se resuelve `path` a `realpath`.
  - Si hay `sha256`, se compara con el hash del fichero; un desajuste es
    `config_error`.
  - En cada `spawn` se vuelven a resolver y comparar el `realpath` y el inodo
    con los fijados; un cambio **impide el lanzamiento** (`:command_blocked`).
  - Un ejecutable fuera de la lista no se lanza nunca.

  ## Por qué `SafeCommand` no es el único punto (D-50)

  1. Ejecuta a través de shell autodetectado y puede cargar ficheros de
     configuración del shell. `run/3` fuerza `/bin/sh`.
  2. Es una lista negra: defensa en profundidad, **no** frontera de seguridad.
     La frontera es que ningún dato del modelo ni del usuario llega nunca a un
     comando (§15) y que los argumentos se citan con quoting POSIX.
  3. Devuelve al terminar: no sirve de transporte duplex.
  4. Un `Port` cerrado no mata el proceso si este no vigila su stdin.

  ## Regla de código

  Ningún `System.cmd`, `:os.cmd` ni `Port.open` fuera de `Gunther.Command`
  (SPEC §3.4). Se comprueba con grep en CI.

  ## Ejemplos

      iex> Gunther.Command.quote("hola mundo")
      "'hola mundo'"
  """

  alias Gunther.Command.AllowList
  alias Gunther.Command.Spawner
  alias Gunther.Error

  @doc """
  Ejecuta un comando corto.

  ## Opciones

    * `:timeout_ms` — timeout real (por defecto 30 000)
    * `:cd` — directorio de trabajo
    * `:env` — variables de entorno adicionales
    * `:allow` — la lista de permitidos; sin ella, no se ejecuta nada

  ## Ejemplos

      iex> {:error, error} = Gunther.Command.run("echo", ["hola"], timeout_ms: 100)
      iex> error.code
      :command_blocked
  """
  @spec run(String.t(), [String.t()], keyword()) ::
          {:ok, %{stdout: binary(), stderr: binary(), exit_status: integer()}} | {:error, Error.t()}
  def run(cmd, args \\ [], opts \\ []) do
    with {:ok, entry} <- AllowList.resolve(cmd, opts),
         {:ok, args} <- AllowList.validate_args(args) do
      timeout = Keyword.get(opts, :timeout_ms, 30_000)

      # El comando corto se ejecuta con `/bin/sh` para no cargar la
      # configuracion del shell del usuario (G-06). El `stderr` se mezcla con
      # el `stdout`: `Port.open` no permite separarlos cuando se usa
      # `:use_stdio` (Erlang no acepta `stderr_to_stdout: true` junto a
      # `:use_stdio`), y el modo corto no necesita separarlos.
      port_options =
        [
          :binary,
          :exit_status,
          :use_stdio,
          {:line, 65_536}
        ]
        |> maybe_put(:cd, Keyword.get(opts, :cd))
        |> maybe_put(:env, Keyword.get(opts, :env))

      try do
        # Las keyword van SIEMPRE al final de la lista: por eso `args` se
        # concatena despues, no antes.
        port =
          Port.open(
            {:spawn_executable, "/bin/sh"},
            port_options ++ [args: [entry.realpath | args]]
          )

        {output, status} = collect(port, timeout)
        close_port(port)

        case status do
          0 ->
            {:ok, %{stdout: output, stderr: "", exit_status: status}}

          other ->
            {:error,
             Error.new(:command_failed, "el comando termino con codigo #{other}",
               details: %{exit_status: other, stdout: output}
             )}
        end
      rescue
        error ->
          {:error, Error.new(:command_failed, "el comando no se pudo ejecutar", cause: error)}
      catch
        :exit, {:timeout, _reason} ->
          {:error,
           Error.new(:timeout, "el comando supero el timeout de #{timeout} ms", details: %{timeout_ms: timeout})}
      end
    end
  end

  # Lee el port hasta que el proceso termina, con un plazo total.
  defp collect(port, timeout) do
    deadline = System.monotonic_time(:millisecond) + timeout
    collect(port, deadline, "")
  end

  defp collect(port, deadline, acc) do
    remaining = deadline - System.monotonic_time(:millisecond)

    if remaining <= 0 do
      exit({:timeout, :command})
    else
      receive do
        {^port, {:data, {:eol, line}}} -> collect(port, deadline, acc <> line)
        {^port, {:data, {:noeol, fragment}}} -> collect(port, deadline, acc <> fragment)
        {^port, {:data, {:eol, line, _rest}}} -> collect(port, deadline, acc <> line)
        {^port, {:exit_status, status}} -> {acc, status}
      after
        remaining -> exit({:timeout, :command})
      end
    end
  end

  # Cerrar un port cuyo proceso ya termino lanza `ArgumentError` ("argument
  # error"): no es un fallo del comando, es el port que ya no existe.
  defp close_port(port) do
    Port.close(port)
  rescue
    _other -> :ok
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, _key, []), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)

  @doc """
  Arranca un proceso largo, sin shell, con la lista de permitidos.

  ## Opciones

    * `:allow` — la lista de permitidos (obligatoria)
    * `:env` — el entorno; el proceso **no hereda** el de la VM salvo `env_allow`
    * `:env_allow` — variables del entorno de la VM que sí se heredan
    * `:cd` — directorio de trabajo
    * `:stderr` — `:merge` o `:inherit`
    * `:line` — tamaño del búfer de línea

  ## Ejemplos

      iex> {:error, error} = Gunther.Command.spawn("no-permitido", [], allow: [])
      iex> error.code
      :command_blocked
  """
  @spec spawn(String.t(), [String.t()], keyword()) :: {:ok, port()} | {:error, Error.t()}
  def spawn(cmd, args \\ [], opts \\ []) do
    with {:ok, entry} <- AllowList.resolve(cmd, opts),
         {:ok, args} <- AllowList.validate_args(args) do
      Spawner.spawn(entry, args, opts)
    end
  end

  @doc """
  Cita un argumento con quoting POSIX.

  ## Ejemplos

      iex> Gunther.Command.quote("hola mundo")
      "'hola mundo'"

      iex> Gunther.Command.quote("simple")
      "'simple'"
  """
  @spec quote(String.t()) :: String.t()
  def quote(arg) when is_binary(arg) do
    "'" <> String.replace(arg, "'", "'\\''") <> "'"
  end
end
