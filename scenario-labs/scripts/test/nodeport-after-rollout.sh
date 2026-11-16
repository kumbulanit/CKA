#!/bin/bash
# After a rollout of the frontend: how long do requests to the NodePort fail?
# usage: nodeport-after-rollout.sh [seconds to sleep after rollout status]
pause=${1:-0}
kubectl rollout restart deploy/frontend -n dev >/dev/null
kubectl rollout status deploy/frontend -n dev >/dev/null
[ "$pause" -gt 0 ] && sleep "$pause"
ip=$(minikube ip)
s=$(date +%s); fails=0
for i in $(seq 1 30); do
  c=$(curl -s -m 3 -o /dev/null -w '%{http_code}' "http://$ip:30080/api/items")
  [ "$c" = 200 ] || fails=$((fails + 1))
  printf '%ss:%s ' $(( $(date +%s) - s )) "$c"
  sleep 1
done
echo; echo "pause ${pause}s: $fails of 30 requests failed"
