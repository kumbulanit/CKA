# Lab 1.1 explained: Kubernetes architecture and the three environments

This page goes with [Lab 1.1](./lab-1.1-architecture-and-namespaces.md). The lab has the commands; this page explains them: what happens in the cluster, why it matters for the Shop, what usually goes wrong, and what the exam asks. There is nothing to paste here.

## In short

A Kubernetes cluster is a group of machines (nodes) run by a **control plane**. You never talk to the nodes directly: you tell the control plane what you want, and it makes it happen. In this lab you meet the parts of the cluster, and you create three **namespaces**, one per environment of the Shop.

## The ideas behind this lab

### Desired state

Kubernetes works with **desired state**. You do not say "start a container on node 2". You say "I want 2 copies of the backend", and Kubernetes keeps checking and correcting until the cluster looks like that. Every object you create (a pod, a Deployment, a Service) is a written-down wish, stored in the cluster's database.

### The control plane and the workers

| Part | Where | What it does |
| --- | --- | --- |
| **kube-apiserver** | Control plane | The only front door. `kubectl`, the other parts and the nodes all talk to it. It checks who you are and whether you may do what you ask. |
| **etcd** | Control plane | The database. Every object is stored here. Lose etcd, lose the cluster (Lab 2.5 backs it up). |
| **kube-scheduler** | Control plane | Picks a node for every new pod (Module 4). |
| **kube-controller-manager** | Control plane | Runs the controllers: small loops that compare what you want with what there is, and fix the difference. |
| **kubelet** | Every node | Starts and watches the containers of the pods on its node, and reports back to the API server. |
| **kube-proxy** | Every node | Makes Service addresses work (Lab 1.4, Module 3). |
| **container runtime** | Every node | Actually runs the containers (containerd on the course cluster). |

One way to remember it: the API server is the **front desk**, etcd is the **filing cabinet**, the scheduler **assigns the work**, the controller manager **checks that the work is done**, and the kubelets are the **workers on the floor**.

### Namespaces

A **namespace** is a folder for objects. Names must be unique inside a namespace, but the same name can exist in two namespaces. That is exactly what the Shop needs: a `backend` in `dev`, another `backend` in `uat` and another in `prod`, all from the same files.

A namespace separates **names**, nothing more. Pods in different namespaces can still talk to each other over the network (Lab 3.1 fixes that), and anyone with access to the cluster can still see all of them (Lab 5.1 fixes that).

## Step by step

### Step 1: go to the lab folder

All the files of Module 1 are in one folder. The labs use short file names such as `backend-pod.yaml`, which only work from inside that folder.

### Step 2: look at the nodes

`kubectl get nodes` sends a request to the API server, which reads the node objects from etcd. Each kubelet updates its node object every few seconds. That update is what makes a node `Ready`: a node whose kubelet stops reporting turns `NotReady` within about a minute (you see this in Lab 8.1).

`ROLES` is read from the node's labels. `VERSION` is the version of the kubelet on that node.

### Step 3: look at the control plane

`kubectl cluster-info` prints the address of the API server, taken from your kubeconfig, plus the cluster DNS. Port `8443` is minikube's port for the API server; on kubeadm clusters it is usually `6443`.

`kubectl get pods -n kube-system` shows that the control plane parts are themselves **pods**. On the control plane node they are **static pods**: the kubelet starts them from files on the node, not from the API server. That is how the API server can run in a pod while the pods depend on the API server (Lab 2.1 and Lab 2.3 look at those files).

The names tell you where each pod runs: `etcd-minikube` and `kube-apiserver-minikube` end in the node name; `calico-node` and `kube-proxy` have **three** pods, one per node, because they run as DaemonSets (Lab 2.2).

### Step 4: create the three environments

`kubectl create namespace dev` stores a Namespace object in etcd. Nothing starts running: a namespace is only a place to put things. The cluster already had four namespaces:

| Namespace | What is in it |
| --- | --- |
| `default` | Where things go when you name no namespace |
| `kube-system` | The parts of Kubernetes itself |
| `kube-public` | A little information anyone may read |
| `kube-node-lease` | One small "I am alive" object per node, updated by each kubelet |

### Step 5: make `dev` your working namespace

`kubectl config set-context --current --namespace=dev` changes your **kubeconfig** file (`~/.kube/config`), not the cluster. From now on, a command without `-n` works in `dev`. The cluster does not know or care which namespace "you are in": it is only a default that `kubectl` adds to every request.

That is why the labs always write `-n uat` and `-n prod` in full: a missing `-n` sends the command to `dev`.

## When something goes wrong

| What you see | What it means | What to do |
| --- | --- | --- |
| `The connection to the server ... was refused` | The cluster is stopped | `cd ~/CKA && sudo ./setup.sh` |
| A node is `NotReady` | Its kubelet or its network pod is not working | Wait a minute; still `NotReady`: run `setup.sh` again |
| `namespaces "dev" already exists` | You created it before | Nothing to do: it is there |
| A pod in `kube-system` is not `Running` | A part of the cluster is unhealthy | Run `check-ready.sh`; it names the part and the fix |

## For the exam

- Know the job of every control plane part and every node part, and where each one runs. "Which component chooses the node for a pod?" is a classic question.
- Every exam task names its namespace. Use `-n` on every command, or switch the namespace first. Objects created in the wrong namespace earn no points.
- `kubectl get pods -A` (all namespaces) is the fastest way to see everything that runs.

## Check your understanding

1. Which part of the cluster does `kubectl` talk to?
2. Where is the backend you create in the next lab stored?
3. Why do `kube-proxy` and `calico-node` have three pods each?
4. Two teams both want a Deployment called `backend`. How can they share one cluster?
5. You ran `kubectl config set-context --current --namespace=dev`. Did the cluster change?

<details><summary>Answers</summary>

1. The API server, and only the API server.
2. In etcd, through the API server.
3. They run on every node: one pod per node, three nodes.
4. Each team uses its own namespace.
5. No. Only your kubeconfig changed: it now adds `dev` to commands without `-n`.

</details>

**Back to:** [Lab 1.1](./lab-1.1-architecture-and-namespaces.md) · **Next:** [Lab 1.2 explained](./lab-1.2-pods-labels-selectors-explained.md)
