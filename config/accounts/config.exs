import Config

# MailDomain lets an address through when DNS is slow instead of calling it invalid
config :email_checker, validations: [EmailChecker.Check.Format]

config :hearth, Hearth.Common.MailDomain, timeout: 3_000

config :hearth, Hearth.Accounts.Taken, rebuild_on_boot: true

if config_env() == :test do
  import_config "#{config_env()}.exs"
end
