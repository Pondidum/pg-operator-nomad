#!/bin/sh

set -eu

echo "==> Configuring Nomad ACL"

export NOMAD_ADDR=http://localhost:4646

# secret=$(nomad acl bootstrap -t '{{ .SecretID }}')
# export NOMAD_TOKEN="$secret"


echo "==> Configuring Vault"

export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN="vault-root"

vault auth enable -path 'jwt-nomad' 'jwt' || true 

echo '{
  "jwks_url": "http://127.0.0.1:4646/.well-known/jwks.json",
  "jwt_supported_algs": ["RS256", "EdDSA"],
  "default_role": "nomad-workloads"
}' | vault write auth/jwt-nomad/config -


echo '{
  "role_type": "jwt",
  "bound_audiences": ["vault.io"],
  "user_claim": "/nomad_job_id",
  "user_claim_json_pointer": true,
  "claim_mappings": {
    "nomad_namespace": "nomad_namespace",
    "nomad_job_id": "nomad_job_id",
    "nomad_task": "nomad_task"
  },
  "token_type": "service",
  "token_policies": ["nomad-workloads"],
  "token_period": "30m",
  "token_explicit_max_ttl": 0
}
' | vault write auth/jwt-nomad/role/nomad-workloads -

accessor=$(vault auth list -format=json | jq -r '.["jwt-nomad/"].accessor')

echo $(cat <<-EOF
path "kv/data/{{identity.entity.aliases.${accessor}.metadata.nomad_namespace}}/{{identity.entity.aliases.${accessor}.metadata.nomad_job_id}}/*" {
  capabilities = ["read"]
}

path "kv/data/{{identity.entity.aliases.${accessor}.metadata.nomad_namespace}}/{{identity.entity.aliases.${accessor}.metadata.nomad_job_id}}" {
  capabilities = ["read"]
}

path "kv/metadata/{{identity.entity.aliases.${accessor}.metadata.nomad_namespace}}/*" {
  capabilities = ["list"]
}

path "kv/metadata/*" {
  capabilities = ["list"]
}

path "database/creds/{{ identity.entity.aliases.${accessor}.metadata.nomad_job_id }}-*" {
  capabilities = ["read"]
}
EOF
) | vault policy write 'nomad-workloads' -



vault secrets enable database || true

vault write database/config/pgds \
  plugin_name="postgresql-database-plugin" \
  allowed_roles="*" \
  connection_url="postgresql://{{username}}:{{password}}@localhost:5432/postgres" \
  username="postgres" \
  password="password" \
  password_authentication="scram-sha-256"
