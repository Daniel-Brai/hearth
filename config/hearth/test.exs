import Config

config :hearth, Hearth.Instance.Releases,
  req_options: [plug: {Req.Test, Hearth.Instance.Releases}, retry: false]
