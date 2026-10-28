# Module 9: Cluster maintenance

Each lab below is a practical from this repository, step by step: the command, what it does, and what it printed on the practice cluster. Names with random endings (pod names such as `nginx-7d9c…`), IP addresses and ages will differ on yours. Lab numbers are those of the labs in Desired Labs.

- [Lab 2.8: Cordon and drain a node](#lab-28-cordon-and-drain-a-node)
- [Lab 2.9: Upgrade the control plane](#lab-29-upgrade-the-control-plane)
- [Lab 2.10: Upgrade the workers](#lab-210-upgrade-the-workers)
- [Lab 2.11: Back up etcd](#lab-211-back-up-etcd)

## Before you start

These labs continue on the kubeadm cluster you built in the [installation guide](./01-installation.md) (`controlplane`, `node01` and `node02` from `sudo ./scripts/one-server.sh create`, plus `node03` if you grew it). They drain a node, upgrade the cluster one minor version and back up etcd, as the CKA exam does on kubeadm clusters. Start from Lab 2.7's cluster: `sudo ./scripts/one-server.sh shell` opens root@controlplane.

## Lab 2.8: Cordon and drain a node

### What you will do

Follow the example scenario in [01-cordoning-and-draining-nodes.md](https://github.com/kumbulanit/CKA/blob/main/09-cluster-maintenance/01-cordoning-and-draining-nodes.md):

1. Cordon **node01** and check its status (`SchedulingDisabled`).
2. Drain it with `--ignore-daemonsets --delete-emptydir-data`.
3. Reboot it (`ssh node01`, then `sudo reboot`) and wait until it is `Ready` again.
4. Uncordon it and check the nodes.

### Step by step

**Step 1.** Marks the node `node01` unschedulable; its pods keep running.

```bash
kubectl cordon node01
```

You should see something like:

```text
node/node01 cordoned
```

**Step 2.** Lists the nodes.

```bash
kubectl get nodes
```

You should see something like:

```text
NAME           STATUS                     ROLES           AGE   VERSION
controlplane   Ready                      control-plane   13m   v1.36.5
node01         Ready,SchedulingDisabled   <none>          12m   v1.36.5
node02         Ready                      <none>          12m   v1.36.5
```

**Step 3.** Evicts the pods from `node01` and marks it unschedulable, ready for maintenance.

```bash
kubectl drain node01 --ignore-daemonsets --delete-emptydir-data
```

You should see something like:

```text
node/node01 already cordoned
Warning: ignoring DaemonSet-managed Pods: kube-system/calico-node-jxx9c, kube-system/kube-proxy-zqnfk
node/node01 drained
```

**Step 4.** Restarts the machine (a moment later, so this command can finish first). Sudo reboot, without cutting off this script.

```bash
ssh node01 'sudo systemd-run --on-active=2 systemctl reboot'
```

You should see something like:

```text
Running timer as unit: run-rde24e2240b184e27af16b8bbcb2a544b.timer
Will run service as unit: run-rde24e2240b184e27af16b8bbcb2a544b.service
```

**Step 5.** Waits 20 seconds.

```bash
sleep 20
```

It prints nothing when it works.

**Step 6.** Waits until the node `node01` is Ready.

```bash
kubectl wait --for=condition=Ready node/node01 --timeout=180s
```

You should see something like:

```text
node/node01 condition met
```

**Step 7.** Lets the scheduler place pods on `node01` again.

```bash
kubectl uncordon node01
```

You should see something like:

```text
node/node01 uncordoned
```

**Step 8.** Lists the nodes.

```bash
kubectl get nodes
```

You should see something like:

```text
NAME           STATUS   ROLES           AGE   VERSION
controlplane   Ready    control-plane   14m   v1.36.5
node01         Ready    <none>          12m   v1.36.5
node02         Ready    <none>          12m   v1.36.5
```

### If you see something else

- The check says: _node01 has not been cordoned yet._
- The check says: _node01 is still cordoned. Uncordon it with `kubectl uncordon node01`._
- The check says: _node01 is not Ready._
- `kubectl drain` cordons the node itself before evicting pods; DaemonSet pods (calico-node, kube-proxy) stay, which is why it needs `--ignore-daemonsets`.
- After the reboot the kubelet starts by itself (it is enabled), so the node comes back on its own.

### Why it works

**Why it works.** `kubectl cordon` marks the node unschedulable (`spec.unschedulable: true`), so no new pods land on it. `kubectl drain` cordons it and evicts its pods, respecting PodDisruptionBudgets; controllers recreate them elsewhere. DaemonSet pods are left alone (`--ignore-daemonsets`), and pods with emptyDir data are only evicted with `--delete-emptydir-data`, because that data is lost. After maintenance, `kubectl uncordon` makes the node schedulable again.

**In this lab:** the machine is a container, so a reboot restarts the container; systemd, containerd and the kubelet come back as on a VM.

---

## Lab 2.9: Upgrade the control plane

![A kubeadm upgrade, one minor version: control plane first, then each worker in turn](../images/upgrade.svg)

*A kubeadm upgrade, one minor version: control plane first, then each worker in turn*

### What you will do

Follow section 1, step 2 of [02-cluster-maintenance.md](https://github.com/kumbulanit/CKA/blob/main/09-cluster-maintenance/02-cluster-maintenance.md)
on **controlplane**, to upgrade it from v1.36 to **v1.37.1**:

1. Point the Kubernetes apt repository at v1.37, update, and list the kubeadm versions.
2. Upgrade kubeadm to `1.37.1-1.1`, run `kubeadm upgrade plan`, then `kubeadm upgrade apply v1.37.1`.
3. Drain controlplane, upgrade kubelet and kubectl to `1.37.1-1.1`, restart the kubelet, and
   uncordon controlplane.

### Step by step

**Step 1.** Edits `/etc/apt/sources.list.d/kubernetes.list`: `/v1.36/` becomes `/v1.37/`.

```bash
sudo sed -i 's|/v1.36/|/v1.37/|' /etc/apt/sources.list.d/kubernetes.list
```

**Step 2.** Refreshes the list of packages.

```bash
sudo apt update
```

**Step 3.** Lists the versions of `kubeadm` you can install.

```bash
apt-cache madison kubeadm
```

**Step 4.** Releases the hold so these packages can be upgraded, then installs `kubeadm=1.37.1-1.1`, then holds these packages at their version so a routine upgrade does not change them.

```bash
sudo apt-mark unhold kubeadm && sudo apt install -y kubeadm='1.37.1-1.1' && sudo apt-mark hold kubeadm
```

**Step 5.** Checks which versions this cluster can be upgraded to.

```bash
sudo kubeadm upgrade plan
```

**Step 6.** Upgrades the control plane components to that version.

```bash
sudo kubeadm upgrade apply v1.37.1 -y   # -y answers kubeadm's "Are you sure?"
```

**Step 7.** Evicts the pods from `controlplane` and marks it unschedulable, ready for maintenance.

```bash
kubectl drain controlplane --ignore-daemonsets
```

**Step 8.** Releases the hold so these packages can be upgraded, then installs `kubelet=1.37.1-1.1`, `kubectl=1.37.1-1.1`, then holds these packages at their version so a routine upgrade does not change them.

```bash
sudo apt-mark unhold kubelet kubectl && sudo apt install -y kubelet='1.37.1-1.1' kubectl='1.37.1-1.1' && sudo apt-mark hold kubelet kubectl
```

**Step 9.** Makes systemd read the changed unit files, then restarts kubelet.

```bash
sudo systemctl daemon-reload && sudo systemctl restart kubelet
```

**Step 10.** Lets the scheduler place pods on `controlplane` again.

```bash
kubectl uncordon controlplane
```

**Step 11.** Waits until the node `controlplane` is Ready.

```bash
kubectl wait --for=condition=Ready node/controlplane --timeout=120s
```

**Step 12.** Lists the nodes.

```bash
kubectl get nodes
```

### If you see something else

- The check says: _The control plane is not running v1.37.1 yet (`kubeadm upgrade apply v1.37.1`)._
- The check says: _The kubelet on controlplane is not v1.37.1 yet. Upgrade the kubelet package and restart it._
- The check says: _controlplane is cordoned or not Ready. Uncordon it._
- `pkgs.k8s.io` has one repository per minor version, so the repository line has to change from `/v1.36/` to `/v1.37/` before apt sees the new packages.
- Order matters: kubeadm first, then `kubeadm upgrade apply`, then the kubelet. kubeadm asks you to confirm with `y`.

### Why it works

**Why it works.** You upgrade one minor version at a time, control plane first. Upgrading the kubeadm package gives you the tool for the new version; `kubeadm upgrade plan` checks the cluster and shows the target versions; `kubeadm upgrade apply` replaces the static pod manifests (new images for the API server, controller manager, scheduler and etcd), renews certificates, and upgrades CoreDNS and kube-proxy. The kubelet is a separate package and is upgraded last, after draining the node.

**In the exam:** the order is the whole skill: repository, kubeadm, `upgrade apply` (or `upgrade node`), drain, kubelet and kubectl, restart, uncordon.

---

## Lab 2.10: Upgrade the workers

### What you will do

Follow section 1, step 3 of the cluster maintenance document for **node01**, then repeat for
**node02**, one at a time:

1. On the worker, point the repository at v1.37, upgrade kubeadm to `1.37.1-1.1`, and run
   `kubeadm upgrade node`.
2. From controlplane, drain the worker.
3. On the worker, upgrade kubelet and kubectl to `1.37.1-1.1` and restart the kubelet.
4. From controlplane, uncordon it.

node03 can stay on v1.36: a kubelet may be older than the control plane.

### Step by step

**Step 1.** Repeats the command for each of `node01`, `node02`.

```bash
for n in node01 node02; do
  ssh $n 'bash -s' <<'KUBEADM'
sudo sed -i 's|/v1.36/|/v1.37/|' /etc/apt/sources.list.d/kubernetes.list
sudo apt update
sudo apt-mark unhold kubeadm && sudo apt install -y kubeadm='1.37.1-1.1' && sudo apt-mark hold kubeadm
sudo kubeadm upgrade node
KUBEADM
  kubectl drain $n --ignore-daemonsets --delete-emptydir-data
  ssh $n 'bash -s' <<'KUBELET'
sudo apt-mark unhold kubelet kubectl && sudo apt install -y kubelet='1.37.1-1.1' kubectl='1.37.1-1.1' && sudo apt-mark hold kubelet kubectl
sudo systemctl daemon-reload && sudo systemctl restart kubelet
KUBELET
  kubectl uncordon $n
done
```

You should see something like:

```text

WARNING: apt does not have a stable CLI interface. Use with caution in scripts.

Hit:1 http://ports.ubuntu.com/ubuntu-ports noble InRelease
Hit:3 http://ports.ubuntu.com/ubuntu-ports noble-updates InRelease
Get:2 https://prod-cdn.packages.k8s.io/repositories/isv:/kubernetes:/core:/stable:/v1.37/deb  InRelease [1227 B]
Get:4 https://prod-cdn.packages.k8s.io/repositories/isv:/kubernetes:/core:/stable:/v1.37/deb  Packages [4384 B]
Hit:5 http://ports.ubuntu.com/ubuntu-ports noble-backports InRelease
Hit:6 http://ports.ubuntu.com/ubuntu-ports noble-security InRelease
Fetched 5611 B in 2s (3232 B/s)
Reading package lists...
Building dependency tree...
Reading state information...
3 packages can be upgraded. Run 'apt list --upgradable' to see them.
Canceled hold on kubeadm.

WARNING: apt does not have a stable CLI interface. Use with caution in scripts.

… (172 more lines)
```

**Step 2.** Waits until the nodes `node01`, `node02` are Ready.

```bash
kubectl wait --for=condition=Ready node/node01 node/node02 --timeout=120s
```

You should see something like:

```text
node/node01 condition met
node/node02 condition met
```

**Step 3.** Lists the nodes.

```bash
kubectl get nodes
```

You should see something like:

```text
NAME           STATUS   ROLES           AGE   VERSION
controlplane   Ready    control-plane   21m   v1.37.1
node01         Ready    <none>          20m   v1.37.1
node02         Ready    <none>          20m   v1.37.1
```

**Step 4.** Lists the pods in every namespace.

```bash
kubectl get pods --all-namespaces
```

You should see something like:

```text
NAMESPACE     NAME                                       READY   STATUS    RESTARTS        AGE
kube-system   calico-kube-controllers-6ffffbccff-s4pp8   1/1     Running   0               21s
kube-system   calico-node-2cmbx                          1/1     Running   0               21m
kube-system   calico-node-jxx9c                          1/1     Running   5 (7m48s ago)   20m
kube-system   calico-node-zxwzw                          1/1     Running   3 (10m ago)     20m
kube-system   coredns-589f44dc88-7hrrp                   1/1     Running   0               21s
kube-system   coredns-589f44dc88-9xj9d                   1/1     Running   0               49s
kube-system   etcd-controlplane                          1/1     Running   0               2m17s
kube-system   kube-apiserver-controlplane                1/1     Running   0               2m18s
kube-system   kube-controller-manager-controlplane       1/1     Running   0               2m23s
kube-system   kube-proxy-2828w                           1/1     Running   0               21m
kube-system   kube-proxy-fklqs                           1/1     Running   0               20m
kube-system   kube-proxy-zqnfk                           1/1     Running   1 (7m48s ago)   20m
kube-system   kube-scheduler-controlplane                1/1     Running   0               2m36s
```

### If you see something else

- The check says: _node01 and node02 are not both on v1.37.1._
- The check says: _node01 or node02 is cordoned or not Ready._
- On a worker, `kubeadm upgrade node` updates the kubelet's configuration; it does not touch the control plane.
- Drain and uncordon run on controlplane (where kubectl has the admin kubeconfig); the apt steps run on the worker.

### Why it works

**Why it works.** On a worker, `kubeadm upgrade node` only updates the kubelet's configuration for the new version; there are no control plane components to replace. The kubelet package does the real upgrade, so the node is drained first and uncordoned after. Upgrading one worker at a time keeps the applications running on the others.

**Version skew:** a kubelet may be up to three minor versions older than the API server, but never newer, which is why node03 can stay on v1.36 for now.

---

## Lab 2.11: Back up etcd

### What you will do

Follow section 4, step 1 of the cluster maintenance document on **controlplane**:

1. Install the etcd client (`apt install -y etcd-client`).
2. Save a snapshot of etcd to **/opt/etcd-backup.db** with `etcdctl snapshot save`, using the
   endpoint `https://127.0.0.1:2379` and the certificates in `/etc/kubernetes/pki/etcd/`.
3. Check the snapshot with `snapshot status --write-out=table`.

### Step by step

**Step 1.** Installs `etcd-client`.

```bash
sudo apt install -y etcd-client
```

You should see something like:

```text

WARNING: apt does not have a stable CLI interface. Use with caution in scripts.

Reading package lists...
Building dependency tree...
Reading state information...
The following NEW packages will be installed:
  etcd-client
0 upgraded, 1 newly installed, 0 to remove and 0 not upgraded.
Need to get 4757 kB of archives.
After this operation, 17.1 MB of additional disk space will be used.
Get:1 http://ports.ubuntu.com/ubuntu-ports noble-updates/universe arm64 etcd-client arm64 3.4.30-1ubuntu0.24.04.3 [4757 kB]
debconf: unable to initialize frontend: Dialog
debconf: (Dialog frontend will not work on a dumb terminal, an emacs shell buffer, or without a controlling terminal.)
debconf: falling back to frontend: Readline
debconf: unable to initialize frontend: Readline
debconf: (This frontend requires a controlling tty.)
debconf: falling back to frontend: Teletype
… (7 more lines)
```

**Step 2.** Saves a snapshot of etcd, the whole cluster state, to a file.

```bash
sudo ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  snapshot save /opt/etcd-backup.db
```

You should see something like:

```text
{"level":"info","ts":1793141210.3652878,"caller":"snapshot/v3_snapshot.go:119","msg":"created temporary db file","path":"/opt/etcd-backup.db.part"}
{"level":"info","ts":"2026-10-27T22:46:50.37038Z","caller":"clientv3/maintenance.go:212","msg":"opened snapshot stream; downloading"}
{"level":"info","ts":1793141210.3704422,"caller":"snapshot/v3_snapshot.go:127","msg":"fetching snapshot","endpoint":"https://127.0.0.1:2379"}
{"level":"info","ts":"2026-10-27T22:46:50.567942Z","caller":"clientv3/maintenance.go:220","msg":"completed snapshot read; closing"}
{"level":"info","ts":1793141210.590544,"caller":"snapshot/v3_snapshot.go:142","msg":"fetched snapshot","endpoint":"https://127.0.0.1:2379","size":"9.4 MB","took":0.225078158}
{"level":"info","ts":1793141210.590847,"caller":"snapshot/v3_snapshot.go:152","msg":"saved","path":"/opt/etcd-backup.db"}
Snapshot saved at /opt/etcd-backup.db
```

**Step 3.** Checks the snapshot: its hash, revision, keys and size.

```bash
sudo etcdutl snapshot status /opt/etcd-backup.db --write-out=table || sudo ETCDCTL_API=3 etcdctl snapshot status /opt/etcd-backup.db --write-out=table
```

You should see something like:

```text
sudo: etcdutl: command not found
+---------+----------+------------+------------+
|  HASH   | REVISION | TOTAL KEYS | TOTAL SIZE |
+---------+----------+------------+------------+
| 85479a7 |     2570 |       2597 |     9.4 MB |
+---------+----------+------------+------------+
```

### If you see something else

- The check says: _The etcd client is not installed (`sudo apt install -y etcd-client`)._
- The check says: _/opt/etcd-backup.db does not exist yet._
- The check says: _/opt/etcd-backup.db is not a valid etcd snapshot._
- etcd only accepts clients with a certificate: `--cacert`, `--cert` and `--key` point at files in /etc/kubernetes/pki/etcd/.
- `cat /etc/kubernetes/manifests/etcd.yaml` shows the endpoint and certificate paths etcd itself uses.

### Why it works

**Why it works.** etcd holds the whole cluster state, so a snapshot of it is a backup of every object. `etcdctl snapshot save` asks the running etcd for a consistent copy over its client port (2379), which only accepts clients with a certificate signed by the etcd CA. `snapshot status` reads the file and reports its revision, key count and size.

**Restoring:** `etcdutl snapshot restore` writes a new data directory; you then point etcd's static pod manifest (`--data-dir` and its hostPath volume) at it.

---
