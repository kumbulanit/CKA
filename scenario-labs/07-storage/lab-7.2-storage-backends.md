# Lab 7.2: Storage backends: a real disk for the database

**The situation:** the database needs a disk that stays when the pod goes.

**Goal:** make a disk on a node (a **local** backend), give it to the DEV database, and prove that the data survives. Then read what the same disk looks like on a network backend (NFS, GlusterFS).

**Outline topic:** Storage: *Storage backend in Kubernetes: local, NFS, GlusterFS*.

**What you learn:** PersistentVolume, PersistentVolumeClaim, access modes, reclaim policy, local and network storage backends.

📘 **More detail:** [Lab 7.2 explained](./lab-7.2-storage-backends-explained.md): what happens in the cluster at each step, common mistakes and exam notes.

A **storage backend** is where the bytes really are. The PersistentVolume hides it: the application only sees a claim.

| Backend | Where the data is | Can pods on different nodes share it? |
| --- | --- | --- |
| **Local** (`hostPath`, `local`) | A folder or disk on **one node** | No. The pod must run on that node. |
| **NFS** | A file server on the network | Yes |
| **GlusterFS**, Ceph | A storage cluster of several servers | Yes |
| Cloud disks | A disk of the cloud provider | Depends on the type |

Your cluster has no file server, so you use the local backend. The steps are the same for every backend. Only one part of the PersistentVolume is different.

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
cd ~/CKA/scenario-labs/07-storage
kubectl config set-context --current --namespace=dev
```

**What this does:**

- `cd ~/CKA/scenario-labs/07-storage`: Goes to the folder `~/CKA/scenario-labs/07-storage`.
- `kubectl config set-context --current --namespace=dev`: Makes `dev` your working namespace: commands without `-n` now work in `dev`.

**👀 You should see** *(do not paste)*:

```text
Context "minikube" modified.
```

💡 **Tip:** `kubens dev` does the same as the second line (see the shortcuts in [setup, Step 5](../00-setup.md)).

## Part A: a local disk for the DEV database

### Step 1: look at the disk (PersistentVolume)

**⌨️ Command line option:** none. kubectl has no command that creates a PersistentVolume, so the YAML is the only way. In the exam, copy an example from the Kubernetes documentation and change it.

**📋 Copy and paste into your terminal:**

```bash
cat db-pv-dev.yaml
```

**What this does:** Shows what is in the file `db-pv-dev.yaml`.

**👀 You should see** *(do not paste)*:

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: shop-dev-pv
spec:
  capacity:
    storage: 1Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain      # keep the data when the claim is deleted
  storageClassName: shop-disk
  hostPath:
    path: /data/shop/dev                     # a folder on the node
    type: DirectoryOrCreate
  nodeAffinity:                              # the folder is on this node only
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - minikube-m02
```

| Line | Meaning |
| --- | --- |
| `capacity: 1Gi` | The size of the disk |
| `accessModes: ReadWriteOnce` | One node at a time may read and write it |
| `persistentVolumeReclaimPolicy: Retain` | Keep the data, even when the claim is deleted |
| `hostPath` | **The backend**: the folder `/data/shop/dev` on a node |
| `nodeAffinity` | That folder is on `minikube-m02`, so the database pod must run there (you know this rule from Lab 4.2) |

The access modes:

| Mode | Short | Meaning |
| --- | --- | --- |
| `ReadWriteOnce` | RWO | Read and write, by one node |
| `ReadOnlyMany` | ROX | Read only, by many nodes |
| `ReadWriteMany` | RWX | Read and write, by many nodes (needs a network backend) |

### Step 2: create the storage class and the disk

**📋 Copy and paste into your terminal:**

```bash
kubectl apply -f db-storageclass.yaml -f db-pv-dev.yaml
kubectl get pv
```

**What this does:**

- `kubectl apply -f db-storageclass.yaml -f db-pv-dev.yaml`: Creates (or updates) what is described in `db-storageclass.yaml` and `db-pv-dev.yaml`.
- `kubectl get pv`: Lists the PersistentVolumes (disks).

**👀 You should see** *(do not paste)*:

```text
storageclass.storage.k8s.io/shop-disk created
persistentvolume/shop-dev-pv created
NAME          CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM   STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE
shop-dev-pv   1Gi        RWO            Retain           Available           shop-disk      <unset>                          0s
```

The disk is `Available`: nobody uses it yet. (The storage class `shop-disk` is explained in Lab 7.3.)

