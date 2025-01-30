#!/bin/sh

set -eu

db_name="${1:-""}"

if [ -z "${db_name}" ]; then
  echo "You must specify a database name as the first argument" >&2
  exit 1
fi

echo "==> Postgres Database Service"
echo "    Database: ${db_name}"

if psql --list --no-align --tuples-only | cut -d"|" -f1 | grep --quiet "^${db_name}\$"; then
  echo "--> Database exists"
else
  echo "--> Creating Database"
  echo "create database :db_name;" | psql -v "db_name=\"${db_name}\""
fi

echo "--> Configure Vault"

vault write "database/roles/${db_name}-reader" \
  db_name="pg-operator" \
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; \
        GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
  default_ttl="1h" \
  max_ttl="24h"

vault write "database/roles/${db_name}-writer" \
  db_name="pg-operator" \
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; \
        GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE  ON ALL TABLES IN SCHEMA public TO \"{{name}}\"; \
        GRANT SELECT, USAGE ON ALL SEQUENCES IN SCHEMA public to \"{{name}}\";" \
  default_ttl="1h" \
  max_ttl="24h"

vault write "database/roles/${db_name}-maintainer" \
  db_name="pg-operator" \
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; \
        GRANT ALL ON ALL TABLES IN SCHEMA public TO \"{{name}}\"; \
        GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO \"{{name}}\";" \
  default_ttl="1h" \
  max_ttl="24h"

echo "==> Done"
