defmodule Gunther.Provider.ContractTest do
  # El ContractTest se aplica al mock: si el mock se desvía del contrato,
  # todas las pruebas del motor que lo usan mienten.
  use ExUnit.Case, async: true
  use Gunther.ContractTest, behaviour: Gunther.Provider, module: Gunther.Provider.Mock
end
