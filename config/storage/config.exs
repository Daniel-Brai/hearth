import Config

# local keeps files in a folder and s3 uses any S3 compatible store
config :hearth, Hearth.Storage,
  adapter: {:system, "STORAGE", "local"},
  local_root: {:system, "STORAGE_PATH", Path.expand("../../storage", __DIR__)},
  local_url: {:system, "API_URL", "http://localhost:4000"},
  bucket: {:system, "S3_BUCKET", "hearth"},
  endpoint: {:system, "S3_ENDPOINT", "https://s3.amazonaws.com"},
  region: {:system, "S3_REGION", "auto"},
  access_key_id: {:system, "S3_ACCESS_KEY_ID", nil},
  secret_access_key: {:system, "S3_SECRET_ACCESS_KEY", nil},
  path_style: {:system, :boolean, "S3_PATH_STYLE", false},
  # Turn it off for stores that don't check x-amz-checksum-sha256
  checksums: {:system, :boolean, "S3_CHECKSUMS", true}

config :ex_aws,
  http_client: ExAws.Request.Req,
  json_codec: Jason

if config_env() == :test do
  import_config "#{config_env()}.exs"
end
