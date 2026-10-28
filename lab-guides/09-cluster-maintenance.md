# Module 9: Cluster maintenance

Each lab below is a practical from this repository, step by step: the command, what it does, and what it printed on the practice cluster. Names with random endings (pod names such as `nginx-7d9c…`), IP addresses and ages will differ on yours. The outputs show Kubernetes v1.36.4 (v1.37.0 after the upgrade lab), the newest version the practice cluster's images have; the cluster `setup.sh` makes runs v1.36.5, so the VERSION columns on yours say v1.36.5. Lab numbers are those of the labs in Desired Labs.

- [Lab 9.1: Cordon and drain a node](#lab-91-cordon-and-drain-a-node)
- [Lab 9.2: Upgrade the cluster](#lab-92-upgrade-the-cluster)
- [Lab 9.3: Back up etcd](#lab-93-back-up-etcd)

## Before you start

Start the practice cluster on your Ubuntu server, as in the [README](../README.md#the-practice-cluster):

```bash
git clone https://github.com/kumbulanit/CKA.git && cd CKA
sudo ./setup.sh          # minikube with three nodes, Kubernetes v1.36 (about 10 minutes the first time)
kubectl get nodes         # minikube, minikube-m02, minikube-m03
```

The steps use those node names, and `minikube ssh -n <node>` for commands on a node. Run `kubectl` as your own user on the server; commands on the control plane's files (`/etc/kubernetes/manifests`, the kubelet) go through `minikube ssh` with `sudo`. The outputs were recorded in Desired Labs, whose cluster is set out like minikube's (the API server on port 8443, certificates in `/var/lib/minikube/certs` and `~/.minikube`); its terminal is root on `minikube`, so prompts differ, and addresses and ages on yours will differ too.

## Lab 9.1: Cordon and drain a node

### What you will do

Follow the example scenario in [01-cordoning-and-draining-nodes.md](https://github.com/kumbulanit/CKA/blob/main/09-cluster-maintenance/01-cordoning-and-draining-nodes.md).
The lab runs a Deployment **web** with 3 nginx pods, so draining has something to move.

1. Cordon **minikube-m02** and check its status (`SchedulingDisabled`).
2. Drain it with `--ignore-daemonsets --delete-emptydir-data`, and see where web's pods went.
3. Restart it: `minikube node stop minikube-m02`, then `minikube node start minikube-m02`.
4. Uncordon it and check the nodes.

### Step by step

**Step 1.** Marks the node `minikube-m02` unschedulable; its pods keep running.

```bash
kubectl cordon minikube-m02
```

You should see something like:

```text
node/minikube-m02 cordoned
```

**Step 2.** Lists the nodes.

```bash
kubectl get nodes
```

You should see something like:

```text
NAME           STATUS                     ROLES           AGE    VERSION
minikube       Ready                      control-plane   2m8s   v1.36.4
minikube-m02   Ready,SchedulingDisabled   worker          118s   v1.36.4
minikube-m03   Ready                      worker          118s   v1.36.4
```

**Step 3.** Evicts the pods from `minikube-m02` and marks it unschedulable, ready for maintenance.

```bash
kubectl drain minikube-m02 --ignore-daemonsets --delete-emptydir-data
```

You should see something like:

```text
node/minikube-m02 already cordoned
Warning: ignoring DaemonSet-managed Pods: kube-system/kindnet-wv9q8, kube-system/kube-proxy-vfbl6
evicting pod default/web-7887448d46-6xr99
pod/web-7887448d46-6xr99 evicted
node/minikube-m02 drained
```

**Step 4.** Lists the pods, with IP address and node.

```bash
kubectl get pods -o wide
```

You should see something like:

```text
NAME                   READY   STATUS              RESTARTS   AGE   IP           NODE           NOMINATED NODE   READINESS GATES
web-7887448d46-k999f   1/1     Running             0          43s   10.244.1.3   minikube-m03   <none>           <none>
web-7887448d46-ljxtd   0/1     ContainerCreating   0          2s    <none>       minikube-m03   <none>           <none>
web-7887448d46-m92p5   1/1     Running             0          43s   10.244.1.2   minikube-m03   <none>           <none>
```

**Step 5.** Runs `minikube`.

```bash
minikube node stop minikube-m02
```

You should see something like:

```text
✋  Stopping node "minikube-m02" ...
🛑  Successfully stopped node minikube-m02
```

**Step 6.** Runs `minikube`.

```bash
minikube node start minikube-m02
```

You should see something like:

```text
👍  Starting "minikube-m02" worker node in "minikube" cluster
😄  Successfully started node minikube-m02!
```

**Step 7.** Lets the scheduler place pods on `minikube-m02` again.

```bash
kubectl uncordon minikube-m02
```

You should see something like:

```text
node/minikube-m02 uncordoned
```

**Step 8.** Waits until the node `minikube-m02` is Ready.

```bash
kubectl wait --for=condition=Ready node/minikube-m02 --timeout=120s
```

You should see something like:

```text
node/minikube-m02 condition met
```

**Step 9.** Lists the nodes.

```bash
kubectl get nodes
```

You should see something like:

```text
NAME           STATUS   ROLES           AGE     VERSION
minikube       Ready    control-plane   2m11s   v1.36.4
minikube-m02   Ready    worker          2m1s    v1.36.4
minikube-m03   Ready    worker          2m1s    v1.36.4
```

### If you see something else

- The check says: _minikube-m02 has not been drained yet (web's pods are still where they started)._
- The check says: _minikube-m02 is still cordoned. Uncordon it with `kubectl uncordon minikube-m02`._
- The check says: _minikube-m02 is not Ready. Did you start it again (`minikube node start minikube-m02`)?_
- `kubectl drain` cordons the node itself before evicting pods; DaemonSet pods (kindnet, kube-proxy) stay, which is why it needs `--ignore-daemonsets`.
- `kubectl get pods -o wide` shows which node each pod runs on, before and after the drain.

### Why it works

**Why it works.** `kubectl cordon` marks the node unschedulable (`spec.unschedulable: true`), so no new pods land on it. `kubectl drain` cordons it and evicts its pods, respecting PodDisruptionBudgets; controllers recreate them elsewhere. DaemonSet pods are left alone (`--ignore-daemonsets`), and pods with emptyDir data are only evicted with `--delete-emptydir-data`, because that data is lost. After maintenance, `kubectl uncordon` makes the node schedulable again.

**On minikube**, `minikube node stop` and `minikube node start` stand in for a reboot: the kubelet stops, the node turns `NotReady`, and it comes back when the kubelet starts again. On a kubeadm cluster you run `sudo reboot` on the node.

---

## Lab 9.2: Upgrade the cluster

![An upgrade, one minor version: the control plane first, then each worker in turn](../images/upgrade.svg)

*An upgrade, one minor version: the control plane first, then each worker in turn*

### What you will do

Follow section 1, step 2 of [02-cluster-maintenance.md](https://github.com/kumbulanit/CKA/blob/main/09-cluster-maintenance/02-cluster-maintenance.md):
upgrade the cluster from v1.36 to **v1.37.0**.

1. Check the versions now (`kubectl get nodes`).
2. Upgrade every node with `minikube start --kubernetes-version=v1.37.0`. It takes a few minutes.
3. Check the nodes again, and that the pods in every namespace are running.

### Step by step

**Step 1.** Lists the nodes.

```bash
kubectl get nodes
```

You should see something like:

```text
NAME           STATUS   ROLES           AGE     VERSION
minikube       Ready    control-plane   2m11s   v1.36.4
minikube-m02   Ready    worker          2m1s    v1.36.4
minikube-m03   Ready    worker          2m1s    v1.36.4
```

**Step 2.** Runs `minikube`.

```bash
minikube start --kubernetes-version=v1.37.0
```

You should see something like:

```text
😄  minikube on the lab's machines
✨  Using the existing cluster (3 nodes: minikube minikube-m02 minikube-m03)
🔄  Upgrading the cluster from Kubernetes v1.36.4 to v1.37.0
    ▪ Upgrading the control plane on minikube
    ▪ Upgrading minikube-m02
    ▪ Upgrading minikube-m03
    ▪ Setting the cluster out as before
🏄  Done! The cluster runs Kubernetes v1.37.0
🏄  Done! kubectl is now configured to use "minikube" cluster and "default" namespace by default
```

**Step 3.** Lists the nodes.

```bash
kubectl get nodes
```

You should see something like:

```text
NAME           STATUS   ROLES           AGE   VERSION
minikube       Ready    control-plane   11m   v1.37.0
minikube-m02   Ready    worker          11m   v1.37.0
minikube-m03   Ready    worker          11m   v1.37.0
```

**Step 4.** Lists the pods in every namespace.

```bash
kubectl get pods --all-namespaces
```

You should see something like:

```text
NAMESPACE            NAME                                      READY   STATUS              RESTARTS        AGE
default              web-7887448d46-k999f                      1/1     Running             0               10m
default              web-7887448d46-ljxtd                      1/1     Running             0               9m24s
default              web-7887448d46-m92p5                      1/1     Running             0               10m
kube-system          coredns-559f6c778d-lw782                  0/1     ContainerCreating   0               51s
kube-system          coredns-559f6c778d-scj8b                  0/1     ContainerCreating   0               51s
kube-system          coredns-589f44dc88-jj9h8                  1/1     Running             0               11m
kube-system          etcd-minikube                             1/1     Running             0               50s
kube-system          kindnet-jlvh5                             1/1     Running             0               11m
kube-system          kindnet-n2psz                             1/1     Running             0               11m
kube-system          kindnet-wv9q8                             1/1     Running             1 (9m22s ago)   11m
kube-system          kube-apiserver-minikube                   0/1     Running             0               50s
kube-system          kube-controller-manager-minikube          1/1     Running             0               50s
kube-system          kube-proxy-9wxkg                          0/1     ContainerCreating   0               51s
kube-system          kube-proxy-t6mww                          1/1     Running             0               11m
kube-system          kube-proxy-vfbl6                          1/1     Running             1 (9m22s ago)   11m
kube-system          kube-scheduler-minikube                   0/1     Running             2 (35s ago)     50s
local-path-storage   local-path-provisioner-56c4685b7c-rdsml   1/1     Running             0               11m
```

### If you see something else

- The check says: _The control plane is not running v1.37.0 yet (`minikube start --kubernetes-version=v1.37.0`)._
- The check says: _Not every node runs v1.37.0 yet._
- The check says: _Not every node is Ready after the upgrade._
- One minor version at a time: from v1.36 the next is v1.37.
- `minikube start` on a running cluster keeps it; with `--kubernetes-version` it upgrades the control plane, then every node's kubelet.

### Why it works

**Why it works.** A cluster is upgraded one minor version at a time, control plane first, then each worker. `minikube start --kubernetes-version` does all of it for you: it upgrades the control plane components (API server, controller manager, scheduler, etcd, CoreDNS, kube-proxy), then the kubelet on every node. The applications keep running, because a kubelet restart does not stop the containers it runs.

**In the exam:** the clusters are kubeadm clusters, and you upgrade them by hand: on the control plane, point apt at the new minor version, upgrade kubeadm, `kubeadm upgrade plan`, `kubeadm upgrade apply`, drain, upgrade kubelet and kubectl, restart the kubelet, uncordon; then on each worker, `kubeadm upgrade node` and the same kubelet steps. The lesson shows those steps, and the optional kubeadm labs in Module 2 build such a cluster. A kubelet may be up to three minor versions older than the API server, but never newer.

---

## Lab 9.3: Back up etcd

### What you will do

Follow section 4, step 1 of [02-cluster-maintenance.md](https://github.com/kumbulanit/CKA/blob/main/09-cluster-maintenance/02-cluster-maintenance.md),
the minikube way:

1. Save a snapshot of etcd to **/var/lib/minikube/etcd/etcd-backup.db** with `etcdctl snapshot save`,
   run inside the etcd pod (`kubectl -n kube-system exec etcd-minikube -- etcdctl ...`), using the
   endpoint `https://127.0.0.1:2379` and the certificates in `/var/lib/minikube/certs/etcd/`.
2. Check the snapshot with `etcdutl snapshot status ... --write-out=table`, also inside the pod.

### Step by step

**Step 1.** Inside the pod `etcd-minikube`, not on the server: queries etcd.

```bash
kubectl -n kube-system exec etcd-minikube -- etcdctl --endpoints=https://127.0.0.1:2379 \
  --cacert=/var/lib/minikube/certs/etcd/ca.crt \
  --cert=/var/lib/minikube/certs/etcd/server.crt \
  --key=/var/lib/minikube/certs/etcd/server.key \
  snapshot save /var/lib/minikube/etcd/etcd-backup.db
```

You should see something like:

```text
{"level":"info","ts":"2026-10-28T15:55:20.642886Z","caller":"snapshot/v3_snapshot.go:83","msg":"created temporary db file","path":"/var/lib/minikube/etcd/etcd-backup.db.part"}
{"level":"info","ts":"2026-10-28T15:55:20.649958Z","logger":"client","caller":"v3/maintenance.go:236","msg":"opened snapshot stream; downloading"}
{"level":"info","ts":"2026-10-28T15:55:20.653248Z","caller":"snapshot/v3_snapshot.go:96","msg":"fetching snapshot","endpoint":"https://127.0.0.1:2379"}
{"level":"info","ts":"2026-10-28T15:55:20.683259Z","logger":"client","caller":"v3/maintenance.go:302","msg":"completed snapshot read; closing"}
{"level":"info","ts":"2026-10-28T15:55:20.687318Z","caller":"snapshot/v3_snapshot.go:111","msg":"fetched snapshot","endpoint":"https://127.0.0.1:2379","size":"3.8 MB","took":"44.385691ms","etcd-version":"3.7.0"}
{"level":"info","ts":"2026-10-28T15:55:20.687424Z","caller":"snapshot/v3_snapshot.go:121","msg":"saved","path":"/var/lib/minikube/etcd/etcd-backup.db"}
Snapshot saved at /var/lib/minikube/etcd/etcd-backup.db
Server version 3.7.0
```

**Step 2.** Inside the pod `etcd-minikube`, not on the server: runs `etcdutl`.

```bash
kubectl -n kube-system exec etcd-minikube -- etcdutl snapshot status /var/lib/minikube/etcd/etcd-backup.db --write-out=table
```

You should see something like:

```text
┌──────────┬──────────┬────────────┬────────────┬─────────┐
│   HASH   │ REVISION │ TOTAL KEYS │ TOTAL SIZE │ VERSION │
├──────────┼──────────┼────────────┼────────────┼─────────┤
│ 4d8e716f │     1856 │        609 │     3.8 MB │   3.7.0 │
└──────────┴──────────┴────────────┴────────────┴─────────┘
```

### If you see something else

- The check says: _/var/lib/minikube/etcd/etcd-backup.db does not exist yet._
- The check says: _/var/lib/minikube/etcd/etcd-backup.db is not a valid etcd snapshot._
- etcd only accepts clients with a certificate: `--cacert`, `--cert` and `--key` point at files in /var/lib/minikube/certs/etcd/.
- `minikube ssh -- sudo cat /etc/kubernetes/manifests/etcd.yaml` shows the endpoint and certificate paths etcd itself uses.

### Why it works

**Why it works.** etcd holds the whole cluster state, so a snapshot of it is a backup of every object. `etcdctl snapshot save` asks the running etcd for a consistent copy over its client port (2379), which only accepts clients with a certificate signed by the etcd CA. On minikube those certificates are in `/var/lib/minikube/certs/etcd/`, and running `etcdctl` inside the etcd pod (`kubectl exec etcd-minikube`) means nothing has to be installed; the snapshot is written into etcd's data folder, `/var/lib/minikube/etcd`, on the control plane node. `etcdutl snapshot status` reads the file and reports its revision, key count and size.

**On a kubeadm cluster** (the exam), install `etcd-client` on the control plane and run the same `etcdctl` with the certificates in `/etc/kubernetes/pki/etcd/`. **Restoring:** `etcdutl snapshot restore` writes a new data directory; you then point etcd's static pod manifest (`--data-dir` and its hostPath volume) at it.

---
