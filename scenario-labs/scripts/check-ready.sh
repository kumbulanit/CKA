#!/usr/bin/env bash
# Checks that everything the labs need is there and running: the server, the tools, the cluster
# and its parts, and the Shop. It only looks; it changes nothing. Run it as your own user:
#
#   ~/CKA/scenario-labs/scripts/check-ready.sh
#
# Every line says OK, WARN (it works, but look at it), FAIL (fix it before you go on) or INFO.
# Under a WARN or FAIL line, "fix:" says what to do.

fails=0; warns=0
ok()      { printf '  OK    %s\n' "$1"; }
info()    { printf '  INFO  %s\n' "$1"; }
warn()    { printf '  WARN  %s\n' "$1"; [ -z "${2:-}" ] || printf '        fix: %s\n' "$2"; warns=$((warns+1)); }
fail()    { printf '  FAIL  %s\n' "$1"; [ -z "${2:-}" ] || printf '        fix: %s\n' "$2"; fails=$((fails+1)); }
section() { printf '\n%s\n' "$1"; }
kc()      { kubectl --context minikube --request-timeout=10s "$@"; }
setup="cd ~/CKA && sudo ./setup.sh"
scripts=$(cd "$(dirname "$0")" && pwd)

echo "Checking your server and cluster for the labs (about 30 seconds)."

# ---------------------------------------------------------------------------------------------
section "Server"
[ "$(id -u)" -ne 0 ] || fail "you run this as root" "run it without sudo, as your own user"

. /etc/os-release 2>/dev/null
if [ "${ID:-}" = ubuntu ] && [ "$(printf '%s\n24.04\n' "$VERSION_ID" | sort -V | head -1)" = 24.04 ]; then
  ok "Ubuntu $VERSION_ID"
else
  warn "${PRETTY_NAME:-unknown system}: the labs are written for Ubuntu 24.04 or newer"
fi

cpus=$(nproc)
if   [ "$cpus" -ge 4 ]; then ok "$cpus CPUs"
elif [ "$cpus" -ge 2 ]; then warn "$cpus CPUs: 4 are recommended, the cluster will be slow"
else fail "$cpus CPU: minikube needs at least 2" "use a server with 4 CPUs"; fi

mem=$(awk '/MemTotal/ { print int($2 / 1024) }' /proc/meminfo)
memgb=$(awk -v m="$mem" 'BEGIN { printf "%.1f", m / 1024 }')
if   [ "$mem" -ge 7000 ]; then ok "$memgb GB memory"
elif [ "$mem" -ge 3500 ]; then warn "$memgb GB memory: 8 GB is recommended; Lab 6.4 (Prometheus) needs it" "use a server with 8 GB"
else fail "$memgb GB memory: too little for a cluster with 3 nodes" "use a server with 8 GB"; fi

disk=$(df -P -BG /var/lib/docker 2>/dev/null || df -P -BG /)
disk=$(awk 'NR == 2 { sub("G", "", $4); print $4 }' <<<"$disk")
if   [ "$disk" -ge 10 ]; then ok "$disk GB free disk space"
elif [ "$disk" -ge 5 ];  then warn "only $disk GB free disk space" "free some disk space on the server"
else fail "only $disk GB free disk space: new pods cannot start" "free some disk space on the server"; fi

