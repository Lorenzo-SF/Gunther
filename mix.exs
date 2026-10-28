defmodule Gunther.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/Lorenzo-SF/Gunther"

  def project do
    [
      app: :gunther,
      version: @version,
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      # `test/support` lleva el constructor de cabeceras GGUF que usan los
      # tests del parser. No entra en el paquete: `files:` lista `lib`
      # explicitamente.
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      name: "Gunther",
      description:
        "Framework de Elixir para usar N modelos de lenguaje configurados como si fueran uno: " <>
          "un enrutador decide a qué modelo va cada petición, con ranking, traza y failover.",
      source_url: @source_url,
      homepage_url: @source_url,
      package: package(),
      docs: docs(),
      aliases: aliases(),
      dialyzer: dialyzer(),
      test_coverage: [tool: ExCoveralls]
    ]
  end

  def cli do
    [
      preferred_envs: %{
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.html": :test,
        # `mix test` dentro de un alias corre en el entorno actual: si el
        # alias se lanza desde `dev`, la suite no puede arrancar (los tests
        # viven en `:test`). `preferred_envs` hace que Mix **reejecute** el
        # alias con el entorno que necesita, en vez de avisar.
        "check.all": :test
      }
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto, :ssl, :public_key, :telemetry],
      mod: {Gunther.Application, []}
    ]
  end

  defp package do
    [
      name: :gunther,
      licenses: ["Apache-2.0"],
      # `files` es una LISTA, no un mapa: Hex la recorre con
      # `String.contains?/2`, que recibe una lista de patrones. Con un mapa,
      # `mix hex.build` revienta con un FunctionClauseError. La lista es
      # explicita a proposito: el paquete lleva lo que dice y nada mas, y el
      # trabajo `package` de CI comprueba que no se cuelan `probes/`,
      # `_build/`, `deps/` ni `.github/`.
      files: [
        "lib",
        "mix.exs",
        "README.md",
        "CHANGELOG.md",
        "LICENSE",
        "NOTICE",
        "SECURITY.md",
        "CONTRIBUTING.md",
        "SPEC-000-GUNTHER_r9.md",
        "docs"
      ],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md"
      },
      maintainers: ["Lorenzo Sánchez"]
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md",
        "CHANGELOG.md",
        "SECURITY.md",
        "CONTRIBUTING.md",
        "SPEC-000-GUNTHER_r9.md",
        "LICENSE",
        "NOTICE"
      ],
      groups_for_modules: [
        Núcleo: [Gunther, Gunther.Application, Gunther.Supervisor],
        Configuración: [
          Gunther.Config,
          Gunther.Config.Loader,
          Gunther.Config.Validator,
          Gunther.Config.Server
        ],
        Errores: [Gunther.Error],
        "Catálogo y registro": [
          Gunther.Catalog,
          Gunther.Catalog.Server,
          Gunther.Registry
        ],
        Enrutado: [
          Gunther.Router,
          Gunther.Decision,
          Gunther.Rule,
          Gunther.Rule.Evaluator
        ],
        Inferencia: [
          Gunther.Response,
          Gunther.Provider,
          Gunther.Provider.Mock
        ],
        Caché: [Gunther.Cache],
        Cancelación: [Gunther.Cancel],
        Telemetría: [Gunther.Telemetry.Bridge],
        Contexto: [Gunther.Context]
      ],
      source_ref: "v#{@version}"
    ]
  end

  defp deps do
    [
      # Ecosistema Lorenzo-SF (SPEC §0.3)
      # G-17: la insignia del README de arrea dice 3.0.0; lo publicado es 4.0.0.
      # Pero trebejo (publicado y en su `main`) exige `arrea ~> 3.1`, asi que 4.0.0
      # es irresoluble con el ecosistema publicado. Rango A: `~> 3.0` del SPEC, que
      # `~> 3.1` cumple. El ledger es propio (D-48), luego `Arrea.Resource` no hace falta.
      {:arrea, "~> 3.1"},
      {:apero, "~> 4.0"},
      {:trebejo, "~> 2.0"},

      # Obligatorias del núcleo
      {:jason, "~> 1.4"},
      {:finch, "~> 0.24"},
      {:telemetry, "~> 1.4"},
      # Validador de JSON Schema (SPEC §0.3, decisión de F0)
      {:jsx, "~> 3.1"},
      # Parser TOML: `Apero.Conf` lo carga si está disponible (G-07)
      {:toml, "~> 0.7"},

      # Opcionales: se cargan con `Code.ensure_loaded?/1` (SPEC §0.4)
      {:plug, "~> 1.20", optional: true},
      {:bandit, "~> 1.14", optional: true},
      {:exqlite, "~> 0.43", optional: true},
      {:postgrex, "~> 0.22", optional: true},
      {:opentelemetry, "~> 1.0", optional: true},

      # Solo pruebas
      {:stream_data, "~> 1.4", only: [:test, :dev]},
      {:benchee, "~> 1.5", only: [:dev, :test], runtime: false},

      # Solo desarrollo: los gates L2 de las cuatro capas de verificacion
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.38", only: [:dev, :test], runtime: false}
    ]
  end

  defp dialyzer do
    [
      plt_file: {:no_warn, "priv/plts/gunther"},
      plt_core_path: "priv/plts/core",
      flags: [:unknown]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  defp aliases do
    [
      # L1: formato y compilación sin warnings.
      "check.format": ["format --check-formatted"],
      "check.compile": ["compile --force --warnings-as-errors"],
      # L2: estáticos. El `--strict` va **junto**: sin él, Credo solo mira la
      # configuración por defecto y el recuento de avisos sale siempre 0.
      # Un check que no ve nada no es un check.
      "check.static": ["credo --strict --format=oneline", "dialyzer"],
      # L3 y L4: las cuatro capas de verificación. L4 son las fronteras y el
      # lint de documento, que también entran aquí: el README dice que hay
      # cuatro capas, y un alias que solo hace tres miente.
      "check.all": [
        "format --check-formatted",
        "compile --force --warnings-as-errors",
        "credo --strict --format=oneline",
        "dialyzer",
        "test",
        "cmd bash scripts/check_boundaries.sh",
        "cmd bash scripts/doc_lint.sh"
      ],
      "hex.build": ["hex.build"]
    ]
  end
end
