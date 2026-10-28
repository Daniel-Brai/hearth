import Config

config :hearth, Hearth.Notifications.Mailer, adapter: Swoosh.Adapters.Test

config :hearth, Hearth.Notifications.WebPush,
  public_key:
    "BFiE652KnDJzshOdPlnCUval4mv_eYe7_lPhUQ_8xsBAxwzcaajGLl9tk8f0uxCxdlyrZ_CGse6SMM76vR2lGIQ",
  private_key: "iSitQRLVG5B-Ob9QV_dorgN1LY5aA4uB7siScPFdcOg",
  subject: "mailto:push@hearth.localhost",
  req_options: [plug: {Req.Test, Hearth.Notifications.WebPush}, retry: false]

# Swoosh's API client is only needed by production adapters
config :swoosh, :api_client, false
