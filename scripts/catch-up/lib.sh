# shellcheck shell=bash
# Shared by the catch-up scripts (day1.sh, day2.sh, day3.sh); they source it, it is not run.
# Each day script defines its labs as functions lab_<name> and lists them in LABS, then calls
# run_labs "$@".
set -euo pipefail

# shellcheck disable=SC2034 # used by the day scripts
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)

step() { printf '\n==> %s\n' "$*"; }
die() { echo "error: $*" >&2; exit 1; }

# apply: create or update the objects in the YAML on stdin. Objects that cannot be changed in
# place (a pod's containers, a claim's storage class) are deleted and created again.
apply() {
  local yaml
  yaml=$(cat)
  kubectl apply -f - <<<"$yaml" 2>/dev/null || kubectl replace --force --grace-period=1 -f - <<<"$yaml"
}

# run_pod <name> <kubectl run arguments...>: the pod `kubectl run <name> ...` creates.
run_pod() {
  local name=$1
  shift
  # The flags go first: arguments after "--" belong to the container's command.
  kubectl run "$name" --dry-run=client -o yaml "$@" | apply
}

# namespace <name>: create a namespace and wait for its default service account, which pods need
# and which a new namespace only gets a moment later.
namespace() {
  kubectl create namespace "$1" --dry-run=client -o yaml | apply
  until kubectl -n "$1" get serviceaccount default >/dev/null 2>&1; do sleep 1; done
}

# on_node <node> <command>: run a command as root on a node, through a short-lived pod, so it
# works without SSH between the nodes.
on_node() {
  local node=$1 cmd=$2 pod="catch-up-$1"
  kubectl delete pod "$pod" --ignore-not-found --wait >/dev/null
  kubectl apply -f - >/dev/null <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: $pod
spec:
  nodeName: $node
  restartPolicy: Never
  tolerations:
  - operator: Exists
  containers:
  - name: run
    image: busybox:1.37
    command: ["chroot", "/host", "sh", "-c", "$cmd"]
    volumeMounts:
    - name: host
      mountPath: /host
  volumes:
  - name: host
    hostPath:
      path: /
EOF
  kubectl wait --for=jsonpath='{.status.phase}'=Succeeded "pod/$pod" --timeout=180s >/dev/null \
    || die "'$cmd' did not finish on $node (kubectl logs $pod)"
  kubectl delete pod "$pod" --wait=false >/dev/null
}

need_root() { [ "$(id -u)" -eq 0 ] || die "this step installs packages; run the script as root (sudo -i), or install them first"; }

# find_nodes: the course's nodes on this cluster. CP is the control plane (controlplane; minikube on
# minikube); NODE1 and NODE2 are the first two workers (node01 and node02; minikube-m02 and
# minikube-m03), or the control plane when there are none. CLUSTER is the kubeconfig's cluster name.
# shellcheck disable=SC2034 # used by the day scripts
find_nodes() {
  local workers
  CP=$(kubectl get nodes -l node-role.kubernetes.io/control-plane -o jsonpath='{.items[0].metadata.name}')
  read -r -a workers <<<"$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' -o jsonpath='{.items[*].metadata.name}')"
  NODE1=${workers[0]:-$CP}
  NODE2=${workers[1]:-$NODE1}
  CLUSTER=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}')
}

list_labs() {
  local entry
  for entry in "${LABS[@]}"; do printf '  %-18s %s\n' "${entry%%|*}" "${entry#*|}"; done
}

# run_labs [lab ...]: run the named labs, or all of them in course order except the ones in
# OPTIONAL (run those by name).
run_labs() {
  case ${1:-} in
    -h|--help|--list) echo "Usage: $(basename "$0") [lab ...]   (no lab: all of them)"; echo "Labs:"; list_labs; exit 0 ;;
  esac
  kubectl get nodes >/dev/null 2>&1 || die "kubectl cannot reach the cluster; run this where kubectl works (on the minikube server, or as root on controlplane)"
  find_nodes
  local wanted=("$@") entry name
  if [ ${#wanted[@]} -eq 0 ]; then
    for entry in "${LABS[@]}"; do
      name=${entry%%|*}
      [[ " ${OPTIONAL[*]:-} " == *" $name "* ]] || wanted+=("$name")
    done
  fi
  for name in "${wanted[@]}"; do
    entry=$(printf '%s\n' "${LABS[@]}" | grep "^$name|") || { echo "unknown lab: $name"; echo "Labs:"; list_labs; exit 1; }
    step "${entry#*|}"
    "lab_${name//-/_}"
  done
  printf '\nDone. Pods may take a minute to pull their images: kubectl get pods -A\n'
}
