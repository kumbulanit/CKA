#!/usr/bin/env bash
# setup.sh: installs everything the course needs on one Ubuntu server, then creates and starts the
# practice cluster, in one command:
#
#   git clone https://github.com/kumbulanit/CKA.git && cd CKA
#   sudo ./setup.sh
#
# It installs the same tools as the minikube lesson (01-installation/01-install-minikube.md): Docker, minikube, kubectl v1.36 and helm, plus git, curl,
# jq, vim, nano and bash completion. Then, as the user who ran sudo, it creates and starts a
# minikube cluster on Docker: Kubernetes v1.36.5 with Calico, 3 nodes: one control plane (minikube)
# and two workers (minikube-m02 and minikube-m03). It takes about 10 minutes the first time.
#
# Run it again at any time (after the server restarts, for example): it installs what is missing,
# then makes sure the cluster is there and running with one control plane and two workers. It
# creates it if there is none, starts it or any stopped node, adds missing workers, uncordons
# nodes, and points kubectl at it again.
# The server: Ubuntu 22.04 or 24.04, 4 CPUs, 8 GB RAM, 30 GB free disk.
set -euo pipefail

K8S_VERSION=v1.36.5
K8S_MINOR=v1.36
MINIKUBE_VERSION=v1.39.0
NODES=3
CNI=calico

