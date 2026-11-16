#!/usr/bin/env bash
# Puts one fault into the Shop, for the troubleshooting labs.   ./break.sh 3      (faults 1 to 6)
# ./break.sh all   puts in faults 1 to 5.     Your job: find it, fix it, explain it.
set -euo pipefail
env=${SHOP_ENV:-dev}
n=${1:-}
q() { "$@" >/dev/null 2>&1; }

fault() {
  case "$1" in
    1) q kubectl set image deployment/frontend frontend=nginx:1.27-alpnie -n "$env" ;;
    2) q kubectl patch service backend -n "$env" -p '{"spec":{"selector":{"app":"backend-api"}}}' ;;
    3) q kubectl patch deployment backend -n "$env" --type=json -p \
         '[{"op":"replace","path":"/spec/template/spec/containers/0/env/0/valueFrom/secretKeyRef/name","value":"db-secrets"}]' ;;
    4) q kubectl patch resourcequota env-quota -n "$env" -p '{"spec":{"hard":{"pods":"2"}}}'
       q kubectl delete pod -n "$env" -l app=frontend --wait=false ;;
    5) q kubectl patch networkpolicy allow-backend-to-db -n "$env" --type=json -p \
         '[{"op":"replace","path":"/spec/ingress/0/ports/0/port","value":5433}]'
       q kubectl delete pod -n "$env" -l app=backend --wait=false ;;
    6) q minikube ssh -n minikube-m03 -- sudo systemctl stop kubelet ;;
    *) echo "use: $0 1|2|3|4|5|6|all"; exit 1 ;;
  esac
}

if [ "$n" = all ]; then
  for i in 1 2 3 4 5; do fault "$i"; done
  echo "Five faults are now in the Shop (namespace $env). Find and fix them all."
else
  fault "$n"
  echo "Fault $n is now in the Shop (namespace $env). Something is broken. Find it and fix it."
  [ "$n" = 6 ] && echo "(This one takes about a minute to show.)"
fi
echo "Check your work with:  ./check-shop.sh $env"
