import Config

config :hearth_web,
  ecto_repos: [Hearth.Repo],
  generators: [context_app: :hearth, binary_id: true]

config :hearth_web, HearthWeb.Endpoint,
  url: [host: "localhost"],
  http: [port: {:system, :integer, "PORT", 4000}],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: HearthWeb.ErrorHTML, json: HearthWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Hearth.PubSub,
  live_view: [signing_salt: "8ZSOZ/If"]

# Access tokens are ES256 JWTs for 15 minutes
config :hearth_web, HearthWeb.Guardian,
  issuer: {:system, "API_URL", "http://localhost:4000"},
  verify_issuer: true,
  allowed_algos: ["ES256"],
  allowed_drift: 2_000,
  ttl: {15, :minutes},
  token_ttl: %{"access" => {15, :minutes}},
  secret_fetcher: HearthWeb.Guardian.Keys

config :hearth_web, api_docs: {:system, :boolean, "API_DOCS", false}

# Cookies go over HTTPS only and development and tests turn this off
config :hearth_web, secure_cookies: true

config :esbuild,
  version: "0.25.4",
  hearth_web: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../../apps/hearth_web/assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../../deps", __DIR__), Mix.Project.build_path()]}
  ]

config :tailwind,
  version: "4.3.3",
  hearth_web: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("../../apps/hearth_web", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../../deps", __DIR__), Mix.Project.build_path()]}
  ]

config :phoenix, :json_library, Jason

config :request_validator, :strict?, true

config :phoenix_live_view,
  root_tag_attribute: "phx-r"

config :hearth_web, HearthWeb.MetricsEndpoint,
  adapter: Bandit.PhoenixAdapter,
  http: [ip: {0, 0, 0, 0}, port: {:system, :integer, "METRICS_PORT", 9568}]

config :hearth_web, :metrics_basic_auth,
  username: {:system, "METRICS_USERNAME", ""},
  password: {:system, "METRICS_PASSWORD", ""}

config :hearth_web, HearthWeb.PromEx,
  manual_metrics_start_delay: :no_delay,
  drop_metrics_groups: [],
  grafana: :disabled,
  metrics_server: :disabled

import_config "#{config_env()}.exs"
