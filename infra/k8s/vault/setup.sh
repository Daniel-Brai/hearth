#!/bin/sh
# Prepares Vault for one environment, run with the vault CLI signed in as
# someone who may change mounts, auth and policies
#
#     ENV=production NAMESPACE=hearth ./setup.sh
#
# Pass APPROLE=1 to also make an AppRole for the Compose setup
# Secret values are put in with `vault kv put`, as the README shows
set -eu

ENV=${ENV:?set ENV, such as staging or production}
NAMESPACE=${NAMESPACE:-hearth}
SERVICE_ACCOUNT=${SERVICE_ACCOUNT:-hearth}
ROLE=${ROLE:-hearth}
AUTH_MOUNT=${AUTH_MOUNT:-kubernetes}
here=$(cd "$(dirname "$0")" && pwd)

vault secrets list -format=json | grep -q '"hearth/"' \
  || vault secrets enable -path=hearth -version=2 kv

sed "s/ENV/$ENV/g" "$here/policy.hcl" | vault policy write "hearth-$ENV" -

# Inside the cluster Vault's own service account reviews tokens, so only the host is needed
vault auth list -format=json | grep -q "\"$AUTH_MOUNT/\"" \
  || vault auth enable -path="$AUTH_MOUNT" kubernetes

if [ -n "${KUBERNETES_HOST:-}" ]; then
  vault write "auth/$AUTH_MOUNT/config" kubernetes_host="$KUBERNETES_HOST"
fi

vault write "auth/$AUTH_MOUNT/role/$ROLE" \
  bound_service_account_names="$SERVICE_ACCOUNT" \
  bound_service_account_namespaces="$NAMESPACE" \
  token_policies="hearth-$ENV" \
  token_ttl=15m \
  audience=vault

if [ "${APPROLE:-}" = 1 ]; then
  vault auth list -format=json | grep -q '"approle/"' || vault auth enable approle
  vault write "auth/approle/role/hearth-$ENV" token_policies="hearth-$ENV" token_ttl=15m
  echo "Role id and secret id for Compose go in files, not in .env:"
  echo "  vault read -field=role_id auth/approle/role/hearth-$ENV/role-id > vault-role-id"
  echo "  vault write -f -field=secret_id auth/approle/role/hearth-$ENV/secret-id > vault-secret-id"
fi
