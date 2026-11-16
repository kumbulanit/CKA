# Lab 7.2 explained: storage backends, a real disk for the database

This page goes with [Lab 7.2](./lab-7.2-storage-backends.md). The lab has the commands; this page explains them: what happens in the cluster, why it matters for the Shop, what usually goes wrong, and what the exam asks. There is nothing to paste here.

## In short

A **storage backend** is where the bytes really are: a folder on a node, an NFS server, a storage cluster, a cloud disk. The PersistentVolume describes the backend; the claim and the application do not care which one it is. In this lab the DEV database gets a disk on one node, the Juice survives a deleted pod, and you compare the local disk with an NFS one.

## The ideas behind this lab

### Kinds of backends

| Backend | Where the data is | Shared by many nodes? | Survives a node failure? |
| --- | --- | --- | --- |
| `hostPath`, `local` | A folder or disk on one node | No | No |
| NFS | A file server on the network | Yes (`ReadWriteMany`) | Yes, if the server survives |
| GlusterFS, CephFS | A cluster of storage servers | Yes | Yes |
| Block storage (cloud disks, Ceph RBD, iSCSI) | A disk attached to one node at a time | No (`ReadWriteOnce`) | Yes: it is re-attached to another node |

Today most backends are connected through **CSI** (Container Storage Interface) drivers, installed like any application. The old built-in types for GlusterFS and others were removed from Kubernetes; `nfs`, `hostPath` and `local` remain built in.

### Access modes

| Mode | Short | Meaning |
| --- | --- | --- |
| `ReadWriteOnce` | RWO | Read and write by **one node** (several pods on that node may share it) |
| `ReadOnlyMany` | ROX | Read only, by many nodes |
| `ReadWriteMany` | RWX | Read and write by many nodes (file storage such as NFS) |
| `ReadWriteOncePod` | RWOP | Read and write by **one pod** in the whole cluster |

The mode is a promise the backend must be able to keep: a folder on one node can never be `ReadWriteMany`.

### Why the local disk needs node affinity

A `hostPath` folder exists on one node only. The PV's `nodeAffinity` (the same rule as Lab 4.2, on the volume) tells the scheduler: any pod using this volume must run on `minikube-m02`. Without it, a database pod scheduled on another node would get an empty folder there, and start a second, separate database.

### When the claim binds: WaitForFirstConsumer

The class `shop-disk` uses `volumeBindingMode: WaitForFirstConsumer`: a claim is not bound until a pod that uses it is scheduled. Then the scheduler places the pod on a node where a suitable volume can be reached, and binds the claim to that volume. For local disks this matters: binding first could join the claim to a volume on a node the pod cannot run on. Lab 7.3 explains the class itself.

## Step by step

### Step 1: look at the disk (PersistentVolume)

`shop-dev-pv` describes: 1Gi, `ReadWriteOnce`, `Retain`, class `shop-disk`, backend `hostPath` at `/data/shop/dev` (created if missing, `DirectoryOrCreate`), on node `minikube-m02` only. The folder is inside the `minikube-m02` node container, not on your server directly.

### Step 2: create the storage class and the disk

The volume is `Available`: it exists, nobody claims it. A PV is a cluster object, so no `-n`.

### Step 3: ask for the disk (PersistentVolumeClaim)

The claim `db-data` asks for 1Gi, RWO, class `shop-disk`, in `dev`. It stays `Pending`: not an error, but `WaitForFirstConsumer` at work.

### Step 4: give the disk to the database

The new Deployment differs from Lab 1.6 in one place: the volume `data` is now `persistentVolumeClaim: claimName: db-data` instead of `emptyDir`. The mount path inside the container does not change, so PostgreSQL notices nothing. The Deployment's `Recreate` strategy (Lab 1.6) stops the old pod first, so two database pods never share the disk.

### Step 5: see the claim and the disk joined

The new pod made the claim bind: `db-data` is `Bound` to `shop-dev-pv`, and the volume shows `dev/db-data` as its claim. The database pod runs on `minikube-m02`, because the volume's node affinity left the scheduler no other choice.

### Step 6: the test: add the Juice, delete the pod

The backend is restarted first, so that it connects cleanly to the new database (the database started on an empty disk and loaded its first items). Then the Juice goes in, the pod is deleted, and the new pod, on the same node, mounts the same folder: the Juice is still there. Data and pod are finally separate.

### Step 7: see the data on the node

The PostgreSQL files (`PG_VERSION`, `base`, `pg_wal`...) are in `/data/shop/dev/pgdata` on `minikube-m02`: the folder the PV names, plus the `pgdata` sub-folder set by `PGDATA` in Lab 1.6.

### Step 8: read an NFS volume

The NFS example differs in exactly one block: `nfs: server, path` instead of `hostPath`, plus no node affinity (every node can reach the server) and `ReadWriteMany`. The claim and the Deployment would not change at all. That is the design: applications ask for storage; administrators decide where it comes from.

### GlusterFS

GlusterFS joins the disks of several servers into one shared volume. Its built-in Kubernetes volume type was removed in v1.26; storage clusters like it are now used through CSI drivers. The PV and PVC pattern is the same.

## When something goes wrong

| What you see | What it means | What to do |
| --- | --- | --- |
| The claim stays `Pending` with no pod using it | `WaitForFirstConsumer`: normal | Start the pod that uses it |
| The claim stays `Pending` with a pod | No volume fits: size, access mode or class name | `kubectl describe pvc`: the events say why; compare it with the PV |
| The database pod is `Pending` | The volume's node is full, cordoned or tainted | `kubectl describe pod`: the events name the node affinity |
| The data is gone after the pod moved | A `hostPath` volume used directly in a pod, without node affinity | Use a PV with `nodeAffinity`, as the lab does |
| `kubectl delete pvc` hangs | The claim is still used by a pod (`kubernetes.io/pvc-protection`) | Delete or change the pod first |

## For the exam

- The classic task: a PV with `hostPath`, a PVC that binds to it, and a pod that mounts the claim. Copy the YAML from the documentation page "Configure a Pod to Use a PersistentVolume for Storage".
- For a claim to bind: the same `storageClassName` (or both empty), enough capacity, and a matching access mode.
- `kubectl describe pvc NAME` gives the reason a claim is `Pending`.
- Know the access modes and their short names; `ReadWriteOnce` is per node, not per pod.

## Check your understanding

1. What changes in the PV when the backend changes from a local folder to NFS? And in the claim?
2. Why does the local PV have `nodeAffinity`?
3. Why was the claim `Pending` in Step 3?
4. Can two database pods on different nodes share this RWO volume?
5. The Juice survived the deleted pod in Step 6. Would it survive the loss of `minikube-m02`?

<details><summary>Answers</summary>

1. Only the backend block (`hostPath` → `nfs`), plus no node affinity and possibly `ReadWriteMany`. The claim does not change.
2. The folder exists on one node only, so any pod using the volume must run there.
3. The class uses `WaitForFirstConsumer`: the claim binds only when a pod that uses it is scheduled.
4. No. `ReadWriteOnce` allows one node at a time, and the folder only exists on one node anyway.
5. No. The data is on that node's disk; a network backend would survive.

</details>

**Back to:** [Lab 7.2](./lab-7.2-storage-backends.md) · **Next:** [Lab 7.3 explained](./lab-7.3-storage-classes-and-dynamic-provisioning-explained.md)
