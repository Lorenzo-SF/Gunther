defmodule Gunther.Selector do
  @moduledoc """
  Reparto justo entre candidatos **ya elegibles** (SPEC §5.8, D-53, CE-09).

  Round-robin por defecto (D-15), con la prioridad como peso.

  ## Estado por consumer

  El `state` es **por consumer y por conjunto de candidatos**: la clave es
  `{consumer, sha256(candidatos ordenados)}`. Un consumer con mucho tráfico no
  desplaza el reparto de otro.

  Vive en `Selector.Server` (ETS con tope `selector.max_states` y LRU de
  `Gunther.Cache`).

  **No decide colocación en GPU**: eso es el Placer (§11.4).

  ## Ejemplos

      iex> Gunther.Selector.default_state()
      %{}
  """

  @callback next(candidates :: [atom()], state :: map()) :: {:ok, atom(), map()}

  @doc """
  El estado inicial del selector.

  ## Ejemplos

      iex> Gunther.Selector.default_state()
      %{}
  """
  @spec default_state() :: map()
  def default_state, do: %{}
end
