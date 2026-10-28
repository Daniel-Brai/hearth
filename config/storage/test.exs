import Config

config :hearth, Hearth.Storage,
  adapter: "local",
  local_root: Path.join(System.tmp_dir!(), "hearth-storage-test"),
  local_url: "http://localhost:4002",
  bucket: "hearth-test",
  endpoint: "https://s3.test",
  region: "auto",
  access_key_id: "test-key",
  secret_access_key: "test-secret",
  path_style: true,
  checksums: true,
  req_options: [plug: {Req.Test, Hearth.Storage.S3}, retry: false]
