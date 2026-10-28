import Config

config :hearth, Hearth.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "hearth_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10
