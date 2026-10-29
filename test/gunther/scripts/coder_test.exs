defmodule Gunther.Scripts.CoderSelftestTest do
  @moduledoc """
  El bucle que relanza al coder tiene que distinguir **el trabajo** del
  **resumen**.

  El fallo que ya pasó es silencioso: con el prompt anterior, el Nemotron
  leyo el SPEC, corrio todas las comprobaciones y respondio con un resumen
  de ocho minutos. **Cero ficheros escritos.** El comando salia con 0 y
  todo parecia bien.

  Un bucle que no distingue esa situacion se gastaria la GPU en sesiones que
  no producen nada, una detras de otra, sin que nadie se entere. Asi que
  `scripts/coder.sh` mide el repositorio antes y despues de cada sesion, y
  **para** si no ha cambiado.

  `scripts/coder_selftest.sh` lo comprueba con dobles: el script real se
  ejecuta contra un repositorio de mentira y un doble de `mcode` que sabe
  trabajar y sabe resumir.
  """

  use ExUnit.Case, async: false

  @selftest Path.expand("../../../scripts/coder_selftest.sh", __DIR__)

  test "el bucle distingue el trabajo del resumen, y para cuando no hay trabajo" do
    {out, rc} = System.cmd("bash", [@selftest], stderr_to_stdout: true)

    assert rc == 0, """
    la autocomprobacion de scripts/coder.sh fallo:

    #{out}
    """
  end
end
