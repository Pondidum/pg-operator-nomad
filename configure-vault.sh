#!/bin/sh

set -eu

export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN="vault-root"

vault secrets enable database || true

vault write database/config/pgds \
  plugin_name="postgresql-database-plugin" \
  allowed_roles="*" \
  connection_url="postgresql://{{username}}:{{password}}@postgres:5432/postgres" \
  username="postgres" \
  password="password" \
  password_authentication="scram-sha-256"
