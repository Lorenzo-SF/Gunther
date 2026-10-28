defmodule Gunther.Decision.Parse do
  @moduledoc """
  El interprete de la salida del modelo de decision (SPEC §6.11).

  Tambien es personalizable (D-72): `{:builtin, :json_route}` o un modulo
  propio que implemente `parse/2`.

  ## La salida incorporada

  `{"route": "nombre"}`. Un JSON que no sea eso, o un JSON invalido, es una
  **abstension** (control M4): nunca se adivina.

  ## Ejemplos

      iex> Gunther.Decision.Parse.parse({:builtin, :json_route}, ~s({"route": "code"}))
      {:ok, "code"}

      iex> Gunther.Decision.Parse.parse({:builtin, :json_route}, "no es json")
      {:error, :invalid_output}
  """

  @doc """
  Interpreta la salida del modelo de decision.

  ## Ejemplos

      iex> Gunther.Decision.Parse.parse({:builtin, :json_route}, ~s({"route": "code"}))
      {:ok, "code"}
  """
  @spec parse({:builtin, atom()} | {:module, module()}, map() | nil, binary()) ::
          {:ok, binary()} | {:error, term()}
  def parse({:module, module}, spec, content), do: module.parse(spec, content)

  def parse({:builtin, :json_route}, _spec, content) when is_binary(content) do
    case Jason.decode(content) do
      {:ok, %{"route" => route}} when is_binary(route) -> {:ok, route}
      {:ok, _other} -> {:error, :invalid_output}
      {:error, _reason} -> {:error, :invalid_output}
    end
  end

  def parse(_other, _spec, _content), do: {:error, :invalid_output}
end
