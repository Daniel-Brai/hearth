# Messages from other processes can be slow on a busy machine and a passing assert returns early
ExUnit.start(assert_receive_timeout: 5_000)
Ecto.Adapters.SQL.Sandbox.mode(Hearth.Repo, :manual)
