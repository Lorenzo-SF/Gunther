defmodule Gunther.Tokenizer do
  @moduledoc """
  Cuenta tokens de un texto o de unos mensajes (SPEC §5.11, §7.6, D-58).

  ## Orden de preferencia (§7.6)

  1. Contador exacto del provider.
  2. `Gunther.Tokenizer` registrado para ese modelo.
  3. Modo `approximate`: `tokens = ceil(caracteres / chars_per_token) × (1 + margin)`,
     con `chars_per_token` y `margin` **calibrados por modelo**.

  Sin calibración guardada, el modo `approximate` **no está disponible** para
  ese modelo.

  ## Ejemplos

      iex> Gunther.Tokenizer.approximate?()
      false
  """

  @callback count(text_or_messages :: binary() | [map()], model :: atom()) ::
              {:ok, non_neg_integer()} | {:error, term()}
  @callback approximate?() :: boolean()

  @doc """
  ¿El contador activo es aproximado?

  ## Ejemplos

      iex> Gunther.Tokenizer.approximate?()
      false
  """
  @spec approximate?() :: boolean()
  def approximate?, do: false

  @doc """
  Calcula el número de tokens en modo aproximado.

  ## Ejemplos

      iex> Gunther.Tokenizer.approximate_count("abcd", 4, 0.0)
      1
  """
  @spec approximate_count(binary(), pos_integer(), float()) :: non_neg_integer()
  def approximate_count(text, chars_per_token, margin) when chars_per_token > 0 do
    characters = String.length(text)
    base = ceil(characters / chars_per_token)
    ceil(base * (1 + margin))
  end
end
