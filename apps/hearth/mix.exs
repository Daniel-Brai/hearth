defmodule Hearth.MixProject do
  use Mix.Project

  def project do
    [
      app: :hearth,
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
      compilers: [:boundary] ++ Mix.compilers()
    ]
  end

  def application do
    [
      mod: {Hearth.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:assent, "~> 0.3"},
      {:boundary, "~> 0.10", runtime: false},
      {:bumblebee, "~> 0.8"},
      {:confex, "~> 3.5"},
      {:dns_cluster, "~> 0.2.0"},
      {:ecto_sql, "~> 3.14"},
      {:email_checker, "~> 0.2"},
      {:ex_aws, "~> 2.7"},
      {:ex_aws_s3, "~> 2.5"},
      {:ex_webrtc, "0.17.0"},
      {:exla, "~> 1.0", override: true},
      {:faker, "~> 0.19", only: :test},
      {:flop, "~> 0.29"},
      {:gen_smtp, "~> 1.3"},
      {:gen_stage, "~> 1.3"},
      {:hammer, "~> 7.5"},
      {:image, "~> 0.72"},
      {:jason, "~> 1.2"},
      {:jose, "~> 1.11.13"},
      {:mjml, "~> 6.0"},
      {:muontrap, "~> 2.0"},
      {:nx, "~> 1.0", override: true},
      {:oban, "~> 2.24"},
      {:oban_notifiers_phoenix, "~> 0.2"},
      {:opentelemetry, "~> 1.7"},
      {:opentelemetry_api, "~> 1.5"},
      {:opentelemetry_ecto, "~> 1.2"},
      {:opentelemetry_exporter, "~> 1.11"},
      {:opentelemetry_oban, "~> 1.2"},
      {:partitioned_buffer, "~> 0.4"},
      {:phoenix_live_view, "~> 1.2.0"},
      {:phoenix_pubsub, "~> 2.4"},
      {:postgrex, ">= 0.0.0"},
      {:req, "~> 0.5"},
      {:rop,
       github: "ruby2elixir/rop", ref: "2065eaf9b16ee665b705371b11d345dd7f4b33fe", depth: 1},
      {:sobelow, "~> 0.14", only: [:dev, :test], runtime: false, warn_if_outdated: true},
      {:sweet_xml, "~> 0.7"},
      {:swoosh, "~> 1.16"},
      {:tz, "~> 0.28"},
      {:xfsm, "~> 0.6.0-rc.4"},
      {:yaml_elixir, "~> 2.12"}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run #{__DIR__}/priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end
end
