# Lab 2.1: Installing the cluster: what is under the Shop

**The situation:** the Shop runs in three environments. Before you put real users on it, you must know the cluster under it: how it was installed, what it is made of, and how to check that it is healthy.

**Outline topic:** 2. Installation, Configuration & Validation: *Kubernetes installation*.

**What you learn:** how the cluster was installed with **minikube**, what a node is made of, how to validate a cluster.

📘 **More detail:** [Lab 2.1 explained](./lab-2.1-installing-the-cluster-explained.md): what happens in the cluster at each step, common mistakes and exam notes.

Your cluster was installed by `setup.sh` with **minikube**, on your Ubuntu server. minikube builds a full Kubernetes cluster inside Docker: every node is one container.

> **How to use this lab**
>
> - **📋 Copy and paste into your terminal:** copy the whole grey box (the copy button is in its top right corner), paste it into the terminal of your server, and press Enter.
> - **👀 You should see** *(do not paste)*: what the command prints. Names that end in random letters, IP addresses and ages are different on your server. That is normal.
> - **📖 Read only:** something to look at. Do not paste it.
> - **💡 Tip:** a shortcut or an extra. You do not need it to finish the lab.

## What `setup.sh` did

| Step | What | Command it ran |
| --- | --- | --- |
| 1 | Install Docker | `apt-get install docker-ce ...` |
| 2 | Install minikube, kubectl and helm, and the shortcuts `kubens` and `kubectx` | downloads the programs |
| 3 | Create and start the cluster | `minikube start --driver=docker --nodes=3 --kubernetes-version=v1.36.5 --cni=calico` |
| 4 | Validate | `kubectl get nodes` |

Read step 3 again. One command, four choices:

| Option | Meaning |
| --- | --- |
| `--driver=docker` | Every node is a Docker container |
| `--nodes=3` | One control plane node and two workers |
| `--kubernetes-version=v1.36.5` | The Kubernetes version to install |
| `--cni=calico` | The network plugin for the pods (Module 3) |

## Before you start

Go to the folder of this module, and make `dev` your working namespace:

**📋 Copy and paste into your terminal:**

```bash
cd ~/CKA/scenario-labs/02-installation
kubectl config set-context --current --namespace=dev
```

**What this does:**

- `cd ~/CKA/scenario-labs/02-installation`: Goes to the folder `~/CKA/scenario-labs/02-installation`.
- `kubectl config set-context --current --namespace=dev`: Makes `dev` your working namespace: commands without `-n` now work in `dev`.

**👀 You should see** *(do not paste)*:

```text
Context "minikube" modified.
```

💡 **Tip:** `kubens dev` does the same as the second line (see the shortcuts in [setup, Step 5](../00-setup.md)).

## Step 1: see the cluster as minikube sees it

**📋 Copy and paste into your terminal:**

```bash
minikube status
```

**What this does:** Shows if each node and its parts are running.

**👀 You should see** the three nodes and their parts *(do not paste)*:

```text
minikube
type: Control Plane
host: Running
kubelet: Running
apiserver: Running
kubeconfig: Configured

minikube-m02
type: Worker
host: Running
kubelet: Running

minikube-m03
type: Worker
host: Running
kubelet: Running
```

Every node has a **kubelet**: the agent that starts and watches the pods on that node. Only the control plane has an **apiserver**.

## Step 2: see the nodes as Docker sees them

**📋 Copy and paste into your terminal:**

```bash
docker ps --format "table {{.Names}}\t{{.Status}}"
```

**What this does:** Lists the running Docker containers: each one is a node of your cluster.

**👀 You should see** three containers, one for each node *(do not paste)*:

```text
NAMES          STATUS
minikube-m03   Up 53 minutes
minikube-m02   Up 53 minutes
minikube       Up 53 minutes
```

## Step 3: go inside the control plane node

The control plane parts are started from four files on the control plane node:

**📋 Copy and paste into your terminal:**

```bash
minikube ssh -- sudo ls /etc/kubernetes/manifests
```

**What this does:** Lists the folder `/etc/kubernetes/manifests` on the control plane node (`minikube`). `minikube ssh --` runs one command on a node, and comes back to your server.

**👀 You should see** *(do not paste)*:

```text
etcd.yaml	     kube-controller-manager.yaml
kube-apiserver.yaml  kube-scheduler.yaml
```

Four files, four parts of the control plane (Lab 1.1). The kubelet reads this folder and starts one pod for each file. Pods started this way are called **static pods**. You make one yourself in Lab 2.3.

## Step 4: validate the cluster

Three checks. Use them after every installation, upgrade or repair.

**Check 1: the nodes**

**📋 Copy and paste into your terminal:**

```bash
kubectl get nodes -o wide
```

**What this does:** Lists the nodes, with extra columns such as the IP address and the node.

**👀 You should see** three nodes, all `Ready`, all on the same version.

**Check 2: the system pods**

**📋 Copy and paste into your terminal:**

```bash
kubectl get pods -n kube-system
```

**What this does:** Lists the pods in the namespace `kube-system`.

**👀 You should see** all pods `Running` (Lab 1.1, Step 3).

**Check 3: ask the API server how it feels**

**📋 Copy and paste into your terminal:**

```bash
kubectl get --raw='/readyz?verbose' | tail -4
```

**What this does:** Asks the API server itself if it is healthy, check by check. `| tail` shows only the last 4 lines.

**👀 You should see** *(do not paste)*:

```text
[+]poststarthook/apiservice-openapi-controller ok
[+]poststarthook/apiservice-openapiv3-controller ok
[+]shutdown ok
readyz check passed
```

💡 **Tip:** the course script `~/CKA/scenario-labs/scripts/check-ready.sh` ([setup, Step 6](../00-setup.md)) does these three checks and more in one go: it also looks at Docker, the tools, DNS, storage and the Shop. In the exam there is no such script: learn the three checks above.

## Step 5: stop and start the cluster

A cluster you can install, you can also stop and start. Your Shop is kept.

**📋 Copy and paste into your terminal:**

```bash
minikube stop
```

**What this does:** Stops the cluster (all its nodes). Nothing in it is lost.

**👀 You should see** (the last line) *(do not paste)*:

```text
* 3 nodes stopped.
```

**📋 Copy and paste into your terminal:**

```bash
minikube start
kubectl get nodes
```

**What this does:**

- `minikube start`: Starts the cluster (all its nodes).
- `kubectl get nodes`: Lists the nodes.

**👀 You should see** (after about two minutes) three `Ready` nodes again. Then check the Shop *(do not paste)*:

**📋 Copy and paste into your terminal:**

```bash
kubectl rollout status deployment/backend -n dev
curl -s http://$(minikube ip):30080/api/items; echo
```

**What this does:**

- `kubectl rollout status deployment/backend -n dev`: Waits until the new pods of the Deployment `backend` in the namespace `dev` are all ready, and says when it is done.
- `curl -s http://$(minikube ip):30080/api/items; echo`: Asks the Shop for its items, as a web browser would.

**👀 You should see** the items. The Deployments, Services, ConfigMaps and Secrets were all kept: they are stored in etcd, on the control plane node.

Look at the list: the Juice is gone again, if you had added it. The database pod was stopped and started. The Storage module fixes this.

## To start again from nothing

If a cluster is broken beyond repair, delete it and install it again. **Do not run this now**: it removes the Shop.

**📖 Read only (do not paste):**

```text
minikube delete
cd ~/CKA && sudo ./setup.sh
```

✅ **Check:** all three validation checks pass, and the Shop answers.

**Next:** [Lab 2.2: Growing the cluster](./lab-2.2-growing-the-cluster.md)
