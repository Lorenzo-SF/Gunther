defmodule Gunther.Command.AllowList do
  @moduledoc """
  La lista de permitidos de ejecutables (SPEC §3.4, CE-18).

  Cada entrada es `{name, path, sha256?}`. Al arrancar se resuelve el `path`
  a `realpath`; si hay `sha256`, se compara con el hash del fichero y un
  desajuste es `config_error`.

  En cada `spawn` se vuelven a resolver y comparar el `realpath` y el **inodo**
  con los fijados. Un cambio **impide el lanzamiento** (`:command_blocked`):
  el binario que se ejecuta tiene que ser el binario que se autorizó, no uno
  que alguien haya sustituido entre medias.

  ## Ejemplos

      iex> Gunther.Command.AllowList.resolve("nada", allow: [])
      {:error, %Gunther.Error{code: :command_blocked, message: "el comando no esta en la lista de permitidos: nada", retryable?: false, retry_after_ms: nil, details: %{command: "nada"}, cause: nil}}
  """

  alias Gunther.Error

  @type entry :: %{name: String.t(), path: Path.t(), realpath: Path.t(), sha256: String.t() | nil, inode: term()}

  @doc """
  Resuelve un comando contra la lista de permitidos.

  Devuelve la entrada con su `realpath` y su `inode` ya comprobados.

  ## Ejemplos

      iex> {:error, error} = Gunther.Command.AllowList.resolve("nada", allow: [])
      iex> error.code
      :command_blocked
  """
  @spec resolve(String.t(), keyword()) :: {:ok, entry()} | {:error, Error.t()}
  def resolve(cmd, opts) do
    allow = Keyword.get(opts, :allow, [])

    case Enum.find(allow, &matches?(&1, cmd)) do
      nil ->
        {:error,
         Error.new(:command_blocked, "el comando no esta en la lista de permitidos: #{cmd}", details: %{command: cmd})}

      entry ->
        case normalize(entry) do
          nil ->
            {:error,
             Error.new(:command_blocked, "la entrada de la lista de permitidos no es valida", details: %{command: cmd})}

          normalized ->
            check(normalized)
        end
    end
  end

  # La forma canonica es el mapa `{name, path, sha256?}` (SPEC §3.4). Una
  # entrada que es una ruta se interpreta como nombre y ruta. Cualquier otra
  # cosa no se puede autorizar: bloquea, y no revienta.
  defp normalize(entry) when is_binary(entry) do
    %{name: entry, path: entry, sha256: nil}
  end

  defp normalize(entry) when is_map(entry) do
    %{
      name: entry[:name] || entry["name"],
      path: entry[:path] || entry["path"],
      sha256: entry[:sha256] || entry["sha256"]
    }
  end

  defp normalize(_entry), do: nil

  defp matches?(entry, cmd) do
    case normalize(entry) do
      %{name: name} -> is_binary(name) and name == cmd
      _other -> false
    end
  end

  defp check(entry) do
    path = entry[:path] || entry["path"]
    sha256 = entry[:sha256] || entry["sha256"]

    with {:ok, realpath} <- realpath(path),
         {:ok, inode} <- inode(realpath),
         :ok <- check_hash(realpath, sha256) do
      {:ok,
       %{
         name: entry[:name] || entry["name"],
         path: path,
         realpath: realpath,
         sha256: sha256,
         inode: inode
       }}
    end
  end

  defp realpath(nil) do
    {:error, Error.new(:command_blocked, "la entrada de la lista de permitidos no tiene ruta", details: %{path: nil})}
  end

  defp realpath(path) do
    # `File.stat/1` sigue los enlaces; `File.lstat/1` no. Para fijar la
    # identidad del binario hay que resolver el enlace hasta el fichero real:
    # si el enlace cambia de destino, el `realpath` cambia y el `spawn` se
    # bloquea.
    case File.stat(path) do
      {:ok, %File.Stat{type: :regular}} ->
        {:ok, resolve_link(path)}

      {:ok, %File.Stat{}} ->
        {:error, Error.new(:command_blocked, "el ejecutable no es un fichero regular: #{path}", details: %{path: path})}

      {:error, reason} ->
        {:error,
         Error.new(:command_blocked, "el ejecutable no existe o no se puede leer: #{path}",
           details: %{path: path},
           cause: reason
         )}
    end
  end

  # Si `path` es un enlace simbolico, se resuelve su destino. `File.read_link/1`
  # devuelve la ruta **tal cual esta escrita** en el enlace, que puede ser
  # relativa: se expande contra el directorio del propio enlace.
  defp resolve_link(path) do
    case File.read_link(path) do
      {:ok, target} ->
        Path.expand(target, Path.dirname(path))

      {:error, :einval} ->
        # No es un enlace: `path` es ya el fichero real.
        path

      {:error, reason} ->
        raise File.Error, reason: reason, action: "read link", path: path
    end
  end

  defp inode(realpath) do
    case File.stat(realpath) do
      {:ok, %File.Stat{inode: inode, major_device: device}} ->
        {:ok, {inode, device}}

      {:error, reason} ->
        {:error,
         Error.new(:command_blocked, "no se puede obtener el inodo de: #{realpath}",
           details: %{path: realpath},
           cause: reason
         )}
    end
  end

  defp check_hash(_realpath, nil), do: :ok

  defp check_hash(realpath, expected) do
    case File.read(realpath) do
      {:ok, content} ->
        actual = :sha256 |> :crypto.hash(content) |> Base.encode16(case: :lower)

        if actual == expected do
          :ok
        else
          {:error,
           Error.new(:config_error, "el sha256 del ejecutable no coincide con el declarado",
             details: %{path: realpath, expected: expected, actual: actual}
           )}
        end

      {:error, reason} ->
        {:error,
         Error.new(:command_blocked, "el ejecutable no se puede leer: #{realpath}",
           details: %{path: realpath},
           cause: reason
         )}
    end
  end

  @doc """
  Valida que los argumentos no bringnan la frontera de seguridad.

  Un argumento con un caracter nulo se rechaza antes de llegar al proceso.

  ## Ejemplos

      iex> Gunther.Command.AllowList.validate_args(["ok", "con espacio"])
      {:ok, ["ok", "con espacio"]}

      iex> {:error, error} = Gunther.Command.AllowList.validate_args(["con\\0nulo"])
      iex> error.code
      :command_blocked
  """
  @spec validate_args([String.t()]) :: {:ok, [String.t()]} | {:error, Error.t()}
  def validate_args(args) when is_list(args) do
    if Enum.all?(args, &(is_binary(&1) and not String.contains?(&1, <<0>>))) do
      {:ok, args}
    else
      {:error, Error.new(:command_blocked, "un argumento contiene un caracter nulo", details: %{args: args})}
    end
  end
end
