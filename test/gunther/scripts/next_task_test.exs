defmodule Gunther.Scripts.NextTaskSelftestTest do
  @moduledoc """
  La cola de trabajo del coder tiene que estar **derivada del
  repositorio**, no escrita a mano.

  Una lista de tareas escrita a mano se pudre en silencio: nadie la
  actualiza, el modelo trabaja sobre una lista que ya no describe el
  repositorio, y el síntoma sale cuando el trabajo ya está hecho mal.

  `scripts/next_task_selftest.sh` comprueba la derivación con dobles,
  ejecutando el `scripts/next_task.sh` real contra un repositorio de
  mentira: sin nota de fase la tarea es escribir la nota; con nota, la
  tarea es el primer WP con AC sin cumplir; un WP en verde se salta; uno
  con la dependencia sin cumplir se salta; con todo en verde no queda
  tarea; y una nota con una fila que no se reconoce hace fallar el script
  en vez de inventarse el estado.

  Un checker con OK falso es peor que no tener checker: por eso el
  selftest corre el script de verdad y no una copia de su lógica.
  """

  use ExUnit.Case, async: false

  @selftest Path.expand("../../../scripts/next_task_selftest.sh", __DIR__)

  test "la cola se deriva del repositorio y no de una lista escrita a mano" do
    {out, rc} = System.cmd("bash", [@selftest], stderr_to_stdout: true)

    assert rc == 0, """
    la autocomprobacion de scripts/next_task.sh fallo:

    #{out}
    """
  end
end
