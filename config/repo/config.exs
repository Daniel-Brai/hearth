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

# Migrations up to the v0.0.5 release already ran on servers, so only newer ones are checked for unsafe changes
config :excellent_migrations, start_after: "20261104194849"

import_config "#{config_env()}.exs"
