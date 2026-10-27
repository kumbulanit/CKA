# Installing and Configuring Kubernetes for Ubuntu (Minikube)

Minikube runs a small Kubernetes cluster on one machine. It is the course's practice cluster: `sudo ./setup.sh`, at the top of this repository, does everything in this lesson in one command (Docker, minikube, kubectl, helm) and starts a 3-node cluster with `minikube start --driver=docker --nodes=3 --kubernetes-version=v1.36.5 --cni=calico`; see the README. The exam uses kubeadm clusters, which [Kubernetes installation using kubeadm](./Kubernetes%20installation%20using%20kubeadm.md) builds.

## 1. Prerequisites

- Ubuntu 22.04 or 24.04 (amd64 or arm64), 2 CPUs, 2 GB of free memory, 20 GB of free disk.
- A driver for Minikube. This guide uses **Docker** (works on amd64 and arm64). VirtualBox also works, on amd64 only.

## 2. Install Dependencies

**Install curl:**
```sh
sudo apt-get update
sudo apt-get install -y curl ca-certificates gpg
```

**Install Docker** (from Docker's own repository):

1. **Add Docker's official GPG key:**
   ```sh
   sudo install -m 0755 -d /etc/apt/keyrings
   sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
   sudo chmod a+r /etc/apt/keyrings/docker.asc
   ```

2. **Set up the Docker repository:**
   ```sh
   echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
   ```

3. **Install Docker:**
   ```sh
   sudo apt-get update
   sudo apt-get install -y docker-ce docker-ce-cli containerd.io
   ```

4. **Check Docker version to verify installation:**
   ```sh
   docker --version
   ```

5. **Allow your user to run Docker commands without `sudo`** (Minikube's Docker driver needs this):
   ```sh
   sudo usermod -aG docker $USER
   newgrp docker
   ```

6. **Verify Docker installation by running the hello-world image:**
   ```sh
   docker run hello-world
   ```

## 3. Install Minikube

**Download the Minikube binary for your CPU** (`amd64` or `arm64`):
```sh
ARCH=$(dpkg --print-architecture)
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-${ARCH}
```

**Install Minikube:**
```sh
sudo install -o root -g root -m 0755 minikube-linux-${ARCH} /usr/local/bin/minikube
```

**Verify Installation:**
```sh
minikube version
```

## 4. Install kubectl

kubectl is the command-line tool for interacting with the cluster. Install it from the Kubernetes package repository (`pkgs.k8s.io`):

```sh
sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.36/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.36/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubectl
```

**Verify Installation:**
```sh
kubectl version --client
```

(Or download the binary directly, see *Installing kubectl* below.)

## 5. Start Minikube

**Start Minikube with Docker:**
```sh
minikube start --driver=docker
```

This command downloads the Kubernetes images, creates a container that acts as the cluster node, and starts the cluster.

**Start Minikube with VirtualBox (amd64 only, alternative):**
```sh
sudo apt-get install -y virtualbox
minikube start --driver=virtualbox
```

## 6. Verify Cluster Status

Once Minikube has started, you can check the status of the cluster:

```sh
minikube status
```

You should see that the cluster and various components (e.g., kubelet, apiserver) are running.

## 7. Interact with the Cluster

**Check Nodes:**
```sh
kubectl get nodes
```
You should see a single node listed with a status of Ready.

**Access Kubernetes Dashboard (Optional):**
Minikube ships its own copy of the Dashboard as an add-on. This command opens it in your default web browser:

```sh
minikube dashboard
```

## 8. Stopping and Deleting Minikube

**Stop Minikube:**
```sh
minikube stop
```
This stops the cluster but keeps its configuration intact.

**Delete Minikube:**
```sh
minikube delete
```
This deletes the cluster and all cluster-related data.

## Documentation Link for kubectl

https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/

### Installing kubectl (binary download):
```sh
ARCH=$(dpkg --print-architecture)
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${ARCH}/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin
```

To use a cluster that runs elsewhere, copy its kubeconfig file (for a kubeadm cluster: `/etc/kubernetes/admin.conf` on the control plane node) to `~/.kube/config`:

```sh
mkdir -p ~/.kube
nano ~/.kube/config
```

### Verification:
```sh
kubectl get nodes
```

## Installing Helm

Helm's apt repository has moved (the old `baltocdn.com` repository no longer serves packages):

```sh
curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install -y helm
```
