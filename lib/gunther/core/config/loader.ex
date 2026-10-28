defmodule Gunther.Config.Loader do
  @moduledoc """
  Carga `gunther.toml` (SPEC §14, §3.6).

  Es el módulo de frontera que nombra `Apero.Conf` y `Apero.Env`. Ningún otro
  módulo del núcleo los nombra (SPEC §3.6).

  ## Secretos (SPEC §14.3)

  Las claves salen del entorno (`api_key_env`). Ninguna clave vive en el TOML.
  `.env` solo se carga si `gunther.dotenv = true` (defecto `false`, CE-17):
  una carga automática es una fuente de filtraciones silenciosas.
  """

  alias Gunther.Error

  @doc """
  Carga un fichero de configuración.

  Devuelve el mapa crudo (sin validar) o `{:error, %Gunther.Error{}}`.

  ## Ejemplos

      iex> Gunther.Config.Loader.load("/no/existe.toml")
      {:error, %Gunther.Error{code: :config_error, message: "no se puede leer el fichero de configuracion: /no/existe.toml", retryable?: false, retry_after_ms: nil, details: %{path: "/no/existe.toml"}, cause: nil}}
  """
  @spec load(Path.t()) :: {:ok, map()} | {:error, Error.t()}
  def load(path) do
    with {:ok, content} <- read(path),
         {:ok, parsed} <- parse(content, path) do
      case load_dotenv(parsed) do
        :ok -> {:ok, parsed}
        {:error, error} -> {:error, error}
      end
    end
  end

  defp read(path) do
    case File.read(path) do
      {:ok, content} ->
        {:ok, content}

      {:error, reason} ->
        {:error,
         Error.new(:config_error, "no se puede leer el fichero de configuracion: #{path}",
           details: %{path: path},
           cause: reason
         )}
    end
  end

  defp parse(content, path) do
    case Apero.Conf.load(path, content: content) do
      {:ok, parsed} when is_map(parsed) ->
        {:ok, parsed}

      {:error, reason} ->
        {:error,
         Error.new(:config_error, "no se puede interpretar la configuracion: #{path}",
           details: %{path: path},
           cause: reason
         )}
    end
  end

  # CE-17: `.env` solo si `gunther.dotenv = true`.
  defp load_dotenv(parsed) do
    dotenv = get_in(parsed, ["gunther", "dotenv"])

    if dotenv == true do
      case Apero.Env.load() do
        {:ok, _value} -> :ok
        {:error, reason} -> {:error, Error.new(:config_error, "no se puede cargar .env", cause: reason)}
      end
    else
      :ok
    end
  end

  @doc """
  Resuelve el valor de una clave de API desde el entorno.

  La variable sale de `api_key_env`. Si no está definida, es
  `config_error`: es mejor fallar al arrancar que en la primera petición.

  ## Ejemplos

      iex> Gunther.Config.Loader.fetch_api_key("GUNTHER_TEST_VAR_NO_EXISTE")
      {:error, %Gunther.Error{code: :config_error, message: "la variable de entorno GUNTHER_TEST_VAR_NO_EXISTE no esta definida", retryable?: false, retry_after_ms: nil, details: %{env_var: "GUNTHER_TEST_VAR_NO_EXISTE"}, cause: nil}}
  """
  @spec fetch_api_key(String.t()) :: {:ok, binary()} | {:error, Error.t()}
  def fetch_api_key(env_var) when is_binary(env_var) do
    case System.get_env(env_var) do
      nil ->
        {:error,
         Error.new(:config_error, "la variable de entorno #{env_var} no esta definida", details: %{env_var: env_var})}

      "" ->
        {:error, Error.new(:config_error, "la variable de entorno #{env_var} esta vacia", details: %{env_var: env_var})}

      value ->
        {:ok, value}
    end
  end
end
