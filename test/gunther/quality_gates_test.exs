defmodule Gunther.QualityGatesTest do
  @moduledoc """
  Los aliases de `mix.exs` son la puerta que se ejecuta a diario. Si uno de
  ellos **deja de mirar** algo, el fallo es silencioso: el alias sale en verde
  mientras no comprueba lo que dice comprobar.

  Ya pasó: `check.static` y `check.all` usaban `credo --format=oneline` sin
  `--strict`, y el recuento de avisos salía **siempre 0** porque el formato por
  defecto de `--strict` no produce las líneas que se contaban. La CI estuvo en
  rojo durante quince runs con 18 avisos de Credo que nadie veía.

  Aquí se fija lo que los aliases **tienen que** mirar. Un test que se puede
  degradar sin que nadie lo note es un test muerto, y este no se puede degradar.
  """

  use ExUnit.Case, async: true

  import Bitwise

  @mix_exs Path.expand("../../mix.exs", __DIR__)

  setup_all do
    {:ok, contenido: File.read!(@mix_exs)}
  end

  defp cuerpo_del_alias(contenido, nombre) do
    case Regex.run(~r/"#{Regex.escape(nombre)}":\s*\[(.*?)\]/s, contenido) do
      [_todo, cuerpo] -> cuerpo
      nil -> flunk("el alias #{nombre} no existe en mix.exs")
    end
  end

  describe "Credo" do
    test "los dos aliases que lo usan llevan `--strict`", %{contenido: contenido} do
      for nombre <- ["check.static", "check.all"] do
        cuerpo = cuerpo_del_alias(contenido, nombre)

        assert cuerpo =~ "credo --strict --format=oneline",
               "el alias #{nombre} debe contar los avisos de Credo de TODAS las prioridades"
      end
    end

    test "ningún alias usa Credo sin `--strict`", %{contenido: contenido} do
      # Solo los aliases: el resto del fichero menciona `credo` como
      # dependencia, y eso no es un comando.
      sin_strict =
        Regex.scan(~r/"([\w.]+)":\s*\[(.*?)\]/s, contenido)
        |> Enum.filter(fn [_todo, _nombre, cuerpo] -> cuerpo =~ "credo" end)
        |> Enum.reject(fn [_todo, _nombre, cuerpo] -> cuerpo =~ "credo --strict" end)
        |> Enum.map(fn [_todo, nombre, _cuerpo] -> nombre end)

      assert sin_strict == [],
             "estos aliases usan credo sin --strict: #{inspect(sin_strict)}"
    end
  end

  describe "las cuatro capas" do
    test "`check.all` incluye las fronteras y el lint de documento", %{contenido: contenido} do
      cuerpo = cuerpo_del_alias(contenido, "check.all")

      assert cuerpo =~ "check_boundaries.sh",
             "L4 (fronteras) tiene que entrar en el alias que dice las cuatro capas"

      assert cuerpo =~ "doc_lint.sh",
             "L4 (lint de documento) tiene que entrar en el alias que dice las cuatro capas"
    end

    test "`check.all` incluye las cuatro capas por nombre", %{contenido: contenido} do
      cuerpo = cuerpo_del_alias(contenido, "check.all")

      for capa <- [
            "format --check-formatted",
            "compile --force --warnings-as-errors",
            "credo --strict --format=oneline",
            "dialyzer",
            "test"
          ] do
        assert cuerpo =~ capa, "el alias check.all no incluye: #{capa}"
      end
    end
  end

  describe "las puertas de fase" do
    test "los dos scripts de cierre existen y son ejecutables" do
      raiz = Path.expand("../..", __DIR__)

      for script <- ["scripts/check_phase.sh", "scripts/check_ac.sh"] do
        ruta = Path.join(raiz, script)

        assert File.exists?(ruta), "falta #{script}"

        assert File.stat!(ruta).mode && (File.stat!(ruta).mode &&& 0x111) != 0,
               "#{script} tiene que ser ejecutable"
      end
    end
  end
end
