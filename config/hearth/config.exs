import Config

config :hearth,
  instance_name: {:system, "INSTANCE_NAME", "Hearth"},
  # false serves noindex everywhere and an empty sitemap
  instance_indexing: {:system, :boolean, "INSTANCE_INDEXING", true},
  # A wordmark and a square icon as URLs or paths and Hearth's own when blank
  instance_logo: {:system, "INSTANCE_LOGO", nil},
  instance_icon: {:system, "INSTANCE_ICON", nil},
  public_url: {:system, "PUBLIC_URL", "http://localhost:5173"},
  dns_cluster_query: {:system, "DNS_CLUSTER_QUERY", nil},
  # Comma separated from web rtc media and ai and unset does everything but rtc
  roles: {:system, :list, "HEARTH_ROLES", ["web", "media", "ai"]}

# For development and tests only since prod.exs requires ENCRYPTION_KEY of 32 bytes in base64
# Old keys stay in ENCRYPTION_PREVIOUS_KEYS so messages sealed with them still read
config :hearth, Hearth.Vault,
  key: {:system, "ENCRYPTION_KEY", "Vx/kkoMOydcAKT7fbjOHfzioSqQXHLKxLFO7M/JhpVg="},
  previous_keys: {:system, "ENCRYPTION_PREVIOUS_KEYS", ""},
  # Must stay the same when ENCRYPTION_KEY changes
  hash_key: {:system, "ENCRYPTION_HASH_KEY", "fnDz4UX2IJaBnhKLBg3dPG9ZkjLMzo0TebaGuG9w2xE="}

# UPDATE_CHECK=false turns off the daily check for a newer Hearth
config :hearth, Hearth.Instance.Releases,
  enabled: {:system, :boolean, "UPDATE_CHECK", true},
  base_url: "https://api.github.com/repos/daniel-brai/hearth"

if config_env() in [:prod, :test] do
  import_config "#{config_env()}.exs"
end
