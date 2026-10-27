#!/usr/bin/env bash
# one-server.sh <create|install|shell|kubeconfig|status|delete>
#
# Runs the whole course on one Ubuntu server (a VM is fine: 4 CPUs, 8 GB RAM, 40 GB disk).
# The course needs three machines, controlplane, node01 and node02; here they are containers on
# that server, each a full Ubuntu 24.04 machine with systemd and SSH, so every command in the
# lessons works unchanged, including the kubeadm installation, `ssh node01` and draining nodes.
#
#   sudo ./scripts/one-server.sh create        three bare machines (to do the installation lesson)
#   sudo ./scripts/one-server.sh install       the same, with Kubernetes installed (install-cluster.sh)
#   sudo ./scripts/one-server.sh shell [node]  a root shell on controlplane (or node01, node02)
#   sudo ./scripts/one-server.sh kubeconfig    kubectl on this server too (install does this for you)
#   sudo ./scripts/one-server.sh status        the machines and their addresses
#   sudo ./scripts/one-server.sh delete        remove the machines and everything on them
#
# Each machine has the repository in /root/CKA. The machines restart with the server.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/.." && pwd)
NODES=(controlplane node01 node02)
SUBNET=${CKA_SUBNET:-172.30.56}   # the machines get .10, .11 and .12
IMAGE=cka-node:24.04
NETWORK=cka

step() { printf '\n==> %s\n' "$*"; }
die() { echo "error: $*" >&2; exit 1; }
ip_of() { case $1 in controlplane) echo "$SUBNET.10" ;; node01) echo "$SUBNET.11" ;; node02) echo "$SUBNET.12" ;; esac; }
IPS=("$SUBNET.10" "$SUBNET.11" "$SUBNET.12")
ips() { echo "${IPS[*]}"; }
exists() { docker container inspect "$1" >/dev/null 2>&1; }

need_docker() {
  if ! command -v docker >/dev/null; then
    [ "$(id -u)" -eq 0 ] || die "Docker is not installed; run this with sudo to install it"
    step "Installing Docker"
    apt-get update -q && apt-get install -y -q docker.io
    systemctl enable --now docker
  fi
  docker info >/dev/null 2>&1 || die "cannot use Docker; run this with sudo"
}

# What kind recommends on the host for Kubernetes nodes in containers.
host_settings() {
  [ "$(uname)" = Linux ] && [ "$(id -u)" -eq 0 ] || return 0
  modprobe overlay
  modprobe br_netfilter
  printf 'fs.inotify.max_user_watches = 524288\nfs.inotify.max_user_instances = 512\n' > /etc/sysctl.d/99-cka-one-server.conf
  sysctl --system >/dev/null
}

create() {
  need_docker
  host_settings
  step "Building the machine image ($IMAGE)"
  docker build -q -t "$IMAGE" "$here/one-server" >/dev/null
  docker network inspect "$NETWORK" >/dev/null 2>&1 || docker network create --subnet "$SUBNET.0/24" "$NETWORK" >/dev/null

  step "Starting controlplane, node01 and node02"
  local n
  for n in "${NODES[@]}"; do
    if exists "$n"; then
      docker start "$n" >/dev/null
      continue
    fi
    # The flags kind uses to run systemd, containerd and the kubelet inside a container.
    docker run -d --name "$n" --hostname "$n" --network "$NETWORK" --ip "$(ip_of "$n")" --network-alias "$n" \
      --restart unless-stopped --privileged --security-opt seccomp=unconfined --security-opt apparmor=unconfined \
      --tmpfs /tmp --tmpfs /run --volume /var --cgroupns private -e container=docker "$IMAGE" >/dev/null
  done
  local i
  for n in "${NODES[@]}"; do
    for i in $(seq 1 180); do
      docker exec "$n" systemctl is-active -q ssh 2>/dev/null && break
      [ "$i" -lt 180 ] || die "$n did not start; see: docker logs $n"
      sleep 1
    done
  done

  step "Root SSH between the machines, and the repository in /root/CKA"
  docker exec controlplane sh -c '[ -f /root/.ssh/id_ed25519 ] || ssh-keygen -q -t ed25519 -N "" -f /root/.ssh/id_ed25519'
  local key pub
  key=$(docker exec controlplane cat /root/.ssh/id_ed25519)
  pub=$(docker exec controlplane cat /root/.ssh/id_ed25519.pub)
  for n in "${NODES[@]}"; do
    docker exec -i "$n" sh -c 'umask 077; mkdir -p /root/.ssh; cat > /root/.ssh/id_ed25519' <<<"$key"
    docker exec "$n" sh -c "umask 077; grep -qxF '$pub' /root/.ssh/authorized_keys 2>/dev/null || echo '$pub' >> /root/.ssh/authorized_keys; echo '$pub' > /root/.ssh/id_ed25519.pub"
    printf 'Host controlplane node01 node02\n  StrictHostKeyChecking accept-new\n' | docker exec -i "$n" sh -c 'umask 077; cat > /root/.ssh/config'
    docker exec "$n" mkdir -p /root/CKA
    tar -C "$repo" --exclude='*.pptx' --exclude=.DS_Store -cf - . | docker exec -i "$n" tar -C /root/CKA -xf -
  done
}

