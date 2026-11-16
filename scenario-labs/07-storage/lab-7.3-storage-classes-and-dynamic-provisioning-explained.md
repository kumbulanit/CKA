# Lab 7.3 explained: storage classes and dynamic provisioning

This page goes with [Lab 7.3](./lab-7.3-storage-classes-and-dynamic-provisioning.md). The lab has the commands; this page explains them: what happens in the cluster, why it matters for the Shop, what usually goes wrong, and what the exam asks. There is nothing to paste here.

## In short

A **StorageClass** describes a kind of storage: who makes the volumes (the **provisioner**), when a claim is bound (the **binding mode**) and what happens to the volume when its claim is deleted (the **reclaim policy**). With a provisioner, a claim alone is enough: the volume is made on request. That is **dynamic provisioning**. In this lab you see both kinds side by side, and give UAT and PROD their own disks.

## The ideas behind this lab

### Static and dynamic provisioning

| | Static (Lab 7.2) | Dynamic |
| --- | --- | --- |
| Who makes the PV | An administrator, beforehand | The class's provisioner, when a claim arrives |
| PV names | Chosen by people (`shop-dev-pv`) | Generated (`pvc-` plus the claim's UID) |
| Scales to many applications | No | Yes |
| What the application writes | A claim | The same claim |

On clouds, dynamic provisioning is the normal way: a claim creates a real cloud disk through the provider's CSI driver.

### The fields of a StorageClass

| Field | Meaning | `standard` | `shop-disk` |
| --- | --- | --- | --- |
| `provisioner` | The program that makes volumes | `k8s.io/minikube-hostpath` | `kubernetes.io/no-provisioner`: none, volumes are made by hand |
| `reclaimPolicy` | For volumes it makes: delete or keep with the claim | `Delete` | `Retain` |
| `volumeBindingMode` | `Immediate`: bind as soon as the claim exists; `WaitForFirstConsumer`: wait for a pod | `Immediate` | `WaitForFirstConsumer` |
| `allowVolumeExpansion` | May a claim grow later? | `false` | `false` |
| `parameters` | Settings for the provisioner (disk type, speed...) | none | none |

### The default class

One class can carry the annotation `storageclass.kubernetes.io/is-default-class: "true"`; `kubectl get storageclass` marks it `(default)`. A claim **without** `storageClassName` gets the default class. A claim with `storageClassName: ""` asks for **no** class: it only binds to a hand-made PV without a class. A fresh kubeadm cluster has no default class at all.

### Why the Shop's database does not use `standard`

`standard` makes each volume as a folder on whichever node it chooses, and binds at once (`Immediate`), without telling the scheduler where that folder is. On one node that is fine; on three nodes, a database pod scheduled on another node finds an empty folder. The Shop's `shop-disk` volumes name their node (`nodeAffinity`) and the class waits for the pod (`WaitForFirstConsumer`), so pod and data always meet. Real dynamic provisioners for local disks (and all cloud disk drivers) record the volume's location, and use `WaitForFirstConsumer` for the same reason.

## Step by step

### Step 1: look at the two storage classes

The table in the lab compares them column by column. The key contrast: `standard` makes and deletes disks by itself; `shop-disk` makes nothing, keeps everything, and waits for a pod.

### Step 2: make a claim, and nothing else

The claim `reports` names `standard`, and there is no PV for it. The provisioner sees the new claim, creates a folder on a node, creates a PV for it (`pvc-3f6c...`) with the class's reclaim policy (`Delete`), and binds the two, within seconds. With `Immediate`, no pod was needed.

### Step 3: delete the claim and watch the disk go

With `Delete`, removing the claim removes its PV and the folder behind it: the data is gone for good. Convenient for test data and temporary space; a disaster for a database deleted by mistake. The hand-made `shop-dev-pv` with `Retain` is unaffected.

### Why the database does not use `standard`

See above: the placement of the folder is not known to the scheduler on a multi-node cluster.

### Step 4: look at the storage class of the Shop

`shop-disk` is a class without a provisioner. It still matters: it groups the Shop's hand-made volumes, sets `WaitForFirstConsumer`, and makes sure the Shop's claims only bind to the Shop's volumes (the class name must match on both).

### Step 5: make the disks and move the databases onto them

Each environment gets its own PV (`shop-uat-pv`, `shop-prod-pv`, each a folder on its node), the same claim file (`db-data`, applied with `-n uat` and `-n prod`), and the same database Deployment with the claim. Applying the Deployment replaces the old database pod (with its `emptyDir`) by one on the disk: it starts with the first three items, and from then on keeps what is added. The backends are restarted so they connect to the new database pods at once.

### Step 6: three environments, three disks

Three `Retain` volumes, each `Bound` to the `db-data` claim of its namespace. The same claim name in three namespaces, three different volumes: like the Service name `db` in Lab 3.3.

### Step 7: check PROD

The PROD Shop answers through its hostname. From now on its data survives pod restarts, drains and cluster restarts.

## When something goes wrong

| What you see | What it means | What to do |
| --- | --- | --- |
| A claim to `standard` stays `Pending` | The provisioner pod (`storage-provisioner` in `kube-system`) is not running | `kubectl get pods -n kube-system` |
| A claim without a class binds to the wrong kind of volume | It got the default class | Name the class, or `""` for hand-made volumes |
| A UAT or PROD claim stays `Pending` with the database running | Its PV is missing, or names another class | `kubectl get pv`; apply the right `db-pv-*.yaml` |
| Data gone after deleting a claim | The volume's reclaim policy was `Delete` | Use `Retain` for data you must keep |
| `persistentvolumeclaims "db-data" is forbidden` in a new namespace | A storage quota (Lab 7.4) is full | `kubectl describe resourcequota -n NS` |

## For the exam

- Know a StorageClass by heart: `provisioner`, `reclaimPolicy`, `volumeBindingMode`, `allowVolumeExpansion`, and the default-class annotation.
- "Make class X the default": add the annotation to X, and remove it from (or set it to `"false"` on) the old default.
- A claim grows by editing `resources.requests.storage`, only if the class has `allowVolumeExpansion: true`.
- `WaitForFirstConsumer` explains most "my claim is Pending" questions: it waits for a pod.

## Check your understanding

1. What is the difference between static and dynamic provisioning?
2. What does `kubernetes.io/no-provisioner` mean?
3. A claim names no storage class. Which class does it get?
4. Why is `Delete` dangerous for a database?
5. Why does the Shop's class use `WaitForFirstConsumer`?

<details><summary>Answers</summary>

1. Static: an administrator makes the PV first. Dynamic: the class's provisioner makes it when a claim arrives.
2. The class makes no volumes; they must be created by hand.
3. The default class, the one with the annotation `is-default-class: "true"` (`standard` on minikube).
4. Deleting the claim, even by mistake, deletes the volume and the data with it.
5. So the claim is bound only when the pod is placed, and pod and local disk end up on the same node.

</details>

**Back to:** [Lab 7.3](./lab-7.3-storage-classes-and-dynamic-provisioning.md) · **Next:** [Lab 7.4 explained](./lab-7.4-resource-quotas-explained.md)
