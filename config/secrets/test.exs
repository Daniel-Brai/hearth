import Config

config :secrets, Secrets.HashiCorp,
  address: "http://vault.test",
  req_options: [plug: {Req.Test, Secrets.HashiCorp}, retry: false]
