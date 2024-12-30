#!/bin/sh

set -eu

auth_json=$(vault auth list -format=json )

auth_method="${1:-""}"

if [ -z "${auth_method}" ]; then
  echo "You must specify the Nomad auth backend (usually 'jwt-nomad')"
  echo "Possible values:"
  echo "${auth_json}" | jq -r ". | keys | .[]" | tr '/' ' '
  exit 1
fi

echo "==> Configuring Vault"

accessor=$(echo "${auth_json}" | jq -r ".[\"${auth_method}/\"].accessor")
if [ -z "${accessor}" ]; then
  echo "Unable to find an auth method accessor.  Possibe values:"
  echo "Possible values:"
  echo "${auth_json}" | jq -r ". | keys | .[]" | tr '/' ' '
  exit 1
fi

echo "    Accessor: ${accessor}"

policy_name="pg-operator-accessor"

echo "    Policy name: ${policy_name}"
echo "    Writing database credentials policy"

echo $(cat <<-EOF
path "database/creds/{{ identity.entity.aliases.${accessor}.metadata.nomad_job_id }}-*" {
  capabilities = ["read"]
}
EOF
) | vault policy write "${policy_name}" "-" > /dev/null

echo "    Configuring default Nomad role"

role=$(vault read -field default_role "auth/${auth_method}/config")
echo "    Default role: ${role}"

vault read -format=json "auth/${auth_method}/role/${role}" \
  | jq ".data.token_policies += [\"${policy_name}\"] | .data" \
  | vault write "auth/${auth_method}/role/${role}" "-" > /dev/null

if ! vault secrets list -format json | jq --exit-status '.["database/"]' > /dev/null; then
  echo "--> Enabling Database backend"
  vault secrets enable database > /dev/null 
fi

echo "    Configuring Database backend"

vault write database/config/pg-operator \
  plugin_name="postgresql-database-plugin" \
  allowed_roles="*" \
  connection_url="postgresql://{{username}}:{{password}}@localhost:5432/postgres" \
  username="postgres" \
  password="password" \
  password_authentication="scram-sha-256" > /dev/null

echo "==> Done"
