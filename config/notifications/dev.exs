import Config

# Swoosh's API client is only needed by production adapters
config :swoosh, :api_client, false
