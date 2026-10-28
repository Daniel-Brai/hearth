import Config

config :secrets, Secrets,
  file: {:system, "SECRETS_FILE", nil},
  env: {:system, "SECRETS_ENV", "production"}

# VAULT_AUTH is kubernetes or approle (role id and secret id in files) or token (VAULT_TOKEN)
config :secrets, Secrets.HashiCorp,
  address: {:system, "VAULT_ADDR", nil},
  namespace: {:system, "VAULT_NAMESPACE", nil},
  auth: {:system, "VAULT_AUTH", "kubernetes"},
  auth_mount: {:system, "VAULT_AUTH_MOUNT", nil},
  role: {:system, "VAULT_ROLE", "hearth"},
  jwt_file: {:system, "VAULT_JWT_FILE", "/var/run/secrets/kubernetes.io/serviceaccount/token"},
  role_id_file: {:system, "VAULT_ROLE_ID_FILE", nil},
  secret_id_file: {:system, "VAULT_SECRET_ID_FILE", nil},
  token: {:system, "VAULT_TOKEN", nil}

if config_env() == :test do
  import_config "#{config_env()}.exs"
end
