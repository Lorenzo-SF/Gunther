defmodule Gunther.ContractTest do
  @moduledoc """
  El test de contrato (SPEC §5.14).

  `use Gunther.ContractTest, behaviour: B, module: M` genera los tests que
  comprueban que `M` cumple el contrato de `B`:

    1. **La forma del retorno** segun el `@callback`.
    2. **La robustez**: una entrada mala devuelve `{:error, _}`, no lanza.
    3. **El determinismo** donde aplique.
    4. **La cancelacion**: un provider lento aborta al cancelar.

  ## Uso

      defmodule MiProviderTest do
        use ExUnit.Case, async: true
        use Gunther.ContractTest, behaviour: Gunther.Provider, module: MiProvider
      end

  ## Lo que el test supone

  El modulo bajo prueba se llama con una peticion de mentira, sin modelo
  real. Un provider de verdad recibe `opts` con `:model_id`; aqui se le da
  el que el modulo declare, o `:mock` si no declara ninguno.

  Las comprobaciones que no aplican al behaviour se saltan: un modulo sin
  `stream/3` no se prueba con `stream/3`.
  """

  @doc """
  Genera los tests de contrato.
  """
  defmacro __using__(opts) do
    behaviour = Keyword.fetch!(opts, :behaviour)
    module = Keyword.fetch!(opts, :module)

    quote do
      use ExUnit.Case, async: true

      @moduletag :contract
      @moduletag unquote(behaviour)

      describe "contrato de #{unquote(inspect(behaviour))}" do
        test "el modulo declara el comportamiento" do
          behaviours =
            unquote(module).module_info(:attributes)
            |> Keyword.get_values(:behaviour)
            |> List.flatten()

          assert unquote(behaviour) in behaviours
        end

        test "la forma del retorno es la que dice el callback" do
          for {callback, check} <- Gunther.ContractTest.checks(unquote(behaviour)) do
            assert_shape(unquote(module), callback, check)
          end
        end

        test "una entrada mala devuelve un error y no lanza" do
          for {callback, check} <- Gunther.ContractTest.checks(unquote(behaviour)) do
            assert_bad_input(unquote(module), callback, check)
          end
        end

        test "la misma peticion da la misma respuesta" do
          for {callback, check} <- Gunther.ContractTest.checks(unquote(behaviour)) do
            assert_deterministic(unquote(module), callback, check)
          end
        end

        test "la cancelacion aborta la llamada" do
          for {callback, check} <- Gunther.ContractTest.checks(unquote(behaviour)) do
            assert_cancellable(unquote(module), callback, check)
          end
        end
      end

      defp assert_shape(module, callback, check) do
        if function_exported?(module, callback, check.arity) do
          assert {:ok, value} = check.call.(module, check.args)

          for key <- check.shape do
            assert Map.has_key?(value, key),
                   "el resultado no tiene la clave #{inspect(key)}"
          end
        end
      end

      defp assert_bad_input(module, callback, check) do
        if function_exported?(module, callback, check.arity) do
          assert {:error, _reason} = check.bad.(module, check.args)
        end
      end

      defp assert_deterministic(module, callback, check) do
        if function_exported?(module, callback, check.arity) do
          assert check.call.(module, check.args) == check.call.(module, check.args)
        end
      end

      defp assert_cancellable(module, callback, check) do
        if function_exported?(module, callback, check.arity) and check.cancelable? do
          assert {:error, _reason} = check.cancelled.(module, check.args)
        end
      end
    end
  end

  @doc """
  Las comprobaciones de un behaviour.

  Cada una es un `{callback, %{arity:, args:, call:, bad:, cancelled:, cancelable?}}`.
  """
  @spec checks(module()) :: [{atom(), map()}]
  def checks(Gunther.Provider) do
    [
      {:chat,
       %{
         arity: 2,
         args: [[%{role: :user, content: "hola"}], [model_id: :mock]],
         call: fn module, args -> module.chat(hd(args), tl(args)) end,
         bad: fn module, args -> module.chat([], tl(args)) end,
         cancelled: fn module, args ->
           module.chat(hd(args), Keyword.put(tl(args), :cancelled?, fn -> true end))
         end,
         cancelable?: true,
         shape: [
           :content,
           :reasoning,
           :tool_calls,
           :finish_reason,
           :usage,
           :provider_request_id,
           :cost
         ]
       }},
      {:embed,
       %{
         arity: 2,
         args: [["hola"], [model_id: :mock]],
         call: fn module, args -> module.embed(hd(args), tl(args)) end,
         bad: fn module, args -> module.embed(:no_una_lista, tl(args)) end,
         cancelled: fn module, args ->
           module.embed(hd(args), Keyword.put(tl(args), :cancelled?, fn -> true end))
         end,
         cancelable?: true,
         shape: []
       }}
    ]
  end

  def checks(Gunther.Embedder) do
    [
      {:embed,
       %{
         arity: 2,
         args: [["hola"], []],
         call: fn module, args -> module.embed(hd(args), tl(args)) end,
         bad: fn module, args -> module.embed(:no_una_lista, tl(args)) end,
         cancelled: fn _module, _args -> {:error, :cancelled} end,
         cancelable?: false,
         shape: []
       }}
    ]
  end

  def checks(Gunther.Classifier) do
    [
      {:classify,
       %{
         arity: 3,
         args: [%{routes: %{a: %{description: "a", models: [:m]}}}, "hola", []],
         call: fn module, args -> module.classify(hd(args), Enum.at(args, 1), Enum.at(args, 2)) end,
         bad: fn module, args -> module.classify(:no_un_spec, Enum.at(args, 1), Enum.at(args, 2)) end,
         cancelled: fn _module, _args -> {:error, :cancelled} end,
         cancelable?: false,
         shape: []
       }}
    ]
  end

  def checks(_other), do: []
end
