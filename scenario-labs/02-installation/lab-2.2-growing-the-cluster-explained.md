# Lab 2.2 explained: growing the cluster

This page goes with [Lab 2.2](./lab-2.2-growing-the-cluster.md). The lab has the commands; this page explains them: what happens in the cluster, why it matters for the Shop, what usually goes wrong, and what the exam asks. There is nothing to paste here.

## In short

A cluster grows by **joining** new nodes. The new node's kubelet gets a certificate, registers with the API server, and becomes `Ready` once the network plugin runs on it. DaemonSets put their pods on it by themselves; your applications do not move until new pods are made. To shrink, you **drain** a node first, then delete it.

## The ideas behind this lab

### What joining means

On a kubeadm cluster, a worker joins in three steps:

1. **Prepare the machine** like the first one: container runtime, kubelet, kubeadm.
2. **Get a join command** on the control plane: `kubeadm token create --print-join-command`. It contains the API server's address, a **token** (a short-lived password for joining, valid 24 hours by default) and the **hash of the cluster's CA certificate**, so the new node can check it talks to the real cluster.
3. **Run it on the new node.** The kubelet uses the token to ask for its own certificate (**TLS bootstrapping**), gets it signed, and from then on logs in with that certificate. It creates its Node object and starts reporting.

`minikube node add` does these steps for you: it starts a new node container and joins it.

### Why the node becomes `Ready` by itself

A new node is `NotReady` until it has a network. The network plugin runs as a **DaemonSet** (`calico-node`), and so does `kube-proxy`. A DaemonSet means "one pod on every node, including nodes that join later". So the moment the node appears, the DaemonSet controller creates its pods there, the network comes up, and the node turns `Ready`. Nobody has to do anything.

### Roles are only labels

`ROLES` in `kubectl get nodes` is read from labels named `node-role.kubernetes.io/<role>`. kubeadm labels the control plane; workers get no role label, so they show `<none>`. The label changes nothing about what the node does. It is for people, and for scheduling rules that select by it.

### New capacity is not used at once

The scheduler only places **new** pods. Pods already running stay on their node; Kubernetes does not rebalance by itself. The new node fills up as pods are created: by scaling, by updates, by `kubectl rollout restart`, or when other pods are replaced.

## Step by step

### Step 1: add a node

minikube creates a fourth container (`minikube-m04`), installs the same Kubernetes version in it, and joins it. This takes a minute or two, and memory: on a small server, this is the lab that strains it most.

### Step 2: see the new node

`minikube-m04` appears, first `NotReady`, then `Ready` once Calico runs on it. `ROLES` is `<none>`: minikube did not label it.

### Step 3: give it the worker role

`kubectl label node minikube-m04 node-role.kubernetes.io/worker=` adds the label with an empty value. Only the key matters. `setup.sh` does the same for the course's workers.

### Step 4: see what runs on a new node

`--field-selector spec.nodeName=minikube-m04` lists only the pods on that node, across all namespaces (`-A`). Only `calico-node` and `kube-proxy` are there: the two DaemonSets. Their IP is the node's own address, because they run in the node's network (`hostNetwork`), not in the pod network.

### Step 5: use the new node

Scaling the DEV frontend to 4 makes two new pods. The scheduler scores the nodes, and the empty new node scores well, so new pods usually land there. Scaling back to 2 removes two pods; which ones is the ReplicaSet's choice.

### Step 6: remove the node again

The order matters:

1. **`kubectl drain`** marks the node unschedulable and evicts its pods, so their Deployments recreate them on other nodes. `--ignore-daemonsets` is needed because DaemonSet pods would come straight back; `--delete-emptydir-data` accepts that `emptyDir` data on the node is lost.
2. **`minikube node delete`** removes the container and the Node object.

Deleting a node without draining it first stops its pods abruptly. Their controllers do replace them, but only after Kubernetes notices the node is gone (minutes), and the users notice first. Lab 2.7 looks at `drain` in detail.

## When something goes wrong

| What you see | What it means | What to do |
| --- | --- | --- |
| `minikube node add` is very slow or fails | The server is short of memory | Show it as a demo; check `free -h` |
| The new node stays `NotReady` | Its `calico-node` pod is not running yet | `kubectl get pods -n kube-system -o wide`; wait |
| On kubeadm: `token ... invalid` | The join token expired | `kubeadm token create --print-join-command` again |
| `cannot delete DaemonSet-managed Pods` | `drain` without `--ignore-daemonsets` | Add the option |
| `kubectl get nodes` still lists 4 nodes | The node was not removed | `minikube node delete minikube-m04`; the next labs expect 3 nodes |

## For the exam

- Join a worker: `kubeadm token create --print-join-command` on the control plane, run the output on the worker (with `sudo`).
- Always `kubectl drain` before removing or maintaining a node; `kubectl uncordon` when it may take pods again.
- DaemonSets put one pod on every node, new ones included. A task may ask you to create one: write a Deployment, change `kind` to `DaemonSet`, and remove `replicas` and `strategy`.
- Node roles are labels: `kubectl label node NAME node-role.kubernetes.io/worker=`.

## Check your understanding

1. What is in a `kubeadm join` command, and why the CA hash?
2. Why did `calico-node` and `kube-proxy` appear on the new node without anyone creating them?
3. You add a node to a busy cluster. Do the running pods move to it?
4. What does the `worker` role change about the node?
5. Why drain a node before deleting it?

<details><summary>Answers</summary>

1. The API server's address, a token, and the hash of the cluster's CA certificate. The hash lets the new node check that it joins the real cluster.
2. They are DaemonSets: one pod on every node, including new ones.
3. No. Only new pods are scheduled there; running pods stay put.
4. Nothing about its behaviour: it is a label for people and for selectors.
5. So its pods are moved to other nodes in an orderly way first, instead of disappearing with the node.

</details>

**Back to:** [Lab 2.2](./lab-2.2-growing-the-cluster.md) · **Next:** [Lab 2.3 explained](./lab-2.3-standalone-pods-explained.md)
