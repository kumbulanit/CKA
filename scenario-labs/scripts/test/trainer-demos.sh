#!/usr/bin/env bash
# Tests the two trainer demos that the students only watch:
#   upgrade   Lab 2.6, Step 3: minikube start --kubernetes-version=<new version>, while the Shop
#             is asked for its items every 2 seconds (does it stay open?), then the Step 1 and
#             Step 4 commands and check-shop.sh in dev, uat and prod
#   ha        Lab 2.4: minikube start --ha --nodes=5 (three control plane nodes), in its own
#             profile "ha-demo", then deleted again
#   restore   a fresh course cluster again: minikube delete --all, then setup.sh
#
#   trainer-demos.sh                  all three, in that order
#   trainer-demos.sh upgrade          only the upgrade
#
# The upgrade cannot be undone: run this on a test server, after run-all.sh, never on a student's
# server during the course. Output: ~/labtest/demos.txt (and the screen).

here=$(cd "$(dirname "$0")" && pwd)
L=$(cd "$here/../.." && pwd)
T=${LABTEST_DIR:-$HOME/labtest}
mkdir -p "$T"
out=$T/demos.txt
say() { echo "$*" | tee -a "$out"; }
show() { say "\$ $*"; bash -c "$*" 2>&1 | tee -a "$out"; }

to=${UPGRADE_TO:-$(grep -o 'kubernetes-version=v[0-9.]*' "$L/02-installation/lab-2.6-upgrade.md" | head -1 | cut -d= -f2)}
steps=${*:-upgrade ha restore}

for s in $steps; do
  case $s in
  upgrade)
    say "=== upgrade to $to (Lab 2.6, Step 3)  $(date +%T)"
    show "kubectl get nodes"
    ip=$(minikube ip)
    # ask the Shop (dev, through the NodePort) every 2 seconds while minikube upgrades
    ( while :; do printf '%s %s\n' "$(date +%T)" "$(curl -s -m 2 -o /dev/null -w '%{http_code}' "http://$ip:30080/api/items")"; sleep 2; done ) > "$T/upgrade-shop.txt" 2>&1 &
    watcher=$!
    start=$(date +%s)
    minikube start --kubernetes-version="$to" 2>&1 | tee -a "$out"
    rc=${PIPESTATUS[0]}
    say "minikube start exit $rc after $(( $(date +%s) - start ))s"
    # does the Shop come back by itself? check-shop.sh every 15 seconds, for 10 minutes at most
    envs=$(for ns in dev uat prod; do kubectl get namespace $ns >/dev/null 2>&1 && echo $ns; done)
    back=$(date +%s); bad=x
    while [ -n "$bad" ] && [ $(( $(date +%s) - back )) -lt 600 ]; do
      bad=""; for ns in $envs; do "$L/scripts/check-shop.sh" $ns 2>&1 | tail -1 | grep -q 'All 8' || bad="$bad $ns"; done
      [ -n "$bad" ] && sleep 15
    done
    if [ -z "$bad" ]; then say "after the upgrade, check-shop.sh passes in all environments after $(( $(date +%s) - back ))s"
    else say "after 10 minutes, check-shop.sh still fails in:$bad"; fi
    kill $watcher
    total=$(wc -l < "$T/upgrade-shop.txt"); failed=$(grep -vc ' 200$' "$T/upgrade-shop.txt")
    say "the Shop (dev, port 30080) during the upgrade: $failed of $total requests failed, from $(grep -vm1 ' 200$' "$T/upgrade-shop.txt" | cut -d' ' -f1) to $(grep -v ' 200$' "$T/upgrade-shop.txt" | tail -1 | cut -d' ' -f1)"
    # Step 1 and Step 4 of Lab 2.6, after the upgrade
    show "kubectl version"
    show "kubectl get nodes -o custom-columns=NODE:.metadata.name,KUBELET:.status.nodeInfo.kubeletVersion,RUNTIME:.status.nodeInfo.containerRuntimeVersion"
    show "kubectl get nodes"
    show "kubectl get pods -n kube-system"
    show "kubectl get --raw='/readyz?verbose' | tail -1"
    for ns in dev uat prod; do show "$L/scripts/check-shop.sh $ns | tail -1"; done
    ;;
  ha)
    say "=== three control plane nodes (Lab 2.4): the read-only box of the lab  $(date +%T)"
    show "free -g | head -2"
    # The lab's command, as written, next to an existing cluster: what does minikube say?
    show "minikube start --ha --nodes=5 2>&1 | tail -5"
    minikube stop 2>&1 | tail -1 | tee -a "$out"       # room for five more nodes
    start=$(date +%s)
    minikube start -p ha-demo --ha --nodes=5 --driver=docker 2>&1 | tee -a "$out"
    say "minikube start -p ha-demo exit ${PIPESTATUS[0]} after $(( $(date +%s) - start ))s"
    show "kubectl get nodes"
    show "kubectl get pods -n kube-system -l component=kube-apiserver -o wide"
    show "kubectl -n kube-system exec etcd-ha-demo -- etcdctl --endpoints=https://127.0.0.1:2379 --cacert=/var/lib/minikube/certs/etcd/ca.crt --cert=/var/lib/minikube/certs/etcd/server.crt --key=/var/lib/minikube/certs/etcd/server.key member list"
    show "minikube delete -p ha-demo 2>&1 | tail -1"
    # back to the course cluster, as a trainer does after the demo
    show "kubectl config current-context"
    minikube start 2>&1 | tail -2 | tee -a "$out"
    show "kubectl config current-context"
    show "kubectl get nodes"
    for ns in dev uat prod; do kubectl get namespace $ns >/dev/null 2>&1 || continue
      kubectl rollout status deployment/db deployment/backend deployment/frontend -n $ns --timeout=300s >/dev/null 2>&1
      show "$L/scripts/check-shop.sh $ns | tail -1"; done
    ;;
  restore)
    say "=== a fresh course cluster again  $(date +%T)"
    minikube delete --all 2>&1 | tail -2 | tee -a "$out"
    sudo sed -i '/shop\.local/d' /etc/hosts
    rm -rf ~/thabo ~/exam
    kubectl config delete-context thabo >/dev/null 2>&1; kubectl config delete-user thabo >/dev/null 2>&1
    (cd "$L/.." && sudo ./setup.sh) 2>&1 | tail -4 | tee -a "$out"
    show "$L/scripts/check-ready.sh | tail -1"
    ;;
  esac
done
say "=== done  $(date +%T)"
