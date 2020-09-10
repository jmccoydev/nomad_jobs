#!/bin/bash -l
set -ex
###########
# Set Vault env vars for client usage
###########
export VAULT_IP="server-a-1"
export VAULT_ADDR="http://$VAULT_IP:8200"
export VAULT_TOKEN="root"
echo "export VAULT_ADDR=$VAULT_ADDR" >> /root/.bashrc
echo "export VAULT_TOKEN=$VAULT_TOKEN" >> /root/.bashrc

###########
# Wait for Vault to start
###########
# sleep 10


###########
# Set up the Kubernetes auth method with k3s
###########
vault auth enable kubernetes

export SA_NAME="products-api"
export SA_NAMESPACE=$(kubectl get sa $SA_NAME -o jsonpath="{.metadata.namespace}")
export VAULT_SECRET_NAME=$(kubectl get sa $SA_NAME -o jsonpath="{.secrets[*]['name']}")
export SA_JWT_TOKEN=$(kubectl get secret $VAULT_SECRET_NAME -o jsonpath="{.data.token}" | base64 --decode; echo)
export SA_CA_CRT="$(kubectl get secret $VAULT_SECRET_NAME -o jsonpath="{.data['ca\.crt']}" | base64 --decode; echo)"
export K8S_HOST=$(kubectl get svc kubernetes -o=json | jq -r .spec.clusterIP)

# Tell Vault how to communicate with the Kubernetes cluster
# vault write auth/kubernetes/config \
#   token_reviewer_jwt="$SA_JWT_TOKEN" \
#   kubernetes_host="https://$K8S_HOST:443" \
#   kubernetes_ca_cert="$SA_CA_CRT"

# Create a role to map Kubernetes Service Account to Vault policies and default token TTL
# vault write auth/kubernetes/role/$SA_NAME \
#   bound_service_account_names=$SA_NAME \
#   bound_service_account_namespaces="$SA_NAMESPACE" \
#   policies=products-api \
#   ttl=24h

###########
# Seed Secrets
###########
# vault secrets enable kv

# Create the KV secrets engine for static secrets
vault secrets enable -path="kv" kv

# Place an example secret in a "shared" mount to demo a bad secret management practice
mkdir -p /share/
echo "username=postgres
password=password" > /share/postgres-product-creds.txt

# Don't change the password here, the user will update it in a challenge.
vault kv put kv/db/postgres/product-db-creds username=postgres password=replacemeplz


###########
# User Policies
###########

mkdir -p /root/policies/

tee /root/policies/dba-operator-policy.hcl <<EOF
path "kv/db/*" {
  capabilities = ["list", "read", "create", "update"]
}
EOF

tee /root/policies/operator-policy.hcl <<EOF
path "kv/api/*" {
  capabilities = ["list", "read", "create", "update"]
}
EOF

tee /root/policies/security-policy.hcl <<EOF
path "kv/db/*" {
  capabilities = ["read"]
}
path "kv/api/*" {
  capabilities = ["read"]
}
EOF

###########
# Service Policies
###########
tee /root/policies/products-api-policy.hcl <<EOF
path "kv/db/postgres/product-db-creds" {
  capabilities = ["read"]
}
EOF

vault policy write products-api /root/policies/products-api-policy.hcl