#!/bin/bash
# kube-proxy raises the kernel's conntrack limit at start-up. Inside a container that write is
# denied, so kube-proxy crashes after a plain `kubeadm init`. kind avoids it with
# `conntrack.maxPerCore: 0` (leave the kernel setting alone); this applies the same setting to the
# cluster's kube-proxy ConfigMap as soon as it exists, so the course's commands work unchanged.
# Not needed on real machines. Runs on every node; only control plane nodes have admin.conf.
export KUBECONFIG=/etc/kubernetes/admin.conf
while sleep 5; do
  [ -f "$KUBECONFIG" ] && command -v kubectl >/dev/null || continue
  cfg=$(kubectl -n kube-system get configmap kube-proxy -o jsonpath='{.data.config\.conf}' 2>/dev/null) || continue
  if grep -q 'maxPerCore: null' <<<"$cfg"; then
    kubectl -n kube-system get configmap kube-proxy -o yaml | sed 's/maxPerCore: null/maxPerCore: 0/' | kubectl replace -f - &&
      kubectl -n kube-system delete pod -l k8s-app=kube-proxy --wait=false
  fi
done
