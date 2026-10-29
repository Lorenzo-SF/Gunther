defmodule Gunther.Scripts.IdentificadoresTest do
  @moduledoc """
  Los identificadores del repositorio viven en dos espacios de nombres que
  antes se parecian: el WP del plan (`F3-01`) y el AC de la nota (`F3-1`).
  Un modelo que los confundia cerraba el AC equivocado y declaraba un WP
  terminado sin haberlo hecho.

  Ahora las formas son distintas y **distintas de verdad**:

    * WP: `Fnn-nn`, dos digitos (`F3-04`). El SPEC §19.2 los cita, asi que no
      se renombran.
    * AC: `Fnn-ACn`, con el infijo `AC` (`F3-AC7`).

  Este test fija esa distincion en los tres sitios donde vive: el plan, las
  notas de fase y la biblioteca que las parsea.
  """

  use ExUnit.Case, async: true

  @raiz Path.expand("../../..", __DIR__)
  @plan Path.join(@raiz, "docs/01-plan-de-desarrollo.md")
  @notas Path.join(@raiz, "docs/fases")

  @wp ~r/^F\d+-\d\d$/
  @ac ~r/^F\d+-AC\d+[a-z]?$/

  describe "el plan" do
    test "los WP del plan tienen dos digitos, sin infijo" do
      filas = filas_de_tabla(File.read!(@plan), "| F", 3)

      refute filas == [],
             "el plan tiene que tener filas de WP: si no, la cola no tiene de donde sacar"

      refute Enum.any?(filas, &(&1 =~ ~r/-AC/)),
             "un WP del plan no lleva el infijo AC: ese es de los AC de las notas"
    end

    test "los WP del plan que cita el SPEC siguen existiendo" do
      # El SPEC §19.2 nombra `F1-01`, `F4-03` y `F4-04`. Son los WP del
      # plan. Si el plan los renombra, el SPEC queda con referencias
      # colgando, y el SPEC es la ley.
      spec = Path.join(@raiz, "SPEC-000-GUNTHER_r9.md")
      texto = File.read!(spec)

      citados =
        texto
        |> String.split("\n")
        |> Enum.filter(&(&1 =~ ~r/\*\*F\d+-\d+\*\*/))
        |> Enum.map(fn linea ->
          case Regex.run(~r/\*\*(F\d+-\d+)\*\*/, linea) do
            [_todo, id] -> id
            _otro -> nil
          end
        end)
        |> Enum.reject(&is_nil/1)
        |> Enum.uniq()

      refute citados == [],
             "el SPEC §19.2 deberia citar AC de r8 con identificador Fnn-nn"

      for id <- citados do
        assert File.read!(@plan) =~ "| #{id} |",
               "el SPEC cita el WP #{id} y el plan ya no lo tiene: la referencia queda colgando"
      end
    end
  end

  describe "las notas de fase" do
    test "cada AC lleva el infijo AC y cada WP dos digitos" do
      notas = Path.wildcard(Path.join(@notas, "F*.md"))

      refute notas == [], "hay notas de fase"

      for nota <- notas do
        texto = File.read!(nota)

        # Cada fila dice que es lo que es: una fila de tres celdas es un
        # WP y su identificador tiene que ser de WP; una de cuatro es un
        # AC y su identificador tiene que ser de AC. Un AC con forma de
        # WP es el fallo que este test existe para cazar.
        for {celdas, id} <- filas_con_identificador(texto) do
          case celdas do
            3 ->
              assert id =~ @wp,
                     "en #{nota}, la fila de WP #{inspect(id)} no tiene forma de WP (Fnn-nn)"

            4 ->
              assert id =~ @ac,
                     "en #{nota}, la fila de AC #{inspect(id)} no tiene forma de AC (Fnn-ACn)"

            otros ->
              flunk("en #{nota}, una fila con identificador #{inspect(id)} tiene #{otros} celdas")
          end
        end
      end
    end

    test "ninguna nota repite un identificador entre las dos tablas" do
      # Un AC y un WP con el mismo nombre es exactamente el fallo que se
      # quiere evitar. Con las formas distintas no puede pasar, y este test
      # lo vigila por si alguien vuelve a copiar un id.
      for nota <- Path.wildcard(Path.join(@notas, "F*.md")) do
        texto = File.read!(nota)

        wps =
          texto
          |> filas_de_tabla("| F", 3)
          |> Enum.map(&primera_celda/1)
          |> Enum.filter(&(&1 =~ ~r/^F\d+-/))

        acs =
          texto
          |> filas_de_tabla("| F", 4)
          |> Enum.map(&primera_celda/1)
          |> Enum.filter(&(&1 =~ ~r/^F\d+-/))

        comunes = Enum.filter(wps, &(&1 in acs))

        assert comunes == [],
               "en #{nota} estos identificadores salen en las dos tablas: #{inspect(comunes)}"
      end
    end
  end

  describe "la biblioteca que parsea las notas" do
    test "nota_es_id y nota_es_id_wp no aceptan el mismo identificador" do
      # Se ejecutan los scripts de verdad: una copia de su logica se queda
      # vieja, y el test acabaria comprobando algo que ya no existe.
      script = Path.join(@raiz, "scripts/lib_nota.sh")

      for id <- ["F3-01", "F3-AC1", "F3-AC4", "F1-AC7a"] do
        es_ac = funcion_de_la_nota(script, "nota_es_id", id)
        es_wp = funcion_de_la_nota(script, "nota_es_id_wp", id)

        refute es_ac and es_wp,
               "#{id} es AC y WP a la vez: los dos espacios de nombres tienen que ser disjuntos"
      end

      assert funcion_de_la_nota(script, "nota_es_id", "F3-AC1"),
             "F3-AC1 tiene que ser un AC"

      refute funcion_de_la_nota(script, "nota_es_id_wp", "F3-AC1"),
             "F3-AC1 no puede ser un WP"

      assert funcion_de_la_nota(script, "nota_es_id_wp", "F3-01"),
             "F3-01 tiene que ser un WP"

      refute funcion_de_la_nota(script, "nota_es_id", "F3-01"),
             "F3-01 no puede ser un AC"
    end
  end

  # ------------------------------------------------------------------
  # Utilidades
  # ------------------------------------------------------------------

  # Ejecuta una funcion de `scripts/lib_nota.sh` con un argumento y dice si
  # sale con 0 (la funcion acepto el identificador).
  defp funcion_de_la_nota(script, funcion, id) do
    {_salida, codigo} =
      System.cmd(
        "bash",
        ["-c", "source \"$1\"; #{funcion} \"$2\"", "bash", script, id],
        stderr_to_stdout: true
      )

    codigo == 0
  end

  # Las filas de una tabla de markdown que empiezan por `prefijo` y tienen
  # `celdas` celdas.
  defp filas_de_tabla(texto, prefijo, celdas) do
    texto
    |> String.split("\n")
    |> Enum.filter(&(String.starts_with?(&1, prefijo) and num_celdas(&1) == celdas))
  end

  # La primera celda de una fila de tabla: su identificador.
  defp primera_celda(linea) do
    linea
    |> String.trim()
    |> String.trim_leading("|")
    |> String.split("|")
    |> List.first()
    |> String.trim()
  end

  # Las filas cuyo primer campo es un identificador de fase (`F3-...`),
  # con su numero de celdas y su identificador. Las notas tienen otras
  # tablas (la de "lo que ya esta") cuya primera celda es texto.
  defp filas_con_identificador(texto) do
    texto
    |> String.split("\n")
    |> Enum.filter(&String.starts_with?(&1, "| F"))
    |> Enum.map(fn linea -> {num_celdas(linea), primera_celda(linea)} end)
    |> Enum.filter(fn {_celdas, id} -> id =~ ~r/^F\d+-/ end)
  end

  defp num_celdas(linea) do
    linea
    |> String.trim()
    |> String.trim_leading("|")
    |> String.trim_trailing("|")
    |> String.split("|")
    |> length()
  end
end
