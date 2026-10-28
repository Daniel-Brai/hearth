#!/bin/sh
# Compose passes blank .env keys as empty strings, which Hearth reads as set
# Unset them so they keep their defaults
# awk lists the names since it reads a multiline value like a PEM key as one
for key in $(awk 'BEGIN { for (name in ENVIRON) if (ENVIRON[name] == "" && name ~ /^[A-Za-z_][A-Za-z0-9_]*$/) print name }'); do
  unset "$key"
done

exec "$@"
