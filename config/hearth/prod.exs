import Config

config :hearth, public_url: {:system, "PUBLIC_URL"}

config :hearth, Hearth.Vault,
  key: {:system, "ENCRYPTION_KEY"},
  hash_key: {:system, "ENCRYPTION_HASH_KEY"}
