defmodule Gunther.Scripts.CheckPhaseSelftestTest do
  @moduledoc """
  El checker de fases (`scripts/check_phase.sh`) tiene que **registrar** sus
  comprobaciones y salir en rojo cuando una falla.

  Un checker con OK falso es peor que no tener checker, y este lo fue. Tres
  comprobaciones usaban `return 1` dentro de un `eval`, y una usaba
  `exit 0`: un `return` o un `exit` dentro de un `eval` aborta la funcion
  que lo contiene, asi que la comprobacion **desaparecia del informe** en
  vez de marcarse FALLA, y el script salia con 0. Un verde falso con el
  informe a medias se lee como un verde.

  `scripts/check_phase_selftest.sh` comprueba el checker con dobles, sin
  correr la suite: que en verde salgan las diez comprobaciones, y que una
  en rojo aparezca marcada como FALLA con las otras nueve en verde y el
  script exiting con 1.
  """

  use ExUnit.Case, async: false

  @selftest Path.expand("../../../scripts/check_phase_selftest.sh", __DIR__)

  test "el checker de fases registra sus comprobaciones y falla cuando debe" do
    {out, rc} = System.cmd("bash", [@selftest], stderr_to_stdout: true)

    assert rc == 0, """
    la autocomprobacion de scripts/check_phase.sh fallo:

    #{out}
    """
  end
end
