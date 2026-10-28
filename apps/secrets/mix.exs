defmodule Secrets.MixProject do
  use Mix.Project

  def project do
    [
      app: :secrets,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      source_url: "https://github.com/daniel-brai/hearth",
      homepage_url: "https://github.com/daniel-brai/hearth",
      test_coverage: [tool: ExCoveralls],
      compilers: [:boundary] ++ Mix.compilers()
    ]
  end

  # Nothing runs under a supervisor and config/runtime.exs calls
  # Secrets.inject!/0 before any other app starts
  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:boundary, "~> 0.10", runtime: false},
      {:confex, "~> 3.5"},
      {:jason, "~> 1.2"},
      {:plug, "~> 1.18", only: :test},
      {:req, "~> 0.5"},
      {:sobelow, "~> 0.14", only: [:dev, :test], runtime: false, warn_if_outdated: true},
      {:yaml_elixir, "~> 2.12"}
    ]
  end
end
