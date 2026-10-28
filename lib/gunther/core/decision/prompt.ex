defmodule Gunther.Decision.Prompt do
  @moduledoc """
  La plantilla de la peticion al modelo de decision (SPEC §6.11).

  El prompt es **personalizable** (D-72): puede ser una plantilla incorporada
  (`{:builtin, :preference_router}`) o un modulo propio que implemente
  `render/2`. El codigo de Gunther **no contiene nombres de modelos**: lo que
  depende de un modelo concreto es configuracion del operador.

  ## La plantilla incorporada

  El **prefijo estatico va primero** (la descripcion de las rutas) y el texto
  del usuario **al final**. Asi el servidor puede reutilizar la cache de
  prompt: el prefijo no cambia entre peticiones y lo unico que va al final es
  lo que cambia.

  ## Ejemplos

      iex> spec = %Gunther.DecisionSpec{
      ...>   id: :r,
      ...>   kind: :preference_router,
      ...>   model: :m,
      ...>   routes: %{code: %{description: "Programacion", models: [:a]}}
      ...> }
      iex> view = Gunther.DecisionView.new(text: "arregla este bug", roles: [:user])
      iex> prompt = Gunther.Decision.Prompt.render({:builtin, :preference_router}, spec, view)
      iex> String.contains?(prompt, "arregla este bug")
      true
      iex> String.contains?(prompt, "Programacion")
      true
  """

  @doc """
  Renderiza el prompt de la peticion.

  ## Opciones

    * `:spec` — el `Gunther.DecisionSpec`
    * `:view` — el `Gunther.DecisionView` con lo que ve el decisor (M2)

  ## Ejemplos

      iex> prompt = Gunther.Decision.Prompt.render({:builtin, :preference_router}, nil, nil)
      iex> String.contains?(prompt, "(ninguna)")
      true
  """
  @spec render({:builtin, atom()} | {:module, module()}, map() | nil, map() | nil) :: binary()
  def render({:module, module}, spec, view) do
    module.render(spec, view)
  end

  def render({:builtin, :preference_router}, spec, view) do
    routes = routes_section(spec)
    text = if is_nil(view), do: "", else: Map.get(view, :text, "")

    """
    Eres un enrutador de modelos. Elige la ruta que mejor responde a la peticion.
    Responde solo con un objeto JSON con la clave "route" y el nombre de la ruta.

    Rutas:
    #{routes}

    Peticion:
    #{text}
    """
  end

  def render(_other, _spec, _view), do: ""

  # Las rutas, una por linea y en orden alfabetico: el prefijo tiene que ser
  # el mismo en todas las peticiones para que la cache de prompt sirva.
  defp routes_section(nil), do: "(ninguna)"

  defp routes_section(spec) do
    spec.routes
    |> Enum.sort_by(fn {name, _route} -> Atom.to_string(name) end)
    |> Enum.map_join("\n", fn {name, route} -> "- #{name}: #{Map.get(route, :description, "")}" end)
  end
end
