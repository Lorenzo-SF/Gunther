defmodule Gunther.PromptTest do
  @moduledoc """
  El prompt del *coder* (`PROMPT.md`) es lo que le dice al modelo cómo se
  trabaja en este repositorio. Si le falta una pieza, el modelo deja de
  hacer algo: se salta una comprobacion, se salta el SPEC, se inventa el
  estado de una fase.

  Un prompt que se degrada en silencio es un check con OK falso, que es
  justamente lo que este repositorio condena. Por eso aqui se fija **que
  piezas tiene que tener** el prompt.

  Y hay un detalle que no es de estilo: el prompt **no debe llevar cifras
  del estado**. El estado vive en `docs/13-registro-de-fases.md`, que se lee
  cada vez. Una cifra dentro del prompt es una cifra que se queda vieja, y
  una cifra vieja es peor que ninguna: el modelo contesta con datos de un
  repo que ya no es este.
  """

  use ExUnit.Case, async: true

  @prompt Path.expand("../../PROMPT.md", __DIR__)

  setup_all do
    {:ok, prompt: File.read!(@prompt)}
  end

  describe "el prompt tiene que estar" do
    test "existe y no esta vacio" do
      assert File.exists?(@prompt)
      assert File.stat!(@prompt).size > 1000
    end
  end

  describe "las piezas obligatorias" do
    # Cada pieza con la razon por la que hace falta. Si una se cae, el
    # modelo deja de hacer algo concreto.
    @piezas [
      {"el SPEC vigente, que es la ley", "SPEC-000-GUNTHER_r9.md"},
      {"el mapa de la documentacion", "docs/13-registro-de-fases.md"},
      {"los ADR, que son el porque de cada decision", "docs/08-decisiones/"},
      {"el contrato corto del repositorio", "AGENTS.md"},
      {"el plan de fases", "docs/01-plan-de-desarrollo.md"},
      {"la estrategia de pruebas", "docs/03-estrategia-de-pruebas.md"},
      {"el ciclo de TDD, con el test primero", "ESTE PASO VA PRIMERO"},
      {"las nueve comprobaciones", "scripts/check_phase.sh"},
      {"la comprobacion de los AC uno a uno", "scripts/check_ac.sh"},
      {"Credo con --strict, que cuenta los avisos de verdad", "credo --strict"},
      {"el toolchain oficial", "1.19.5-otp-28"},
      {"la regla de una tarea por sesión", "Una tarea por sesión"},
      {"los errores como valores", "VALORES, nunca excepciones"},
      {"la unica puerta de ejecucion", "Gunther.Command"},
      {"la frontera con las hermanas", "Trebejo"},
      {"el staging explicito", "git diff --cached --name-only"},
      {"la fecha de los commits", "20:00"},
      {"los límites de decisión", "Lo que NO decides tú"},
      {"que no se cierre una fase sin el dueño", "cierre es del dueño"},
      {"que se mire la CI antes de darlo por bueno", "tiene que estar en verde"},
      {"la pregunta de fondo", "qué se hizo, por qué y cómo se comprueba"},
      {"la tarea, en imperativo, y de donde sale", "bash scripts/next_task.sh"},
      {"que el modelo NO elija la tarea", "No eliges la tarea: la lees"},
      {"el criterio de fin de la sesion", "criterio de fin"},
      {"que verificar NO es un entregable", "NO es un entregable"},
      {"el criterio de terminacion", "no ha producido nada"},
      {"que el SPEC no se lea entero", "No lo leas\nentero"},
      {"que los SPEC historicos se ahorren", "son **historicos**"}
    ]

    test "el prompt incluye todas las piezas obligatorias", %{prompt: prompt} do
      faltan =
        for {razon, texto} <- @piezas, not (prompt =~ texto), do: razon

      assert faltan == [],
             "al prompt le faltan estas piezas: #{inspect(faltan)}"
    end
  end

  describe "el prompt no debe llevar" do
    test "cifras del estado, que se quedan viejas", %{prompt: prompt} do
      # El estado vive en docs/13-registro-de-fases.md. Un numero de tests o
      # de doctests dentro del prompt es una promesa que el modelo no puede
      # cumplir.
      refute prompt =~ ~r/\d+ doctests/,
             "el prompt no debe llevar el numero de doctests: se lee del registro de fases"

      refute prompt =~ ~r/\d+ tests/,
             "el prompt no debe llevar el numero de tests: se lee del registro de fases"
    end

    test "una tarea fija, que se queda vieja", %{prompt: prompt} do
      # La tarea sale de `scripts/next_task.sh`, que la deriva del
      # repositorio. Si el prompt dijera "escribe docs/fases/F3.md", en
      # cuanto F3 estuviera cerrada el modelo seguiria intentando escribir
      # una nota que ya existe, y creeria que el trabajo estaba por hacer.
      refute prompt =~ "Escribe `docs/fases/F",
             "el prompt no fija la tarea: la cola la calcula scripts/next_task.sh"

      refute prompt =~ ~r/^\*\*Escribe /m,
             "el prompt no empieza por una tarea escrita a mano"
    end

    test "el numero de AC de una fase, que se queda viejo", %{prompt: prompt} do
      # "10 de sus 12 AC cumplidos" es una cifra que caduca en cuanto se
      # cumple uno mas.
      refute prompt =~ ~r/\d+ de (?:sus |los )?\d+ AC/,
             "el prompt no lleva el recuento de AC: se lee del registro y de check_ac.sh"
    end

    test "la estructura del repo, que ya esta en su documento", %{prompt: prompt} do
      # El prompt **apunta** al documento de estructura: es un puntero, no una
      # descripcion. Lo que no puede hacer es describir el arbol de ficheros,
      # que se queda viejo en cuanto se anade algo.
      assert prompt =~ "docs/05-estructura-del-repositorio.md",
             "el prompt tiene que apuntar al documento que describe la estructura"

      refute prompt =~ ~r/lib\/gunther\/[a-z_]+\.ex/,
             "el prompt no describe el arbol de ficheros: eso vive en su documento"
    end

    test "el numero de version de otra revision del SPEC", %{prompt: prompt} do
      # El SPEC vigente es el r9. Los historicos (r7 y r8) se nombran **una
      # vez y solo** para decir que no se lean: si aparecen en otra parte (el
      # mapa, el estado), el modelo puede trabajar contra el historico.
      for revision <- ["SPEC-000-GUNTHER_r8.md", "SPEC-000-GUNTHER_r7.md"] do
        menciones = length(String.split(prompt, revision)) - 1

        assert menciones == 1,
               "#{revision} aparece #{menciones} veces: solo puede aparecer en la frase que la descarta"
      end
    end
  end

  describe "el prompt no puede quedarse viejo" do
    test "no lleva el numero de lineas del SPEC si no es para advertir de su tamano", %{
      prompt: prompt
    } do
      # El tamano del SPEC SI puede estar: es lo que justifica "no lo leas
      # entero". Lo que no puede estar es el estado.
      assert prompt =~ "3271 lineas"
    end
  end

  describe "el prompt y la documentacion no se contradicen" do
    test "el prompt no dice que la CI no arranca", %{prompt: prompt} do
      # La CI funciona (el repositorio es publico y no consume minutos).
      # Si el prompt dijera lo contrario, el coder se autobloquea.
      refute prompt =~ "no arranca",
             "la CI funciona: el prompt no puede decir que no arranca"

      refute prompt =~ "minutos de Actions agotados",
             "la CI funciona: el prompt no puede decir que los minutos estan agotados"
    end

    test "el prompt no dice que no se puede mergear", %{prompt: prompt} do
      refute prompt =~ "no se mergea",
             "la CI verde permite mergear; lo que no se hace es cerrar la fase"
    end

    test "el prompt no trabaja encima de main", %{prompt: prompt} do
      # El proceso del repo (`docs/02-proceso-de-desarrollo.md` §1): `main`
      # esta siempre verde y el trabajo va en una rama `fNN/wp-nn-descripcion`.
      # Si el prompt dijera que la rama de trabajo es `main`, el modelo
      # trabajaria encima de la rama verde.
      refute prompt =~ "La rama de trabajo es **`main`**",
             "el trabajo va en una rama, no en main"

      assert prompt =~ "git checkout -b fNN/wp-nn-descripcion",
             "el prompt tiene que decir como se crea la rama de trabajo"
    end
  end
end
