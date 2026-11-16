# Lab 2.5 explained: back up etcd, lose PROD, get it back

This page goes with [Lab 2.5](./lab-2.5-cluster-maintenance-etcd-backup.md). The lab has the commands; this page explains them: what happens in the cluster, why it matters for the Shop, what usually goes wrong, and what the exam asks. There is nothing to paste here.

## In short

Every Kubernetes object lives in **etcd**. A **snapshot** of etcd is a backup of the whole cluster's objects. In this lab you take one, delete PROD, and restore the snapshot: PROD comes back. A restore takes the **whole cluster** back in time, and it brings back the objects, not the data inside the Shop's database.

## The ideas behind this lab

### What is in etcd, and what is not

| In etcd (restored by a snapshot) | Not in etcd (not restored) |
| --- | --- |
| Namespaces, Deployments, ReplicaSets, pods (as objects) | The files inside containers |
| Services, ConfigMaps, Secrets | The data in the Shop's database |
| Nodes, roles and bindings, everything `kubectl get` can show | Data on PersistentVolumes (Module 7) |

A cluster backup therefore has two halves: an etcd snapshot for the objects, and the application's own backup (for example a database dump, or volume snapshots) for the data. This lab does the first half.

### Snapshot save and restore

- **`etcdctl snapshot save`** asks the running etcd for a consistent copy of all its data, and writes it to one file. The cluster keeps running; nothing stops.
- **`etcdutl snapshot restore`** does **not** talk to etcd. It reads the file and builds a fresh **data folder** from it. Nothing in the cluster changes until etcd is pointed at that folder.

`etcdctl` is the client for a running etcd; `etcdutl` works on files directly. Older guides use `etcdctl snapshot restore`, which still works in some versions, but `etcdutl` is the tool meant for it.

### Why the certificates

etcd only accepts clients that show a certificate signed by etcd's own certificate authority, over TLS. `--cacert` checks etcd's identity; `--cert` and `--key` prove yours. On a kubeadm cluster the files are in `/etc/kubernetes/pki/etcd/`; on minikube in `/var/lib/minikube/certs/etcd/`. The etcd static pod file lists them, so you never have to guess.

### Why restart the cluster after a restore

Every part of Kubernetes keeps a picture of the cluster in memory: the API server's cache, the controllers, the kubelets. After a restore, etcd is back in the past, but those pictures are from the present. Restarting makes every part start again from the restored data, so they all agree. On a kubeadm cluster you would restart the control plane static pods and the kubelets; on minikube, `minikube stop` and `minikube start` do it all.

## Step by step

### Step 1: make the snapshot

`kubectl exec etcd-minikube -- etcdctl ...` runs `etcdctl` inside the etcd pod, where the tool and the certificates already are. `--endpoints=https://127.0.0.1:2379` is etcd's client address on the node itself. The snapshot file is written into etcd's data area on the control plane node, which is mounted into the pod, so the file survives the pod.

### Step 2: check the snapshot

`etcdutl snapshot status` reads the file and prints its hash, revision (etcd counts every change), number of keys and size. A snapshot that cannot be read here cannot be restored either: always check before you rely on it. In real life, the next step is copying the file off the cluster.

### Step 3: note what PROD looks like now

The list is your proof later: the same objects must come back.

### Step 4: delete PROD

Deleting a namespace deletes everything in it: the namespace controller removes all its objects, and the pods stop. This is the "wrong command" every team fears, and the reason for backups.

### Step 5: build a new data folder from the snapshot

`etcdutl snapshot restore ... --data-dir .../restore` writes a new data folder, `restore/member`, next to the live one. The live cluster is untouched: a restore can be prepared calmly, and checked, before anything changes.

### Step 6: put the restored data in the place of the live data

etcd reads its data from `member` in its data folder (set by `--data-dir` in its static pod file). Renaming the live folder to `member-old` and moving the restored one in its place makes etcd use the backup at its next start. Keeping `member-old` means you can go back if the restore was a mistake.

On a kubeadm cluster there is a second common way: restore into a new folder, and change the `hostPath` of the etcd data volume in `/etc/kubernetes/manifests/etcd.yaml` to point at it. The kubelet then restarts etcd with the new folder.

### Step 7: restart the cluster

`minikube stop` and `minikube start` restart every node: etcd starts on the restored data, and the API server, the controllers and the kubelets start from it too. The cluster needs about a minute before every node is `Ready`.

### Step 8: PROD is back

The namespace and every object in it are back, as they were at the snapshot. The pods are recreated by their Deployments, so they are new pods. The database pod starts empty and loads its first three items again: etcd brought back the **objects**, not the data inside the database.

### Clean up

`member-old` and `restore` take space on the control plane node, and are no longer needed once the restore is checked.

## When something goes wrong

| What you see | What it means | What to do |
| --- | --- | --- |
| `context deadline exceeded` from `etcdctl` | Wrong endpoint, or wrong certificates | Check the four options against the etcd static pod file |
| `snapshot restore` says the data dir exists | The `restore` folder is left from an earlier try | Remove it, or restore into a new folder name |
| After the restart, `kubectl` is refused for a while | The control plane is starting | Wait a minute |
| PROD is back but its pods are `Pending` or not ready | Pods are being recreated | `kubectl rollout status` on each Deployment |
| Objects created **after** the snapshot are gone | That is what a restore does, in every namespace | Take a fresh snapshot before risky work |

## For the exam

- Know the save command with its four options by heart: `--endpoints`, `--cacert`, `--cert`, `--key`. Find the certificate paths in `/etc/kubernetes/manifests/etcd.yaml`.
- Restore with `etcdutl snapshot restore <file> --data-dir <new folder>`, then point etcd at the new folder (the `hostPath` in the etcd static pod file) and wait for it to restart.
- `etcdctl` may need `ETCDCTL_API=3` on old versions; current versions use API 3 by default.
- Always check a snapshot with `etcdutl snapshot status`.

## Check your understanding

1. Does an etcd snapshot back up the items in the Shop's database?
2. What is the difference between `etcdctl` and `etcdutl`?
3. After `snapshot restore`, has anything in the cluster changed yet?
4. Why does the cluster need a restart after the restore?
5. You took the snapshot at 10:00 and created a Deployment in `dev` at 10:30. You restore at 11:00. What happens to that Deployment?

<details><summary>Answers</summary>

1. No. It backs up Kubernetes objects; application data needs its own backup.
2. `etcdctl` talks to a running etcd (for example to save a snapshot); `etcdutl` works on files directly (for example to restore one).
3. No. There is only a new data folder; etcd still uses the old one.
4. Every part keeps a picture of the cluster in memory from before the restore; a restart makes them all start from the restored data.
5. It is gone: a restore takes the whole cluster back to 10:00, in every namespace.

</details>

**Back to:** [Lab 2.5](./lab-2.5-cluster-maintenance-etcd-backup.md) · **Next:** [Lab 2.6 explained](./lab-2.6-upgrade-explained.md)