step() { printf '\n==> %s\n' "$*"; }
die() { echo "error: $*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "run it with sudo: sudo $0"
user=${SUDO_USER:-}
[ -n "$user" ] && [ "$user" != root ] \
  || die "run it with sudo from your own user (not as root): minikube does not run on Docker as root"
home=$(getent passwd "$user" | cut -d: -f6)
repo=$(cd "$(dirname "$0")" && pwd)
arch=$(dpkg --print-architecture)
export DEBIAN_FRONTEND=noninteractive
# sudo -u reads the user's groups again, so the docker group added below applies straight away.
as_user() { sudo -u "$user" -H "$@"; }

step "The course folder $repo belongs to $user"
# The lessons create files in their folders, as $user. If the repository was cloned with sudo,
# its files belong to root, so give them to $user.
if [ -n "$(find "$repo" ! -user "$user" -print -quit)" ]; then
  chown -R "$user:$(id -gn "$user")" "$repo"
fi

step "Packages"
apt-get update -q
apt-get install -y -q ca-certificates curl gpg git jq vim nano bash-completion

step "Docker"
if ! command -v docker >/dev/null; then
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  echo "deb [arch=$arch signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list
  apt-get update -q
  apt-get install -y -q docker-ce docker-ce-cli containerd.io
fi
# Started now and at every boot (Docker from snap starts itself, so its unit name does not matter).
systemctl enable --now docker >/dev/null 2>&1 || true
docker info >/dev/null 2>&1 || die "Docker is installed but does not run: see systemctl status docker"
usermod -aG docker "$user"
docker --version

step "minikube $MINIKUBE_VERSION"
if ! minikube version 2>/dev/null | grep -q "$MINIKUBE_VERSION"; then
  curl -fsSLo /tmp/minikube "https://storage.googleapis.com/minikube/releases/$MINIKUBE_VERSION/minikube-linux-$arch"
  install -o root -g root -m 0755 /tmp/minikube /usr/local/bin/minikube
  rm -f /tmp/minikube
fi
minikube version --short

step "kubectl $K8S_MINOR"
install -d -m 755 /etc/apt/keyrings
curl -fsSL "https://pkgs.k8s.io/core:/stable:/$K8S_MINOR/deb/Release.key" | gpg --dearmor --yes -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$K8S_MINOR/deb/ /" > /etc/apt/sources.list.d/kubernetes.list
step "helm"
curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey | gpg --dearmor --yes -o /usr/share/keyrings/helm.gpg
echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" > /etc/apt/sources.list.d/helm-stable-debian.list
apt-get update -q
apt-get install -y -q kubectl helm
kubectl version --client | head -1
helm version --short

# What kind and minikube recommend for several Kubernetes nodes on one Docker host.
printf 'fs.inotify.max_user_watches = 524288\nfs.inotify.max_user_instances = 512\n' > /etc/sysctl.d/99-cka-minikube.conf
sysctl --system >/dev/null

step "Shell: kubectl, minikube and helm completion, and the alias k for kubectl"
if ! grep -qs '# CKA course' "$home/.bashrc"; then
  cat >> "$home/.bashrc" <<'EOF'
# CKA course
source <(kubectl completion bash)
source <(minikube completion bash)
source <(helm completion bash)
alias k=kubectl
complete -o default -F __start_kubectl k
EOF
fi

# The cluster: one control plane (minikube) and two workers (minikube-m02, minikube-m03), running.
# Every run checks each part and fixes what is missing, so it always ends with that cluster.
mk() { as_user minikube "$@"; }
kc() { as_user kubectl --context minikube "$@"; }
# The nodes minikube knows, one per line: name, worker (true or false), host and kubelet state.
# minikube status can also print messages as JSON; only the node entries (with a Host) are kept.
nodes() {
  { mk status -o json 2>/dev/null || true; } | jq -r '(if type == "array" then .[] else . end)
    | select(type == "object" and has("Host"))
    | "\(.Name) \(.Worker // (.Name != "minikube")) \(.Host) \(.Kubelet)"' 2>/dev/null || true
}
again="Run sudo ./setup.sh again; if it fails again, start from a new cluster: minikube delete, then sudo ./setup.sh"

if ! mk profile list -o json 2>/dev/null | jq -e '[.valid[]?, .invalid[]?] | any(.Name == "minikube")' >/dev/null 2>&1; then
  step "Creating and starting the cluster: $NODES nodes, Kubernetes $K8S_VERSION, $CNI (about 5 to 10 minutes)"
  mk start --driver=docker --nodes="$NODES" --kubernetes-version="$K8S_VERSION" --cni="$CNI" \
    || die "minikube could not create the cluster (see the messages above). $again"
elif mk status >/dev/null 2>&1; then
  step "The cluster is already running"
else
  # Stopped (after the server restarts, or minikube stop), or ~/.kube/config no longer points at it.
  step "Starting the cluster"
  mk start || mk start || die "minikube could not start the cluster (see the messages above). $again"
fi

# A node stopped on its own (minikube node stop, in the drain lesson) is started again.
for n in $(nodes | awk '$3 != "Running" || $4 != "Running" { print $1 }'); do
  step "Starting node $n"
  mk node start "$n" || die "minikube could not start node $n. $again"
done

# Two workers: a cluster made earlier with fewer nodes gets the missing ones.
[ -n "$(nodes)" ] || die "minikube status shows no nodes. $again"
workers=$(nodes | awk '$2 == "true"' | wc -l)
while [ "$workers" -lt $((NODES - 1)) ]; do
  step "Adding a worker node ($((workers + 1)) of $((NODES - 1)))"
  mk node add --worker || die "minikube could not add a worker node. $again"
  workers=$((workers + 1))
done

# kubectl uses the cluster: its address in ~/.kube/config is updated, and minikube is the current
# context again (scripts/one-server.sh and the security lessons point kubectl elsewhere).
mk update-context >/dev/null
as_user kubectl config use-context minikube >/dev/null

step "Waiting for the nodes to be Ready"
kc wait --for=condition=Ready node/minikube --timeout=600s >/dev/null \
  || die "the control plane node is not Ready after 10 minutes (see kubectl get nodes, and minikube logs). $again"
# A worker that minikube runs but Kubernetes does not list as Ready (it never joined, or its
# kubelet stopped) is restarted, which joins it to the cluster again.
for n in $(nodes | awk '$2 == "true" { print $1 }'); do
  kc wait --for=condition=Ready "node/$n" --timeout=180s >/dev/null 2>&1 && continue
  step "Worker $n is not Ready: restarting it"
  mk node stop "$n" >/dev/null 2>&1 || true
  mk node start "$n" || die "minikube could not restart worker $n. $again"
  for _ in $(seq 1 60); do kc get node "$n" >/dev/null 2>&1 && break; sleep 5; done
  kc wait --for=condition=Ready "node/$n" --timeout=300s >/dev/null \
    || die "worker $n is not Ready after a restart (see kubectl describe node $n, and minikube logs -n $n). $again"
done
# A node left cordoned (the drain lesson) takes no new pods: uncordon it.
for n in $(kc get nodes -o jsonpath='{range .items[?(@.spec.unschedulable==true)]}{.metadata.name}{"\n"}{end}'); do
  step "Uncordoning $n"
  kc uncordon "$n" >/dev/null
done
# minikube gives the workers no role, so kubectl get nodes would show <none>: label them as workers.
for n in $(kc get nodes -l '!node-role.kubernetes.io/control-plane' -o name); do
  kc label "$n" node-role.kubernetes.io/worker= --overwrite >/dev/null
done
cps=$(kc get nodes -l node-role.kubernetes.io/control-plane --no-headers | grep -cw Ready || true)
workers=$(kc get nodes -l node-role.kubernetes.io/worker --no-headers | grep -cw Ready || true)
kc get nodes -o wide
[ "$cps" -ge 1 ] && [ "$workers" -ge $((NODES - 1)) ] \
  || die "the cluster has $cps control plane and $workers worker nodes Ready, instead of 1 and $((NODES - 1)). $again"
step "OK: $cps control plane and $workers worker nodes, all Ready; kubectl uses the minikube cluster"

if docker container inspect controlplane >/dev/null 2>&1; then
  echo
  echo "Note: the kubeadm machines from scripts/one-server.sh are also running. If you do not need"
  echo "them, free their memory with: sudo ./scripts/one-server.sh delete"
fi

cat <<EOF

The cluster is ready. As $user:
  kubectl get nodes               the cluster (kubectl is set up in $home/.kube/config)
  minikube ssh                    a shell on the control plane node; minikube ssh -n minikube-m02 for a worker
  minikube stop / minikube start  stop and start the cluster; sudo ./setup.sh also starts it
Log out and in again once (or run: newgrp docker) so minikube and docker work without sudo.
In the lessons, controlplane is minikube, node01 is minikube-m02 and node02 is minikube-m03.
EOF
