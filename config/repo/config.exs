import Config

config :hearth,
  ecto_repos: [Hearth.Repo]

config :hearth, Hearth.Repo,
  migration_primary_key: [type: :uuid],
  migration_foreign_key: [type: :uuid],
  migration_timestamps: [type: :timestamptz]

import_config "#{config_env()}.exs"
