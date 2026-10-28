import Config

# Voice needs a public address browsers reach directly and a range of open UDP ports
# public_ip is announced to browsers and voice stays hidden while it is unset
# port_range is first-last and turn_url and turn_secret set the coturn relay and turn_ttl must outlast a long session
config :hearth, Hearth.RTC,
  public_ip: {:system, "RTC_PUBLIC_IP", nil},
  port_range: {:system, "RTC_PORT_RANGE", "50000-50199"},
  turn_url: {:system, "TURN_URL", nil},
  turn_secret: {:system, "TURN_SECRET", nil},
  turn_ttl: 6 * 60 * 60,
  ready_ms: 10_000

# grace_ms is how long a dropped person keeps their place and empty_ms is how long an empty session stays live,
# short so a room everyone left stops showing as live, while an event's room stays live until its time is up
# drain_limit_ms is how long a stopping rtc node keeps its sessions before people rejoin elsewhere
# caption_limit is how many stretches of speech a node turns into live captions at once, the rest are skipped
config :hearth, Hearth.Voice,
  room_limit: {:system, :integer, "VOICE_ROOM_LIMIT", 50},
  grace_ms: 15_000,
  empty_ms: 10_000,
  drain_limit_ms: 2 * 60 * 60 * 1000,
  caption_limit: {:system, :integer, "CAPTION_LIMIT", 2}

if config_env() == :test do
  import_config "#{config_env()}.exs"
end
