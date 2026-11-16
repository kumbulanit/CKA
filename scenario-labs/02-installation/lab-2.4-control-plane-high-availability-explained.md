# Lab 2.4 explained: control plane high availability

This page goes with [Lab 2.4](./lab-2.4-control-plane-high-availability.md). The lab has the commands; this page explains them: what happens in the cluster, why it matters for the Shop, what usually goes wrong, and what the exam asks. There is nothing to paste here.

## In short

The course cluster has one control plane node: if it goes, nobody can change anything. In this lab you stop the API server and see the surprise: the Shop keeps serving. A **highly available** (HA) control plane removes the single point of failure: three control plane nodes behind a load balancer, three etcd members that vote, and one active leader for the scheduler and the controller manager.

## The ideas behind this lab

### What the control plane is needed for

The control plane makes **decisions and changes**. The workers do the **work**. Once a pod runs, the kubelet keeps it running and kube-proxy's rules stay in the kernel, without asking anybody. So when the control plane is down:

| Still works | Does not work |
| --- | --- |
| Running pods keep running and serving | `kubectl`: no answers, no changes |
| Services keep sending traffic (the rules are already on the nodes) | No new pods are scheduled |
| A crashed container is restarted by its kubelet, in the same pod | A pod that disappears (deleted, node lost) is not replaced |
| | Scaling, updates, new Services: nothing changes |

The Shop stays open, but it is frozen, and every failure from now on is permanent until the control plane returns.

### The three parts of an HA control plane

| Part | How it is made highly available | Why that way |
| --- | --- | --- |
| **API server** | Several copies, all active, behind one **load balancer** address | It keeps no state of its own (the state is in etcd), so any copy can answer any request |
| **etcd** | Several **members** that vote; a change counts only when a **majority** agrees | Copies of a database must agree on one truth |
| **Scheduler, controller manager** | Several copies, but only one **leader** works at a time | Two schedulers placing the same pod would fight |

### Majority (quorum) and odd numbers

etcd needs a majority of its members to agree on every change. With 3 members, 2 is a majority: one member may fail. With 5, 3 is a majority: two may fail. With 4 members, 3 is a majority, so still only one may fail, at the cost of an extra machine. That is why control plane nodes come in **odd** numbers. With 2 members, losing either one stops the cluster: worse than 1.

### Leader election

Each scheduler and controller manager copy tries to take a **lease**, a small object in the namespace `kube-system`. The one that holds it is the leader and works; it renews the lease every few seconds. The others wait. If the leader stops renewing (its node died), the lease runs out after a few seconds and another copy takes it. The setting `--leader-elect=true` turns this on.

### Stacked or external etcd

**Stacked:** each control plane node also runs an etcd member (the kubeadm default, and the course cluster). Fewer machines, but losing a node loses both. **External:** etcd has its own machines. More machines, but the two kinds of failure are separate.

## Step by step

### Step 1: see where the control plane runs

The label `tier=control-plane` selects the four static pods. They all run on the one node `minikube`, and their IP is the node's own address, because they use the node's network. One node, one copy of each: the single point of failure.

### Step 2: see the leader election setting

The scheduler's and controller manager's static pod files say `--leader-elect=false`. minikube turns it off because there is only one copy: nothing to elect. On a kubeadm cluster it is `true` even with one control plane node, so a second one can join later.

### Step 3: see the etcd members

`etcdctl member list` asks etcd itself for its members. `etcdctl` runs inside the etcd pod and logs in with the cluster's etcd certificates, the same three options you use for the backup in Lab 2.5. One member, at port 2379 for clients (the API server) and 2380 for the other members. An HA cluster would list three.

### Step 4: what still works when the control plane is down?

Moving `kube-apiserver.yaml` out of `/etc/kubernetes/manifests` makes the kubelet stop the API server: a static pod lives exactly as long as its file (Lab 2.3). `kubectl` now gets `connection refused`. But `curl` to the Shop still returns the items: the request goes through kube-proxy's rules to pods that were already running, and never touches the API server.

### Step 5: bring the API server back

Moving the file back makes the kubelet start the API server again. It takes a little while: the API server connects to etcd, and the other parts and the kubelets reconnect. After that, everything that was missed (for example, a pod that died meanwhile) is fixed by the controllers.

### How a highly available cluster is built

The load balancer is the key: workers and `kubectl` talk to its one address, so they do not care which API server answers. With kubeadm, the first node is made with `kubeadm init --control-plane-endpoint=<load balancer address>`, and the other two join with `kubeadm join ... --control-plane`. minikube's `--ha` option builds the same shape, but needs more memory than a course server has.

## When something goes wrong

| What you see | What it means | What to do |
| --- | --- | --- |
| `kubectl` still refused after Step 5 | The API server needs a little longer | Wait 30 seconds and try again |
| Still refused after two minutes | The file was not put back, or was changed | `minikube ssh -- sudo ls /etc/kubernetes/manifests`: all four files must be there |
| `etcdctl` says `certificate signed by unknown authority` | A certificate path is wrong | Use the paths from the etcd file: `minikube ssh -- 'sudo grep -E "cert\|key" /etc/kubernetes/manifests/etcd.yaml'` (with the single quotes) |
| The Shop stops answering in Step 4 | A Shop pod died while the control plane was down, and nothing replaced it | Bring the API server back; the controllers fix it |

## For the exam

- Know the HA picture: a load balancer, an odd number of control plane nodes, etcd quorum, leader election.
- "Stacked" etcd runs on the control plane nodes; "external" etcd has its own machines.
- Know what keeps working without the API server (running workloads) and what does not (any change).
- Control plane parts are static pods: their files are in `/etc/kubernetes/manifests`, and fixing a broken control plane often means fixing one of those files.

## Check your understanding

1. The API server is down. Does the Shop answer? Can you scale the backend?
2. Why may several API servers be active at once, but only one scheduler?
3. Why is a cluster with 4 etcd members not safer than one with 3?
4. What happens when the scheduler's leader dies?
5. What do the workers and `kubectl` point at in an HA cluster?

<details><summary>Answers</summary>

1. Yes, the Shop answers. No, nothing can be changed until the API server is back.
2. The API server keeps no state of its own (it is all in etcd); two schedulers would make conflicting decisions about the same pods.
3. Both survive only one failed member: 4 needs 3 to agree, 3 needs 2.
4. It stops renewing its lease; after a few seconds another copy takes the lease and becomes the leader.
5. The load balancer's address, never a single control plane node.

</details>

**Back to:** [Lab 2.4](./lab-2.4-control-plane-high-availability.md) · **Next:** [Lab 2.5 explained](./lab-2.5-cluster-maintenance-etcd-backup-explained.md)
