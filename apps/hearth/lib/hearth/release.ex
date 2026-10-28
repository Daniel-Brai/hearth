defmodule Hearth.Release do
  alias Ecto.Migrator
  @app :hearth

  @spec migrate() :: :ok
  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _result, _apps} =
        Migrator.with_repo(repo, &Migrator.run(&1, :up, all: true))
    end

    :ok
  end

  @spec rollback(module(), integer()) :: :ok
  def rollback(repo, version) do
    load_app()

    {:ok, _result, _apps} =
      Migrator.with_repo(repo, &Migrator.run(&1, :down, to: version))

    :ok
  end

  defp repos, do: Application.fetch_env!(@app, :ecto_repos)

  # The app isn't started here so {:system, ...} settings are read by hand
  defp load_app do
    {:ok, _apps} = Application.ensure_all_started(:ssl)
    :ok = Application.ensure_loaded(@app)
    Confex.resolve_env!(@app)
  end
end
