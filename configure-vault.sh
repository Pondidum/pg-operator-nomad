#!/bin/sh

set -eu

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
