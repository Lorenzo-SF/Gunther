defmodule Gunther.Command.Spawner do
  @moduledoc """
  El contrato de lanzamiento de procesos largos (SPEC §3.4, D-70, CE-20).

  ## Requisitos

  | Req. | Requisito                                              | Obligatorio |
  | ---- | ------------------------------------------------------ | ----------- |
  | R1   | Sin shell intermedio                                   | Sí          |
  | R2   | `env` explícito: no hereda el entorno de la VM         | Sí          |
  | R3   | Directorio de trabajo (`cd`)                           | Sí          |
  | R4   | `stdout` y `stderr` separados                          | No          |
  | R5   | El hijo muere si muere la VM                           | No          |
  | R6   | `os_pid` disponible para señales                       | Sí          |
  | R7   | Código de salida entregado al propietario              | Sí          |
  | R8   | Contrapresión (lectura bajo demanda, `active: :once`)  | Sí          |

  ## Línea base

  `Port.open({:spawn_executable, ruta}, args:, env:, cd:, ...)` con `:binary`,
  `:exit_status`, `:use_stdio` y `{:line, n}` o `:stream`.

  Un `Port` de Erlang ofrece `:stderr_to_stdout` y **no** un canal separado
  para `stderr` (R4). Consecuencias normativas:

  | Proceso            | `stderr`                                            | Framing                                                     |
  | ------------------ | --------------------------------------------------- | ------------------------------------------------------------ |
  | `llama-server`     | `:merge` (con `stdout`)                             | `{:line, 8192}` a un anillo de las últimas `engine.log_lines` líneas |
  | Servidor MCP stdio | `:inherit` (no se mezcla con `stdout`)             | `{:line, 65536}` con reensamblado de `{:noeol, fragmento}`    |

  Mezclar `stderr` en `stdout` corrompería el JSON-RPC del MCP.

  ## Ejemplos

      iex> Gunther.Command.Spawner.stderr_mode(:llama_server)
      :merge
  """

  alias Gunther.Error

  @doc """
  El modo de `stderr` de un proceso concreto.

  ## Ejemplos

      iex> Gunther.Command.Spawner.stderr_mode(:llama_server)
      :merge

      iex> Gunther.Command.Spawner.stderr_mode(:mcp_stdio)
      :inherit
  """
  @spec stderr_mode(:llama_server | :mcp_stdio) :: :merge | :inherit
  def stderr_mode(:llama_server), do: :merge
  def stderr_mode(:mcp_stdio), do: :inherit

  @doc """
  Abre un proceso largo sin shell.

  ## Opciones

    * `:env` — el entorno completo del proceso (R2)
    * `:cd` — directorio de trabajo (R3)
    * `:stderr` — `:merge` o `:inherit`
    * `:line` — tamaño del búfer de línea
    * `:args` — los argumentos (ya validados por `AllowList`)

  ## Ejemplos

      iex> {:error, error} = Gunther.Command.Spawner.spawn(
      ...>   %{realpath: "/no/existe", path: "/no/existe", name: "x", sha256: nil, inode: nil},
      ...>   [],
      ...>   []
      ...> )
      iex> error.code
      :command_blocked
  """
  @spec spawn(map(), [String.t()], keyword()) :: {:ok, port()} | {:error, Error.t()}
  def spawn(entry, args, opts) do
    stderr = Keyword.get(opts, :stderr, :merge)
    line = Keyword.get(opts, :line, 8192)
    env = Keyword.get(opts, :env, [])
    cd = Keyword.get(opts, :cd)

    # `Port.open/2` no acepta `stderr: :inherit` ni `stderr_to_stdout: true`
    # como opciones sueltas: la unica forma de que `stderr` vaya aparte de
    # `stdout` es NO usar `:use_stdio` para el hijo y dejar que el proceso
    # herede el `stderr` de la VM (que es lo que hace `:inherit`).
    #
    # Con `:use_stdio`, el `stderr` del hijo se mezcla con `stdout` (`:merge`),
    # que es lo que necesita `llama-server` y lo que corromperia el JSON-RPC
    # del MCP si se usara ahi.
    # En una lista de Elixir, las keyword van SIEMPRE al final: por eso los
    # `args` (que es una keyword) se anteponen como lista normal.
    # `Port.open/2` y las opciones de `stderr`:
    #
    # - Con `:use_stdio`, el `stderr` del hijo **se mezcla** con su `stdout`
    #   (que es lo que necesita `llama-server`, cuya salud se mide por HTTP y
    #   cuyos logs solo sirven para diagnosticar un arranque fallido).
    # - Sin `:use_stdio`, el `stderr` del hijo va al `stderr` de la VM
    #   (`:inherit`), que es lo que necesita el MCP stdio: mezclar el
    #   `stderr` en el `stdout` corromperia el JSON-RPC.
    #
    # `stderr_to_stdout: true` **no** es combinable con `:use_stdio`: Erlang
    # lo rechaza con "argument error".
    #
    # `:use_stdio` es un ATOMO de la lista de opciones, no una keyword: por eso
    # se antepone con `++` y no con `Keyword.put/3`.
    port_options = [:binary, :exit_status, {:line, line}]

    port_options =
      if use_stdio?(stderr) do
        [:use_stdio | port_options]
      else
        port_options
      end

    port_options =
      port_options
      |> maybe_put(:cd, cd)
      |> maybe_put(:env, env)

    # Las keyword van SIEMPRE al final de la lista: por eso `args` se
    # concatena despues, no antes.
    port_options = port_options ++ [args: args]

    try do
      {:ok, Port.open({:spawn_executable, entry.realpath}, port_options)}
    rescue
      error ->
        {:error,
         Error.new(:command_blocked, "no se puede arrancar el proceso: #{entry.realpath}",
           details: %{path: entry.realpath},
           cause: error
         )}
    end
  end

  defp use_stdio?(:inherit), do: false
  defp use_stdio?(_mode), do: true

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, _key, []), do: opts
  defp maybe_put(opts, _key, false), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)

  @doc """
  Reensambla los fragmentos `:noeol` en mensajes completos (CE-20).

  Un `Port` con `{:line, n}` entrega `{:noeol, fragmento}` cuando el mensaje
  es mas largo que el búfer, y `{:eol, mensaje}` cuando acaba en newline.
  Sin reensamblado, el receptor ve trozos y el JSON-RPC se rompe.

  ## Ejemplos

      iex> Gunther.Command.Spawner.reassemble([{:noeol, "a"}, {:noeol, "b"}, {:eol, "c"}], "")
      ["abc"]
  """
  @spec reassemble([tuple()], binary()) :: [binary()]
  def reassemble(messages, buffer \\ "") do
    {acc, buffer} =
      Enum.reduce(messages, {[], buffer}, fn
        {:eol, line}, {acc, buffer} ->
          {[buffer <> line | acc], ""}

        {:noeol, fragment}, {acc, buffer} ->
          {acc, buffer <> fragment}

        _other, {acc, buffer} ->
          {acc, buffer}
      end)

    Enum.reverse(acc) ++ if(buffer == "", do: [], else: [buffer])
  end
end
