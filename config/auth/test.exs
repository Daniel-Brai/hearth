import Config

config :hearth, :secret_key_base, "test-only-hearth-secret-0000000000000000000000000000000000000000"

config :hearth, Hearth.Auth, providers: [github: [client_id: "test", client_secret: "test"]]
