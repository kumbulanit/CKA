# Installing and Configuring Kubenetes for Ubuntu

Prerequisites
Before installing Minikube, make sure you have the following prerequisites installed:

Ubuntu System: This guide assumes you're using Ubuntu 18.04 or later.
Virtualization Software: Minikube supports various virtualization providers. For Ubuntu, you can use VirtualBox, KVM, or Docker. Ensure that you have one of these installed. This guide will use VirtualBox.
2. Install Dependencies
Install VirtualBox
```sh

sudo apt update
```
sudo apt install -y virtualbox virtualbox-ext-pack
Install curl
```sh

sudo apt install -y curl
```
3. Install Minikube
Download Minikube Binary
```sh

curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
```
Install Minikube
```sh

sudo install -o root -g root -m 0755 minikube-linux-amd64 /usr/local/bin/minikube
```
Verify Installation
```sh

minikube version
```
4. Install kubectl
kubectl is the command-line tool for interacting with Kubernetes clusters.

Install kubectl Using apt
```sh

sudo apt update
sudo apt install -y kubectl
```
Verify Installation
```sh

kubectl version --client
```
5. Start Minikube
Start Minikube with VirtualBox
```sh

minikube start --driver=virtualbox
```
This command will download the Minikube VM image, create a virtual machine, and start the Kubernetes cluster.

Start Minikube with Docker (Alternative)
If you prefer using Docker instead of VirtualBox:

```sh

minikube start --driver=docker
```
6. Verify Cluster Status
Once Minikube has started, you can check the status of the cluster:

```sh

minikube status
```
You should see that the cluster and various components (e.g., kubelet, apiserver) are running.

7. Interact with the Cluster
Check Nodes
```sh

kubectl get nodes
```
You should see a single node listed with a status of Ready.

Access Kubernetes Dashboard (Optional)
Minikube provides a Kubernetes Dashboard that you can access from your browser:

```sh

minikube dashboard
```
This command will open the Kubernetes Dashboard in your default web browser.

8. Stopping and Deleting Minikube
Stop Minikube
```sh

minikube stop
```
This will stop the Minikube VM but keep the cluster configuration intact.

Delete Minikube
```sh

minikube delete
```
This will delete the Minikube VM and remove all cluster-related data.

###  Documentation Link for kubectl

https://kubernetes.io/docs/tasks/tools/install-kubectl/   


### Installing Kubectl:
```sh
curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl

chmod +x kubectl
mv kubectl /usr/local/bin
```
##
Copy the config file which you have downloaded inside the config file in ~/kube directory.
### Verification:
```sh
kubectl get nodes
```

```sh
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
sudo apt-get install apt-transport-https --yes
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm
```
