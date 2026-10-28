import Config

config :hearth_web, HearthWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "ry/aMDmTU9V+AxziKdhz5zQmvIYxsR2Ge/vqYjlnF7xhrQi55bx7JBNvr8uXKV/z",
  server: false

config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  enable_expensive_runtime_checks: true

config :phoenix,
  sort_verified_routes_query_params: true

config :hearth_web, HearthWeb.Guardian.Keys,
  private_key: """
  -----BEGIN PRIVATE KEY-----
  MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQga5VVQ1+xKQv4X1Ph
  nCNmo2mYs1Dq/sytFmCX5yYqkOWhRANCAASzGR+OBn3NsCSI7meaj+Tj7hzTo0Qi
  ACwkr8n9YsbY9hdxr4dhUtnfkaunbe+NSHmoNWLtceB0KDc90egVZewK
  -----END PRIVATE KEY-----
  """,
  previous_public_keys: """
  -----BEGIN PUBLIC KEY-----
  MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEOxIbWNhqlOgYxzBw+8t4YOKjMfSA
  djGhxMGvh/gdJAH+4YCmvxBh3sMQf5MlAsPgVaScugj20GlB7QFIAloTLQ==
  -----END PUBLIC KEY-----
  """

config :hearth_web, secure_cookies: false

config :hearth_web, api_docs: true

# The queue poller runs outside any test's sandbox so tests leave it out
config :hearth_web, HearthWeb.PromEx, drop_metrics_groups: [:oban_queue_poll_metrics]
