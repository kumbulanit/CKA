# Lab 2.7 explained: cordoning and draining nodes

This page goes with [Lab 2.7](./lab-2.7-cordon-and-drain.md). The lab has the commands; this page explains them: what happens in the cluster, why it matters for the Shop, what usually goes wrong, and what the exam asks. There is nothing to paste here.

## In short

Before you work on a node, you empty it. **Cordon** stops new pods from going there. **Drain** cordons and then evicts the pods, so their controllers recreate them on other nodes. **Uncordon** opens the node again. With two copies of each Shop part, the Shop stays open the whole time.

## The ideas behind this lab

### Three commands, three states

| Command | New pods? | Pods already there | Node status |
| --- | --- | --- | --- |
| (normal) | Yes | Stay | `Ready` |
| `kubectl cordon` | No | Stay | `Ready,SchedulingDisabled` |
| `kubectl drain` | No | Evicted, recreated elsewhere | `Ready,SchedulingDisabled` |
| `kubectl uncordon` | Yes again | (whatever is there) | `Ready` |

`cordon` sets `spec.unschedulable: true` on the node, which shows as the taint `node.kubernetes.io/unschedulable:NoSchedule`. The scheduler skips the node; nothing else changes.

### Eviction, not deletion

`drain` does not simply delete pods. It **evicts** them, which is a polite request that respects **PodDisruptionBudgets** (PDBs): a PDB says "at least N pods of this app must stay available". If an eviction would break a PDB, `drain` waits and tries again. Each evicted pod gets its normal grace period to shut down, and its controller (a ReplicaSet) creates a replacement, which the scheduler places on another node, because this one is cordoned.

### What `drain` refuses to do without being told

| Pods | Why drain stops | The option that says "go on" |
| --- | --- | --- |
| DaemonSet pods | They belong on every node; evicting them is pointless, they would come back | `--ignore-daemonsets` (they stay) |
| Pods with an `emptyDir` | Their temporary data is lost when they move | `--delete-emptydir-data` |
| Standalone pods (no controller) | Nothing would recreate them | `--force` (they are deleted for good) |

These are safety checks: each option is you saying "I know what will be lost".

### Pods do not move back

After `uncordon`, the node is empty and stays empty until something new is scheduled. Kubernetes does not rebalance running pods. A `kubectl rollout restart` makes new pods, and the scheduler spreads them over all nodes again, the empty one included.

## Step by step

### Step 1: see which pods are on the node

`--field-selector spec.nodeName=minikube-m03` with `-A` lists every pod on that node, in all namespaces. You see Shop pods from all three environments, and the two DaemonSet pods (`calico-node`, `kube-proxy`) that every node has.

### Step 2: cordon the node

The node turns `Ready,SchedulingDisabled`. Its pods keep running; only new pods avoid it. Cordon on its own is useful when you want a node to "run empty" slowly, as pods are replaced over time.

### Step 3: drain the node

`drain` evicts every Shop pod on the node, one per line, and ends with `node/minikube-m03 drained`. The DaemonSet pods stay (`--ignore-daemonsets`), and the pods with `emptyDir` are allowed to go (`--delete-emptydir-data`).

The database pods use an `emptyDir` (Lab 1.6). A database pod evicted from this node starts again elsewhere with an empty folder, and only its first three items. That is the second time the Shop loses data this way; Module 7 fixes it.

### Step 4: where are the pods now, and is the Shop open?

The replacement pods run on `minikube-m02` and on `minikube`, the control plane node. On the course cluster the control plane takes normal pods too: minikube does not put the usual control plane taint on it (a kubeadm cluster does, so there workloads stay off the control plane). The Shop answers, because one copy of the frontend and of the backend was always running somewhere else. If the DEV database was on the drained node, the Shop gives an error for a few seconds while the new database pod starts.

### Step 5: the maintenance is done: bring the node back

`uncordon` removes the unschedulable mark. The node is `Ready` again, but empty apart from its DaemonSet pods.

### Step 6: spread the pods again

`rollout restart` for the frontend and the backend in every environment makes new pods, and the scheduler, which prefers to spread a Deployment's pods over nodes, places some on the empty node. The databases are left alone on purpose: restarting them would lose their data again.

## When something goes wrong

| What you see | What it means | What to do |
| --- | --- | --- |
| `cannot delete DaemonSet-managed Pods` | DaemonSet pods are on the node | Add `--ignore-daemonsets` |
| `cannot delete Pods with local storage` | Pods use `emptyDir` | Add `--delete-emptydir-data` if losing that data is fine |
| `cannot delete Pods not managed by ReplicationController, ReplicaSet, Job, DaemonSet or StatefulSet` | Standalone pods | Check them; `--force` deletes them for good |
| `drain` waits with `Cannot evict pod as it would violate the pod's disruption budget` | A PDB protects the app | Wait, or scale the app up so one pod can go |
| New pods are `Pending` after the drain | No room on the other nodes | Uncordon, or add capacity, before draining |
| The node is still `SchedulingDisabled` the next day | Uncordon was forgotten | `kubectl uncordon NODE` |

## For the exam

- `kubectl drain NODE --ignore-daemonsets` is the form you need almost every time; add `--delete-emptydir-data` and `--force` only when the error asks for it, and read what each one costs.
- Every upgrade of a node starts with a drain and ends with an uncordon.
- `SchedulingDisabled` in `kubectl get nodes` means cordoned.
- A task "make node X unschedulable, but leave its pods running" means `cordon`, not `drain`.

## Check your understanding

1. What is the difference between `cordon` and `drain`?
2. Why does `drain` evict pods instead of deleting them?
3. Why do DaemonSet pods stay on a drained node?
4. After `uncordon`, why is the node still empty?
5. Why did the Shop stay open during the drain, and when could it not?

<details><summary>Answers</summary>

1. `cordon` only stops new pods; `drain` cordons and moves the existing pods away.
2. Eviction respects PodDisruptionBudgets and gives each pod its normal shutdown time.
3. They belong on every node (network, proxy); evicted, they would come straight back.
4. Pods do not move back by themselves; only newly scheduled pods land there.
5. The frontend and the backend have two copies on different nodes. The single database pod could not: its part paused while it restarted elsewhere, and lost its data.

</details>

**Back to:** [Lab 2.7](./lab-2.7-cordon-and-drain.md) · **Next:** [Lab 3.1 explained](../03-networking/lab-3.1-network-model-explained.md)
