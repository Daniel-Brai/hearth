import Config

config :hearth_web, HearthWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: {:system, :integer, "PORT", 4000}],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "4oNQ4+Mitk0EvA6rRKyR1iManqnFEmvJcB+LmuoBnEiZxThbmHPZQ/99vpEttu7o",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:hearth_web, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:hearth_web, ~w(--watch)]}
  ]

config :hearth_web, HearthWeb.Endpoint,
  live_reload: [
    web_console_logger: true,
    patterns: [
      ~r"priv/static/(?!uploads/).*\.(js|css|png|jpeg|jpg|gif|svg)$"E,
      ~r"priv/gettext/.*\.po$"E,
      ~r"lib/hearth_web/router\.ex$"E,
      ~r"lib/hearth_web/(controllers|live|components)/.*\.(ex|heex)$"E
    ]
  ]

config :hearth_web, dev_routes: true

config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  debug_heex_annotations: true,
  debug_attributes: true,
  enable_expensive_runtime_checks: true

config :phoenix, :stacktrace_depth, 20

# JWT_PRIVATE_KEY when set so sessions outlive a switch of machines
config :hearth_web, HearthWeb.Guardian.Keys,
  private_key:
    {:system, "JWT_PRIVATE_KEY",
     """
     -----BEGIN PRIVATE KEY-----
     MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQgwWqg8ZgY7At9HhM3
     Ev13koHeIsaVLeTyVuCdGdbagCehRANCAAQxVBjdGZs3mDTTguhA8ZqVk1mkeSog
     TvfVPygBFVgYvBBHWfAqG5J44Tl5p2MNeHKbGx6V2hzi5/aSbtkBDYyF
     -----END PRIVATE KEY-----
     """}

# Refresh cookies over plain HTTP, and request bodies in the log
config :hearth_web, secure_cookies: false
config :hearth_web, HearthWeb.RequestLogger, bodies: true

config :hearth_web, api_docs: true

config :hearth_web, HearthWeb.MetricsEndpoint, server: true
