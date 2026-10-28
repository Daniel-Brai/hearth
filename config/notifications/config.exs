import Config

config :hearth, Hearth.Notifications,
  from: {:system, "MAIL_FROM", "noreply@hearth.localhost"},
  from_name: {:system, "MAIL_FROM_NAME", nil}

# Dev keeps sent emails in memory, readable at /dev/mailbox
config :hearth, Hearth.Notifications.Mailer, adapter: Swoosh.Adapters.Local

# Web push is on only when both VAPID keys are set
config :hearth, Hearth.Notifications.WebPush,
  public_key: {:system, "VAPID_PUBLIC_KEY", nil},
  private_key: {:system, "VAPID_PRIVATE_KEY", nil},
  subject: {:system, "VAPID_SUBJECT", "mailto:push@localhost"}

import_config "#{config_env()}.exs"
