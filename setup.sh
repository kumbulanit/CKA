#!/usr/bin/env bash
# setup.sh: installs everything the course needs on one Ubuntu server, then creates and starts the
# practice cluster, in one command:
#
#   git clone https://github.com/kumbulanit/CKA.git && cd CKA
#   sudo ./setup.sh
#
# It installs the same tools as the minikube lesson (02-installation/install-kubernetes.md): Docker, minikube, kubectl v1.36 and helm, plus git, curl,
# jq, vim, nano and bash completion. Then, as the user who ran sudo, it creates and starts a
# minikube cluster on Docker: Kubernetes v1.36.5 with Calico, 3 nodes (minikube is the control
# plane; minikube-m02 and minikube-m03 are the workers). It takes about 10 minutes the first time.
#
# Running it again is safe: it installs only what is missing, and starts the cluster if it is
# stopped (after the server restarts, for example).
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
arch=$(dpkg --print-architecture)
export DEBIAN_FRONTEND=noninteractive
# sudo -u reads the user's groups again, so the docker group added below applies straight away.
as_user() { sudo -u "$user" -H "$@"; }

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
systemctl enable --now docker
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

ready=$(as_user kubectl --context minikube get nodes --no-headers 2>/dev/null | grep -c ' Ready ' || true)
if [ "${ready:-0}" -ge "$NODES" ]; then
  step "The cluster is already running"
elif as_user minikube profile list -o json 2>/dev/null | grep -q '"Name":"minikube"'; then
  step "Starting the cluster"
  as_user minikube start
else
  step "Creating and starting the cluster: $NODES nodes, Kubernetes $K8S_VERSION, $CNI (about 5 to 10 minutes)"
  as_user minikube start --driver=docker --nodes="$NODES" --kubernetes-version="$K8S_VERSION" --cni="$CNI"
fi

step "Waiting for all nodes to be Ready"
as_user kubectl wait --for=condition=Ready node --all --timeout=600s >/dev/null
as_user kubectl get nodes -o wide

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
