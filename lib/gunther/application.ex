defmodule Gunther.Application do
  @moduledoc """
  La aplicación OTP de Gunther.

  Arranca `Gunther.Supervisor`, que es el árbol de §2.3. `Gunther.Gateway` y
  `Gunther.MCP.Server` **no** están en el árbol (D-31): los arranca la
  aplicación del usuario. El agente de nodo (`Gunther.Node.Agent`) tampoco: es
  una aplicación aparte que corre en el otro PC (§18.2).
  """

  use Application

  @impl Application
  def start(_type, _args) do
    children = [
      Gunther.Supervisor
    ]

    # Sin `name:` aqui: el nombre lo pone el child_spec de `Gunther.Supervisor`.
    # Si lo pusieramos en los dos sitios, el supervisor intentaria registrar
    # dos veces el mismo nombre y arrancaria con "already started".
    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
