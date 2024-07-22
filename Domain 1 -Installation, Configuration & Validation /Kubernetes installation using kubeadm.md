### Kubernetes Installation Using kubeadm: Installation, Configuration & Validation

#### Overview

`kubeadm` is a tool that helps you install and configure a secure Kubernetes cluster rapidly. It automates the process of setting up the control plane and joining worker nodes to the cluster.

### Prerequisites

1. **Servers**: At least one master node and one worker node.
2. **Operating System**: Ubuntu 20.04 or CentOS 7.
3. **Network**: Full network connectivity between all machines in the cluster.
4. **User**: Root user or a user with sudo privileges.

### Step 1: Prepare the System

**1. Update the system**:
```sh
sudo apt update && sudo apt upgrade -y
```

**2. Install necessary packages**:
```sh
sudo apt install -y apt-transport-https ca-certificates curl
```

**3. Disable swap**:
```sh
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
```

### Step 2: Install Docker

**1. Install Docker CE**:
```sh
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io
```

**2. Start and enable Docker**:
```sh
sudo systemctl start docker
sudo systemctl enable docker
```

### Step 3: Install kubeadm, kubelet, and kubectl

**1. Add the Kubernetes repository**:
```sh
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
sudo apt-add-repository "deb http://apt.kubernetes.io/ kubernetes-xenial main"
```

**2. Install Kubernetes packages**:
```sh
sudo apt update
sudo apt install -y kubeadm kubelet kubectl
sudo apt-mark hold kubeadm kubelet kubectl
```

### Step 4: Initialize the Master Node

**1. Initialize the control plane**:
```sh
sudo kubeadm init --pod-network-cidr=192.168.0.0/16
```

**Output**:
```sh
Your Kubernetes control-plane has initialized successfully!
To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/networking/

You can now join any number of machines by running the following on each node
as root:

  kubeadm join <master-ip>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>
```

**2. Configure kubectl for the regular user**:
```sh
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

### Step 5: Deploy a Pod Network

**1. Install Calico network plugin**:
```sh
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
```

### Step 6: Join Worker Nodes

**1. On each worker node, run the join command (from Step 4 output)**:
```sh
sudo kubeadm join <master-ip>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>
```

### Step 7: Validate the Cluster

**1. Check nodes status**:
```sh
kubectl get nodes
```

**Output**:
```sh
NAME         STATUS   ROLES    AGE     VERSION
master-node  Ready    master   10m     v1.20.1
worker-node1 Ready    <none>   5m      v1.20.1
worker-node2 Ready    <none>   5m      v1.20.1
```

**2. Check the status of pods**:
```sh
kubectl get pods --all-namespaces
```

### Diagram: Kubernetes Cluster Setup

```plaintext
+-------------------------------------+
|             Master Node             |
|                                     |
| +---------------------------------+ |
| |        Control Plane            | |
| |                                 | |
| |  - kube-apiserver               | |
| |  - kube-controller-manager      | |
| |  - kube-scheduler               | |
| |  - etcd                         | |
| +---------------------------------+ |
|                                     |
+-------------------------------------+
                 |
                 |
                 v
+-------------------------------------+
|            Worker Node 1            |
|                                     |
| +---------------------------------+ |
| |            kubelet              | |
| |            kube-proxy           | |
| |                                 | |
| |  - Container Runtime (Docker)   | |
| |  - Pods                         | |
| +---------------------------------+ |
|                                     |
+-------------------------------------+
                 |
                 |
                 v
+-------------------------------------+
|            Worker Node 2            |
|                                     |
| +---------------------------------+ |
| |            kubelet              | |
| |            kube-proxy           | |
| |                                 | |
| |  - Container Runtime (Docker)   | |
| |  - Pods                         | |
| +---------------------------------+ |
|                                     |
+-------------------------------------+
```

### Conclusion

Using `kubeadm` simplifies the installation and configuration of a Kubernetes cluster. By following the steps outlined above, you can set up a basic Kubernetes cluster with a master node and worker nodes, deploy a network plugin, and validate the installation.

### Additional Resources

- **Kubernetes Official Documentation**: [https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)
- **Kubernetes the Hard Way**: [https://github.com/kelseyhightower/kubernetes-the-hard-way](https://github.com/kelseyhightower/kubernetes-the-hard-way)
- **Books**: "Kubernetes Up & Running" by Kelsey Hightower, Brendan Burns, and Joe Beda