### Step 3: ask for the disk (PersistentVolumeClaim)

**⌨️ Command line option:** none. kubectl has no command that creates a PersistentVolumeClaim, so the YAML is the only way. In the exam, copy an example from the Kubernetes documentation and change it.

**📋 Copy and paste into your terminal:**

```bash
cat db-pvc.yaml
```

**What this does:** Shows what is in the file `db-pvc.yaml`.

**👀 You should see** *(do not paste)*:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: db-data
spec:
  storageClassName: shop-disk
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
```

The claim says what it needs: 1Gi, `ReadWriteOnce`, of the class `shop-disk`. It does not say where.

**📋 Copy and paste into your terminal:**

```bash
kubectl apply -f db-pvc.yaml
kubectl get pvc
```

**What this does:**

- `kubectl apply -f db-pvc.yaml`: Creates (or updates) what is described in `db-pvc.yaml`.
- `kubectl get pvc`: Lists the PersistentVolumeClaims (requests for a disk).

**👀 You should see** *(do not paste)*:

```text
persistentvolumeclaim/db-data created
NAME      STATUS    VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
db-data   Pending                                      shop-disk      <unset>                 0s
```

`Pending` is correct here: this storage class waits until a pod wants the disk.

### Step 4: give the disk to the database

This file is the database Deployment from Lab 1.6, with one change at the end: the `emptyDir` is replaced by the claim.

**⌨️ Command line option:** none for these lines. kubectl has no command that adds a volume to a Deployment. The command-line way is to open the Deployment in the editor and type the lines yourself:

```bash
kubectl edit deployment db
```

**📖 Read only (do not paste):**

```yaml
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: db-data
```

**📋 Copy and paste into your terminal:**

```bash
kubectl apply -f db-deployment-with-disk.yaml
kubectl rollout status deployment/db
```

**What this does:**

- `kubectl apply -f db-deployment-with-disk.yaml`: Creates (or updates) what is described in `db-deployment-with-disk.yaml`.
- `kubectl rollout status deployment/db`: Waits until the new pods of the Deployment `db` are all ready, and says when it is done.

**👀 You should see** *(do not paste)*:

```text
deployment.apps/db configured
deployment "db" successfully rolled out
```

### Step 5: see the claim and the disk joined

**📋 Copy and paste into your terminal:**

```bash
kubectl get pvc,pv
```

**What this does:** Lists the PersistentVolumeClaims and the PersistentVolumes.

**👀 You should see** *(do not paste)*:

```text
NAME                            STATUS   VOLUME        CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/db-data   Bound    shop-dev-pv   1Gi        RWO            shop-disk      <unset>                 24s

NAME                           CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM         STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE
persistentvolume/shop-dev-pv   1Gi        RWO            Retain           Bound    dev/db-data   shop-disk      <unset>                          26s
```

![The claim and the disk are Bound](../images/pvc-bound.png)

Both say `Bound`. And the database pod runs on `minikube-m02`, where the disk is:

**📋 Copy and paste into your terminal:**

```bash
kubectl get pods -l app=db -o wide
```

**What this does:** Lists the pods with the label `app=db`, with extra columns such as the IP address and the node.

**👀 You should see** one pod, `Running`, with `minikube-m02` in the `NODE` column.

### Step 6: the test: add the Juice, delete the pod

**📋 Copy and paste into your terminal:**

```bash
kubectl rollout restart deployment/backend
kubectl rollout status deployment/backend
sleep 10
curl -s -X POST http://$(minikube ip):30080/api/items \
  -H 'Content-Type: application/json' \
  -d '{"name":"Juice","price":20}' -w '%{http_code}\n'
```

**What this does:**

- `kubectl rollout restart deployment/backend`: Replaces the pods of the Deployment `backend` with new ones, one by one.
- `kubectl rollout status deployment/backend`: Waits until the new pods of the Deployment `backend` are all ready, and says when it is done.
- `sleep 10`: Waits 10 seconds, to give Kubernetes time.
- `curl -s -X POST ...`: Adds a new item, Juice, to the Shop, as a customer filling in a form would (a POST request). `-w` prints only the answer code: `201` means it was created.

**👀 You should see** (the last line) *(do not paste)*:

```text
201
```

Now delete the database pod, as in Lab 7.1:

**📋 Copy and paste into your terminal:**

```bash
kubectl delete pod -l app=db
kubectl rollout status deployment/db
sleep 40
curl -s http://$(minikube ip):30080/api/items; echo
```

**What this does:**

- `kubectl delete pod -l app=db`: Deletes the pod with the label `app=db`.
- `kubectl rollout status deployment/db`: Waits until the new pods of the Deployment `db` are all ready, and says when it is done.
- `sleep 40`: Waits 40 seconds, to give the backend time to connect to the new database pod.
- `curl -s http://$(minikube ip):30080/api/items; echo`: Asks the Shop for its items, as a web browser would.

