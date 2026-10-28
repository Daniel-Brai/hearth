defmodule HearthWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :hearth_web

  @session_options [
    store: :cookie,
    key: "_hearth_web_key",
    signing_salt: "e7wi+Djh",
    same_site: "Lax"
  ]

  socket "/socket", HearthWeb.UserSocket,
    auth_token: true,
    websocket: true,
    longpoll: false

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]],
    longpoll: [connect_info: [session: @session_options]]

  plug Plug.Static,
    at: "/",
    from: :hearth_web,
    gzip: not code_reloading?,
    only: HearthWeb.static_paths(),
    raise_on_missing_only: code_reloading?

  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :hearth_web
  end

  plug Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"

  plug RemoteIp

  plug Plug.RequestId

  # RequestLogger writes the log instead
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint], log: false

  plug HearthWeb.Plugs.Health

  plug Corsica,
    origins: {HearthWeb.Cors, :allowed_origin?, []},
    allow_credentials: true,
    allow_headers: ~w[accept authorization content-type hearth-version idempotency-key],
    allow_methods: ~w[GET POST PATCH PUT DELETE],
    expose_headers: ~w[hearth-version retry-after x-request-id],
    max_age: 600

  # Raw upload bodies so this goes before the parsers
  plug HearthWeb.Plugs.LocalStorage

  plug Plug.Parsers,
    parsers: ~w[urlencoded multipart json]a,
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug HearthWeb.Router
end
