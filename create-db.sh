#!/bin/sh

set -eu

# this will come from somewhere else later
connection="postgresql://postgres:password@localhost:5432"

db_name="${1:-""}"

if [ -z "${db_name}" ]; then
  echo "You must specify a database name as the first argument" >&2
  exit 1
fi

echo "==> Postgres Database Service"
echo "    Database: ${db_name}"

if psql "${connection}" --list --no-align --tuples-only | cut -d"|" -f1 | grep --quiet "^${db_name}\$"; then
  echo "--> Database exists"
else
  echo "--> Creating Database"
  echo "create database :db_name;" | psql "${connection}" -v db_name="${db_name}"
fi

echo "--> Configure Vault"

export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN="vault-root"

vault write "database/roles/${db_name}-reader" \
  db_name="pgds" \
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; \
        GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
  default_ttl="1h" \
  max_ttl="24h"

