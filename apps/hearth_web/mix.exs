defmodule HearthWeb.MixProject do
  use Mix.Project

  def project do
    [
      app: :hearth_web,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      source_url: "https://github.com/daniel-brai/hearth",
      homepage_url: "https://github.com/daniel-brai/hearth",
      test_coverage: [tool: ExCoveralls],
      compilers: [:boundary, :phoenix_live_view] ++ Mix.compilers(),
      listeners: [Phoenix.CodeReloader]
    ]
  end

  def application do
    [
      mod: {HearthWeb.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:bandit, "~> 1.14"},
      {:boundary, "~> 0.10", runtime: false},
      {:confex, "~> 3.5"},
      {:corsica, "~> 2.1"},
      {:daisyui,
       github: "saadeghi/daisyui",
       tag: "v5.5.20",
       sparse: "packages/bundle",
       app: false,
       compile: false,
       depth: 1},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:gen_stage, "~> 1.3"},
      {:gettext, "~> 1.0"},
      {:guardian, "~> 2.5"},
      {:hearth, in_umbrella: true},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.2.0",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:jason, "~> 1.2"},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:logger_json, "~> 7.0"},
      {:oaskit, "~> 0.17"},
      {:open_api_spex, "~> 3.22"},
      {:opentelemetry_bandit, "~> 0.3"},
      {:opentelemetry_phoenix, "~> 2.0"},
      {:phoenix, "~> 1.8.16"},
      {:phoenix_ecto, "~> 4.5"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.2.0"},
      {:prom_ex, "~> 1.11"},
      {:remote_ip, "~> 1.2"},
      {:request_validator, "~> 1.0"},
      {:sobelow, "~> 0.14", only: [:dev, :test], runtime: false, warn_if_outdated: true},
      {:tailwind, "~> 0.5", runtime: Mix.env() == :dev},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "assets.setup", "assets.build"],
      # Pinned to this app, so running it from the umbrella root writes the same file
      "api.spec": [
        "openapi.dump HearthWeb.OpenAPISpec -o #{Path.expand("priv/openapi.json", __DIR__)}"
      ],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["compile", "tailwind hearth_web", "esbuild hearth_web"],
      "assets.deploy": [
        "tailwind hearth_web --minify",
        "esbuild hearth_web --minify",
        "phx.digest"
      ]
    ]
  end
end
