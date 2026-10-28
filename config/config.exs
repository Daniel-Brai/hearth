import Config

# Events repeat in their own time zone so the calendar needs real zone data
config :elixir, :time_zone_database, Tz.TimeZoneDatabase

config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :user_id, :api_version, :trace_id]

config :phoenix,
       :filter_parameters,
       ~w[password token access_token refresh_token sign_up_token code secret sha256]

config :opentelemetry, traces_exporter: :none

# Must stay above the area configs below, which override it
import_config "#{config_env()}.exs"

import_config "accounts/config.exs"
import_config "auth/config.exs"
import_config "buffer/config.exs"
import_config "communities/config.exs"
import_config "hearth/config.exs"
import_config "jobs/config.exs"
import_config "media/config.exs"
import_config "moderation/config.exs"
import_config "notifications/config.exs"
import_config "repo/config.exs"
import_config "secrets/config.exs"
import_config "storage/config.exs"
import_config "transcription/config.exs"
import_config "voice/config.exs"
import_config "web/config.exs"
