#!/usr/bin/env bash
# Builds the complete Shop application in one environment (namespace), with everything from the course.
# Use it to catch up, or to start Day 4.   ./deploy-shop.sh dev     (or uat, or prod)
set -euo pipefail
env=${1:-dev}
case "$env" in dev|uat|prod) ;; *) echo "use: $0 dev|uat|prod"; exit 1 ;; esac
here=$(cd "$(dirname "$0")" && pwd)
labs=$(dirname "$here")
pv=$labs/07-storage/db-pv-$env.yaml

echo "==> Namespace $env"
# Only when it is missing: "apply" on a namespace made with "kubectl create" (Lab 1.1) prints a warning.
kubectl get namespace "$env" >/dev/null 2>&1 || kubectl create namespace "$env"
echo "==> Database password (Secret db-secret)"
kubectl get secret db-secret -n "$env" >/dev/null 2>&1 \
  || kubectl create secret generic db-secret -n "$env" --from-literal=password="$env-pass-123"
echo "==> Disk for the database"
kubectl apply -f "$labs/07-storage/db-storageclass.yaml"
kubectl apply -f "$pv"
echo "==> Limits and quota"
kubectl apply -n "$env" -f "$labs/07-storage/limitrange.yaml" -f "$labs/07-storage/quota.yaml"
echo "==> The application"
kubectl apply -n "$env" -f "$labs/shop-complete/"
# in dev the frontend is also reachable from the server, on port 30080 of a node
[ "$env" = dev ] && kubectl patch service frontend -n dev \
  -p '{"spec":{"type":"NodePort","ports":[{"port":80,"targetPort":80,"nodePort":30080}]}}'
echo "==> Network policies"
kubectl apply -n "$env" -f "$labs/03-networking/netpol-default-deny.yaml" -f "$labs/03-networking/netpol-allow-app.yaml"
echo "==> Waiting for the pods"
kubectl rollout status deployment/db deployment/backend deployment/frontend -n "$env" --timeout=300s
echo
kubectl get pods -n "$env"
echo
echo "Done. Test it:  $here/check-shop.sh $env"
