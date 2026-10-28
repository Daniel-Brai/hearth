import Config

config :hearth, Hearth.Repo,
  url: {:system, "DATABASE_URL"},
  pool_size: {:system, :integer, "POOL_SIZE", 10}
