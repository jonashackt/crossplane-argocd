#!/usr/bin/env bash
set -euo pipefail

echo "### This Script will prepare a K8s Secret with a ArgoCD API Token for Crossplane ArgoCD Provider (be sure to have a service/argocd-server 8443:443 running before)"

echo "--- Extract ArgoCD password"
ARGOCD_ADMIN_SECRET=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo)

echo "--- Create temporary JWT token for the provider-argocd user"
ARGOCD_ADMIN_TOKEN=$(curl -s -X POST -k -H "Content-Type: application/json" --data '{"username":"admin","password":"'$ARGOCD_ADMIN_SECRET'"}' https://localhost:8443/api/v1/session | jq -r .token)

echo "--- Create ArgoCD API Token"
ARGOCD_API_TOKEN=$(curl -s -X POST -k -H "Authorization: Bearer $ARGOCD_ADMIN_TOKEN" -H "Content-Type: application/json" https://localhost:8443/api/v1/account/provider-argocd/token | jq -r .token)

echo "--- Already create a namespace for crossplane for the Secret (if not already exist, see https://stackoverflow.com/a/65411733/4964553)"
kubectl create namespace crossplane-system --dry-run=client -o yaml | kubectl apply -f -

echo "--- Create Secret containing the ARGOCD_API_TOKEN for Crossplane ArgoCD Provider"
kubectl create secret generic argocd-credentials -n crossplane-system --from-literal=authToken="$ARGOCD_API_TOKEN"

