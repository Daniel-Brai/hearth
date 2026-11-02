import Config

config :hearth,
  ecto_repos: [Hearth.Repo]

# An advisory lock lets a migration build an index concurrently while other pods wait their turn
config :hearth, Hearth.Repo,
  migration_lock: :pg_advisory_lock,
  migration_primary_key: [type: :uuid],
  migration_foreign_key: [type: :uuid],
  migration_timestamps: [type: :timestamptz]

config :ecto_sql, migration_module: Hearth.Repo.Migration

import_config "#{config_env()}.exs"
