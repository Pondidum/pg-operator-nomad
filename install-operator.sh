#!/bin/sh

set -eu

log() {
  echo "$@" >&2
}

verify_vault() {
  if [ -z "${VAULT_ADDR:-""}" ]; then
    log "VAULT_ADDR must be set; and will be passed to the pg-operator nomad job"
    exit 1
  fi

  if ! vault token lookup >/dev/null 2>&1; then
    log "You must be authenticated to vault to run this script."
    log "Check VAULT_ADDR and VAULT_TOKEN, or run 'vault login...'"
    exit 1
  fi

  log "    Vault okay"
}

verify_nomad() {
  if ! nomad status >/dev/null 2>&1; then
    log "You must be authenticated to nomad to run this script."
    exit 1
  fi

  log "    Nomad okay"
}

verify_postgres() {
  if ! psql --list >/dev/null 2>&1; then
    log "You must be authenticated to postgres to run this script."
    log "The script will create a new postgres role and password for vault to use"
    exit 1
  fi

  if [ -z "${PGHOST:-""}" ]; then
    log "PGHOST must be set for configuring vault."
    exit 1
  fi

  log "    Postgres okay"
}

print_auth_methods() {
  auth_json="$1"
  log "Possible values:"
  echo "${auth_json}" | jq -r ". | keys | .[]" | tr '/' ' ' >&2
}

validate_auth_method() {
  auth_method="$1"
  auth_json=$(vault auth list -format=json)

  if [ -z "${auth_method}" ]; then
    log "You must specify the Nomad auth backend (usually 'jwt-nomad')"
    print_auth_methods "${auth_json}"
    exit 1
  fi

  accessor=$(echo "${auth_json}" | jq -r ".[\"${auth_method}/\"].accessor")
  if [ -z "${accessor}" ]; then
    log "Unable to find an auth method accessor.  Possibe values:"
    print_auth_methods "${auth_json}"
    exit 1
  fi

  echo "${accessor}"
}

configure_vault_roles() {
  auth_method="$1"
  accessor="$2"

  log "    Writing pg-operator policy to Vault"
  echo $(cat <<-EOF
  path "database/creds/operator" {
    capabilities = ["read"]
  }

  path "database/config/*" {
    capabilities = ["read", "list", "create", "update", "patch"]
  }

  path "database/roles/*" {
    capabilities = ["create", "read", "update", "patch", "delete", "list"]
  }


EOF
) | vault policy write "pg-operator" "-" > /dev/null

  log "    Writing pg-operator-jobs policy to Vault"
  echo $(cat <<-EOF
  path "database/creds/{{ identity.entity.aliases.${accessor}.metadata.nomad_job_id }}-*" {
    capabilities = ["read"]
  }
EOF
) | vault policy write "pg-operator-jobs" "-" > /dev/null

  default_role=$(vault read -field default_role "auth/${auth_method}/config")

  log "    Adding pg-operator-jobs policy to nomad default ${default_role}"
  vault read -format=json "auth/${auth_method}/role/${default_role}" \
    | jq '.data.token_policies += ["pg-operator-jobs"] | .data' \
    | vault write "auth/${auth_method}/role/${default_role}" "-" > /dev/null

  log "    Creating pg-operator role"
  vault read -format=json "auth/${auth_method}/role/${default_role}" \
    | jq '.data.token_policies += ["pg-operator-jobs", "pg-operator"] | .data' \
    | vault write "auth/${auth_method}/role/pg-operator" "-" > /dev/null
}

generate_password() {
  password=$(uuidgen)

  log "    operator password: ${password}"

  echo "${password}"
}

create_postgres_role() {
  password="$1"

  psql -c  "
    do \$\$
    begin
      create role \"pg-operator\" with login password '${password}' createrole createdb superuser;
    exception when duplicate_object then
      alter user \"pg-operator\" with password '${password}';
    end
    \$\$;"
}

configure_database_backend() {
  password="$1"

  if ! vault secrets list -format json | jq --exit-status '.["database/"]' > /dev/null; then
    log "--> Enabling Database backend"
    vault secrets enable database > /dev/null
  fi

  log "    Configuring Database backend"

  vault write database/config/pg-operator \
    plugin_name="postgresql-database-plugin" \
    allowed_roles="*" \
    connection_url="postgresql://{{username}}:{{password}}@${PGHOST}:5432/postgres" \
    username="pg-operator" \
    password="${password}" \
    password_authentication="scram-sha-256" > /dev/null

  vault write "database/roles/operator" \
    db_name="pg-operator" \
    creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' SUPERUSER CREATEDB CREATEROLE VALID UNTIL '{{expiration}}';" \
    default_ttl="1h" \
    max_ttl="24h"
}

generate_operator() {

  jq \
    --arg vault "${VAULT_ADDR}" \
    --arg postgres "${PGHOST}" \
    '.TaskGroups[].Tasks[].Env |= . + { VAULT_ADDR: $vault, PGHOST: $postgres}' \
    "pg-operator.tpl.json" \
  > "pg-operator.json"

  log "    Job written to 'pg-operator.json'"
  log "    Install by running:"
  log "      nomad job run -json pg-operator.json"
}

main() {
  log "==> Operator installer"
  log "--> Validating environment"
  verify_vault
  verify_postgres
  verify_nomad

  log "--> Done"

  auth_method="${1:-""}"
  accessor=$(validate_auth_method "${auth_method}")

  configure_vault_roles "${auth_method}" "${accessor}"

  password=$(generate_password)
  create_postgres_role "${password}"
  configure_database_backend "${password}"

  generate_operator

  echo "==> Done"
}

main "$@"
