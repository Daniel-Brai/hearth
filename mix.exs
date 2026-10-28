defmodule Hearth.Umbrella.MixProject do
  use Mix.Project

  # Bumped by `mix git_ops.release` from the commit messages since the last release.
  @version "0.1.0"

  def project do
    [
      apps_path: "apps",
      version: @version,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      source_url: "https://github.com/daniel-brai/hearth",
      homepage_url: "https://github.com/daniel-brai/hearth",
      aliases: aliases(),
      listeners: [Phoenix.CodeReloader],
      test_coverage: [tool: ExCoveralls],
      dialyzer: [
        plt_add_apps: [:ex_unit]
      ],
      releases: [
        hearth: [
          applications: [
            # Tracing must never take the node down with it.
            opentelemetry_exporter: :permanent,
            opentelemetry: :temporary,
            hearth: :permanent,
            hearth_web: :permanent,
            # Loaded but not started. config/runtime.exs calls it before boot.
            secrets: :load
          ]
        ]
      ]
    ]
  end

  def cli do
    [
      preferred_envs: [coveralls: :test, "coveralls.html": :test, precommit: :test]
    ]
  end

  defp deps do
    [
      {:castore, "~> 1.0"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:git_hooks, "~> 0.9.0", only: :dev, runtime: false},
      {:git_ops, "~> 2.6.1", only: :dev},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
      {:phoenix_live_view, ">= 0.0.0"}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "cmd mix setup", "git_hooks.install"],
      precommit: ["compile --warnings-as-errors", "deps.unlock --unused", "format", "test"],
      scan: ["deps.audit", "cmd mix sobelow --skip"]
    ]
  end
end
