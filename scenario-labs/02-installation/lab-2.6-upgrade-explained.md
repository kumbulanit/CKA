# Lab 2.6 explained: upgrade to a new version

This page goes with [Lab 2.6](./lab-2.6-upgrade.md). The lab has the commands; this page explains them: what happens in the cluster, why it matters for the Shop, what usually goes wrong, and what the exam asks. There is nothing to paste here.

## In short

Kubernetes is upgraded one minor version at a time, control plane first, then the workers one by one. Each worker is drained, upgraded and uncordoned, so the Shop's pods move away and come back while the Shop stays open. Before anything, you back up etcd. In the course the trainer shows the upgrade; you learn the rules and the order.

## The ideas behind this lab

### Version numbers

`v1.36.5` means: major version 1, **minor** version 36, **patch** 5. A new minor version (with new features, and old ones removed) comes about three times a year; patches (fixes only) come every few weeks. Each minor version gets fixes for about a year, so a cluster that is not upgraded falls out of support.

### Why one minor version at a time

Each minor version may change how objects are stored, and removes features that were deprecated before. The upgrade steps (for example how kubeadm migrates its settings) are only tested from one minor version to the next. Skipping one (v1.35 → v1.37) is not supported: you go v1.35 → v1.36 → v1.37.

### Why control plane first

The parts of Kubernetes may differ in version, but only within limits (the **version skew** policy):

| Part | Allowed compared with the API server |
| --- | --- |
| kubelet, kube-proxy | Same, or up to **three** minor versions **older**; never newer |
| controller manager, scheduler | Same, or one minor version older |
| kubectl | One minor version older or newer |

So the API server must always be the newest part: it is upgraded first. Then the other control plane parts, then the kubelets, node by node.

### The order with kubeadm

1. **Back up etcd** (Lab 2.5).
2. **First control plane node:** upgrade the kubeadm package; `kubeadm upgrade plan` shows what is possible; `kubeadm upgrade apply v1.37.x` rewrites the static pod files, so the control plane restarts in the new version; then drain the node, upgrade the kubelet and kubectl packages, restart the kubelet, uncordon.
3. **Other control plane nodes:** the same, with `kubeadm upgrade node` instead of `apply`.
4. **Each worker, one at a time:** upgrade kubeadm, `kubeadm upgrade node`, drain, upgrade the kubelet and kubectl, restart the kubelet, uncordon.
5. **Validate** (Lab 2.1, Step 4).

Upgrading the kubeadm package does not upgrade the cluster; `kubeadm upgrade` does not upgrade the kubelet. Each is its own step, and forgetting the kubelet is a classic mistake.

## Step by step

### Step 1: read the versions of your cluster

`kubectl version` shows two versions: the **client** (your `kubectl`) and the **server** (the API server). `-o custom-columns` reads each node's kubelet and container runtime version from the node's status. During an upgrade this table is the progress report: nodes move to the new version one by one, and a mix is normal for a while.

### Step 2: make a backup first

An upgrade changes the control plane and can change stored objects. If it fails halfway, the etcd snapshot from before is the way back. The lab only checks that the file from Lab 2.5 is still there; in real life you take a fresh one, right before the upgrade.

### Step 3: the upgrade with minikube (trainer demo)

`minikube start --kubernetes-version=v1.37.0` on a running cluster upgrades it: minikube runs the kubeadm steps inside its node containers. You watch the same order as on a kubeadm cluster: the control plane first (its static pods restart in the new version), then the kubelets.

The participants do not run it: all the labs are tested on v1.36.5, and a cluster cannot go back down a version. Downgrades are not supported in Kubernetes; the way back is a new cluster plus the etcd backup.

### Step 4: after an upgrade: validate

The same three checks as after an install: nodes `Ready` on the new version, `kube-system` pods running, `readyz check passed`. Then check the applications: here, that the Shop answers in every environment.

### Why the Shop stays open during an upgrade

Each node is drained before its kubelet is upgraded. Because the frontend and the backend run two copies each, there is always a copy on another node to answer. The database runs one copy, so it has a short pause when its node is drained: one more reason to give real databases several copies. Lab 2.7 is the drain on its own.

## When something goes wrong

| What you see | What it means | What to do |
| --- | --- | --- |
| `kubeadm upgrade plan` does not offer the version | The kubeadm package was not upgraded first, or the version is two minors away | Upgrade kubeadm to the target version; go one minor at a time |
| A node shows the old version after the upgrade | Its kubelet package was not upgraded, or the kubelet was not restarted | Upgrade the package, `systemctl daemon-reload`, `systemctl restart kubelet` |
| A node stays `SchedulingDisabled` | It was not uncordoned | `kubectl uncordon NODE` |
| Pods `Pending` during the upgrade | Too little room on the other nodes while one is drained | Upgrade when there is spare capacity, or add a node first |

## For the exam

- Upgrade tasks are common. The order: back up etcd, control plane first (`kubeadm upgrade plan`, `kubeadm upgrade apply`), then each worker (`kubeadm upgrade node`), and for every node: drain, upgrade kubelet and kubectl, restart the kubelet, uncordon.
- The package steps (`apt-get install kubeadm=...`) are in the documentation page "Upgrading kubeadm clusters": follow it, and change only the version.
- Upgrade one minor version, to the version the task names. Read it twice.
- Do not forget `kubectl uncordon` at the end of each node.

## Check your understanding

1. Can you upgrade from v1.35 to v1.37 in one go?
2. Why is the control plane upgraded before the workers?
3. What does `kubeadm upgrade apply` change, and what does it not change?
4. Why does the Shop stay open while a worker is upgraded?
5. The upgrade went wrong. Can you downgrade the cluster?

<details><summary>Answers</summary>

1. No. One minor version at a time: v1.35 → v1.36 → v1.37.
2. The kubelets may be older than the API server, but never newer.
3. It upgrades the control plane parts (it rewrites their static pod files). It does not upgrade the kubelet or kubectl packages.
4. The node is drained first, and the frontend and backend have a second copy on another node.
5. No, downgrades are not supported. Restore from the etcd backup on a cluster of the old version.

</details>

**Back to:** [Lab 2.6](./lab-2.6-upgrade.md) · **Next:** [Lab 2.7 explained](./lab-2.7-cordon-and-drain-explained.md)
