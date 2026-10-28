### Installing a Standalone Kubernetes Cluster on Ubuntu

> Despite its name, this page installs a single-node cluster with **kubeadm** (the tool the CKA exam uses). The course's practice cluster is minikube: see [01-install-minikube.md](./01-install-minikube.md), or run `sudo ./setup.sh`.


Installing a standalone Kubernetes cluster on Ubuntu involves setting up Kubernetes components on a single machine. This setup is suitable for development, testing, or learning purposes. The following guide uses `kubeadm` for installation, which simplifies the process of setting up Kubernetes clusters. (For the 3-node cluster the practicals use, see [Kubernetes installation using kubeadm](./kubeadm-lesson-install-kubeadm.md).)

---

### **Prerequisites**

- **Operating System**: Ubuntu 24.04 LTS (amd64 or arm64).
- **Hardware**: Minimum of 2 GB RAM and 2 CPUs.
- **User**: Non-root user with `sudo` privileges.
- **Network**: Ensure the machine has internet access.

**Commands are to be executed on the terminal.**

---

### **1. Prepare the System**

**1.1. Update the System**

```sh
sudo apt-get update
sudo apt-get upgrade -y
```

**1.2. Install Required Packages**

```sh
sudo apt-get install -y apt-transport-https ca-certificates curl gpg
```

**1.3. Disable Swap**

The kubelet does not start while swap is on (unless you configure it to allow swap).

```sh
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
```

**1.4. Load Kernel Modules and Network Settings**

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

---

### **2. Install the Container Runtime (containerd)**

Kubernetes no longer uses Docker Engine directly (dockershim was removed in v1.24). It uses a CRI runtime such as containerd.

**2.1. Install containerd**

```sh
sudo apt-get install -y containerd
```

**2.2. Configure containerd for the systemd cgroup driver**

```sh
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd
```

**2.3. Add the Kubernetes Repository Key**

The old `apt.kubernetes.io` repository was shut down in 2024; packages now come from `pkgs.k8s.io`, one repository per minor version.

```sh
sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.36/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
```

**2.4. Add the Kubernetes APT Repository**

```sh
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.36/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
```

**2.5. Update APT Package Index**

```sh
sudo apt-get update
```

---

### **3. Install Kubernetes Components**

**3.1. Install `kubeadm`, `kubelet`, and `kubectl`**

```sh
sudo apt-get install -y kubeadm kubelet kubectl
sudo systemctl enable --now kubelet
```

**3.2. Hold the Packages at the Current Version**

```sh
sudo apt-mark hold kubeadm kubelet kubectl
```

---

### **4. Initialize the Kubernetes Cluster**

**4.1. Initialize the Cluster Using `kubeadm`**

```sh
sudo kubeadm init --pod-network-cidr=10.244.0.0/16
```

- `--pod-network-cidr=10.244.0.0/16` specifies the CIDR for Flannel. Adjust this if using a different network plugin.

**4.2. Set Up the Kubernetes Configuration for `kubectl`**

```sh
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

**4.3. Allow Pods on the Control Plane Node**

A single-node cluster has no worker nodes, so remove the taint that keeps ordinary pods off the control plane:

```sh
kubectl taint nodes --all node-role.kubernetes.io/control-plane-
```

**4.4. Verify the Cluster Status**

```sh
kubectl get nodes
```

The node shows `NotReady` until the pod network is installed.

---

### **5. Install a Pod Network**

Kubernetes requires a network solution to enable communication between pods. Flannel is a commonly used network plugin.

**5.1. Apply the Flannel Network Plugin**

```sh
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
```

**5.2. Verify the Network Plugin Installation**

```sh
kubectl get pods --all-namespaces
```

Wait until the `kube-flannel-ds` pods (in the `kube-flannel` namespace) are in the `Running` state.

---

### **6. Test the Cluster**

**6.1. Create a Sample Pod**

```sh
kubectl run nginx --image=nginx --restart=Never
```

**6.2. Verify the Pod Status**

```sh
kubectl get pods
```

**6.3. Expose the Pod via a Service**

```sh
kubectl expose pod nginx --port=80 --name=nginx-service
```

**6.4. Verify the Service**

```sh
kubectl get services
```

---

### **7. Optional: A Web UI**

The Kubernetes Dashboard project has been archived and is no longer maintained, so this guide does not install it. If you want a web UI, use [Headlamp](https://headlamp.dev/), a Kubernetes SIG UI project.

Service account tokens are no longer stored in Secrets automatically (since v1.24). To get a token for a UI or a script, create one on demand:

```sh
kubectl create serviceaccount dashboard-admin-sa
kubectl create clusterrolebinding dashboard-admin-sa --clusterrole=cluster-admin --serviceaccount=default:dashboard-admin-sa
kubectl create token dashboard-admin-sa
```

---

### **Diagram: Standalone Kubernetes Cluster Installation**

```plaintext
+------------------+
|  Ubuntu Machine  |
+--------+---------+
         |
         |
         v
+--------+---------+
| Install containerd|
|  and Kubernetes  |
+--------+---------+
         |
         |
         v
+--------+---------+
|  Initialize      |
|  Cluster         |
+--------+---------+
         |
         |
         v
+--------+---------+
|  Apply Pod       |
|  Network         |
+--------+---------+
         |
         |
         v
+--------+---------+
|  Verify and Test |
+------------------+
```

---

### **Conclusion**

You now have a standalone Kubernetes cluster set up on Ubuntu, suitable for development or testing purposes. Follow these steps to ensure that your cluster is properly configured and operational.

**Additional Resources**:
- **Kubernetes Documentation**: [https://kubernetes.io/docs/](https://kubernetes.io/docs/)
- **Flannel Documentation**: [https://github.com/flannel-io/flannel](https://github.com/flannel-io/flannel)
