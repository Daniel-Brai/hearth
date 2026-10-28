import Config

config :hearth, Hearth.ScreeningPolicy,
  screener: Hearth.Moderation.Screener.Stub,
  image_floor: :off

config :hearth, Hearth.Moderation.Screener, threshold: 0.5

config :hearth, Hearth.Moderation.Screener.Hosted,
  api_key: "test-key",
  req_options: [plug: {Req.Test, Hearth.Moderation.Screener.Hosted}, retry: false]
