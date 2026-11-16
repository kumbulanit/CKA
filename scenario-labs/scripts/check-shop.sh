#!/usr/bin/env bash
# Checks the Shop application in one environment.   ./check-shop.sh dev
env=${1:-dev}
ok=0; bad=0
pass() { echo "  OK    $*"; ok=$((ok+1)); }
fail() { echo "  FAIL  $*"; bad=$((bad+1)); }

echo "Checking the Shop in namespace $env"
notready=$(kubectl get nodes --no-headers | awk '$2 != "Ready"' | wc -l)
[ "$notready" -eq 0 ] && pass "all nodes are Ready" || fail "$notready node(s) not Ready (kubectl get nodes)"
for d in db backend frontend; do
  want=$(kubectl get deployment "$d" -n "$env" -o jsonpath='{.spec.replicas}' 2>/dev/null)
  have=$(kubectl get deployment "$d" -n "$env" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  [ -n "$want" ] && [ "${have:-0}" = "$want" ] && pass "deployment $d: $have/$want ready" \
    || fail "deployment $d: ${have:-0}/${want:-?} ready"
done
for s in db backend frontend; do
  n=$(kubectl get endpointslices -n "$env" -l kubernetes.io/service-name="$s" \
        -o jsonpath='{range .items[*].endpoints[?(@.conditions.ready==true)]}x{end}' 2>/dev/null | wc -c)
  [ "$n" -gt 0 ] && pass "service $s has $n ready pod(s) behind it" || fail "service $s has no ready pods behind it"
done
page=$(kubectl run check-$RANDOM -n "$env" --rm -i --quiet --restart=Never --image=busybox:1.36 \
  -- wget -q -T 5 -O- http://frontend/api/items 2>/dev/null)
echo "$page" | grep -q '"name"' && pass "frontend -> backend -> database returns the items" \
  || fail "frontend -> backend -> database gives no items"
echo
[ "$bad" -eq 0 ] && echo "All $ok checks passed. The Shop works." || echo "$bad check(s) failed."
[ "$bad" -eq 0 ]