code=$(curl -s -m 8 -o /dev/null -w '%{http_code}' https://registry-1.docker.io/v2/ 2>/dev/null)
if [ "${code:-000}" != 000 ]; then ok "internet: images can be downloaded from Docker Hub"
else fail "no connection to Docker Hub (registry-1.docker.io): pods cannot download their images" \
       "check the network (or proxy) of the server"; fi

# ---------------------------------------------------------------------------------------------
section "Tools"
if ! command -v docker >/dev/null; then
  fail "Docker is not installed" "$setup"
elif derr=$(docker info 2>&1 >/dev/null); then
  ok "Docker $(docker version --format '{{.Server.Version}}' 2>/dev/null) runs, and you may use it without sudo"
elif grep -qi 'permission denied' <<<"$derr"; then
  fail "you may not use Docker without sudo yet" "newgrp docker   (or log out and in again)"
else
  fail "Docker does not run" "sudo systemctl start docker"
fi

have_kubectl=0
for tool in minikube kubectl helm jq; do
  if ! command -v "$tool" >/dev/null; then fail "$tool is not installed" "$setup"; continue; fi
  case $tool in
    minikube) v=$(minikube version --short 2>/dev/null) ;;
    kubectl)  v=$(kubectl version --client 2>/dev/null | awk 'NR == 1 { print $3 }'); have_kubectl=1 ;;
    helm)     v=$(helm version --short 2>/dev/null); v=${v%%+*} ;;
    jq)       v=$(jq --version 2>/dev/null); v=${v#jq-} ;;
  esac
  ok "$tool $v"
done
if command -v kubens >/dev/null && command -v kubectx >/dev/null; then
  ok "shortcuts kubens and kubectx"
else
  warn "the shortcuts kubens and kubectx are not installed (you do not need them)" "sudo apt-get install -y kubectx"
fi

# ---------------------------------------------------------------------------------------------
section "Cluster"
api=0
if ! command -v minikube >/dev/null || [ "$have_kubectl" = 0 ]; then
  fail "skipped: minikube or kubectl is missing" "$setup"
else
  # minikube status: one entry per node, with the state of the node and of its kubelet.
  st=$(minikube status -o json 2>/dev/null)
  nodes_mk=$(jq -r '(if type == "array" then .[] else . end)
    | select(type == "object" and has("Host")) | "\(.Name) \(.Host) \(.Kubelet)"' <<<"$st" 2>/dev/null)
  stopped=$(awk '$2 != "Running" || $3 != "Running" { printf "%s ", $1 }' <<<"$nodes_mk")
  if [ -z "$nodes_mk" ]; then
    fail "there is no cluster, or minikube cannot see it" "$setup"
  elif [ -n "$stopped" ]; then
    fail "stopped node(s): ${stopped% }" "$setup"
  else
    ok "minikube: $(wc -l <<<"$nodes_mk") nodes are running"
  fi

  ctx=$(kubectl config current-context 2>/dev/null)
  if [ "$ctx" = minikube ]; then ok "kubectl uses the cluster (context minikube)"
  else fail "kubectl uses the context '${ctx:-none}', not minikube" "kubectl config use-context minikube   (or: kubectx minikube)"; fi

  if [ "$(kc get --raw /readyz 2>/dev/null)" = ok ]; then
    ok "the API server answers"; api=1
  else
    fail "the API server does not answer" "wait one minute and check again; still failing: $setup"
  fi
fi

if [ "$api" = 1 ]; then
  nodes=$(kc get nodes --no-headers 2>/dev/null)
  count=$(grep -c . <<<"$nodes")
  notready=$(awk '$2 !~ /^Ready/ { printf "%s ", $1 }' <<<"$nodes")
  cordoned=$(awk '$2 ~ /SchedulingDisabled/ { printf "%s ", $1 }' <<<"$nodes")
  if [ -n "$notready" ]; then
    fail "node(s) not Ready: ${notready% }" "wait one minute and check again; still not Ready: $setup"
  elif [ "$count" -lt 3 ]; then
    warn "only $count node(s) are Ready; the labs expect 3" "$setup   (it adds the missing nodes)"
  else
    ok "$count nodes, all Ready"
  fi
  [ -z "$cordoned" ] || warn "cordoned node(s), they take no new pods: ${cordoned% }" "kubectl uncordon ${cordoned% }"

  # The parts of the cluster: one line each, with how many of their pods are ready.
  sys=$(kc get pods -n kube-system --no-headers 2>/dev/null)
  for c in etcd kube-apiserver kube-controller-manager kube-scheduler coredns calico-node calico-kube-controllers kube-proxy storage-provisioner; do
    read -r total ready <<<"$(awk -v c="$c" '$1 == c || index($1, c "-") == 1 {
        t++; split($2, r, "/"); if ($3 == "Running" && r[1] == r[2]) n++ } END { print t + 0, n + 0 }' <<<"$sys")"
    if [ "$total" -eq 0 ]; then
      fail "$(printf '%-24s' "$c") not found" "$setup"
    elif [ "$ready" -lt "$total" ]; then
      fail "$(printf '%-24s' "$c") $ready of $total pod(s) ready" "kubectl get pods -n kube-system   then: kubectl describe pod <name> -n kube-system"
    else
      ok "$(printf '%-24s' "$c") $ready of $total pod(s) ready"
    fi
  done

  # A real test: a pod must start on a node, download its image and find a Service by name.
  testpod="ready-check-$RANDOM"
  dns=$(timeout 150 kubectl --context minikube run "$testpod" -n default --rm -i --quiet \
          --restart=Never --image=busybox:1.36 --pod-running-timeout=120s \
          -- nslookup kubernetes.default.svc.cluster.local 2>&1)
  if grep -q '^Name:.*kubernetes.default' <<<"$dns"; then
    ok "a test pod starts, downloads its image and finds Services by name (DNS)"
  else
    fail "a test pod could not start, or could not use DNS" \
         "look at the internet check above, and at: kubectl get pods -n kube-system -l k8s-app=kube-dns"
    kc delete pod "$testpod" -n default --now >/dev/null 2>&1
  fi

  sc=$(kc get storageclass -o jsonpath='{range .items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")]}{.metadata.name} {end}')
  if [ -n "$sc" ]; then ok "storage: default StorageClass ${sc% } (disks on request)"
  else warn "no default StorageClass: disks on request (Lab 7.3) do not work" "minikube addons enable default-storageclass"; fi

  # Add-ons that labs switch on themselves: only a note, unless one is on but broken.
  addon() {  # name, namespace, deployment, the lab that switches it on
    local r; r=$(kc get deployment "$3" -n "$2" -o jsonpath='{.status.readyReplicas}/{.spec.replicas}' 2>/dev/null)
    if [ -z "$r" ]; then info "$1 is not on yet (Lab $4 switches it on)"
    elif [ "${r%%/*}" = "${r#*/}" ]; then ok "$1 is on"
    else warn "$1 is on, but not ready" "kubectl get pods -n $2"; fi
  }
  addon "Ingress controller" ingress-nginx ingress-nginx-controller 3.2
  addon "Metrics Server" kube-system metrics-server 6.3
fi

# ---------------------------------------------------------------------------------------------
section "The Shop"
if [ "$api" != 1 ]; then
  info "skipped: the cluster does not answer"
else
  for ns in dev uat prod; do
    if ! kc get namespace "$ns" >/dev/null 2>&1; then
      info "$ns: no namespace yet (you make it in Lab 1.1)"; continue
    fi
    line=""; have=0; missing=0; notready=0
    for d in db backend frontend; do
      r=$(kc get deployment "$d" -n "$ns" -o jsonpath='{.status.readyReplicas}/{.spec.replicas}' 2>/dev/null)
      if [ -z "$r" ]; then missing=1; line+="$d -, "; continue; fi
      have=1; ready=${r%%/*}; ready=${ready:-0}; want=${r#*/}
      [ "$ready" = "$want" ] || notready=1
      line+="$d $ready/$want, "
    done
    line="${line%, } ready"
    if   [ "$have" = 0 ]; then info "$ns: the Shop is not deployed yet"
    elif [ "$notready" = 1 ]; then
      warn "$ns: $line" "see why: $scripts/check-shop.sh $ns   or rebuild it: $scripts/deploy-shop.sh $ns"
    elif [ "$missing" = 1 ]; then info "$ns: $line (not complete yet: you build it in Module 1)"
    else ok "$ns: $line"; fi
  done
fi

# ---------------------------------------------------------------------------------------------
echo
if [ "$fails" -gt 0 ]; then
  echo "$fails problem(s) to fix (FAIL). Fix them from the top: a problem higher up often causes the ones below it."
elif [ "$warns" -gt 0 ]; then
  echo "Ready for the labs, with $warns warning(s) (WARN)."
else
  echo "Everything is ready for the labs."
fi
[ "$fails" -eq 0 ]
