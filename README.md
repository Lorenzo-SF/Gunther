# Gunther

Librería de Elixir para usar varios modelos de lenguaje configurados como si fueran uno: un enrutador decide a qué modelo va cada petición, con ranking, traza y failover. Los modelos pueden ser de nube, locales (gestionando su arranque y apagado) o de otro PC gestionado de forma remota.

**Estado**: en construcción — DP0, F0 y F1 cerrados. La especificación vigente es `SPEC-000-GUNTHER_r9.md`; la documentación, `docs/00-indice.md`; el registro de fases y puertas, `docs/13-registro-de-fases.md`. El cierre de DP0 está en `CIERRE-DP0.md`. La primera versión se publicará en Hex como `gunther` (el nombre está libre, puerta G-16).

**Qué no hace**: no descarga ni distribuye modelos ni binarios; no soporta Windows; no incluye ningún modelo decisor.

**Licencia**: Apache-2.0 (ver `LICENSE` y `NOTICE`). **Contribuciones**: por _issues_ (ver `CONTRIBUTING.md`).

## Instalación (aún no publicada)

```elixir
def deps do
  [{:gunther, "~> 0.1"}]
end
```

## Uso

```elixir
# La configuración se carga de un fichero y se valida al arrancar.
{:ok, config} = Gunther.Config.Loader.load("gunther.toml")

# Una decisión: a qué modelo va una petición, con la traza de por qué.
{:ok, decision} = Gunther.Router.decide(config, %{prompt: "hola"})
```

La API pública cambia: el paquete está en `0.1.x` y todavía no cumple SemVer
para uso en produccion. Lee `CHANGELOG.md` antes de depender de el.

## Desarrollo

```bash
mix deps.get
mix check.all     # las cuatro capas, en el entorno de test
```

`mix check.all` corre formato, compilacion sin warnings, Credo **estricto**,
Dialyzer, la suite, las fronteras y el lint de documento. Las mismas cuatro
capas son trabajos separados en CI (`.github/workflows/ci.yml`), que es donde
manda.

El contrato de trabajo de quien toque el repositorio —incluido un modelo que
haga de _coder_— esta en [`AGENTS.md`](AGENTS.md). El plan de traspaso, con
el estado real, el metodo, la cola de trabajo y los criterios de revision,
esta en [`docs/14-planificacion-del-coder.md`](docs/14-planificacion-del-coder.md).
