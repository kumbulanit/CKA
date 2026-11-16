# Lab 2.6: Upgrade to a new version

**The situation:** a new Kubernetes version is out, with security fixes. The Shop must stay open while the cluster under it is upgraded.

**Goal:** know the rules and the order of an upgrade, read the versions of your own cluster, and see how minikube upgrades a cluster.

**Outline topic:** 2. Installation, Configuration & Validation: *Upgrade to a new version*.

**What you learn:** version rules, the upgrade order, upgrading with minikube.

📘 **More detail:** [Lab 2.6 explained](./lab-2.6-upgrade-explained.md): what happens in the cluster at each step, common mistakes and exam notes.

Kubernetes brings a new minor version about three times a year (v1.35, v1.36, v1.37). A cluster is upgraded **one minor version at a time**, and **one node at a time**, so that the applications keep running.

> **How to use this lab**
>
> - **📋 Copy and paste into your terminal:** copy the whole grey box (the copy button is in its top right corner), paste it into the terminal of your server, and press Enter.
> - **👀 You should see** *(do not paste)*: what the command prints. Names that end in random letters, IP addresses and ages are different on your server. That is normal.
> - **📖 Read only:** something to look at. Do not paste it.
> - **💡 Tip:** a shortcut or an extra. You do not need it to finish the lab.

## The rules

| Rule | Example |
| --- | --- |
| Go up one minor version at a time | v1.36 → v1.37. Not v1.35 → v1.37. |
| Back up etcd first | Lab 2.5 |
| Control plane first, then the workers | The kubelet may be older than the API server, never newer |
| One node at a time: drain, upgrade, uncordon | The Shop's pods move to the other nodes meanwhile (Lab 2.7) |

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

## Step 1: read the versions of your cluster

**📋 Copy and paste into your terminal:**

```bash
kubectl version
```

**What this does:** Shows the version of kubectl (client) and of the cluster (server).

**👀 You should see** the version of `kubectl` (client) and of the API server (server) *(do not paste)*:

```text
Client Version: v1.36.5
Kustomize Version: v5.7.1
Server Version: v1.36.5
```

**📋 Copy and paste into your terminal:**

```bash
kubectl get nodes -o custom-columns=NODE:.metadata.name,KUBELET:.status.nodeInfo.kubeletVersion,RUNTIME:.status.nodeInfo.containerRuntimeVersion
```

**What this does:** Lists the nodes, showing only the columns named in the command.

**👀 You should see** the kubelet version of every node *(do not paste)*:

```text
NODE           KUBELET   RUNTIME
minikube       v1.36.5   containerd://2.3.4
minikube-m02   v1.36.5   containerd://2.3.4
minikube-m03   v1.36.5   containerd://2.3.4
```

During an upgrade this table shows a mix: some nodes on the old version, some on the new. That is allowed, as long as the workers are not newer than the control plane.

## Step 2: make a backup first

You did this in Lab 2.5. Before an upgrade you always do it again. Check that your backup file is still there:

**📋 Copy and paste into your terminal:**

```bash
minikube ssh -- sudo ls -la /var/lib/minikube/etcd/shop-backup.db
```

**What this does:** Checks that the backup from Lab 2.5 is still on the control plane node. Never upgrade without a backup.

**👀 You should see** the file with its size and date.

## Step 3: the upgrade with minikube (trainer demo)

With minikube, an upgrade is the start command with a newer version:

**📖 Read only (do not paste):**

```text
minikube start --kubernetes-version=v1.37.0
```

minikube then does, for you, what an administrator does by hand:

| # | What happens | Why |
| --- | --- | --- |
| 1 | The control plane node gets the new version first | Rule: control plane first |
| 2 | The API server, scheduler, controller manager and etcd are restarted in the new version | They are static pods: their files are rewritten |
| 3 | The kubelet of each node is replaced and restarted | One node after the other |
| 4 | The nodes report `Ready` with the new version | Check with `kubectl get nodes` |

⚠️ **Do not run the upgrade on your own server during the course.** All the labs are tested on v1.36.5. The trainer shows the upgrade on the screen, and you watch the `VERSION` column of `kubectl get nodes` change.

## Step 4: after an upgrade: validate

The same three checks as after an installation (Lab 2.1, Step 4):

**📋 Copy and paste into your terminal:**

```bash
kubectl get nodes
kubectl get pods -n kube-system
kubectl get --raw='/readyz?verbose' | tail -1
```

**What this does:**

- `kubectl get nodes`: Lists the nodes.
- `kubectl get pods -n kube-system`: Lists the pods in the namespace `kube-system`.
- `kubectl get --raw='/readyz?verbose' | tail -1`: Asks the API server itself if it is healthy, check by check. `| tail` shows only the last line.

**👀 You should see** all nodes `Ready`, all system pods `Running`, and *(do not paste)*:

```text
readyz check passed
```

## Why the Shop stays open during an upgrade

Because of what you built in Module 1: two copies of the frontend and the backend. When one node is taken out, the other copy answers. You try exactly that in the next lab.

💡 **Exam tip:** the order is always the same: back up etcd, control plane first, then each worker: drain, upgrade, uncordon. Do not forget the last step: `kubectl uncordon`.

✅ **Check:** you can say the order of an upgrade without looking.

**Next:** [Lab 2.7: Cordoning and draining nodes](./lab-2.7-cordon-and-drain.md)
