#!/usr/bin/env bash
# install-cluster <node-name> <controlplane-ip> <node01-ip> <node02-ip> [join command]
#
# Builds the course cluster on fresh Ubuntu 24.04 machines, with the same steps as
# "Domain 1 -Installation, Configuration & Validation /Kubernetes installation using kubeadm.md":
# host names, swap, kernel settings, containerd, kubeadm/kubelet/kubectl v1.36, and then
#   - on controlplane: kubeadm init, kubectl for root (and the sudo user), Calico, helm and
#     etcd-client; it prints the command to run on each worker;
#   - on node01/node02: kubeadm join, when the join command is given.
#
# Run it as root (sudo) on each machine, controlplane first:
#   sudo ./install-cluster.sh controlplane 192.168.56.10 192.168.56.11 192.168.56.12
#   sudo ./install-cluster.sh node01 192.168.56.10 192.168.56.11 192.168.56.12 "kubeadm join ..."
#   sudo ./install-cluster.sh node02 192.168.56.10 192.168.56.11 192.168.56.12 "kubeadm join ..."
# Running it again on a machine that is already set up is safe: finished steps are skipped.
set -euo pipefail

K8S_MINOR=v1.36
CALICO_VERSION=v3.33.0
POD_CIDR=192.168.0.0/16

usage() { sed -n '2p;11,15p' "$0" | sed 's/^# \{0,1\}//'; echo 'On one Ubuntu server, use one-server.sh instead: sudo ./one-server.sh install'; exit 1; }
[ $# -ge 4 ] || usage
node=$1 cp_ip=$2 n1_ip=$3 n2_ip=$4 join=${5:-}
case $node in controlplane|node01|node02) ;; *) echo "node name must be controlplane, node01 or node02" >&2; exit 1 ;; esac
[ "$(id -u)" -eq 0 ] || { echo "run this as root: sudo $0 $*" >&2; exit 1; }
export DEBIAN_FRONTEND=noninteractive

step() { printf '\n==> %s\n' "$*"; }

step "Host name and /etc/hosts"
hostnamectl set-hostname "$node" 2>/dev/null || { hostname "$node"; echo "$node" > /etc/hostname; }
hosts=$(grep -vE '[[:space:]](controlplane|node01|node02)$' /etc/hosts || true)
printf '%s\n%s controlplane\n%s node01\n%s node02\n' "$hosts" "$cp_ip" "$n1_ip" "$n2_ip" > /etc/hosts

step "Packages"
apt-get update -q
apt-get install -y -q apt-transport-https ca-certificates curl gpg

step "Swap off"
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

step "Kernel modules and network settings"
printf 'overlay\nbr_netfilter\n' > /etc/modules-load.d/k8s.conf
modprobe overlay
modprobe br_netfilter
cat > /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system >/dev/null

step "containerd (systemd cgroup driver)"
apt-get install -y -q containerd
if ! grep -q 'SystemdCgroup = true' /etc/containerd/config.toml 2>/dev/null; then
  mkdir -p /etc/containerd
  containerd config default > /etc/containerd/config.toml
  sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
  systemctl restart containerd
fi
systemctl enable --now containerd
# kubeadm fails its preflight check if containerd is still starting.
for _ in $(seq 1 60); do ctr version >/dev/null 2>&1 && break; sleep 1; done

step "kubeadm, kubelet and kubectl $K8S_MINOR"
install -d -m 755 /etc/apt/keyrings
curl -fsSL "https://pkgs.k8s.io/core:/stable:/$K8S_MINOR/deb/Release.key" | gpg --dearmor --yes -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$K8S_MINOR/deb/ /" > /etc/apt/sources.list.d/kubernetes.list
apt-get update -q
apt-get install -y -q kubeadm kubelet kubectl
apt-mark hold kubeadm kubelet kubectl
systemctl enable --now kubelet

if [ "$node" != controlplane ]; then
  if [ -f /etc/kubernetes/kubelet.conf ]; then
    step "$node has already joined the cluster"
  elif [ -n "$join" ]; then
    step "Joining the cluster"
    $join
  else
    step "$node is ready to join. Run the join command that install-cluster.sh printed on controlplane:"
    echo "  sudo kubeadm join controlplane:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>"
    echo "  (on controlplane, 'kubeadm token create --print-join-command' prints a new one)"
  fi
  exit 0
fi

if [ -f /etc/kubernetes/admin.conf ]; then
  step "Control plane already initialised"
else
  step "kubeadm init"
  kubeadm init --pod-network-cidr="$POD_CIDR"
fi

step "kubectl for root${SUDO_USER:+ and $SUDO_USER}"
install -d -m 700 /root/.kube
cp /etc/kubernetes/admin.conf /root/.kube/config
if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != root ]; then
  home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
  install -d -m 700 -o "$SUDO_USER" -g "$(id -g "$SUDO_USER")" "$home/.kube"
  install -m 600 -o "$SUDO_USER" -g "$(id -g "$SUDO_USER")" /etc/kubernetes/admin.conf "$home/.kube/config"
fi
export KUBECONFIG=/etc/kubernetes/admin.conf
grep -q 'kubectl completion bash' /root/.bashrc 2>/dev/null || echo 'source <(kubectl completion bash)' >> /root/.bashrc

step "Calico $CALICO_VERSION"
kubectl apply -f "https://raw.githubusercontent.com/projectcalico/calico/$CALICO_VERSION/manifests/calico.yaml"

step "Tools used in the course: helm and etcd-client"
curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey | gpg --dearmor --yes -o /usr/share/keyrings/helm.gpg
echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" > /etc/apt/sources.list.d/helm-stable-debian.list
apt-get update -q
apt-get install -y -q helm etcd-client

step "Waiting for controlplane to be Ready (Calico takes a minute or two)"
kubectl wait --for=condition=Ready node/controlplane --timeout=300s

join=$(kubeadm token create --print-join-command)
cat <<EOF

The control plane is ready. On node01 and node02, run:

  sudo ./install-cluster.sh node01 $cp_ip $n1_ip $n2_ip "$join"
  sudo ./install-cluster.sh node02 $cp_ip $n1_ip $n2_ip "$join"

Then check from controlplane:  kubectl get nodes
For 'ssh node01' as root (used in troubleshooting), see step 8 of the installation guide.
EOF
