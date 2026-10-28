# Tests that load the real screening models run only with --only models
ExUnit.start(exclude: [:models])
Ecto.Adapters.SQL.Sandbox.mode(Hearth.Repo, :manual)
