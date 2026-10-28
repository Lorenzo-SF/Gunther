defmodule Gunther.Provider do
  @moduledoc """
  Un destino de inferencia (SPEC §5.1).

  ## Contrato

  `chat/2` y no `send/2`: definir `send/2` en un módulo obliga a
  `import Kernel, except: [send: 2]`.

  `opts` trae `:model_id`, `:tools`, `:tool_choice`, `:response_format`,
  `:temperature`, `:top_p`, `:max_tokens`, `:stop`, `:seed`, `:timeout` y
  `:cancelled?`. **`:messages` no se duplica** dentro de `opts`.

  ## Precedencia

  Lo declarado en `[[models]]` (skills, modalidades, precios) **gana** a lo
  que declare el provider.

  ## Soporte

  Un provider sin `stream/3` o `embed/2` devuelve `{:error, :not_supported}`;
  el motor ya lo filtró con `supports?/2`.

  ## Ejemplos

      iex> Gunther.Provider.supports?(:tools, :m)
      true
  """

  @type messages :: [map()]
  @type result :: %{
          content: binary(),
          reasoning: binary() | nil,
          tool_calls: [%{id: binary(), name: binary(), arguments: map()}] | nil,
          finish_reason: atom(),
          usage: map(),
          provider_request_id: binary() | nil,
          cost: map() | nil
        }

  @callback chat(messages(), opts :: keyword()) :: {:ok, result()} | {:error, term()}
  @callback stream(messages(), opts :: keyword(), on_chunk :: (map() -> any())) ::
              {:ok, result()} | {:error, term()}
  @callback embed([binary()], opts :: keyword()) :: {:ok, [[float()]]} | {:error, term()}
  @callback models() :: [atom()]
  @callback capabilities(model :: atom()) :: [atom()]
  @callback modalities(model :: atom()) :: [:text | :image | :audio | :video]
  @callback supports?(feature :: atom(), model :: atom()) :: boolean()
  @callback pricing(model :: atom()) ::
              %{
                input_per_mtok_micros: non_neg_integer(),
                output_per_mtok_micros: non_neg_integer()
              }
              | nil

  @optional_callbacks stream: 3, embed: 2

  @doc """
  ¿El provider soporta esta característica en este modelo?

  Los providers que no implementan `supports?/2` declaran soporte de
  herramientas, salida estructurada y streaming, que es lo mínimo razonable.

  ## Ejemplos

      iex> Gunther.Provider.supports?(:tools, :m)
      true
  """
  @spec supports?(atom(), atom()) :: boolean()
  def supports?(feature, _model) when feature in [:tools, :structured_output, :streaming] do
    true
  end

  def supports?(_feature, _model), do: false

  @doc """
  El coste de una llamada, en micro-dólares.

  Los precios se declaran por millón de tokens. El cálculo redondea
  **hacia arriba** a entero (SPEC §0.2).

  ## Ejemplos

      iex> pricing = %{input_per_mtok_micros: 1_000_000, output_per_mtok_micros: 2_000_000}
      iex> Gunther.Provider.cost_micros(1000, 500, pricing)
      2000
  """
  @spec cost_micros(non_neg_integer(), non_neg_integer(), map() | nil) :: non_neg_integer()
  def cost_micros(input_tokens, output_tokens, pricing) when is_map(pricing) do
    input_micros = div_ceil(input_tokens * pricing.input_per_mtok_micros, 1_000_000)
    output_micros = div_ceil(output_tokens * pricing.output_per_mtok_micros, 1_000_000)
    input_micros + output_micros
  end

  def cost_micros(_input_tokens, _output_tokens, _pricing), do: 0

  defp div_ceil(dividend, divisor) do
    div(dividend + divisor - 1, divisor)
  end
end
