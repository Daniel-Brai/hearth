import Config

config :hearth, Oban,
  engine: Oban.Engines.Basic,
  repo: Hearth.Repo,
  prefix: "oban",
  # Nodes tell each other about new jobs over PubSub so it works behind PgBouncer
  notifier: {Oban.Notifiers.Phoenix, pubsub: Hearth.PubSub},
  # A call reaches the node running the model so any node can take the job
  queues: [default: 10, mail: 10, digests: 5, push: 10, media: 4, video: 1, ai: 4, transcribe: 1],
  plugins: [
    # Finished jobs stay a week so a failure can still be looked into
    {Oban.Plugins.Pruner, max_age: 7 * 24 * 60 * 60},
    {Oban.Plugins.Cron,
     crontab: [
       {"@daily", Hearth.Auth.Worker.PurgeTokens},
       {"@daily", Hearth.Instance.Worker.CheckForUpdate},
       {"*/15 * * * *", Hearth.Media.Worker.ExpireUploads},
       {"@hourly", Hearth.RateLimit.Worker.DeleteFullBuckets},
       {"* * * * *", Hearth.Voice.Worker.Reaper},
       {"@hourly", Hearth.Notifications.Worker.ScheduleDigests},
       {"@daily", Hearth.Notifications.Worker.PruneRead}
     ]}
  ]

if config_env() == :test do
  import_config "#{config_env()}.exs"
end
