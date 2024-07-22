### Installing a Standalone Kubernetes Cluster on Ubuntu

Installing a standalone Kubernetes cluster on Ubuntu involves setting up Kubernetes components on a single machine. This setup is suitable for development, testing, or learning purposes. The following guide uses `kubeadm` for installation, which simplifies the process of setting up Kubernetes clusters.

---

### **Prerequisites**

- **Operating System**: Ubuntu 20.04 or later.
- **Hardware**: Minimum of 2 GB RAM and 2 CPUs (recommended).
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
sudo apt-get install -y apt-transport-https ca-certificates curl
```

**1.3. Disable Swap**

Kubernetes requires swap to be disabled for optimal performance.

```sh
sudo swapoff -a
```

To permanently disable swap, comment out or remove the swap entry from `/etc/fstab`.

```sh
sudo nano /etc/fstab
```

Comment out the swap line, save and exit (`Ctrl+O`, `Enter`, `Ctrl+X`).

---

### **2. Install Docker**

Kubernetes uses Docker as the default container runtime.

**2.1. Install Docker**

```sh
sudo apt-get install -y docker.io
```

**2.2. Start and Enable Docker**

```sh
sudo systemctl start docker
sudo systemctl enable docker
```

**2.3. Add Kubernetes Repository**

```sh
sudo curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
```

**2.4. Add the Kubernetes APT Repository**

```sh
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
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

**4.3. Verify the Cluster Status**

```sh
kubectl get nodes
```

---

### **5. Install a Pod Network**

Kubernetes requires a network solution to enable communication between pods. Flannel is a commonly used network plugin.

**5.1. Apply the Flannel Network Plugin**

```sh
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
```

**5.2. Verify the Network Plugin Installation**

```sh
kubectl get pods --all-namespaces
```

Wait until the `kube-flannel-ds` pods are in the `Running` state.

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

### **7. Optional: Enable Kubernetes Dashboard**

**7.1. Deploy the Kubernetes Dashboard**

```sh
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.5.1/aio/deploy/recommended.yaml
```

**7.2. Access the Dashboard**

Create a Service Account and ClusterRoleBinding for dashboard access.

```sh
kubectl create serviceaccount dashboard-admin-sa
kubectl create clusterrolebinding dashboard-admin-sa --clusterrole=cluster-admin --serviceaccount=default:dashboard-admin-sa
```

Get the access token.

```sh
kubectl -n default get secret $(kubectl -n default get sa/dashboard-admin-sa -o=jsonpath='{.secrets[0].name}') -o=jsonpath='{.data.token}' | base64 --decode
```

Start the kubectl proxy.

```sh
kubectl proxy
```

Access the dashboard via [http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/](http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/)

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
|  Install Docker  |
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
- **Flannel Documentation**: [https://github.com/coreos/flannel](https://github.com/coreos/flannel)