**👀 You should see** *(do not paste)*:

```text
[{"id":1,"name":"Coffee","price":35},
 {"id":2,"name":"Tea","price":25},
 {"id":3,"name":"Muffin","price":30},
 {"id":4,"name":"Juice","price":20}]
```

🎉 The **Juice is still there**. The pod is new, the data is not: it is on the disk.

If you get an error instead of the list, wait 20 seconds and run the `curl` command again.

### Step 7: see the data on the node

**📋 Copy and paste into your terminal:**

```bash
minikube ssh -n minikube-m02 -- sudo ls /data/shop/dev/pgdata | head -5
```

**What this does:** Lists the files of the database on the node `minikube-m02`, in the folder of the PersistentVolume. `| head` shows only the first 5 lines.

**👀 You should see** the files of the database, in the folder the PersistentVolume names *(do not paste)*:

```text
PG_VERSION    pg_hba.conf    pg_replslot   pg_subtrans	postgresql.auto.conf
base	      pg_ident.conf  pg_serial	   pg_tblspc	postgresql.conf
global	      pg_logical     pg_snapshots  pg_twophase	postmaster.opts
pg_commit_ts  pg_multixact   pg_stat	   pg_wal	postmaster.pid
pg_dynshmem   pg_notify      pg_stat_tmp   pg_xact
```

## Part B: the same disk on a network backend

A local disk has one weak point: if the node `minikube-m02` is lost, the data is lost with it. A **network backend** keeps the data outside the nodes, so any node can use it.

### Step 8: read an NFS volume

**⌨️ Command line option:** none. kubectl has no command that creates a PersistentVolume, so the YAML is the only way. In the exam, copy an example from the Kubernetes documentation and change it.

**📋 Copy and paste into your terminal:**

```bash
cat nfs-pv-example.yaml
```

**What this does:** Shows what is in the file `nfs-pv-example.yaml`.

**👀 You should see** *(do not paste)*:

```yaml
# EXAMPLE ONLY: do not apply. There is no NFS server in the lab.
# This is what a disk on an NFS server looks like. Only the "nfs:" part is different.
apiVersion: v1
kind: PersistentVolume
metadata:
  name: shop-nfs-pv
spec:
  capacity:
    storage: 5Gi
  accessModes:
  - ReadWriteMany                   # NFS can be used by many nodes at the same time
  persistentVolumeReclaimPolicy: Retain
  storageClassName: nfs
  nfs:
    server: 10.0.0.50               # the NFS server
    path: /exports/shop             # the shared folder on it
```

Compare it with `db-pv-dev.yaml`:

| | Local (`db-pv-dev.yaml`) | NFS (`nfs-pv-example.yaml`) |
| --- | --- | --- |
| The backend part | `hostPath: path: /data/shop/dev` | `nfs: server: ... path: ...` |
| `nodeAffinity` | Needed: the folder is on one node | Not needed: every node can reach the server |
| Access mode | `ReadWriteOnce` | `ReadWriteMany` is possible |
| The claim and the Deployment | The same | **The same** |

That last line is the point of the whole design: the application's claim does not change when the backend changes.

### GlusterFS

**GlusterFS** is a storage cluster: several servers that together look like one big disk. Older Kubernetes versions had a built-in `glusterfs:` volume type, next to `nfs:`. It was removed in Kubernetes v1.26. Today GlusterFS, Ceph and cloud disks are connected through a **CSI driver**: a plugin from the storage vendor that you install in the cluster. For the application nothing changes: it still makes a claim.

💡 **Exam tip:** a claim stays `Pending` when no volume fits. Check four things: the **size** (the volume must be at least as big), the **access mode**, the **storage class name** (must be the same on both), and `kubectl describe pvc <name>` for the reason.

✅ **Check:** Step 6 shows four items, with the Juice, after the database pod was deleted.

## More practice

The Shop part of the lab is done. These exercises use their own disk (`practice-pv`) and claim, with the class name `manual`, so they never touch the database's disk. The clean-up at the end removes them.

