### Kubernetes Installation Using kubeadm: Installation, Configuration & Validation

> **Optional: kubeadm, the tool the CKA exam uses.** The course's practicals run on minikube (`sudo ./setup.sh`). To do this lesson, use machines without Kubernetes: `sudo ./scripts/one-server.sh create` starts `controlplane`, `node01` and `node02` on your server.


#### Overview

`kubeadm` is a tool that helps you install and configure a secure Kubernetes cluster rapidly. It automates the process of setting up the control plane and joining worker nodes to the cluster.

This guide builds the cluster that every practical in this repository uses: one control plane node and two worker nodes, named `controlplane`, `node01` and `node02`. Use the same names so the commands in the other documents work exactly as written.

### Prerequisites

1. **Servers**: 3 machines (VMs are fine): `controlplane`, `node01`, `node02`. With only one Ubuntu server, run `sudo ./scripts/one-server.sh create` from this repository: it starts the three machines on it (IP addresses `172.30.56.10`, `.11`, `.12`), and `sudo ./scripts/one-server.sh shell node01` opens each one.
2. **Operating System**: Ubuntu 24.04 LTS (amd64 or arm64).
3. **Hardware**: at least 2 CPUs and 2 GB RAM on `controlplane`, 1 CPU and 1 GB RAM on each worker.
4. **Network**: full network connectivity between all machines, and internet access.
5. **User**: root, or a user with sudo privileges.

Kubernetes version: **v1.36**. The cluster maintenance document upgrades it to v1.37.

### Step 1: Prepare the System (all 3 nodes)

**1. Set the host name** (run the matching line on each node):
```sh
sudo hostnamectl set-hostname controlplane   # on the control plane node
sudo hostnamectl set-hostname node01         # on the first worker
sudo hostnamectl set-hostname node02         # on the second worker
```

**2. Let the nodes find each other by name.** Replace the IP addresses with your own (`ip -4 addr` shows them):
```sh
cat <<EOF | sudo tee -a /etc/hosts
192.168.56.10 controlplane
192.168.56.11 node01
192.168.56.12 node02
EOF
```

**3. Update the system and install necessary packages**:
```sh
sudo apt update && sudo apt upgrade -y
sudo apt install -y apt-transport-https ca-certificates curl gpg
```

**4. Disable swap**:
```sh
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
```

**5. Load the kernel modules and network settings Kubernetes needs**:
```sh
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system
```

### Step 2: Install the Container Runtime (all 3 nodes)

Kubernetes no longer uses Docker Engine directly (dockershim was removed in v1.24). It talks to a CRI runtime; we use **containerd**.

**1. Install containerd**:
```sh
sudo apt install -y containerd
```

**2. Generate its configuration and switch it to the systemd cgroup driver** (kubeadm configures the kubelet for systemd):
```sh
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd
```

### Step 3: Install kubeadm, kubelet, and kubectl (all 3 nodes)

**1. Add the Kubernetes repository** (`pkgs.k8s.io`; the old `apt.kubernetes.io` repository was shut down in 2024):
```sh
sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.36/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.36/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
```

**2. Install Kubernetes packages**:
```sh
sudo apt update
sudo apt install -y kubeadm kubelet kubectl
sudo apt-mark hold kubeadm kubelet kubectl
sudo systemctl enable --now kubelet
```

The kubelet restarts every few seconds until `kubeadm init` or `kubeadm join` gives it a configuration. That is expected.

### Step 4: Initialize the Control Plane (controlplane only)

**1. Initialize the control plane**:
```sh
sudo kubeadm init --pod-network-cidr=192.168.0.0/16
```

**Output** (shortened):
```sh
Your Kubernetes control-plane has initialized successfully!
To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

You should now deploy a pod network to the cluster.

Then you can join any number of worker nodes by running the following on each as root:

  kubeadm join controlplane:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>
```

**2. Configure kubectl** (as root, and as your regular user if you have one):
```sh
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

### Step 5: Deploy a Pod Network (controlplane only)

**1. Install the Calico network plugin**:
```sh
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.33.0/manifests/calico.yaml
```

**2. Wait until the Calico and CoreDNS pods are `Running`** (press Ctrl+C to stop watching):
```sh
kubectl get pods -n kube-system -w
```

### Step 6: Join Worker Nodes (node01 and node02)

**1. On controlplane, print the join command** (the token from `kubeadm init` expires after 24 hours):
```sh
kubeadm token create --print-join-command
```

**2. On each worker node, run the join command it printed**:
```sh
sudo kubeadm join controlplane:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>
```

### Step 7: Validate the Cluster

**1. Check nodes status**:
```sh
kubectl get nodes
```

**Output**:
```sh
NAME           STATUS   ROLES           AGE   VERSION
controlplane   Ready    control-plane   10m   v1.36.5
node01         Ready    <none>          5m    v1.36.5
node02         Ready    <none>          5m    v1.36.5
```

**2. Check the status of pods**:
```sh
kubectl get pods --all-namespaces
```

### Step 8 (optional): Root SSH Between Nodes

The troubleshooting practicals log in from `controlplane` to the workers with `ssh node01`, as root. To set that up, run this on controlplane as root (`sudo -i`):
```sh
ssh-keygen -t ed25519 -N '' -f ~/.ssh/id_ed25519
cat ~/.ssh/id_ed25519.pub
```
Then on node01 and node02, as root, add that public key to `/root/.ssh/authorized_keys`, and check from controlplane:
```sh
ssh node01 hostname
```

### Diagram: Kubernetes Cluster Setup

```plaintext
+-------------------------------------+
|            controlplane             |
|                                     |
| +---------------------------------+ |
| |        Control Plane            | |
| |  (static pods in                | |
| |   /etc/kubernetes/manifests)    | |
| |  - kube-apiserver               | |
| |  - kube-controller-manager      | |
| |  - kube-scheduler               | |
| |  - etcd                         | |
| +---------------------------------+ |
|  kubelet, kube-proxy, containerd    |
+-------------------------------------+
                 |
                 |
                 v
+-------------------------------------+
|               node01                |
|                                     |
| +---------------------------------+ |
| |            kubelet              | |
| |            kube-proxy           | |
| |                                 | |
| |  - Container Runtime (containerd)| |
| |  - Pods                         | |
| +---------------------------------+ |
|                                     |
+-------------------------------------+
                 |
                 |
                 v
+-------------------------------------+
|               node02                |
|                                     |
| +---------------------------------+ |
| |            kubelet              | |
| |            kube-proxy           | |
| |                                 | |
| |  - Container Runtime (containerd)| |
| |  - Pods                         | |
| +---------------------------------+ |
|                                     |
+-------------------------------------+
```

### Conclusion

Using `kubeadm` simplifies the installation and configuration of a Kubernetes cluster. By following the steps outlined above, you can set up a basic Kubernetes cluster with a control plane node and worker nodes, deploy a network plugin, and validate the installation.

### Additional Resources

- **Installing kubeadm**: [https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)
- **Container runtimes**: [https://kubernetes.io/docs/setup/production-environment/container-runtimes/](https://kubernetes.io/docs/setup/production-environment/container-runtimes/)
- **Calico on kubeadm**: [https://docs.tigera.io/calico/latest/getting-started/kubernetes/self-managed-onprem/onpremises](https://docs.tigera.io/calico/latest/getting-started/kubernetes/self-managed-onprem/onpremises)
- **Kubernetes the Hard Way**: [https://github.com/kelseyhightower/kubernetes-the-hard-way](https://github.com/kelseyhightower/kubernetes-the-hard-way)
