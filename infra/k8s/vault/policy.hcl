# Read only access to one environment's secrets, with ENV filled in by setup.sh
path "hearth/data/ENV/*" {
  capabilities = ["read"]
}

path "hearth/metadata/ENV/*" {
  capabilities = ["list"]
}
