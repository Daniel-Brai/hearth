import Config

config :hearth, Hearth.Notifications, from: {:system, "MAIL_FROM"}

config :swoosh, :api_client, Swoosh.ApiClient.Req

config :swoosh, local: false
