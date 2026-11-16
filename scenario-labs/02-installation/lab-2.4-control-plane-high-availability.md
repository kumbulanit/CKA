# Lab 2.4: Control plane high availability

**The situation:** the Shop runs on a cluster with one control plane node. What happens to the Shop when that node has a problem?

**Goal:** understand what happens when the control plane is lost, and how a real cluster protects itself with more than one control plane node.

**Outline topic:** 2. Installation, Configuration & Validation: *Control Plane High Availability*.

**What you learn:** what keeps running without a control plane, leader election, etcd members, the parts of a highly available (HA) control plane.

Your cluster has **one** control plane node. That is fine for learning. In production it is a risk: if that node is lost, nobody can change anything.

> **How to use this lab**
>
> - **📋 Copy and paste into your terminal:** copy the whole grey box (the copy button is in its top right corner), paste it into the terminal of your server, and press Enter.
> - **👀 You should see** *(do not paste)*: what the command prints. Names that end in random letters, IP addresses and ages are different on your server. That is normal.
> - **📖 Read only:** something to look at. Do not paste it.
> - **💡 Tip:** a shortcut or an extra. You do not need it to finish the lab.

## A highly available control plane

| Part | With one control plane node | Highly available |
| --- | --- | --- |
| API server | 1 | 3, behind a **load balancer** |
| etcd | 1 member | 3 members (it needs a majority: 2 of 3) |
| Scheduler, controller manager | 1 each | 3 each, but only **one is the leader** at a time |

Always an **odd** number of control plane nodes (3 or 5), so that etcd can have a majority.

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

## Step 1: see where the control plane runs

**📋 Copy and paste into your terminal:**

```bash
kubectl get pods -n kube-system -l tier=control-plane -o wide
```

**What this does:** Lists the pods with the label `tier=control-plane` in the namespace `kube-system`, with extra columns such as the IP address and the node.

**👀 You should see** the four parts, all on the node `minikube` *(do not paste)*:

```text
NAME                               READY   STATUS    RESTARTS   AGE   IP             NODE       NOMINATED NODE   READINESS GATES
etcd-minikube                      1/1     Running   0          3h    192.168.49.2   minikube   <none>           <none>
kube-apiserver-minikube            1/1     Running   0          3h    192.168.49.2   minikube   <none>           <none>
kube-controller-manager-minikube   1/1     Running   0          3h    192.168.49.2   minikube   <none>           <none>
kube-scheduler-minikube            1/1     Running   0          3h    192.168.49.2   minikube   <none>           <none>
```

One node, one copy of each. This is the single point of failure.

## Step 2: see the leader election setting

When there are three schedulers, only one may work at a time: the **leader**. The others wait. Look at the setting on your cluster:

**📋 Copy and paste into your terminal:**

```bash
minikube ssh -- sudo grep leader-elect /etc/kubernetes/manifests/kube-scheduler.yaml /etc/kubernetes/manifests/kube-controller-manager.yaml
```

**What this does:** Looks in the files of the scheduler and the controller manager, on the control plane node, for the setting `leader-elect`.

**👀 You should see** *(do not paste)*:

```text
/etc/kubernetes/manifests/kube-scheduler.yaml:    - --leader-elect=false
/etc/kubernetes/manifests/kube-controller-manager.yaml:    - --leader-elect=false
```

`false`: there is only one scheduler here, so there is nothing to elect. In a highly available cluster this is `true`. The schedulers then agree on a leader through a small object called a **lease**. If the leader dies, another one takes the lease within seconds.

## Step 3: see the etcd members

**📋 Copy and paste into your terminal:**

```bash
kubectl -n kube-system exec etcd-minikube -- etcdctl --endpoints=https://127.0.0.1:2379 \
  --cacert=/var/lib/minikube/certs/etcd/ca.crt \
  --cert=/var/lib/minikube/certs/etcd/server.crt \
  --key=/var/lib/minikube/certs/etcd/server.key \
  member list --write-out=table
```

**What this does:** Asks etcd, inside its pod, for its members: the copies of the cluster database. The `--cacert`, `--cert` and `--key` options are the certificates etcd needs to let you in. You use the same options for the backup in Lab 2.5.

**👀 You should see** one member (the ID differs) *(do not paste)*:

```text
+------------------+---------+----------+---------------------------+---------------------------+------------+
|        ID        | STATUS  |   NAME   |        PEER ADDRS         |       CLIENT ADDRS        | IS LEARNER |
+------------------+---------+----------+---------------------------+---------------------------+------------+
| aec36adc501070cc | started | minikube | https://192.168.49.2:2380 | https://192.168.49.2:2379 |      false |
+------------------+---------+----------+---------------------------+---------------------------+------------+
```

An HA cluster shows three members here.

## Step 4: what still works when the control plane is down?

Try it. Stop the API server for half a minute, by moving its file away (it is a static pod, Lab 2.3):

**📋 Copy and paste into your terminal:**

```bash
minikube ssh -- sudo mv /etc/kubernetes/manifests/kube-apiserver.yaml /tmp/
sleep 15
kubectl get nodes
```

**What this does:**

- `minikube ssh -- sudo ...`: On the control plane node: moves the API server's file out of the static pod folder. The kubelet then stops the API server.
- `sleep 15`: Waits 15 seconds, to give Kubernetes time.
- `kubectl get nodes`: Lists the nodes.

**👀 You should see** *(do not paste)*:

```text
The connection to the server 192.168.49.2:8443 was refused - did you specify the right host or port?
```

`kubectl` is blind. But is the Shop down?

**📋 Copy and paste into your terminal:**

```bash
curl -s http://$(minikube ip):30080/api/items; echo
```

**What this does:** Asks the Shop for its items, as a web browser would. This does not use the API server.

**👀 You should see** the items *(do not paste)*:

```text
[{"id":1,"name":"Coffee","price":35},
 {"id":2,"name":"Tea","price":25},
 {"id":3,"name":"Muffin","price":30}]
```

**The Shop still works.** Pods that run keep running without the control plane. What does **not** work: changing anything, scheduling new pods, replacing a pod that dies.

## Step 5: bring the API server back

**📋 Copy and paste into your terminal:**

```bash
minikube ssh -- sudo mv /tmp/kube-apiserver.yaml /etc/kubernetes/manifests/
sleep 45
kubectl get nodes
```

**What this does:**

- `minikube ssh -- sudo ...`: On the control plane node: puts the API server's file back. The kubelet starts the API server again.
- `sleep 45`: Waits 45 seconds, to give Kubernetes time.
- `kubectl get nodes`: Lists the nodes.

**👀 You should see** three `Ready` nodes. If you still get `connection refused`, or a node says `NotReady`, wait 30 seconds and try again.

## How a highly available cluster is built

1. A **load balancer** with one address, in front of all the API servers.
2. Three control plane nodes instead of one. Each has an API server, a scheduler, a controller manager and an etcd member.
3. The workers and `kubectl` talk to the load balancer address, never to one control plane node.

minikube can build this too, when the cluster is created: `minikube start --ha --nodes=5` makes three control plane nodes and two workers. It needs more memory than your server has, so the trainer shows it on the screen.

💡 **Exam tip:** "stacked" etcd means etcd runs on the control plane nodes. "External" etcd means etcd has its own machines.

✅ **Check:** `kubectl get nodes` works again and shows three `Ready` nodes.

**Next:** [Lab 2.5: Cluster maintenance: etcd backup](./lab-2.5-cluster-maintenance-etcd-backup.md)
