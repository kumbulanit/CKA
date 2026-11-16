# Lab 2.2: Growing the cluster: add a node

**Goal:** add a fourth node to the cluster, see it join, and remove it again.

**Outline topic:** 2. Installation, Configuration & Validation: *Growing the cluster*.

**What you learn:** what happens when a node joins, node roles, removing a node.

**The situation:** the Shop gets more users, and three nodes are not enough. A cluster grows by **joining** more nodes. With minikube that is one command: `minikube node add`. It creates the node, gives it a certificate, and joins it to the control plane.

> **How to use this lab**
>
> - **📋 Copy and paste into your terminal:** copy the whole grey box (the copy button is in its top right corner), paste it into the terminal of your server, and press Enter.
> - **👀 You should see** *(do not paste)*: what the command prints. Names that end in random letters, IP addresses and ages are different on your server. That is normal.
> - **📖 Read only:** something to look at. Do not paste it.
> - **💡 Tip:** a shortcut or an extra. You do not need it to finish the lab.

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

## Step 1: add a node

This takes one to two minutes.

**📋 Copy and paste into your terminal:**

```bash
minikube node add
```

**What this does:** Creates a new node and joins it to the cluster.

**👀 You should see** (the last line) *(do not paste)*:

```text
* Successfully added m04 to minikube!
```

## Step 2: see the new node

**📋 Copy and paste into your terminal:**

```bash
kubectl get nodes
```

**What this does:** Lists the nodes.

**👀 You should see** four nodes. The new one is `minikube-m04`. If it says `NotReady`, wait 30 seconds and look again: its network pod is still starting.

```text
NAME           STATUS   ROLES           AGE   VERSION
minikube       Ready    control-plane   3h    v1.36.5
minikube-m02   Ready    worker          3h    v1.36.5
minikube-m03   Ready    worker          3h    v1.36.5
minikube-m04   Ready    <none>          60s   v1.36.5
```

## Step 3: give it the worker role

`ROLES` shows `<none>`. A role is only a label. Add it:

**📋 Copy and paste into your terminal:**

```bash
kubectl label node minikube-m04 node-role.kubernetes.io/worker=
kubectl get nodes
```

**What this does:**

- `kubectl label node minikube-m04 ...`: Puts the label `node-role.kubernetes.io/worker=` on the node `minikube-m04`.
- `kubectl get nodes`: Lists the nodes.

**👀 You should see** `worker` in the `ROLES` column of `minikube-m04`.

## Step 4: see what runs on a new node

**📋 Copy and paste into your terminal:**

```bash
kubectl get pods -A -o wide --field-selector spec.nodeName=minikube-m04
```

**What this does:** Lists the pods in all namespaces, only those on the node `minikube-m04`, with extra columns such as the IP address and the node.

**👀 You should see** two system pods, and no Shop pods *(do not paste)*:

```text
NAMESPACE     NAME                READY   STATUS    RESTARTS   AGE   IP             NODE           NOMINATED NODE   READINESS GATES
kube-system   calico-node-7xk9p   1/1     Running   0          90s   192.168.49.5   minikube-m04   <none>           <none>
kube-system   kube-proxy-w2c4d    1/1     Running   0          90s   192.168.49.5   minikube-m04   <none>           <none>
```

Two things to see:

- The network pods came **by themselves**. They belong to a **DaemonSet**: one pod on every node, also on new nodes.
- The Shop's pods did **not** move. Running pods stay where they are. Only **new** pods can land on the new node.

## Step 5: use the new node

Scale the DEV frontend up and see where the new pods go:

**📋 Copy and paste into your terminal:**

```bash
kubectl scale deployment frontend -n dev --replicas=4
sleep 15
kubectl get pods -n dev -l app=frontend -o wide
```

**What this does:**

- `kubectl scale deployment frontend -n dev --replicas=4`: Changes the number of pods of the Deployment `frontend` in the namespace `dev` to 4.
- `sleep 15`: Waits 15 seconds, to give Kubernetes time.
- `kubectl get pods -n dev -l app=frontend -o wide`: Lists the pods with the label `app=frontend` in the namespace `dev`, with extra columns such as the IP address and the node.

**👀 You should see** four frontend pods. One or more of them run on `minikube-m04`.

Go back to 2:

**📋 Copy and paste into your terminal:**

```bash
kubectl scale deployment frontend -n dev --replicas=2
```

**What this does:** Changes the number of pods of the Deployment `frontend` in the namespace `dev` to 2.

**👀 You should see** *(do not paste)*:

```text
deployment.apps/frontend scaled
```

## Step 6: remove the node again

Your server has room for three nodes. Take the fourth away, in the right order: first move its pods away, then delete it.

**📋 Copy and paste into your terminal:**

```bash
kubectl drain minikube-m04 --ignore-daemonsets --delete-emptydir-data
minikube node delete minikube-m04
kubectl get nodes
```

**What this does:**

- `kubectl drain minikube-m04 --ignore-daemonsets ...`: Empties the node `minikube-m04`: marks it as closed and moves its pods to other nodes.
- `minikube node delete minikube-m04`: Removes the node `minikube-m04` from the cluster.
- `kubectl get nodes`: Lists the nodes.

**👀 You should see** three nodes again *(do not paste)*:

```text
NAME           STATUS   ROLES           AGE   VERSION
minikube       Ready    control-plane   3h    v1.36.5
minikube-m02   Ready    worker          3h    v1.36.5
minikube-m03   Ready    worker          3h    v1.36.5
```

(`kubectl drain` is explained in Lab 2.7.)

💡 **Exam tip:** always empty a node (`kubectl drain`) before you remove it. A node that is removed without a drain takes its pods with it.

✅ **Check:** `kubectl get nodes` shows three `Ready` nodes.

**Next:** [Lab 2.3: Standalone pods](./lab-2.3-standalone-pods.md)
