import Config

config :hearth_web, HearthWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json",
  http: [
    ip: {0, 0, 0, 0, 0, 0, 0, 0},
    port: {:system, :integer, "PORT", 4000}
  ],
  secret_key_base: {:system, "SECRET_KEY_BASE"}

# Calls inside the network such as health probes use plain HTTP and :force_ssl is read at compile time
config :hearth_web, HearthWeb.Endpoint,
  force_ssl: [
    rewrite_on: [:x_forwarded_proto],
    exclude: [
      hosts: ["localhost", "127.0.0.1", "api"],
      paths: ["/healthz/live", "/healthz/ready"]
    ]
  ]

# When replacing the key, put the old public key in JWT_PREVIOUS_PUBLIC_KEYS until its tokens run out
config :hearth_web, HearthWeb.Guardian.Keys,
  private_key: {:system, "JWT_PRIVATE_KEY"},
  previous_public_keys: {:system, "JWT_PREVIOUS_PUBLIC_KEYS", nil}