### 🟡 Practice 1: who uses the disk?

**📋 Copy and paste into your terminal:**

```bash
kubectl get pv shop-dev-pv -o jsonpath='{.spec.claimRef.namespace}/{.spec.claimRef.name}{"\n"}'
kubectl describe pvc db-data | grep -E "^(Status|Volume|Used By)"
```

**What this does:**

- `kubectl get pv shop-dev-pv -o jsonpath=...`: Prints which claim the disk belongs to (namespace/name).
- `kubectl describe pvc db-data | grep ...`: Shows the claim's status, its disk, and the pods that use it.

**👀 You should see** `dev/db-data`, then `Bound`, `shop-dev-pv` and the name of the `db` pod. The disk points to the claim, and the claim to the disk.

### 🟡 Practice 2: when does a claim get a disk?

A claim binds to a disk only when **all** of these match: the class, the access mode, and a size that is **at least** what it asks.

**⌨️ Command line option:** none. kubectl has no command that creates a PersistentVolume or a PersistentVolumeClaim.

**📋 Copy and paste into your terminal:**

```bash
kubectl apply -f - <<'YAML'
apiVersion: v1
kind: PersistentVolume
metadata:
  name: practice-pv
spec:
  capacity:
    storage: 200Mi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath:
    path: /data/practice
    type: DirectoryOrCreate
YAML
kubectl apply -n dev -f - <<'YAML'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: too-much
spec:
  storageClassName: manual
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 500Mi            # more than the disk has
YAML
sleep 3
kubectl get pv practice-pv
kubectl get pvc too-much -n dev
```

**What this does:**

- First `kubectl apply`: Creates a disk `practice-pv` of 200Mi, class `manual`.
- Second `kubectl apply`: Creates a claim `too-much` in `dev` that asks for 500Mi of class `manual`.
- `sleep 3`: Waits 3 seconds.
- `kubectl get pv practice-pv` and `kubectl get pvc too-much -n dev`: Show the disk and the claim.

**👀 You should see** the disk `Available` and the claim `Pending`: no disk is big enough. Delete it, and ask for less:

**📋 Copy and paste into your terminal:**

```bash
kubectl delete pvc too-much -n dev
kubectl apply -n dev -f - <<'YAML'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: small
spec:
  storageClassName: manual
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 100Mi            # less than the disk has
YAML
sleep 3
kubectl get pvc small -n dev
```

**What this does:**

- `kubectl delete pvc too-much -n dev`: Deletes the claim that was too big.
- `kubectl apply ...`: Creates a claim `small` that asks for 100Mi.
- `sleep 3`: Waits 3 seconds.
- `kubectl get pvc small -n dev`: Shows the claim.

**👀 You should see** `Bound` to `practice-pv`, with a capacity of **200Mi**, not 100Mi. A claim gets a whole disk; the rest is not shared with anyone.

(The class `manual` has no StorageClass object. Then there is no `WaitForFirstConsumer`: the claim binds at once.)

### 🟡 Practice 3: after `Retain`, the disk is `Released`, not free

**📋 Copy and paste into your terminal:**

```bash
kubectl delete pvc small -n dev
sleep 3
kubectl get pv practice-pv
```

**What this does:** Deletes the claim `small`, waits 3 seconds, and shows the disk.

**👀 You should see** `Released`. The data is kept (`Retain`), and the disk still remembers its old claim, so **no new claim** can get it. An administrator decides: delete the data, or give the disk free again. Give it free:

**📋 Copy and paste into your terminal:**

```bash
kubectl patch pv practice-pv -p '{"spec":{"claimRef":null}}'
kubectl get pv practice-pv
```

**What this does:**

- `kubectl patch pv practice-pv -p '{"spec":{"claimRef":null}}'`: Removes the link to the old claim from the disk.
- `kubectl get pv practice-pv`: Shows the disk.

**👀 You should see** `Available` again. The old files are still in the folder: the next claim gets them.

### 🔵 Optional 4: why the database's disk names its node

`practice-pv` has no `nodeAffinity`. Watch what that does to a pod on another node. (Do Practice 3 first: the disk must be `Available`.)

**📋 Copy and paste into your terminal:**

