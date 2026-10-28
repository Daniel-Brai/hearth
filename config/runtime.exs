import Config

# Settings that need more than a lookup live here and the rest use {:system, "NAME"} in each area folder

# With SECRETS_FILE set the variables it names are read from HashiCorp Vault first (see infra/k8s/README.md)
if config_env() != :test and System.get_env("SECRETS_FILE") do
  {:ok, _apps} = Application.ensure_all_started(:req)
  Secrets.inject!()
end

# Google and GitHub sign in are on only when both of their keys are set
oauth_providers =
  for {provider, prefix} <- [github: "GITHUB", google: "GOOGLE"],
      client_id = System.get_env("#{prefix}_CLIENT_ID", ""),
      client_secret = System.get_env("#{prefix}_CLIENT_SECRET", ""),
      client_id != "" and client_secret != "" do
    {provider, [client_id: client_id, client_secret: client_secret]}
  end

if config_env() != :test do
  config :hearth, Hearth.Auth, providers: oauth_providers
end

# Grafana dashboards are uploaded at boot when its host is set with a token, or a username and password
grafana_host = System.get_env("GRAFANA_HOST", "")

grafana_login =
  case Enum.map(~w[GRAFANA_TOKEN GRAFANA_USERNAME GRAFANA_PASSWORD], &System.get_env(&1, "")) do
    [token, _username, _password] when token != "" ->
      [auth_token: token]

    ["", username, password] when username != "" and password != "" ->
      [username: username, password: password, auth_token: nil]

    _none ->
      nil
  end

if grafana_host != "" and grafana_login do
  config :hearth_web, HearthWeb.PromEx,
    grafana:
      [
        host: grafana_host,
        upload_dashboards_on_start: true,
        folder_name: "Hearth",
        annotate_app_lifecycle: true
      ] ++ grafana_login
end

# Traces go to any OTLP collector when its endpoint is set
if System.get_env("OTEL_EXPORTER_OTLP_ENDPOINT") do
  config :opentelemetry,
    traces_exporter: :otlp,
    span_processor: :batch,
    resource: [service: [name: System.get_env("OTEL_SERVICE_NAME", "hearth")]]
end

json_logs =
  {LoggerJSON.Formatters.Basic,
   metadata: :all,
   redactors: [
     {LoggerJSON.Redactors.RedactKeys, ~w[
       password
       token
       access_token
       refresh_token
       sign_up_token
       code
       secret
       authorization
       cookie
     ]}
   ]}

# LOG_FORMAT=text keeps plain lines instead of JSON
if config_env() == :prod and System.get_env("LOG_FORMAT", "json") == "json" do
  config :logger, :default_handler, formatter: json_logs
end

# LOG_FILE also writes the JSON lines to a file, for a collector to ship to Loki
log_file = System.get_env("LOG_FILE", "")

if log_file != "" do
  config :hearth, :logger, [
    {:handler, :log_file, :logger_std_h,
     %{
       config: %{file: String.to_charlist(log_file), max_no_bytes: 10_000_000, max_no_files: 3},
       formatter: json_logs
     }}
  ]
end

if config_env() == :prod do
  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  public_url = "PUBLIC_URL" |> System.fetch_env!() |> URI.parse()

  # bin/server sets PHX_SERVER and without it neither endpoint opens a port
  serve? = System.get_env("PHX_SERVER") in ~w(true 1)

  config :hearth_web, HearthWeb.Endpoint,
    url: [host: public_url.host, port: public_url.port, scheme: public_url.scheme],
    server: serve?

  config :hearth_web, HearthWeb.MetricsEndpoint, server: serve?

  config :hearth, Hearth.Repo, socket_options: maybe_ipv6

  # Sign in codes go out by email so a missing key stops the boot with its name
  env = &System.fetch_env!/1

  mailer =
    case System.get_env("MAIL_PROVIDER", "smtp") do
      "smtp" ->
        [
          adapter: Swoosh.Adapters.SMTP,
          relay: env.("SMTP_HOST"),
          port: String.to_integer(env.("SMTP_PORT")),
          username: env.("SMTP_USERNAME"),
          password: env.("SMTP_PASSWORD"),
          ssl: System.get_env("SMTP_TLS") == "ssl",
          tls: :if_available
        ]

      "zeptomail" ->
        zeptomail = [adapter: Swoosh.Adapters.ZeptoMail, api_key: env.("ZEPTOMAIL_API_KEY")]

        case System.get_env("ZEPTOMAIL_BASE_URL") do
          nil -> zeptomail
          base_url -> Keyword.put(zeptomail, :base_url, base_url)
        end

      "postmark" ->
        [adapter: Swoosh.Adapters.Postmark, api_key: env.("POSTMARK_API_KEY")]

      "mailgun" ->
        [
          adapter: Swoosh.Adapters.Mailgun,
          api_key: env.("MAILGUN_API_KEY"),
          domain: env.("MAILGUN_DOMAIN")
        ]

      "sendgrid" ->
        [adapter: Swoosh.Adapters.Sendgrid, api_key: env.("SENDGRID_API_KEY")]

      "brevo" ->
        [adapter: Swoosh.Adapters.Brevo, api_key: env.("BREVO_API_KEY")]

      "ses" ->
        [
          adapter: Swoosh.Adapters.AmazonSES,
          region: env.("SES_REGION"),
          access_key: env.("SES_ACCESS_KEY_ID"),
          secret: env.("SES_SECRET_ACCESS_KEY")
        ]

      other ->
        raise "Unknown MAIL_PROVIDER #{inspect(other)}"
    end

  config :hearth, Hearth.Notifications.Mailer, mailer
end
