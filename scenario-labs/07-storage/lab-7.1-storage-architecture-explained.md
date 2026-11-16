# Lab 7.1 explained: storage architecture

This page goes with [Lab 7.1](./lab-7.1-storage-architecture.md). The lab has the commands; this page explains them: what happens in the cluster, why it matters for the Shop, what usually goes wrong, and what the exam asks. There is nothing to paste here.

## In short

Files inside a container, or in an `emptyDir`, disappear when the pod is replaced. That is why the Shop has lost its Juice three times. Kubernetes keeps data with three objects: a **PersistentVolume** (a real piece of storage), a **PersistentVolumeClaim** (an application's request for storage) and a **StorageClass** (the kind of storage, and who makes it). A pod names a claim; the claim is bound to a volume; a new pod with the same claim gets the same data.

## The ideas behind this lab

### Why containers forget

A container's files live in a writable layer on top of its image. When the container is replaced, the new one starts from the clean image. Pods are replaced all the time, on purpose: rolling updates, drains, evictions, rescheduling after a node failure. Anything an application must keep has to live **outside** the pod.

### Where a pod can keep files

| Place | Survives a container restart | Survives a new pod | Typical use |
| --- | --- | --- | --- |
| The container's own files | No | No | Nothing worth keeping |
| `emptyDir` volume | Yes | No | Scratch space, caches, files shared by containers of one pod |
| `hostPath` volume (directly in the pod) | Yes | Only if the new pod lands on the same node | Node tools, labs; risky for applications |
| ConfigMap or Secret volume | Yes | Yes (read-only data from the API) | Settings (Lab 1.5) |
| **PersistentVolumeClaim** | Yes | Yes | Databases, uploads: data you must keep |

### The three storage objects

| Object | Scope | Made by | Says |
| --- | --- | --- | --- |
| **PersistentVolume (PV)** | Cluster (no namespace) | The administrator, or a provisioner | "Here is 1Gi of storage, of this kind, reachable like this" |
| **PersistentVolumeClaim (PVC)** | One namespace | The application team | "I need 1Gi, read-write, of this class" |
| **StorageClass** | Cluster | The administrator | "This kind of storage, made by this provisioner, with these rules" |

The split is deliberate: application teams ask for storage without knowing where it comes from, and administrators provide it without knowing every application. The pod only ever names its claim.

### Binding

The PV controller (in the controller manager) looks for a PV that fits each claim: same storage class, at least the requested size, the requested access mode. When it finds one, it **binds** them, one to one: the claim says `Bound` to that volume, and the volume says `Bound` to that claim. No other claim can use that volume, even if it is bigger than needed.

### The life of a volume

| Phase | Meaning |
| --- | --- |
| `Available` | Free, waiting for a claim |
| `Bound` | Joined to a claim |
| `Released` | The claim was deleted; the data is still there (with `Retain`) |
| `Failed` | Automatic cleaning failed |

What happens when the claim is deleted is the **reclaim policy**: `Retain` keeps the volume and its data for an administrator to deal with; `Delete` removes the volume (and, for dynamic volumes, the real storage).

## Step by step

### Step 1: see the volume the database uses now

`jsonpath='{.spec.template.spec.volumes[0]}'` prints the database's first volume: `{"emptyDir":{},"name":"data"}`. That one line is the cause of every lost Juice so far.

### Step 2: add an item

The Juice is written into the database's files, in the `emptyDir` of the current database pod.

### Step 3: delete the database pod

The Deployment replaces the pod at once. The new pod gets a new, empty `emptyDir`; PostgreSQL finds an empty data folder, runs `init.sql` again (Lab 1.6), and starts with the first three items. The Juice is gone. The backend may need a few seconds to reconnect to the new database, which is why the lab waits.

### The solution: three objects

The chain is: pod → claim → volume → real storage. The pod's Deployment changes only once (from `emptyDir` to the claim's name), and from then on every new database pod finds the same data.

### Step 4: see what storage the cluster has now

minikube comes with one storage class, `standard`, marked `(default)`. It has a provisioner (`k8s.io/minikube-hostpath`) that makes volumes on request (Lab 7.3), deletes them with their claim (`Delete`), and binds at once (`Immediate`). There are no volumes and no claims yet: the Shop has used none so far.

## When something goes wrong

| What you see | What it means | What to do |
| --- | --- | --- |
| The Juice is gone after a pod restart | The data was in the container or an `emptyDir` | Use a PersistentVolumeClaim (Lab 7.2) |
| The Shop gives an error right after the database pod is replaced | The backend is reconnecting to the new database | Wait 15 to 30 seconds and try again |
| `kubectl get pvc` says `No resources found` but there are claims | Claims are per namespace | Add `-n` or `-A` |

## For the exam

- PVs have no namespace; PVCs do. `kubectl get pv` and `kubectl get pvc -A`.
- Know the chain pod → PVC → PV, and that the pod refers to the claim with `persistentVolumeClaim: claimName:` in its `volumes`, and mounts it with `volumeMounts`.
- Know the PV phases (`Available`, `Bound`, `Released`) and the reclaim policies (`Retain`, `Delete`).
- An `emptyDir` is the right answer when two containers in one pod must share files.

## Check your understanding

1. Why did the Juice disappear when the database pod was deleted?
2. Which of the three storage objects belongs to a namespace?
3. What does a pod name to get persistent storage?
4. A claim asks for 1Gi; a free 5Gi volume of the same class exists. Can they bind, and how much does the claim get?
5. A claim is deleted; its volume has `Retain`. What state is the volume in, and is the data still there?

<details><summary>Answers</summary>

1. The data was in an `emptyDir`, which belongs to the pod; the new pod got a new, empty one.
2. The PersistentVolumeClaim.
3. A PersistentVolumeClaim, by its name.
4. Yes; binding is one to one, so the claim gets the whole 5Gi volume.
5. `Released`, and yes, the data is still there until an administrator removes it.

</details>

**Back to:** [Lab 7.1](./lab-7.1-storage-architecture.md) · **Next:** [Lab 7.2 explained](./lab-7.2-storage-backends-explained.md)
