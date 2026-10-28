# Module 1: Installation

Each lab below is a practical from this repository, step by step: the command, what it does, and what it printed on the practice cluster. Names with random endings (pod names such as `nginx-7d9c…`), IP addresses and ages will differ on yours. The outputs show Kubernetes v1.36.4 (v1.37.0 after the upgrade lab), the newest version the practice cluster's images have; the cluster `setup.sh` makes runs v1.36.5, so the VERSION columns on yours say v1.36.5. Lab numbers are those of the labs in Desired Labs.

- [Lab 2.1: Prepare the machines](#lab-21-prepare-the-machines)
- [Lab 2.2: Install containerd](#lab-22-install-containerd)
- [Lab 2.3: Install kubeadm, kubelet and kubectl](#lab-23-install-kubeadm-kubelet-and-kubectl)
- [Lab 2.4: Initialise the control plane](#lab-24-initialise-the-control-plane)
- [Lab 2.5: Install the network plugin](#lab-25-install-the-network-plugin)
- [Lab 2.6: Join the workers](#lab-26-join-the-workers)
- [Lab 2.7: Grow the cluster](#lab-27-grow-the-cluster)

## Before you start

The course's own cluster is minikube: [01-install-minikube.md](../01-installation/01-install-minikube.md) sets it up with `sudo ./setup.sh`. These labs are the optional kubeadm path (the CKA exam's clusters are kubeadm clusters): they install Kubernetes with kubeadm, so they need machines without Kubernetes. On your Ubuntu server, [scripts/one-server.sh](../scripts/one-server.sh) runs three of them as containers named `controlplane`, `node01` and `node02`, so every command below works as written. On an 8 GB server, stop minikube first (`minikube stop`).

```bash
cd CKA
sudo ./scripts/one-server.sh create    # three bare Ubuntu 24.04 machines
sudo ./scripts/one-server.sh shell     # you are now root@controlplane; the repository is in /root/CKA
```

Their IP addresses are `172.30.56.10` (controlplane), `.11` (node01) and `.12` (node02); `sudo ./scripts/one-server.sh status` shows them. The outputs below were recorded in Desired Labs, where the addresses differ: use yours. `sudo ./scripts/one-server.sh delete` removes the machines so you can start again.

## Lab 2.1: Prepare the machines

### What you will do

Follow **Step 1** of [kubeadm-lesson-install-kubeadm.md](https://github.com/kumbulanit/CKA/blob/main/01-installation/kubeadm-lesson-install-kubeadm.md)
on **controlplane, node01 and node02**. Your terminal is root on controlplane; reach the workers
with `ssh node01` and `ssh node02` (and `exit` to come back).

1. Set each host name with `hostnamectl`.
2. Add all three machines to `/etc/hosts` on every one of them. `ip -4 addr` on each machine shows
   its address (the one on `eth0`).
3. Update the system and install `apt-transport-https ca-certificates curl gpg`.
4. Disable swap.
5. Load the `overlay` and `br_netfilter` modules, and write the sysctl settings in
   `/etc/sysctl.d/k8s.conf`, then `sysctl --system`.

### Step by step

**Step 1.** Saves `$CP_IP`: looks up an address. The addresses of the three machines (ip -4 addr on each shows the same).

```bash
CP_IP=$(getent hosts controlplane | awk '{print $1}')
```

It prints nothing when it works.

**Step 2.** Saves `$NODE01_IP`: looks up an address.

```bash
NODE01_IP=$(getent hosts node01 | awk '{print $1}')
```

It prints nothing when it works.

**Step 3.** Saves `$NODE02_IP`: looks up an address.

```bash
NODE02_IP=$(getent hosts node02 | awk '{print $1}')
```

It prints nothing when it works.

**Step 4.** Repeats the command for each of `controlplane`, `node01`, `node02`. The same steps on each machine.

```bash
for n in controlplane node01 node02; do
  ssh $n "sudo hostnamectl set-hostname $n"
  ssh $n "cat <<EOF | sudo tee -a /etc/hosts
$CP_IP controlplane
$NODE01_IP node01
$NODE02_IP node02
EOF"
  ssh $n 'bash -s' <<'STEP1'
sudo apt update && sudo apt upgrade -y
sudo apt install -y apt-transport-https ca-certificates curl gpg
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
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
STEP1
done
```

You should see something like:

```text
172.30.77.10 controlplane
172.30.77.11 node01
172.30.77.12 node02

WARNING: apt does not have a stable CLI interface. Use with caution in scripts.

Hit:1 http://ports.ubuntu.com/ubuntu-ports noble InRelease
Get:2 http://ports.ubuntu.com/ubuntu-ports noble-updates InRelease [126 kB]
Get:3 http://ports.ubuntu.com/ubuntu-ports noble-backports InRelease [126 kB]
Get:4 http://ports.ubuntu.com/ubuntu-ports noble-security InRelease [126 kB]
Get:5 http://ports.ubuntu.com/ubuntu-ports noble-updates/universe arm64 Packages [2216 kB]
Get:6 http://ports.ubuntu.com/ubuntu-ports noble-updates/main arm64 Packages [1790 kB]
Get:7 http://ports.ubuntu.com/ubuntu-ports noble-security/main arm64 Packages [1476 kB]
Get:8 http://ports.ubuntu.com/ubuntu-ports noble-security/universe arm64 Packages [1638 kB]
Fetched 7500 kB in 7s (1020 kB/s)
Reading package lists...
Building dependency tree...
Reading state information...
… (342 more lines)
```

### If you see something else

- The check says: _/etc/hosts does not list all three machines on every machine._
- The check says: _The kernel module and sysctl settings are not on every machine._
- The check says: _The packages from step 3 are not installed on every machine._
- Run each command on all three machines: on controlplane first, then `ssh node01`, run them again, `exit`, and the same for node02.
- `cat <<EOF | sudo tee -a /etc/hosts` appends the three lines; use the real addresses from `ip -4 addr`, not the 192.168.56.x examples.

### Why it works

**Why it works.** Kubernetes nodes find each other by name, so every machine needs the same names (here in /etc/hosts; in production, DNS). The kubelet refuses to run with swap on by default, because memory limits and scheduling assume pods cannot be swapped out. `br_netfilter` makes bridged pod traffic pass through iptables, where kube-proxy's Service rules live, and `ip_forward` lets the node route packets between pods and other nodes. The files in /etc/modules-load.d and /etc/sysctl.d make all of it survive a reboot.

**In this lab:** the machines are containers. Swap is hidden from them, so `swapoff -a` has nothing to turn off, and the kernel modules are built into the host's kernel, so `modprobe` succeeds without loading anything.

---

## Lab 2.2: Install containerd

### What you will do

Follow **Step 2** of the installation guide on **controlplane, node01 and node02**: install
`containerd`, write its default configuration to `/etc/containerd/config.toml`, switch it to the
systemd cgroup driver (`SystemdCgroup = true`), and restart and enable it.

### Step by step

**Step 1.** Repeats the command for each of `controlplane`, `node01`, `node02`.

```bash
for n in controlplane node01 node02; do
  ssh $n 'bash -s' <<'STEP2'
sudo apt install -y containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd
STEP2
done
```

You should see something like:

```text

WARNING: apt does not have a stable CLI interface. Use with caution in scripts.

Reading package lists...
Building dependency tree...
Reading state information...
The following additional packages will be installed:
  runc
The following NEW packages will be installed:
  containerd runc
0 upgraded, 2 newly installed, 0 to remove and 0 not upgraded.
Need to get 33.7 MB of archives.
After this operation, 134 MB of additional disk space will be used.
Get:1 http://ports.ubuntu.com/ubuntu-ports noble-updates/main arm64 runc arm64 1.3.4-0ubuntu1~24.04.1 [8578 kB]
Get:2 http://ports.ubuntu.com/ubuntu-ports noble-updates/main arm64 containerd arm64 2.2.1-0ubuntu1~24.04.4 [25.2 MB]
debconf: unable to initialize frontend: Dialog
debconf: (Dialog frontend will not work on a dumb terminal, an emacs shell buffer, or without a controlling terminal.)
debconf: falling back to frontend: Readline
… (84 more lines)
```

### If you see something else

- The check says: _containerd is not running on every machine._
- The check says: _containerd is not set to the systemd cgroup driver on every machine._
- `containerd config default | sudo tee /etc/containerd/config.toml > /dev/null` writes the defaults; then `sed` flips `SystemdCgroup = false` to `true`.
- Restart containerd after changing the file, or it keeps the old settings.

### Why it works

**Why it works.** The kubelet does not run containers itself; it talks to a CRI runtime over a socket, here containerd. Both must use the same cgroup driver: kubeadm configures the kubelet for `systemd`, and containerd's default is `cgroupfs`, so `SystemdCgroup = true` lines them up. With mismatched drivers, pods restart for no obvious reason.

**Note:** Docker Engine stopped being a Kubernetes runtime in v1.24 (dockershim was removed); containerd is what Docker itself uses underneath.

---

## Lab 2.3: Install kubeadm, kubelet and kubectl

### What you will do

Follow **Step 3** of the installation guide on **controlplane, node01 and node02**: add the
`pkgs.k8s.io` repository for **v1.36**, install `kubeadm`, `kubelet` and `kubectl`, hold them
(`apt-mark hold`), and enable the kubelet. The kubelet restarts every few seconds until
`kubeadm init` or `join` configures it; that is expected.

### Step by step

**Step 1.** Repeats the command for each of `controlplane`, `node01`, `node02`.

```bash
for n in controlplane node01 node02; do
  ssh $n 'bash -s' <<'STEP3'
sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.36/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.36/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt update
sudo apt install -y kubeadm kubelet kubectl
sudo apt-mark hold kubeadm kubelet kubectl
sudo systemctl enable --now kubelet
STEP3
done
```

You should see something like:

```text
deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.36/deb/ /

WARNING: apt does not have a stable CLI interface. Use with caution in scripts.

Hit:1 http://ports.ubuntu.com/ubuntu-ports noble InRelease
Hit:2 http://ports.ubuntu.com/ubuntu-ports noble-updates InRelease
Hit:3 http://ports.ubuntu.com/ubuntu-ports noble-backports InRelease
Hit:5 http://ports.ubuntu.com/ubuntu-ports noble-security InRelease
Get:4 https://prod-cdn.packages.k8s.io/repositories/isv:/kubernetes:/core:/stable:/v1.36/deb  InRelease [1227 B]
Get:6 https://prod-cdn.packages.k8s.io/repositories/isv:/kubernetes:/core:/stable:/v1.36/deb  Packages [9460 B]
Fetched 10.7 kB in 2s (4641 B/s)
Reading package lists...
Building dependency tree...
Reading state information...
All packages are up to date.

WARNING: apt does not have a stable CLI interface. Use with caution in scripts.

… (162 more lines)
```

### If you see something else

- The check says: _kubeadm v1.36 is not installed on every machine._
- The check says: _The Kubernetes packages are not on hold on every machine._
- The check says: _The kubelet is not enabled on every machine._
- The repository line and the key both name the minor version: `.../core:/stable:/v1.36/deb/`.
- `apt-mark hold` stops `apt upgrade` from upgrading Kubernetes by accident; you unhold them on purpose when you upgrade.

### Why it works

**Why it works.** `kubeadm` bootstraps the cluster, `kubelet` runs pods on every node, and `kubectl` is the client. pkgs.k8s.io has one repository per minor version, so the version you install is chosen by the repository line. Holding the packages stops a routine `apt upgrade` from upgrading Kubernetes behind your back. Until kubeadm writes /var/lib/kubelet/config.yaml, the kubelet exits and systemd restarts it every few seconds.

---

## Lab 2.4: Initialise the control plane

![What kubeadm init and join build: the control plane on controlplane, a kubelet on every node](../images/cluster.svg)

*What kubeadm init and join build: the control plane on controlplane, a kubelet on every node*

### What you will do

Follow **Step 4** of the installation guide on **controlplane**:

1. Run `kubeadm init --pod-network-cidr=192.168.0.0/16` and read its output: keep the
   `kubeadm join` line.
2. Configure kubectl for root: copy `/etc/kubernetes/admin.conf` to `$HOME/.kube/config`.
3. Run `kubectl get nodes`: controlplane is `NotReady` until a network plugin runs.

### Step by step

**Step 1.** Creates the control plane: certificates, etcd, the API server, the scheduler and the controller manager.

```bash
sudo kubeadm init --pod-network-cidr=192.168.0.0/16
```

You should see something like:

```text
I1027 15:59:45.212728    1505 version.go:260] remote version is much newer: v1.37.1; falling back to: stable-1.36
[init] Using Kubernetes version: v1.36.5
[preflight] Running pre-flight checks
    [WARNING SystemVerification]: missing optional cgroups: hugetlb
[preflight] Pulling images required for setting up a Kubernetes cluster
[preflight] This might take a minute or two, depending on the speed of your internet connection
[preflight] You can also perform this action beforehand using 'kubeadm config images pull'
[certs] Using certificateDir folder "/etc/kubernetes/pki"
[certs] Generating "ca" certificate and key
[certs] Generating "apiserver" certificate and key
[certs] apiserver serving cert is signed for DNS names [controlplane kubernetes kubernetes.default kubernetes.default.svc kubernetes.default.svc.cluster.local] and IPs [10.96.0.1 172.30.201.10]
[certs] Generating "apiserver-kubelet-client" certificate and key
[certs] Generating "front-proxy-ca" certificate and key
[certs] Generating "front-proxy-client" certificate and key
[certs] Generating "etcd/ca" certificate and key
[certs] Generating "etcd/server" certificate and key
[certs] etcd/server serving cert is signed for DNS names [controlplane localhost] and IPs [172.30.201.10 127.0.0.1 ::1]
[certs] Generating "etcd/peer" certificate and key
… (67 more lines)
```

**Step 2.** Creates the folder `$HOME/.kube`.

```bash
mkdir -p $HOME/.kube
```

It prints nothing when it works.

**Step 3.** Copies `/etc/kubernetes/admin.conf` to `$HOME/.kube/config`.

```bash
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
```

It prints nothing when it works.

**Step 4.** Makes you the owner of the file, so kubectl can read it without sudo.

```bash
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

It prints nothing when it works.

**Step 5.** Lists the nodes.

```bash
kubectl get nodes
```

You should see something like:

```text
NAME           STATUS     ROLES           AGE   VERSION
controlplane   NotReady   control-plane   1s    v1.36.5
```

### If you see something else

- The check says: _kubeadm init has not run on controlplane yet._
- The check says: _kubectl is not configured for root. Copy /etc/kubernetes/admin.conf to /root/.kube/config._
- The check says: _The cluster was not initialised with --pod-network-cidr=192.168.0.0/16 (Calico's default)._
- `kubeadm init` prints the three commands that configure kubectl; as root, `mkdir -p $HOME/.kube` and the `cp` are enough.
- If init fails half way, `sudo kubeadm reset -f` cleans up so you can run it again.

### Why it works

**Why it works.** `kubeadm init` runs preflight checks, creates the cluster CA and certificates (/etc/kubernetes/pki), writes kubeconfig files for the admin and each component, and writes static pod manifests for etcd, the API server, the controller manager and the scheduler into /etc/kubernetes/manifests, which the kubelet starts. It then installs CoreDNS and kube-proxy and prints a join command. `--pod-network-cidr` reserves the range pod IPs come from; Calico uses 192.168.0.0/16 by default.

**In this lab:** the warning about the optional `hugetlb` cgroup is harmless.

---

## Lab 2.5: Install the network plugin

### What you will do

Follow **Step 5** of the installation guide on **controlplane**: apply the Calico v3.33.0 manifest,
and watch the pods in `kube-system` until Calico and CoreDNS are `Running` and controlplane is
`Ready`.

### Step by step

**Step 1.** Creates the objects in `https://raw.githubusercontent.com/projectcalico/calico/v3.33.0/manifests/calico.yaml`, or updates them if they exist.

```bash
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.33.0/manifests/calico.yaml
```

You should see something like:

```text
poddisruptionbudget.policy/calico-kube-controllers created
serviceaccount/calico-kube-controllers created
serviceaccount/calico-node created
serviceaccount/calico-cni-plugin created
configmap/calico-config created
customresourcedefinition.apiextensions.k8s.io/bgpconfigurations.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/bgpfilters.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/bgppeers.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/blockaffinities.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/caliconodestatuses.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/clusterinformations.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/felixconfigurations.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/globalnetworkpolicies.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/globalnetworksets.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/hostendpoints.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/ipamblocks.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/ipamconfigs.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/ipamhandles.crd.projectcalico.org created
… (20 more lines)
```

**Step 2.** Waits until the rollout of the DaemonSet `calico-node` has finished. Instead of watching with -w.

```bash
kubectl -n kube-system rollout status ds/calico-node --timeout=300s
```

You should see something like:

```text
Waiting for daemon set spec update to be observed...
Waiting for daemon set "calico-node" rollout to finish: 0 out of 1 new pods have been updated...
Waiting for daemon set "calico-node" rollout to finish: 0 of 1 updated pods are available...
daemon set "calico-node" successfully rolled out
```

**Step 3.** Waits until the rollout of the Deployment `coredns` has finished.

```bash
kubectl -n kube-system rollout status deployment/coredns --timeout=120s
```

You should see something like:

```text
Waiting for deployment "coredns" rollout to finish: 0 of 2 updated replicas are available...
Waiting for deployment "coredns" rollout to finish: 1 of 2 updated replicas are available...
deployment "coredns" successfully rolled out
```

**Step 4.** Lists the pods in the namespace `kube-system`.

```bash
kubectl get pods -n kube-system
```

You should see something like:

```text
NAME                                       READY   STATUS              RESTARTS   AGE
calico-kube-controllers-6ffffbccff-l496v   0/1     ContainerCreating   0          2m3s
calico-node-cg9t4                          1/1     Running             0          2m3s
coredns-589f44dc88-ktfk2                   1/1     Running             0          2m3s
coredns-589f44dc88-qhxkh                   1/1     Running             0          2m3s
etcd-controlplane                          1/1     Running             0          2m7s
kube-apiserver-controlplane                1/1     Running             0          2m7s
kube-controller-manager-controlplane       1/1     Running             0          2m7s
kube-proxy-gnk2z                           1/1     Running             0          2m2s
kube-scheduler-controlplane                1/1     Running             0          2m7s
```

**Step 5.** Lists the nodes.

```bash
kubectl get nodes
```

You should see something like:

```text
NAME           STATUS   ROLES           AGE    VERSION
controlplane   Ready    control-plane   2m8s   v1.36.5
```

### If you see something else

- The check says: _Calico is not running yet. Apply the manifest from Step 5 (it takes a minute or two to start)._
- The check says: _controlplane is not Ready yet._
- The check says: _CoreDNS is not running yet. It starts once the network plugin is up._
- `kubectl get pods -n kube-system -w` watches the pods; Ctrl+C stops watching.
- The pod network CIDR you gave kubeadm (192.168.0.0/16) is the one Calico uses by default.

### Why it works

**Why it works.** Kubernetes requires a network plugin but does not ship one. Until a CNI plugin is installed, the node reports `NetworkReady=false` (`NotReady`) and pods that need a pod IP, such as CoreDNS, stay Pending. Calico runs `calico-node` on every node as a DaemonSet, writes the CNI configuration to /etc/cni/net.d, assigns pod IPs from 192.168.0.0/16 and routes between nodes.

**In this lab:** containers cannot change the kernel's conntrack limit, which kube-proxy tries to do; Patchbay sets kube-proxy's `conntrack.maxPerCore: 0` for you (as kind does). On real machines nothing is needed.

---

## Lab 2.6: Join the workers

### What you will do

Follow **Steps 6 and 7** of the installation guide:

1. On controlplane, print a join command with `kubeadm token create --print-join-command`.
2. Run it on **node01** and **node02**.
3. Check that all three nodes are `Ready`, and list the pods in all namespaces.

### Step by step

**Step 1.** Saves `$JOIN`: prints a new join command for workers.

```bash
JOIN=$(kubeadm token create --print-join-command)
```

It prints nothing when it works.

**Step 2.** Prints a value.

```bash
echo "$JOIN"
```

You should see something like:

```text
kubeadm join 172.30.201.10:6443 --token v9udpx.x6dh6x6nsealjqvo --discovery-token-ca-cert-hash sha256:8aeaa19bb92f5d831f2b9a4c32547bec7d7a4aa2fc7310ef930f3a2823f8f82b
```

**Step 3.** On `node01`: joins this machine to the cluster with the join command saved above.

```bash
ssh node01 "sudo $JOIN"
```

You should see something like:

```text
[preflight] Running pre-flight checks
    [WARNING SystemVerification]: missing optional cgroups: hugetlb
[preflight] Reading configuration from the "kubeadm-config" ConfigMap in namespace "kube-system"...
[preflight] Use 'kubeadm init phase upload-config kubeadm --config your-config-file' to re-upload it.
W1027 16:05:35.940621    1648 utils.go:69] The recommended value for "bindAddress" in "KubeProxyConfiguration" is: ::; the provided value is: 0.0.0.0
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/instance-config.yaml"
[patches] Applied patch of type "application/strategic-merge-patch+json" to target "kubeletconfiguration"
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[kubelet-start] Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
[kubelet-start] Starting the kubelet
[kubelet-check] Waiting for a healthy kubelet at http://127.0.0.1:10248/healthz. This can take up to 4m0s
[kubelet-check] The kubelet is healthy after 504.923267ms
[kubelet-start] Waiting for the kubelet to perform the TLS Bootstrap

This node has joined the cluster:
* Certificate signing request was sent to apiserver and a response was received.
* The Kubelet was informed of the new secure connection details.

Run 'kubectl get nodes' on the control-plane to see this node join the cluster.
```

**Step 4.** On `node02`: joins this machine to the cluster with the join command saved above.

```bash
ssh node02 "sudo $JOIN"
```

You should see something like:

```text
[preflight] Running pre-flight checks
    [WARNING SystemVerification]: missing optional cgroups: hugetlb
[preflight] Reading configuration from the "kubeadm-config" ConfigMap in namespace "kube-system"...
[preflight] Use 'kubeadm init phase upload-config kubeadm --config your-config-file' to re-upload it.
W1027 16:05:38.402481    1616 utils.go:69] The recommended value for "bindAddress" in "KubeProxyConfiguration" is: ::; the provided value is: 0.0.0.0
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/instance-config.yaml"
[patches] Applied patch of type "application/strategic-merge-patch+json" to target "kubeletconfiguration"
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[kubelet-start] Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
[kubelet-start] Starting the kubelet
[kubelet-check] Waiting for a healthy kubelet at http://127.0.0.1:10248/healthz. This can take up to 4m0s
[kubelet-check] The kubelet is healthy after 503.933242ms
[kubelet-start] Waiting for the kubelet to perform the TLS Bootstrap

This node has joined the cluster:
* Certificate signing request was sent to apiserver and a response was received.
* The Kubelet was informed of the new secure connection details.

Run 'kubectl get nodes' on the control-plane to see this node join the cluster.
```

**Step 5.** Waits until the nodes `node01`, `node02` are Ready.

```bash
kubectl wait --for=condition=Ready node/node01 node/node02 --timeout=180s
```

You should see something like:

```text
node/node01 condition met
node/node02 condition met
```

**Step 6.** Lists the nodes.

```bash
kubectl get nodes
```

You should see something like:

```text
NAME           STATUS   ROLES           AGE     VERSION
controlplane   Ready    control-plane   4m29s   v1.36.5
node01         Ready    <none>          2m18s   v1.36.5
node02         Ready    <none>          2m15s   v1.36.5
```

**Step 7.** Lists the pods in every namespace.

```bash
kubectl get pods --all-namespaces
```

You should see something like:

```text
NAMESPACE     NAME                                       READY   STATUS     RESTARTS   AGE
kube-system   calico-kube-controllers-6ffffbccff-l496v   1/1     Running    0          4m25s
kube-system   calico-node-4rx7q                          0/1     Init:3/4   0          2m18s
kube-system   calico-node-cg9t4                          1/1     Running    0          4m25s
kube-system   calico-node-zdl5n                          0/1     Init:2/4   0          2m15s
kube-system   coredns-589f44dc88-ktfk2                   1/1     Running    0          4m25s
kube-system   coredns-589f44dc88-qhxkh                   1/1     Running    0          4m25s
kube-system   etcd-controlplane                          1/1     Running    0          4m29s
kube-system   kube-apiserver-controlplane                1/1     Running    0          4m29s
kube-system   kube-controller-manager-controlplane       1/1     Running    0          4m29s
kube-system   kube-proxy-2fj2r                           1/1     Running    0          2m15s
kube-system   kube-proxy-gnk2z                           1/1     Running    0          4m24s
kube-system   kube-proxy-qclz4                           1/1     Running    0          2m18s
kube-system   kube-scheduler-controlplane                1/1     Running    0          4m29s
```

### If you see something else

- The check says: _node01 and node02 are not both Ready members of the cluster._
- The join command holds a token (valid 24 hours) and the CA certificate hash, so the worker can trust the control plane.
- `ssh node01`, paste the join command with `sudo` in front, `exit`, and the same on node02.

### Why it works

**Why it works.** `kubeadm join` uses a bootstrap token to authenticate to the API server, checks the server's identity with the CA certificate hash, and then gets the kubelet a client certificate of its own (TLS bootstrapping). Once the kubelet registers the node, the DaemonSets (kube-proxy, calico-node) start a pod on it, and it turns Ready when its network is up.

**In the exam:** `kubeadm token create --print-join-command` is the reliable way to get a working join command.

---

## Lab 2.7: Grow the cluster

### What you will do

Follow [kubeadm-lesson-growing-the-cluster.md](https://github.com/kumbulanit/CKA/blob/main/01-installation/kubeadm-lesson-growing-the-cluster.md)
to add **node03**:

1. Set node03's host name, add node03 to `/etc/hosts` on controlplane, node01 and node02, and add
   the existing machines to `/etc/hosts` on node03.
2. Run steps 1–3 of the installation guide on node03 (with the same minor version, v1.36).
3. Join it with a fresh join command, and check that it is `Ready`.

### Step by step

**Step 1.** Saves `$NODE03_IP`: looks up an address.

```bash
NODE03_IP=$(getent hosts node03 | awk '{print $1}')
```

It prints nothing when it works.

**Step 2.** On `node03`: sets the machine's name to `node03`.

```bash
ssh node03 "sudo hostnamectl set-hostname node03"
```

It prints nothing when it works.

**Step 3.** Repeats the command for each of `controlplane`, `node01`, `node02`.

```bash
for n in controlplane node01 node02; do ssh $n "echo '$NODE03_IP node03' | sudo tee -a /etc/hosts"; done
```

You should see something like:

```text
172.30.174.13 node03
172.30.174.13 node03
172.30.174.13 node03
```

**Step 4.** Adds these lines to `/etc/hosts` on `node03`.

```bash
grep -E ' (controlplane|node01|node02)$' /etc/hosts | ssh node03 'sudo tee -a /etc/hosts'
```

You should see something like:

```text
172.30.174.10 controlplane
172.30.174.11 node01
172.30.174.12 node02
```

**Step 5.** Runs the commands below on `node03`. Steps 1-3 of the installation guide on node03.

```bash
ssh node03 'bash -s' <<'STEPS'
sudo apt update && sudo apt upgrade -y
sudo apt install -y apt-transport-https ca-certificates curl gpg
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
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
sudo apt install -y containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd
sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.36/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.36/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt update
sudo apt install -y kubeadm kubelet kubectl
sudo apt-mark hold kubeadm kubelet kubectl
sudo systemctl enable --now kubelet
STEPS
```

You should see something like:

```text

WARNING: apt does not have a stable CLI interface. Use with caution in scripts.

Hit:1 http://ports.ubuntu.com/ubuntu-ports noble InRelease
Get:2 http://ports.ubuntu.com/ubuntu-ports noble-updates InRelease [126 kB]
Hit:3 http://ports.ubuntu.com/ubuntu-ports noble-backports InRelease
Hit:4 http://ports.ubuntu.com/ubuntu-ports noble-security InRelease
Get:5 http://ports.ubuntu.com/ubuntu-ports noble-updates/universe arm64 Packages [2223 kB]
Get:6 http://ports.ubuntu.com/ubuntu-ports noble-updates/main arm64 Packages [1795 kB]
Get:7 http://ports.ubuntu.com/ubuntu-ports noble-updates/restricted arm64 Packages [3260 kB]
Fetched 7404 kB in 12s (626 kB/s)
Reading package lists...
Building dependency tree...
Reading state information...
All packages are up to date.

WARNING: apt does not have a stable CLI interface. Use with caution in scripts.

… (164 more lines)
```

**Step 6.** Saves `$JOIN`: prints a new join command for workers.

```bash
JOIN=$(kubeadm token create --print-join-command)
```

It prints nothing when it works.

**Step 7.** On `node03`: joins this machine to the cluster with the join command saved above.

```bash
ssh node03 "sudo $JOIN"
```

You should see something like:

```text
[preflight] Running pre-flight checks
    [WARNING SystemVerification]: missing optional cgroups: hugetlb
[preflight] Reading configuration from the "kubeadm-config" ConfigMap in namespace "kube-system"...
[preflight] Use 'kubeadm init phase upload-config kubeadm --config your-config-file' to re-upload it.
W1028 13:57:16.067996    1066 utils.go:69] The recommended value for "bindAddress" in "KubeProxyConfiguration" is: ::; the provided value is: 0.0.0.0
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/instance-config.yaml"
[patches] Applied patch of type "application/strategic-merge-patch+json" to target "kubeletconfiguration"
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[kubelet-start] Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
[kubelet-start] Starting the kubelet
[kubelet-check] Waiting for a healthy kubelet at http://127.0.0.1:10248/healthz. This can take up to 4m0s
[kubelet-check] The kubelet is healthy after 509.046423ms
[kubelet-start] Waiting for the kubelet to perform the TLS Bootstrap

This node has joined the cluster:
* Certificate signing request was sent to apiserver and a response was received.
* The Kubelet was informed of the new secure connection details.

Run 'kubectl get nodes' on the control-plane to see this node join the cluster.
```

**Step 8.** Waits until the node `node03` is Ready.

```bash
kubectl wait --for=condition=Ready node/node03 --timeout=180s
```

You should see something like:

```text
node/node03 condition met
```

**Step 9.** Lists the nodes.

```bash
kubectl get nodes
```

You should see something like:

```text
NAME           STATUS   ROLES           AGE     VERSION
controlplane   Ready    control-plane   5m19s   v1.36.6
node01         Ready    <none>          4m11s   v1.36.6
node02         Ready    <none>          4m8s    v1.36.6
node03         Ready    <none>          66s     v1.36.6
```

**Step 10.** Lists the pods in every namespace.

```bash
kubectl get pods --all-namespaces
```

You should see something like:

```text
NAMESPACE     NAME                                       READY   STATUS     RESTARTS   AGE
kube-system   calico-kube-controllers-6ffffbccff-bv2tz   1/1     Running    0          5m14s
kube-system   calico-node-2mlkd                          0/1     Init:2/4   0          66s
kube-system   calico-node-86mtt                          1/1     Running    0          4m8s
kube-system   calico-node-h9jtp                          1/1     Running    0          5m15s
kube-system   calico-node-wg6wv                          1/1     Running    0          4m11s
kube-system   coredns-589f44dc88-k24h9                   1/1     Running    0          5m14s
kube-system   coredns-589f44dc88-q5c4z                   1/1     Running    0          5m14s
kube-system   etcd-controlplane                          1/1     Running    0          5m18s
kube-system   kube-apiserver-controlplane                1/1     Running    0          5m18s
kube-system   kube-controller-manager-controlplane       1/1     Running    0          5m18s
kube-system   kube-proxy-blbjh                           1/1     Running    0          4m8s
kube-system   kube-proxy-gsrqc                           1/1     Running    0          5m15s
kube-system   kube-proxy-lxcwt                           1/1     Running    0          4m10s
kube-system   kube-proxy-qcvh5                           1/1     Running    0          66s
kube-system   kube-scheduler-controlplane                1/1     Running    0          5m18s
```

### If you see something else

- The check says: _node03 and the other machines are not all in each other's /etc/hosts._
- The check says: _node03 has not joined the cluster, or is not Ready yet._
- The check says: _node03 should run the same minor version as the cluster, v1.36._
- Steps 1–3 are exactly what you did for the first three machines in tasks 2.1 to 2.3, now on node03 only.
- Join tokens expire after 24 hours; `kubeadm token create --print-join-command` always gives you a fresh one.

### Why it works

**Why it works.** A new node goes through the same preparation as the first ones, then joins with a fresh token. Its packages must match the cluster's minor version: a kubelet must not be newer than the API server. Once it joins, the scheduler starts using it; existing pods stay where they are until they are rescheduled.

**In practice:** adding capacity is this simple because all the cluster's state lives in the control plane; a worker only needs a runtime, a kubelet and a token.

---