```bash
kubectl apply -n dev -f - <<'YAML'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: small
spec:
  storageClassName: manual
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 100Mi
YAML
for n in minikube minikube-m02; do
  kubectl run use-$n -n dev --image=busybox:1.36 --overrides='{"spec":{"nodeSelector":{"kubernetes.io/hostname":"'$n'"},"containers":[{"name":"app","image":"busybox:1.36","command":["sleep","3600"],"volumeMounts":[{"name":"d","mountPath":"/d"}]}],"volumes":[{"name":"d","persistentVolumeClaim":{"claimName":"small"}}]}}'
done
kubectl wait pod/use-minikube pod/use-minikube-m02 -n dev --for=condition=Ready --timeout=60s
kubectl exec use-minikube-m02 -n dev -- sh -c 'echo hello > /d/file.txt'
kubectl exec use-minikube -n dev -- ls /d
```

**What this does:**

- `kubectl apply ...`: Makes the claim `small` again. It binds to `practice-pv`.
- `for n in ...; do kubectl run use-$n ...; done`: Starts two pods that use the **same** claim: one on `minikube`, one on `minikube-m02`.
- `kubectl wait ...`: Waits until both are ready.
- `kubectl exec use-minikube-m02 ...`: Writes a file through the pod on `minikube-m02`.
- `kubectl exec use-minikube -n dev -- ls /d`: Looks for it through the pod on `minikube`.

**👀 You should see** both pods running, and **no** file from `minikube`. With `hostPath`, each node has its own `/data/practice`. Kubernetes did not stop it, because the disk did not say where it lives. `nodeAffinity` on the disk (as in `db-pv-dev.yaml`) makes the scheduler put the pod on the right node. (`ReadWriteOnce` means one **node**, but it is not checked for `hostPath`.)

### 🔵 Optional 5: challenge

Without looking at the answer: make a disk `log-pv` of 100Mi, `ReadWriteMany`, class `manual`, at `/data/logs` on the node `minikube-m02` only. Make a claim `log-claim` of 50Mi in `dev`, and a pod `log-writer` that mounts it at `/var/log/app`. Check that the pod runs on `minikube-m02`.

<details><summary>Show the answer</summary>

**📋 Copy and paste into your terminal:**

```bash
kubectl apply -f - <<'YAML'
apiVersion: v1
kind: PersistentVolume
metadata:
  name: log-pv
spec:
  capacity:
    storage: 100Mi
  accessModes:
  - ReadWriteMany
  storageClassName: manual
  hostPath:
    path: /data/logs
    type: DirectoryOrCreate
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - minikube-m02
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: log-claim
  namespace: dev
spec:
  storageClassName: manual
  accessModes:
  - ReadWriteMany
  resources:
    requests:
      storage: 50Mi
---
apiVersion: v1
kind: Pod
metadata:
  name: log-writer
  namespace: dev
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
    volumeMounts:
    - name: logs
      mountPath: /var/log/app
  volumes:
  - name: logs
    persistentVolumeClaim:
      claimName: log-claim
YAML
kubectl wait pod/log-writer -n dev --for=condition=Ready --timeout=60s
kubectl get pvc log-claim -n dev
kubectl get pod log-writer -n dev -o wide
```

**What this does:** Creates the disk, the claim and the pod from one YAML (the `---` lines separate them), waits until the pod is ready, and shows the claim and the pod with its node.

**👀 You should see** `log-claim` `Bound` to `log-pv`, and `log-writer` on `minikube-m02`: the scheduler read the disk's `nodeAffinity`. (`practice-pv` is `ReadWriteOnce`, so the `ReadWriteMany` claim can only get `log-pv`.)

</details>

🧹 **Clean up the practice:**

**📋 Copy and paste into your terminal:**

```bash
kubectl delete pod use-minikube use-minikube-m02 log-writer -n dev --now --ignore-not-found
kubectl delete pvc small too-much log-claim -n dev --ignore-not-found
kubectl delete pv practice-pv log-pv --ignore-not-found
minikube ssh -- sudo rm -rf /data/practice
minikube ssh -n minikube-m02 -- sudo rm -rf /data/practice /data/logs
kubectl get pv
```

**What this does:**

- `kubectl delete pod ...`, `pvc ...`, `pv ...`: Delete the test pods, claims and disks of this practice.
- `minikube ssh ... sudo rm -rf ...`: Delete the practice folders on the nodes. (`Retain` keeps them, so you remove them yourself.)
- `kubectl get pv`: Lists the disks that are left.

**👀 You should see** only `shop-dev-pv`, `Bound` to `dev/db-data`.

**Next:** [Lab 7.3: Storage classes and dynamic provisioning](./lab-7.3-storage-classes-and-dynamic-provisioning.md)
