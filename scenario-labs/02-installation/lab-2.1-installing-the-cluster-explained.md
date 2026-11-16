# Lab 2.1 explained: installing the cluster

This page goes with [Lab 2.1](./lab-2.1-installing-the-cluster.md). The lab has the commands; this page explains them: what happens in the cluster, why it matters for the Shop, what usually goes wrong, and what the exam asks. There is nothing to paste here.

## In short

Your cluster was built by `setup.sh` with minikube, which runs kubeadm inside Docker containers. In this lab you look under the Shop: what a node is made of, where the control plane comes from, and the three checks that tell you a cluster is healthy. You also stop and start the whole cluster, and see what survives.

## The ideas behind this lab

### How a cluster is built (the kubeadm way)

The exam clusters, and many real ones, are built with **kubeadm**. On a fresh machine it goes like this:

1. **Prepare every node:** a container runtime (containerd), the kubelet, kubeadm and kubectl; swap off; IP forwarding on.
2. **`kubeadm init` on the first control plane node:** it checks the machine, makes a certificate authority and certificates for every part, writes kubeconfig files, writes four **static pod** files (etcd, API server, controller manager, scheduler), waits for them to start, and prints a `kubeadm join` command.
3. **Install a network plugin** (CNI), such as Calico. Until then, every node stays `NotReady`.
4. **`kubeadm join` on every other node:** the node's kubelet gets a certificate and registers with the API server.

minikube does all four steps for you, inside its Docker containers. The result has the same parts, in the same places, as a kubeadm cluster. That is why what you learn in this lab carries over to the exam.

### What a node is made of

| Part | What it is | Runs as |
| --- | --- | --- |
| Container runtime | Runs containers (containerd) | A program (systemd service) |
| kubelet | Starts the pods of its node, reports the node's state | A program (systemd service) |
| kube-proxy | Writes the Service rules | A pod (DaemonSet) |
| Network plugin | Gives pods their network | A pod (`calico-node`, DaemonSet) |
| Control plane parts | Only on control plane nodes | Static pods, from `/etc/kubernetes/manifests` |

The kubelet and the runtime are **not** pods: they must run before any pod can. Everything else runs as pods, started by the kubelet.

### The chicken and the egg: static pods

The API server runs in a pod, but pods are normally created through the API server. The way out: the kubelet watches a folder on its node (`/etc/kubernetes/manifests`) and starts every pod file in it, without asking the API server. Those are **static pods**. Lab 2.3 makes one of your own.

## Step by step

### Step 1: see the cluster as minikube sees it

`minikube status` asks minikube, not Kubernetes. It shows each node's container (`host`), its kubelet, and on the control plane the API server and your kubeconfig. If `kubectl` cannot reach the cluster, `minikube status` still answers, which helps to tell "the cluster is down" from "kubectl is pointed at the wrong place".

### Step 2: see the nodes as Docker sees them

`docker ps` shows the three containers that **are** your nodes. Stopping a container would be like pulling the power cable of a machine. Inside each container runs a complete little Linux machine with containerd and a kubelet.

### Step 3: go inside the control plane node

`minikube ssh -- COMMAND` runs one command on a node; `minikube ssh` alone opens a shell there. The four files in `/etc/kubernetes/manifests` are the control plane. Change one, and the kubelet restarts that part within seconds; remove one, and that part stops (Lab 2.4 does exactly that with the API server).

### Step 4: validate the cluster

Three checks, from the outside in:

| Check | What it proves |
| --- | --- |
| `kubectl get nodes -o wide`: all `Ready`, same version | Every kubelet runs, reports in, and has a network |
| `kubectl get pods -n kube-system`: all `Running` | The control plane parts, DNS and the network plugin all run |
| `kubectl get --raw='/readyz?verbose'` | The API server checks itself, part by part, including its connection to etcd |

`/readyz` is the API server's own health page. `readyz check passed` means it is ready to serve requests. Use these three checks after every install, upgrade or repair, in the lab and in the exam.

### Step 5: stop and start the cluster

`minikube stop` stops the three node containers; `minikube start` starts them again. Everything you created survives, because it is stored in **etcd**, whose files are kept on the control plane node's disk. The pods are recreated from those objects when the kubelets come back.

What does not survive: data inside pods. The database pod started again with a fresh `emptyDir`, so the Juice is gone once more. The objects are safe in etcd; the Shop's **data** is not, yet (Module 7).

### To start again from nothing

`minikube delete` removes the node containers and their disks, including etcd. That deletes the Shop, which is why the lab says not to run it now. `setup.sh` then builds a new, empty cluster, and `scripts/deploy-shop.sh` can rebuild the Shop.

## When something goes wrong

| What you see | What it means | What to do |
| --- | --- | --- |
| `minikube status` shows `Stopped` | The node containers are stopped | `minikube start`, or `sudo ./setup.sh` |
| A node `NotReady` after `minikube start` | Its kubelet or network pod is still starting | Wait a minute; then `setup.sh` |
| `readyz` lists a `[-]` line | One of the API server's own checks fails | Read that line: often etcd |
| `kubectl` hangs after a restart | Your kubeconfig may point at an old address | `minikube update-context`, or run `setup.sh` |

## For the exam

- Know the kubeadm steps: prepare nodes, `kubeadm init`, network plugin, `kubeadm join`. The curriculum names installing a cluster with kubeadm.
- Know where things are on a kubeadm node: `/etc/kubernetes/manifests` (static pods), `/etc/kubernetes/pki` (certificates), `/etc/kubernetes/*.conf` (kubeconfig files), `/var/lib/kubelet/config.yaml` (kubelet settings).
- The kubelet is a systemd service: `systemctl status kubelet` and `journalctl -u kubelet` on the node.
- After any change to a cluster, validate: nodes, `kube-system` pods, `readyz`.

## Check your understanding

1. Which two parts of a node are not pods, and why?
2. How does the API server start, if pods are created through the API server?
3. After `minikube stop` and `minikube start`, the Deployments are back but the Juice is not. Why?
4. Which three checks validate a cluster?
5. What does `kubeadm init` print at the end, and what is it for?

<details><summary>Answers</summary>

1. The container runtime and the kubelet. They must run before any pod can start.
2. As a static pod: the kubelet starts it from a file in `/etc/kubernetes/manifests`, without the API server.
3. Objects are stored in etcd, on disk. The Juice was inside the database pod's `emptyDir`, which is new after every restart.
4. All nodes `Ready`; all `kube-system` pods `Running`; the API server's `/readyz`.
5. The `kubeadm join` command, to run on the other nodes so they join the cluster.

</details>

**Back to:** [Lab 2.1](./lab-2.1-installing-the-cluster.md) · **Next:** [Lab 2.2 explained](./lab-2.2-growing-the-cluster-explained.md)
