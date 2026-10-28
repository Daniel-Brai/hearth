import Config

config :hearth, Hearth.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "hearth_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2
