import Config

config :hearth, Hearth.Common.MailDomain, lookups: false

# A query at boot would race the sandbox
config :hearth, Hearth.Accounts.Taken, rebuild_on_boot: false
