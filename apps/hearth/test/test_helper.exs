# Tests that load the real screening models run only with --only models
# Messages from other processes can be slow on a busy machine and a passing assert returns early
ExUnit.start(exclude: [:models], assert_receive_timeout: 5_000)
Ecto.Adapters.SQL.Sandbox.mode(Hearth.Repo, :manual)
