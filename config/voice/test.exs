import Config

# Peers announce only their own addresses and take any free port
config :hearth, Hearth.RTC,
  public_ip: nil,
  port_range: "0-0",
  turn_url: nil,
  turn_secret: nil,
  ready_ms: 5_000

config :hearth, Hearth.Voice, room_limit: 50, grace_ms: 100, empty_ms: 60_000, drain_limit_ms: 0