install() {
  create
  local log=/tmp/cka-one-server
  mkdir -p "$log"
  step "Installing Kubernetes (about 5 to 10 minutes; logs in $log)"
  local n pids=()
  # The workers prepare (containerd, kubeadm) while controlplane installs; they join at the end.
  for n in node01 node02; do
    docker exec "$n" /root/CKA/scripts/install-cluster.sh "$n" "${IPS[@]}" > "$log/$n.log" 2>&1 &
    pids+=($!)
  done
  docker exec controlplane /root/CKA/scripts/install-cluster.sh controlplane "${IPS[@]}" 2>&1 | tee "$log/controlplane.log" | grep '^==>' || true
  docker exec controlplane test -f /etc/kubernetes/admin.conf || die "controlplane did not install; see $log/controlplane.log"
  for n in "${pids[@]}"; do wait "$n" || die "a worker did not prepare; see $log/node01.log and $log/node02.log"; done
  local join
  join=$(docker exec controlplane kubeadm token create --print-join-command)
  for n in node01 node02; do
    step "Joining $n"
    docker exec "$n" /root/CKA/scripts/install-cluster.sh "$n" "${IPS[@]}" "$join" >> "$log/$n.log" 2>&1 || die "$n did not join; see $log/$n.log"
  done
  docker exec controlplane kubectl wait --for=condition=Ready node --all --timeout=600s >/dev/null
  docker exec controlplane kubectl get nodes
  host_kubectl
}

# kubectl and helm on this server too: the cluster's admin kubeconfig for the user who ran sudo (an existing
# ~/.kube/config is kept as config.before-cka), and kubectl and helm, copied from controlplane so the
# versions match, when the server has none.
host_kubectl() {
  docker exec controlplane test -f /etc/kubernetes/admin.conf 2>/dev/null \
    || die "Kubernetes is not installed on controlplane yet: run sudo $0 install, or do the installation lesson"
  command -v kubectl >/dev/null || docker cp controlplane:/usr/bin/kubectl /usr/local/bin/kubectl
  command -v helm >/dev/null || docker cp controlplane:/usr/bin/helm /usr/local/bin/helm
  local user=${SUDO_USER:-$(id -un)} home=$HOME cfg admin
  [ -z "${SUDO_USER:-}" ] || home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
  grep -qs 'kubectl completion bash' "$home/.bashrc" || echo 'source <(kubectl completion bash)' >> "$home/.bashrc"
  cfg=$home/.kube/config
  admin=$(docker exec controlplane cat /etc/kubernetes/admin.conf)
  mkdir -p "$home/.kube"
  if [ -f "$cfg" ] && [ "$(cat "$cfg")" != "$admin" ]; then cp "$cfg" "$cfg.before-cka"; fi
  printf '%s\n' "$admin" > "$cfg"
  chmod 600 "$cfg"
  chown -R "$user" "$home/.kube"
  step "kubectl on this server now uses the cluster ($cfg)"
}

case ${1:-} in
  create)
    create
    echo
    echo "Three bare Ubuntu machines are running ($(ips)). Kubernetes is not installed on them yet:"
    echo "  - to install it yourself, as in the installation lesson: sudo $0 shell, then follow the lesson"
    echo "  - to install it in one go:                            sudo $0 install"
    echo "kubectl runs on controlplane (sudo $0 shell). After installing, sudo $0 kubeconfig sets it up here too."
    ;;
  install)
    install
    echo
    echo "The cluster is ready:"
    echo "  - on this server:  kubectl get nodes"
    echo "  - the lessons run as root on controlplane:  sudo $0 shell"
    ;;
  kubeconfig)
    need_docker
    host_kubectl
    ;;
  shell)
    node=${2:-controlplane}
    exists "$node" || die "no machine called $node; run: sudo $0 create"
    exec docker exec -it -w /root "$node" bash -l
    ;;
  status)
    docker ps -a --filter "network=$NETWORK" --format 'table {{.Names}}\t{{.Status}}'
    echo "Addresses: controlplane $(ip_of controlplane), node01 $(ip_of node01), node02 $(ip_of node02)"
    ;;
  delete)
    for n in "${NODES[@]}"; do exists "$n" && docker rm -f -v "$n" >/dev/null; done
    docker network rm "$NETWORK" >/dev/null 2>&1 || true
    echo "Removed controlplane, node01 and node02."
    ;;
  *)
    sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
    ;;
esac
