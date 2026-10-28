# Module 8: Troubleshooting

Each lab below is a practical from this repository, step by step: the command, what it does, and what it printed on the practice cluster. Names with random endings (pod names such as `nginx-7d9c…`), IP addresses and ages will differ on yours. The outputs show Kubernetes v1.36.4 (v1.37.0 after the upgrade lab), the newest version the practice cluster's images have; the cluster `setup.sh` makes runs v1.36.5, so the VERSION columns on yours say v1.36.5. Lab numbers are those of the labs in Desired Labs.

- [Lab 8.1: App failure: alpha](#lab-81-app-failure-alpha)
- [Lab 8.2: App failure: beta](#lab-82-app-failure-beta)
- [Lab 8.3: App failure: gamma](#lab-83-app-failure-gamma)
- [Lab 8.4: App failure: delta](#lab-84-app-failure-delta)
- [Lab 8.5: App failure: epsilon (two issues)](#lab-85-app-failure-epsilon-two-issues)
- [Lab 8.6: App failure: zeta (three issues)](#lab-86-app-failure-zeta-three-issues)
- [Lab 8.7: The scheduler is down](#lab-87-the-scheduler-is-down)
- [Lab 8.8: Scaling does not happen](#lab-88-scaling-does-not-happen)
- [Lab 8.9: Scaling stops again](#lab-89-scaling-stops-again)
- [Lab 8.10: minikube-m02 is NotReady](#lab-810-minikube-m02-is-notready)
- [Lab 8.11: minikube-m02 is broken again](#lab-811-minikube-m02-is-broken-again)
- [Lab 8.12: minikube-m02 is broken a third time](#lab-812-minikube-m02-is-broken-a-third-time)
- [Lab 8.13: Services stopped working](#lab-813-services-stopped-working)
- [Lab 8.14: Pods cannot start](#lab-814-pods-cannot-start)

## Before you start

Start the practice cluster on your Ubuntu server, as in the [README](../README.md#the-practice-cluster):

```bash
git clone https://github.com/kumbulanit/CKA.git && cd CKA
sudo ./setup.sh          # minikube with three nodes, Kubernetes v1.36 (about 10 minutes the first time)
kubectl get nodes         # minikube, minikube-m02, minikube-m03
```

The steps use those node names, and `minikube ssh -n <node>` for commands on a node. Run `kubectl` as your own user on the server; commands on the control plane's files (`/etc/kubernetes/manifests`, the kubelet) go through `minikube ssh` with `sudo`. The outputs were recorded in Desired Labs, whose cluster is set out like minikube's (the API server on port 8443, certificates in `/var/lib/minikube/certs` and `~/.minikube`); its terminal is root on `minikube`, so prompts differ, and addresses and ages on yours will differ too.

## Lab 8.1: App failure: alpha

![The two-tier app of the troubleshooting labs, and where each scenario breaks it](../images/two-tier-app.svg)

*The two-tier app of the troubleshooting labs, and where each scenario breaks it*

### What you will do

A simple 2 tier application is deployed in the **alpha** namespace. It must show a green page
that says *DATABASE CONNECTION SUCCESSFUL*. Open it from the terminal:

```
curl http://$(minikube ip):30081
```

It is currently failed. Troubleshoot and fix it. Stick to this architecture (the same names
and ports); you may edit, delete or recreate objects as needed:

| Object | Details |
| --- | --- |
| pod **mysql** (label `name=mysql`) | database, port 3306, `MYSQL_ROOT_PASSWORD=paswrd` |
| service **mysql-service** | ClusterIP, port 3306 → pod port 3306, selects `name=mysql` |
| deployment **webapp-mysql** | web app, port 8080, env `DB_Host=mysql-service`, `DB_User=root`, `DB_Password=paswrd` |
| service **web-service** | NodePort, port 8080, nodePort **30081**, selects `name=webapp-mysql` |

The lecture notes: [02-application-failure.md](https://github.com/kumbulanit/CKA/blob/main/08-troubleshooting/02-application-failure.md).

### Step by step

**Step 1.** Lists the Services in the namespace `alpha`.

```bash
kubectl get service -n alpha
```

You should see something like:

```text
NAME          TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
mysql         ClusterIP   10.96.187.209   <none>        3306/TCP         0s
web-service   NodePort    10.96.133.189   <none>        8080:30081/TCP   0s
```

**Step 2.** Shows the Service `mysql` in the namespace `alpha` as YAML, as the API server stores it.

```bash
kubectl get service -n alpha mysql -o yaml > service.yaml
```

It prints nothing when it works.

**Step 3.** Edits `service.yaml`: `name: mysql` becomes `name: mysql-service`. In vi: change metadata.name to mysql-service.

```bash
sed -i 's/^  name: mysql$/  name: mysql-service/' service.yaml
```

It prints nothing when it works.

**Step 4.** Deletes the Service `mysql` in the namespace `alpha`.

```bash
kubectl delete svc mysql -n alpha
```

You should see something like:

```text
service "mysql" deleted from alpha namespace
```

**Step 5.** Creates the objects in `service.yaml`.

```bash
kubectl create -f service.yaml
```

You should see something like:

```text
service/mysql-service created
```

### If you see something else

- The check says: _The web app connects to its database as `mysql-service`, and there is no service with that name in alpha._
- Read the error on the page. "Name does not resolve" or "Unknown MySQL server host" means the app cannot find a service with the name it uses.
- `kubectl get service -n alpha`: compare the names with the architecture. You cannot rename an object with `kubectl edit`; save it with `-o yaml`, change the name, delete and create it again.
- Start every application failure by opening the app (`curl http://$(minikube ip):30081`). Its error message tells you which link in the chain is broken.

### Why it works

**Why it works.** The web app finds its database by DNS name: `DB_Host=mysql-service`. CoreDNS only answers for services that exist, so a service called `mysql` gives "Name does not resolve" (or "Unknown MySQL server host"). Kubernetes cannot rename an object, which is why the fix is: save it (`-o yaml`), change `metadata.name`, delete the old one and create the new one.

**Method:** work from the outside in, following the request: web-service → webapp pod → mysql-service → mysql pod. The app's own error tells you which hop fails.

---

## Lab 8.2: App failure: beta

### What you will do

The same 2 tier application is deployed in the **beta** namespace (same architecture as 8.1;
`curl http://$(minikube ip):30081`). It is currently failed. Troubleshoot and fix it.

### Step by step

**Step 1.** Prints one field of the pod `mysql` in the namespace `beta`.

```bash
kubectl get po -n beta mysql -o jsonpath='{.spec.containers[*].ports[*].containerPort}'
```

You should see something like:

```text
3306@@PB-STEP 1@@
service/mysql-service edited
```

**Step 2.** Edits the Service `mysql-service`, `beta` with a scripted editor: `targetPort: 8080` becomes `targetPort: 3306`. Kubectl edit service mysql-service -n beta   -> change targetPort: 8080 to targetPort: 3306.

```bash
KUBE_EDITOR="sed -i 's/targetPort: 8080/targetPort: 3306/'" kubectl edit service mysql-service -n beta
```

### If you see something else

- The check says: _mysql-service still sends traffic to the wrong port on the mysql pod._
- "Can't connect to MySQL server on 'mysql-service:3306'" means the service exists, so look at its ports.
- `kubectl get po -n beta mysql -o jsonpath='{.spec.containers[*].ports[*].containerPort}'` shows the port the database listens on; `targetPort` must match it.

### Why it works

**Why it works.** A service has two ports: `port` (where clients connect, 3306) and `targetPort` (where it forwards to on the pod). MySQL listens on 3306, so forwarding to 8080 reaches nothing: "Can't connect to MySQL server". The pod's `containerPort` (or the database's documentation) tells you the right `targetPort`.

---

## Lab 8.3: App failure: gamma

### What you will do

The same 2 tier application is deployed in the **gamma** namespace (same architecture as 8.1;
`curl http://$(minikube ip):30081`). It is currently failed or unresponsive. Troubleshoot and fix it.

### Step by step

**Step 1.** Lists the pods in the namespace `gamma` with their labels.

```bash
kubectl get pods -n gamma --show-labels
```

You should see something like:

```text
NAME                            READY   STATUS              RESTARTS   AGE   LABELS
mysql                           0/1     ContainerCreating   0          1s    name=mysql
webapp-mysql-59699d9cb7-sd99s   0/1     ContainerCreating   0          1s    name=webapp-mysql,pod-template-hash=59699d9cb7
```

**Step 2.** Edits the Service `mysql-service`, `gamma` with a scripted editor: `name: sql00001` becomes `name: mysql`. Kubectl edit service mysql-service -n gamma   -> change the selector name: sql00001 to name: mysql.

```bash
KUBE_EDITOR="sed -i 's/name: sql00001/name: mysql/'" kubectl edit service mysql-service -n gamma
```

You should see something like:

```text
service/mysql-service edited
```

### If you see something else

- The check says: _mysql-service's selector still does not match the mysql pod's labels._
- Name and ports look right? Then check whether the service has any endpoints (`kubectl describe service mysql-service -n gamma`).
- `kubectl get pods -n gamma --show-labels` shows the pod labels; the service's `selector` must match them.

### Why it works

**Why it works.** A service finds its pods by label. With the selector `name: sql00001` it matches no pod, so it has no endpoints and connections are refused. `kubectl describe service` shows `Endpoints: <none>`; `kubectl get pods --show-labels` shows the label to use (ignore `pod-template-hash`, which Kubernetes adds itself).

---

## Lab 8.4: App failure: delta

### What you will do

The same 2 tier application is deployed in the **delta** namespace (same architecture as 8.1;
`curl http://$(minikube ip):30081`). It is currently failed. Troubleshoot and fix it.

### Step by step

**Step 1.** Edits the Deployment `webapp-mysql`, `delta` with a scripted editor: `value: sql-user` becomes `value: root`. Kubectl edit deployment webapp-mysql -n delta   -> set DB_User to root.

```bash
KUBE_EDITOR="sed -i 's/value: sql-user/value: root/'" kubectl edit deployment webapp-mysql -n delta
```

You should see something like:

```text
deployment.apps/webapp-mysql edited
```

**Step 2.** Waits until the rollout of the Deployment `webapp-mysql` has finished.

```bash
kubectl rollout status deployment webapp-mysql -n delta
```

You should see something like:

```text
Waiting for deployment "webapp-mysql" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "webapp-mysql" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "webapp-mysql" rollout to finish: 1 old replicas are pending termination...
deployment "webapp-mysql" successfully rolled out
```

### If you see something else

- The check says: _webapp-mysql still logs in to the database with the wrong user._
- "Access denied for user 'sql-user'": the app reaches the database but uses the wrong account. Compare with the architecture.
- The account comes from the deployment's environment: `kubectl edit deployment webapp-mysql -n delta`.

### Why it works

**Why it works.** "Access denied for user 'sql-user'" means the network path works and the database answers, but rejects the login. The credentials come from the deployment's environment variables. Editing the deployment's pod template starts a rollout: new pods with `DB_User=root` replace the old ones.

---

## Lab 8.5: App failure: epsilon (two issues)

### What you will do

The same 2 tier application is deployed in the **epsilon** namespace (same architecture as 8.1;
`curl http://$(minikube ip):30081`). It is currently failed. There are **two** issues. Troubleshoot and fix them.

### Step by step

**Step 1.** Edits the Deployment `webapp-mysql`, `epsilon` with a scripted editor: `value: sql-user` becomes `value: root`.

```bash
KUBE_EDITOR="sed -i 's/value: sql-user/value: root/'" kubectl edit deployment webapp-mysql -n epsilon
```

You should see something like:

```text
deployment.apps/webapp-mysql edited
```

**Step 2.** Shows the pod `mysql` in the namespace `epsilon` as YAML, as the API server stores it.

```bash
kubectl get pod -n epsilon mysql -o yaml > mysql.yaml
```

It prints nothing when it works.

**Step 3.** Edits `mysql.yaml`: `value: passwooooorrddd` becomes `value: paswrd`. In vi: fix MYSQL_ROOT_PASSWORD.

```bash
sed -i 's/value: passwooooorrddd/value: paswrd/' mysql.yaml
```

It prints nothing when it works.

**Step 4.** Replaces the objects in `mysql.yaml` with the edited file (deletes and creates it again).

```bash
kubectl replace --force -f mysql.yaml
```

You should see something like:

```text
pod "mysql" deleted from epsilon namespace
pod/mysql replaced
```

**Step 5.** Waits until the pod `mysql` is Ready in the namespace `epsilon`.

```bash
kubectl wait -n epsilon --for=condition=Ready pod/mysql --timeout=180s
```

You should see something like:

```text
pod/mysql condition met
```

### If you see something else

- The check says: _webapp-mysql still logs in to the database with the wrong user._
- The check says: _The database's root password is still not the one the app uses._
- Fix the user first, as in delta. If it still fails, the database itself has a different password than the architecture says.
- You cannot change a standalone pod's environment with `kubectl edit`. Save it with `kubectl get pod -n epsilon mysql -o yaml > mysql.yaml`, fix it, and `kubectl replace --force -f mysql.yaml`.
- A pod's environment cannot be changed in place. Save it as YAML, fix it, and recreate it with `kubectl replace --force -f`.

### Why it works

**Why it works.** Two things must agree: the user and password the app sends, and the password the database was started with (`MYSQL_ROOT_PASSWORD`). The app side is fixed in the deployment. The database is a standalone pod, and a pod's spec (its environment included) cannot be edited in place, so `kubectl replace --force -f` deletes it and creates it again from the fixed file. The database initialises with the new password because it starts with empty storage.

---

## Lab 8.6: App failure: zeta (three issues)

### What you will do

The same 2 tier application is deployed in the **zeta** namespace (same architecture as 8.1).
The app should be reachable at `curl http://$(minikube ip):30081`. It is currently failed. There are
**three** issues. Troubleshoot and fix them.

### Step by step

**Step 1.** Lists the Services in the namespace `zeta`.

```bash
kubectl get service -n zeta
```

You should see something like:

```text
NAME            TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
mysql-service   ClusterIP   10.96.106.105   <none>        3306/TCP         1s
web-service     NodePort    10.96.195.13    <none>        8080:30088/TCP   1s
```

**Step 2.** Edits the Service `zeta`, `web-service` with a scripted editor: `nodePort: 30088` becomes `nodePort: 30081`. Kubectl edit service -n zeta web-service   -> set nodePort to 30081.

```bash
KUBE_EDITOR="sed -i 's/nodePort: 30088/nodePort: 30081/'" kubectl edit service -n zeta web-service
```

You should see something like:

```text
service/web-service edited
```

**Step 3.** Edits the Deployment `webapp-mysql`, `zeta` with a scripted editor: `value: sql-user` becomes `value: root`.

```bash
KUBE_EDITOR="sed -i 's/value: sql-user/value: root/'" kubectl edit deployment webapp-mysql -n zeta
```

You should see something like:

```text
deployment.apps/webapp-mysql edited
```

**Step 4.** Shows the pod `mysql` in the namespace `zeta` as YAML, as the API server stores it.

```bash
kubectl get pod -n zeta mysql -o yaml > mysql.yaml
```

It prints nothing when it works.

**Step 5.** Edits `mysql.yaml`: `value: passwooooorrddd` becomes `value: paswrd`.

```bash
sed -i 's/value: passwooooorrddd/value: paswrd/' mysql.yaml
```

It prints nothing when it works.

**Step 6.** Replaces the objects in `mysql.yaml` with the edited file (deletes and creates it again).

```bash
kubectl replace --force -f mysql.yaml
```

You should see something like:

```text
pod "mysql" deleted from zeta namespace
pod/mysql replaced
```

**Step 7.** Waits until the pod `mysql` is Ready in the namespace `zeta`.

```bash
kubectl wait -n zeta --for=condition=Ready pod/mysql --timeout=180s
```

You should see something like:

```text
pod/mysql condition met
```

### If you see something else

- The check says: _Nothing answers on node port 30081. Check web-service's nodePort against the architecture._
- The check says: _webapp-mysql still logs in to the database with the wrong user._
- The check says: _The database's root password is still not the one the app uses._
- If nothing answers on 30081, start at the outside: `kubectl get service -n zeta` shows which node port web-service really uses.
- Then fix the two database issues exactly as in epsilon.

### Why it works

**Why it works.** Nothing answered on 30081 because web-service listened on node port 30088: a NodePort service opens exactly the `nodePort` in its spec on every node. Once traffic arrives, the two database issues from epsilon show up one after the other. Fixing problems in the order you meet them, from the outside in, keeps each step clear.

---

## Lab 8.7: The scheduler is down

### What you will do

The cluster is broken. The deployment **app** in the default namespace has a pod that never
starts. Find out why and fix the cluster, so the pod of **app** runs.

The lecture notes: [04-control-plane-failure.md](https://github.com/kumbulanit/CKA/blob/main/08-troubleshooting/04-control-plane-failure.md).

### Step by step

**Step 1.** Lists the pods in the namespace `kube-system`.

```bash
kubectl get pods -n kube-system
```

You should see something like:

```text
NAME                               READY   STATUS              RESTARTS   AGE
coredns-589f44dc88-7hk9j           1/1     Running             0          7m20s
coredns-589f44dc88-srr7n           1/1     Running             0          7m20s
etcd-minikube                      1/1     Running             0          6m22s
kindnet-td8zm                      1/1     Running             0          7m4s
kindnet-v662g                      1/1     Running             0          7m3s
kindnet-wbdg6                      1/1     Running             0          7m3s
kube-apiserver-minikube            1/1     Running             0          6m19s
kube-controller-manager-minikube   1/1     Running             0          6m22s
kube-proxy-5hbtq                   1/1     Running             0          7m20s
kube-proxy-dmmmd                   1/1     Running             0          7m18s
kube-proxy-dpwdd                   1/1     Running             0          7m18s
kube-scheduler-minikube            0/1     ContainerCreating   0          1s
```

**Step 2.** On the node `minikube`, not on the server: edits `/etc/kubernetes/manifests/kube-scheduler.yaml`: `kube-schedulerrrr` becomes `kube-scheduler`.

```bash
minikube ssh -- "sudo sed -i 's/kube-schedulerrrr/kube-scheduler/g' /etc/kubernetes/manifests/kube-scheduler.yaml"
```

It prints nothing when it works.

### If you see something else

- The check says: _The kube-scheduler manifest still has a wrong setting._
- The check says: _The scheduler is not running yet. It can take half a minute after the manifest is fixed._
- The check says: _app's pod is not running yet._
- `kubectl get pods` shows app's pod `Pending`; `kubectl get pods -n kube-system` shows which control plane component is not running.
- kubeadm runs the control plane as static pods from `/etc/kubernetes/manifests/`. `kubectl -n kube-system describe pod kube-scheduler-minikube` shows why it fails to start.

### Why it works

**Why it works.** A pod stays `Pending` until the scheduler assigns it a node. On a kubeadm cluster the scheduler is a static pod: the kubelet on minikube runs whatever is in `/etc/kubernetes/manifests/`, and restarts it whenever the file changes. The manifest's command said `kube-schedulerrrr`, a program that does not exist, so the container could never start. Fixing the file is enough; the kubelet notices within seconds.

**In the exam:** `kubectl get pods -n kube-system` first. If the API server itself is down, use `crictl ps -a` and `crictl logs` on the control plane node.

---

## Lab 8.8: Scaling does not happen

### What you will do

Scale the deployment **app** to **2** pods. Then make sure 2 pods of **app** are really running:
if they are not, find out why and fix the cluster.

(Do 8.7 first: app needs a working scheduler.)

### Step by step

**Step 1.** Sets the Deployment `app` to 2 replicas.

```bash
kubectl scale deploy app --replicas=2
```

You should see something like:

```text
deployment.apps/app scaled
```

**Step 2.** Lists the pods in the namespace `kube-system`.

```bash
kubectl get pods -n kube-system
```

You should see something like:

```text
NAME                               READY   STATUS    RESTARTS      AGE
coredns-589f44dc88-7hk9j           1/1     Running   0             8m3s
coredns-589f44dc88-srr7n           1/1     Running   0             8m3s
etcd-minikube                      1/1     Running   0             7m5s
kindnet-td8zm                      1/1     Running   0             7m47s
kindnet-v662g                      1/1     Running   0             7m46s
kindnet-wbdg6                      1/1     Running   0             7m46s
kube-apiserver-minikube            1/1     Running   0             7m2s
kube-controller-manager-minikube   0/1     Running   1 (2s ago)    2s
kube-proxy-5hbtq                   1/1     Running   0             8m3s
kube-proxy-dmmmd                   1/1     Running   0             8m1s
kube-proxy-dpwdd                   1/1     Running   0             8m1s
kube-scheduler-minikube            1/1     Running   2 (58s ago)   29s
```

**Step 3.** On the node `minikube`, not on the server: edits `/etc/kubernetes/manifests/kube-controller-manager.yaml`: `controller-manager-XXXX.conf` becomes `controller-manager.conf`.

```bash
minikube ssh -- "sudo sed -i 's/controller-manager-XXXX.conf/controller-manager.conf/' /etc/kubernetes/manifests/kube-controller-manager.yaml"
```

It prints nothing when it works.

### If you see something else

- The check says: _The deployment app is not scaled to 2._
- The check says: _The kube-controller-manager manifest still has a wrong setting._
- The check says: _The controller manager is not running yet._
- The check says: _app does not have 2 ready pods yet._
- The deployment says 2 replicas but no new pod appears. Which component creates pods for a ReplicaSet?
- `kubectl -n kube-system logs kube-controller-manager-minikube` (or `crictl logs` on the control-plane node if the pod keeps restarting) shows which file it cannot find.

### Why it works

**Why it works.** `kubectl scale` only changes `spec.replicas`. The ReplicaSet controller, inside kube-controller-manager, is what creates the extra pods. The controller manager was told to use `/etc/kubernetes/controller-manager-XXXX.conf`, which does not exist, so it could not reach the API server and nothing acted on the new replica count.

---

## Lab 8.9: Scaling stops again

### What you will do

Something is wrong with scaling again. Scale the deployment **app** to **3** pods, and make sure
3 pods of **app** are really running.

### Step by step

**Step 1.** Sets the Deployment `app` to 3 replicas.

```bash
kubectl scale deploy app --replicas=3
```

You should see something like:

```text
deployment.apps/app scaled
```

**Step 2.** Lists the pods in the namespace `kube-system`.

```bash
kubectl get pods -n kube-system
```

You should see something like:

```text
NAME                               READY   STATUS    RESTARTS       AGE
coredns-589f44dc88-7hk9j           1/1     Running   0              8m54s
coredns-589f44dc88-srr7n           1/1     Running   0              8m54s
etcd-minikube                      1/1     Running   0              7m56s
kindnet-td8zm                      1/1     Running   0              8m38s
kindnet-v662g                      1/1     Running   0              8m37s
kindnet-wbdg6                      1/1     Running   0              8m37s
kube-apiserver-minikube            1/1     Running   0              7m53s
kube-controller-manager-minikube   0/1     Running   0              1s
kube-proxy-5hbtq                   1/1     Running   0              8m54s
kube-proxy-dmmmd                   1/1     Running   0              8m52s
kube-proxy-dpwdd                   1/1     Running   0              8m52s
kube-scheduler-minikube            1/1     Running   2 (109s ago)   80s
```

**Step 3.** On the node `minikube`, not on the server: edits `/etc/kubernetes/manifests/kube-controller-manager.yaml`: `WRONG-CERTS-DIRECTORY` becomes `certs`.

```bash
minikube ssh -- "sudo sed -i 's/WRONG-CERTS-DIRECTORY/certs/' /etc/kubernetes/manifests/kube-controller-manager.yaml"
```

It prints nothing when it works.

### If you see something else

- The check says: _The deployment app is not scaled to 3._
- The check says: _The kube-controller-manager manifest still has a wrong setting._
- The check says: _The controller manager is not running yet._
- The check says: _app does not have 3 ready pods yet._
- The controller manager is failing again, for a different reason. Its logs say it cannot read a certificate.
- Compare the `volumes` in `/etc/kubernetes/manifests/kube-controller-manager.yaml` with the files in `/etc/kubernetes/`.

### Why it works

**Why it works.** The controller manager reads the cluster CA and signing keys from `/var/lib/minikube/certs` (`/etc/kubernetes/pki` on a kubeadm cluster), mounted into its pod through a `hostPath` volume. The volume pointed at `/var/lib/minikube/WRONG-CERTS-DIRECTORY`, so inside the container the certificates folder was empty and it failed at start. The flags were right; the volume behind them was wrong, which is why it pays to read the whole manifest, `volumes` included.

---

## Lab 8.10: minikube-m02 is NotReady

### What you will do

Fix the broken cluster: **minikube-m02** is not working. It can take up to a minute before
`kubectl get nodes` shows it as `NotReady`.

The lecture notes: [07-worker-node-failure.md](https://github.com/kumbulanit/CKA/blob/main/08-troubleshooting/07-worker-node-failure.md).

### Step by step

**Step 1.** Lists the nodes.

```bash
kubectl get nodes
```

You should see something like:

```text
NAME           STATUS   ROLES           AGE     VERSION
minikube       Ready    control-plane   9m39s   v1.36.4
minikube-m02   Ready    worker          9m28s   v1.36.4
minikube-m03   Ready    worker          9m28s   v1.36.4
```

**Step 2.** On the node `minikube-m02`, not on the server: shows the state of kubelet.

```bash
minikube ssh -n minikube-m02 -- sudo systemctl status kubelet --no-pager
```

You should see something like:

```text
○ kubelet.service - kubelet: The Kubernetes Node Agent
     Loaded: loaded (/etc/systemd/system/kubelet.service; enabled; preset: enabled)
    Drop-In: /etc/systemd/system/kubelet.service.d
             └─10-kubeadm.conf, 11-kind.conf
     Active: inactive (dead) since Wed 2026-10-28 13:42:40 UTC; 475ms ago
   Duration: 8min 30.107s
 Invocation: 7c44c6a9832245a685c4c82638aa96ab
       Docs: http://kubernetes.io/docs/
    Process: 827 ExecStartPre=/bin/sh -euc if [ -f /sys/fs/cgroup/cgroup.controllers ]; then /kind/bin/create-kubelet-cgroup-v2.sh; fi (code=exited, status=0/SUCCESS)
    Process: 835 ExecStartPre=/bin/sh -euc if [ ! -f /sys/fs/cgroup/cgroup.controllers ] && [ ! -d /sys/fs/cgroup/systemd/kubelet ]; then mkdir -p /sys/fs/cgroup/systemd/kubelet; fi (code=exited, status=0/SUCCESS)
    Process: 837 ExecStart=/usr/bin/kubelet $KUBELET_KUBECONFIG_ARGS $KUBELET_CONFIG_ARGS $KUBELET_KUBEADM_ARGS $KUBELET_EXTRA_ARGS (code=exited, status=0/SUCCESS)
   Main PID: 837 (code=exited, status=0/SUCCESS)
   Mem peak: 48.3M
        CPU: 10.779s

Oct 28 13:40:09 minikube-m02 kubelet[837]: I1028 13:40:09.892100     837 pod_startup_latency_tracker.go:148] "Observed pod startup duration" pod="zeta/mysql" podStartSLOduration=0.89161848 podStartE2EDuration="891.61848ms" totalImagesPullingTime="0s" totalInitContainerRuntime="0s" isStatefulPod=false podCreationTimestamp="2026-10-28 13:40:09 +0000 UTC" imagePullSessionsCount=0 imagePullSessionsStartsCount=0 observedRunningTime="2026-10-28 13:40:09.891229725 +0000 UTC m=+359.744547630" watchObservedRunningTime="2026-10-28 13:40:09.89161848 +0000 UTC m=+359.744936384"
Oct 28 13:40:10 minikube-m02 kubelet[837]: I1028 13:40:10.325658     837 kubelet_volumes.go:161] "Cleaned up orphaned pod volumes dir" podUID="7127b8ed-4507-414a-b898-f23985ee2bbb" path="/var/lib/kubelet/pods/7127b8ed-4507-414a-b898-f23985ee2bbb/volumes"
Oct 28 13:41:44 minikube-m02 kubelet[837]: I1028 13:41:44.648311     837 reconciler_common.go:251] "operationExecutor.VerifyControllerAttachedVolume started for volume \"kube-api-access-8vcsz\" (UniqueName: \"kubernetes.io/projected/649a47ac-ceb3-4260-968f-4ff59da3e11e-kube-api-access-8vcsz\") pod \"app-78cc97bc89-2s7vg\" (UID: \"649a47ac-ceb3-4260-968f-4ff59da3e11e\") " pod="default/app-78cc97bc89-2s7vg"
… (7 more lines)
```

**Step 3.** On the node `minikube-m02`, not on the server: starts kubelet.

```bash
minikube ssh -n minikube-m02 -- sudo systemctl start kubelet
```

It prints nothing when it works.

**Step 4.** Waits until the node `minikube-m02` is Ready.

```bash
kubectl wait --for=condition=Ready node/minikube-m02 --timeout=90s
```

You should see something like:

```text
node/minikube-m02 condition met
```

### If you see something else

- The check says: _The kubelet on minikube-m02 is not running._
- The check says: _minikube-m02 is not Ready yet. Give it a few seconds and check again._
- `NotReady` usually means the API server lost contact with the node's kubelet. Log in with `minikube ssh -n minikube-m02`.
- `systemctl status kubelet` on minikube-m02 shows whether it is running.

### Why it works

**Why it works.** A node is `Ready` while its kubelet keeps reporting to the API server. With the kubelet stopped, the reports stop, and after about 40 seconds the node controller marks the node `NotReady`. Starting the kubelet (`systemctl start kubelet`) brings it back. `systemctl enable kubelet` makes sure it also starts after a reboot.

---

## Lab 8.11: minikube-m02 is broken again

### What you will do

The cluster is broken again: **minikube-m02** is not working. Investigate and fix the issue.

### Step by step

**Step 1.** On the node `minikube-m02`, not on the server: shows the log of the `kubelet` service.

```bash
minikube ssh -n minikube-m02 -- sudo journalctl -u kubelet --no-pager -n 5
```

You should see something like:

```text
Oct 28 13:42:42 minikube-m02 kubelet[4852]: I1028 13:42:42.286132    4852 server.go:985] "Client rotation is on, will bootstrap in background"
Oct 28 13:42:42 minikube-m02 kubelet[4852]: I1028 13:42:42.287006    4852 certificate_store.go:147] "Loading cert/key pair from a file" filePath="/var/lib/kubelet/pki/kubelet-client-current.pem"
Oct 28 13:42:42 minikube-m02 kubelet[4852]: E1028 13:42:42.287474    4852 run.go:72] "command failed" err="failed to run Kubelet: open /var/lib/minikube/certs/WRONG-CA-FILE.crt: no such file or directory"
Oct 28 13:42:42 minikube-m02 systemd[1]: kubelet.service: Main process exited, code=exited, status=1/FAILURE
Oct 28 13:42:42 minikube-m02 systemd[1]: kubelet.service: Failed with result 'exit-code'.
```

**Step 2.** On the node `minikube-m02`, not on the server: lists the files in `/var/lib/minikube/certs`.

```bash
minikube ssh -n minikube-m02 -- sudo ls -l /var/lib/minikube/certs
```

You should see something like:

```text
lrwxrwxrwx 1 root root 19 Oct 28 12:45 /var/lib/minikube/certs -> /etc/kubernetes/pki
```

**Step 3.** On the node `minikube-m02`, not on the server: runs systemctl on kubelet.

```bash
minikube ssh -n minikube-m02 -- sudo systemctl cat kubelet
```

You should see something like:

```text
# /etc/systemd/system/kubelet.service
# slightly modified from:
# https://github.com/kubernetes/kubernetes/blob/ba8fcafaf8c502a454acd86b728c857932555315/build/debs/kubelet.service
[Unit]
Description=kubelet: The Kubernetes Node Agent
Documentation=http://kubernetes.io/docs/
# NOTE: kind deviates from upstream here to avoid crashlooping
# This does *not* support altering the kubelet config path though.
# We intend to upstream this change but first need to solve the upstream
# Packaging problem (all kubernetes versions use the same files out of tree).
ConditionPathExists=/var/lib/kubelet/config.yaml

[Service]
ExecStart=/usr/bin/kubelet
Restart=always
StartLimitInterval=0
# NOTE: kind deviates from upstream here with a lower RestartSec
RestartSec=1s
… (32 more lines)
```

**Step 4.** On the node `minikube-m02`, not on the server: edits `/var/lib/kubelet/config.yaml`: `WRONG-CA-FILE.crt` becomes `ca.crt`.

```bash
minikube ssh -n minikube-m02 -- "sudo sed -i 's/WRONG-CA-FILE.crt/ca.crt/g' /var/lib/kubelet/config.yaml"
```

It prints nothing when it works.

**Step 5.** Waits until the node `minikube-m02` is Ready.

```bash
kubectl wait --for=condition=Ready node/minikube-m02 --timeout=90s
```

You should see something like:

```text
node/minikube-m02 condition met
```

### If you see something else

- The check says: _The kubelet on minikube-m02 still points at a CA file that does not exist._
- The check says: _The kubelet on minikube-m02 is not running steadily yet._
- The check says: _minikube-m02 is not Ready yet. Give it a few seconds and check again._
- On minikube-m02, `systemctl status kubelet` shows it restarting; `journalctl -u kubelet` shows why.
- `systemctl cat kubelet` shows which configuration file the kubelet reads (`--config=`).
- `journalctl -u kubelet` on minikube-m02 shows the exact error; search it for `failed` or `error`.

### Why it works

**Why it works.** The kubelet's settings live in `/var/lib/kubelet/config.yaml` (from `--config=` in `systemctl cat kubelet`). `clientCAFile` is the CA it uses to check who is calling it; with a file that does not exist it exits at start, and systemd restarts it every few seconds (`activating (auto-restart)`). `journalctl -u kubelet` names the missing file. Once the file is fixed, the next automatic restart succeeds.

---

## Lab 8.12: minikube-m02 is broken a third time

### What you will do

The cluster is broken again: **minikube-m02** goes `NotReady` (it can take up to a minute). Investigate and fix the issue.

### Step by step

**Step 1.** On the node `minikube-m02`, not on the server: shows the log of the `kubelet` service.

```bash
minikube ssh -n minikube-m02 -- sudo journalctl -u kubelet --no-pager -n 5
```

You should see something like:

```text
Oct 28 13:43:25 minikube-m02 kubelet[5047]: I1028 13:43:25.138167    5047 container_log_manager.go:146] "Initializing container log rotate workers" workers=1 monitorPeriod="10s"
Oct 28 13:43:25 minikube-m02 kubelet[5047]: I1028 13:43:25.138404    5047 plugin_manager.go:121] "Starting Kubelet Plugin Manager"
Oct 28 13:43:25 minikube-m02 kubelet[5047]: E1028 13:43:25.139618    5047 eviction_manager.go:272] "eviction manager: failed to check if we have separate container filesystem. Ignoring." err="no imagefs label for configured runtime"
Oct 28 13:43:25 minikube-m02 kubelet[5047]: E1028 13:43:25.139669    5047 eviction_manager.go:297] "Eviction manager: failed to get summary stats" err="failed to get node info: node \"minikube-m02\" not found"
Oct 28 13:43:25 minikube-m02 kubelet[5047]: E1028 13:43:25.168551    5047 kubelet.go:3516] "Unable to register mirror pod because node is not registered yet" err="node \"minikube-m02\" not found" node="minikube-m02"
```

**Step 2.** On the node `minikube-m02`, not on the server: edits `/etc/kubernetes/kubelet.conf`: `8553` becomes `8443`.

```bash
minikube ssh -n minikube-m02 -- "sudo sed -i 's/8553/8443/g' /etc/kubernetes/kubelet.conf"
```

It prints nothing when it works.

**Step 3.** On the node `minikube-m02`, not on the server: restarts kubelet.

```bash
minikube ssh -n minikube-m02 -- sudo systemctl restart kubelet
```

It prints nothing when it works.

**Step 4.** Waits until the node `minikube-m02` is Ready.

```bash
kubectl wait --for=condition=Ready node/minikube-m02 --timeout=90s
```

You should see something like:

```text
node/minikube-m02 condition met
```

### If you see something else

- The check says: _The kubelet on minikube-m02 still connects to the wrong API server port._
- The check says: _minikube-m02 is not Ready yet. Did you restart the kubelet after fixing its kubeconfig?_
- This time the kubelet is `active (running)`. Its log says it cannot register the node: look at the address it uses.
- The kubelet finds the API server through its kubeconfig, `--kubeconfig=/etc/kubernetes/kubelet.conf` (see `systemctl cat kubelet`). On minikube the API server listens on port 8443.
- A running kubelet only reads its kubeconfig when it starts. Run `systemctl restart kubelet` on minikube-m02 after the fix.

### Why it works

**Why it works.** The kubelet reaches the API server through its own kubeconfig, `/etc/kubernetes/kubelet.conf`. With the server address on port 8553 the kubelet runs but cannot register or report, so the node goes `NotReady` even though `systemctl status kubelet` looks fine. On minikube the API server listens on 8443 (6443 on a kubeadm cluster). Unlike a crash-looping kubelet, a running one only rereads its kubeconfig on restart.

---

## Lab 8.13: Services stopped working

![Inside the cluster: DNS finds the Service, kube-proxy picks a pod, the CNI carries the packet](../images/cluster-network.svg)

*Inside the cluster: DNS finds the Service, kube-proxy picks a pod, the CNI carries the packet*

### What you will do

The 2 tier application is deployed in the **triton** namespace (same architecture as 8.1;
`curl http://$(minikube ip):30081`). It does not work. Make sure all the cluster's components work, and
that the app shows its green page.

The repository's notes: [10-practice-test-troubleshoot-network.md](https://github.com/kumbulanit/CKA/blob/main/08-troubleshooting/10-practice-test-troubleshoot-network.md) (Test 2).

### Step by step

**Step 1.** Lists the pods in every namespace.

```bash
kubectl get pods -A
```

You should see something like:

```text
NAMESPACE            NAME                                      READY   STATUS              RESTARTS        AGE
default              app-78cc97bc89-2s7vg                      1/1     Running             0               2m36s
default              app-78cc97bc89-gbrjf                      1/1     Running             0               3m51s
default              app-78cc97bc89-kgbfm                      1/1     Running             0               104s
kube-system          coredns-589f44dc88-7hk9j                  1/1     Running             0               11m
kube-system          coredns-589f44dc88-srr7n                  1/1     Running             0               11m
kube-system          etcd-minikube                             1/1     Running             0               10m
kube-system          kindnet-td8zm                             1/1     Running             0               10m
kube-system          kindnet-v662g                             1/1     Running             0               10m
kube-system          kindnet-wbdg6                             1/1     Running             0               10m
kube-system          kube-apiserver-minikube                   1/1     Running             0               10m
kube-system          kube-controller-manager-minikube          1/1     Running             1 (2m31s ago)   2m3s
kube-system          kube-proxy-kdr62                          0/1     Error               3 (38s ago)     52s
kube-system          kube-proxy-mb8sb                          0/1     Error               3 (37s ago)     54s
kube-system          kube-proxy-q6glb                          0/1     Error               3 (39s ago)     53s
kube-system          kube-scheduler-minikube                   1/1     Running             2 (4m5s ago)    3m36s
local-path-storage   local-path-provisioner-56c4685b7c-r8t2s   1/1     Running             0               11m
triton               mysql                                     0/1     ContainerCreating   0               1s
triton               webapp-mysql-59699d9cb7-6bbz2             0/1     ContainerCreating   0               1s
```

**Step 2.** Prints the logs of it.

```bash
kubectl -n kube-system logs -l k8s-app=kube-proxy --tail=3
```

You should see something like:

```text
E1028 13:44:09.758979       1 run.go:72] "command failed" err="failed complete: open /var/lib/kube-proxy/configuration.conf: no such file or directory"
E1028 13:44:11.449084       1 run.go:72] "command failed" err="failed complete: open /var/lib/kube-proxy/configuration.conf: no such file or directory"
E1028 13:44:06.956035       1 run.go:72] "command failed" err="failed complete: open /var/lib/kube-proxy/configuration.conf: no such file or directory"
```

**Step 3.** Shows the details of the ConfigMap `kube-proxy` in the namespace `kube-system`, with its recent events at the bottom.

```bash
kubectl describe cm -n kube-system kube-proxy | grep -E '^(config|kubeconfig)'
```

You should see something like:

```text
config.conf:
configSyncPeriod: 0s
kubeconfig.conf:
```

**Step 4.** Edits the DaemonSet `kube-system`, `kube-proxy` with a scripted editor: `/var/lib/kube-proxy/configuration.conf` becomes `/var/lib/kube-proxy/config.conf`. Kubectl edit ds -n kube-system kube-proxy   -> --config=/var/lib/kube-proxy/config.conf.

```bash
KUBE_EDITOR="sed -i 's#/var/lib/kube-proxy/configuration.conf#/var/lib/kube-proxy/config.conf#'" kubectl edit ds -n kube-system kube-proxy
```

You should see something like:

```text
daemonset.apps/kube-proxy edited
```

**Step 5.** Waits until the rollout of the DaemonSet `kube-proxy` has finished.

```bash
kubectl -n kube-system rollout status ds/kube-proxy
```

You should see something like:

```text
Waiting for daemon set "kube-proxy" rollout to finish: 0 out of 3 new pods have been updated...
Waiting for daemon set "kube-proxy" rollout to finish: 0 out of 3 new pods have been updated...
Waiting for daemon set "kube-proxy" rollout to finish: 0 of 3 updated pods are available...
Waiting for daemon set "kube-proxy" rollout to finish: 1 of 3 updated pods are available...
Waiting for daemon set "kube-proxy" rollout to finish: 2 of 3 updated pods are available...
daemon set "kube-proxy" successfully rolled out
```

### If you see something else

- The check says: _The kube-proxy DaemonSet still points at a configuration file that does not exist._
- The check says: _The kube-proxy pods are not all running yet._
- `kubectl get pods -A`: one system component keeps crashing. `kubectl -n kube-system logs <its pod>` tells you why.
- The DaemonSet mounts a ConfigMap at `/var/lib/kube-proxy`; `kubectl describe cm -n kube-system kube-proxy` lists the files in it.

### Why it works

**Why it works.** kube-proxy turns services into packet-forwarding rules on every node; without it, new services and node ports do nothing. It runs as a DaemonSet that reads its settings from the `kube-proxy` ConfigMap, mounted at `/var/lib/kube-proxy`. The ConfigMap holds `config.conf` and `kubeconfig.conf`, so `--config=.../configuration.conf` made every kube-proxy pod crash at start. Editing the DaemonSet rolls out fixed pods on all nodes.

---

## Lab 8.14: Pods cannot start

### What you will do

The 2 tier application in **triton** has been redeployed, and now its pods do not start.
Examine the cluster (nodes, then pods in all namespaces), find the problem and fix it, so that
`curl http://$(minikube ip):30081` shows the green page again.

The repository's notes: [10-practice-test-troubleshoot-network.md](https://github.com/kumbulanit/CKA/blob/main/08-troubleshooting/10-practice-test-troubleshoot-network.md) (Test 1).

### Step by step

**Step 1.** Lists the nodes.

```bash
kubectl get nodes
```

You should see something like:

```text
NAME           STATUS   ROLES           AGE   VERSION
minikube       Ready    control-plane   12m   v1.36.4
minikube-m02   Ready    worker          12m   v1.36.4
minikube-m03   Ready    worker          12m   v1.36.4
```

**Step 2.** Lists the pods in every namespace.

```bash
kubectl get pods -A
```

You should see something like:

```text
NAMESPACE            NAME                                      READY   STATUS              RESTARTS        AGE
default              app-78cc97bc89-2s7vg                      1/1     Running             0               3m28s
default              app-78cc97bc89-gbrjf                      1/1     Running             0               4m43s
default              app-78cc97bc89-kgbfm                      1/1     Running             0               2m36s
kube-system          coredns-589f44dc88-7hk9j                  1/1     Running             0               12m
kube-system          coredns-589f44dc88-srr7n                  1/1     Running             0               12m
kube-system          etcd-minikube                             1/1     Running             0               11m
kube-system          kube-apiserver-minikube                   1/1     Running             0               11m
kube-system          kube-controller-manager-minikube          1/1     Running             1 (3m23s ago)   2m55s
kube-system          kube-proxy-7wfck                          1/1     Running             0               51s
kube-system          kube-proxy-sbl47                          1/1     Running             0               51s
kube-system          kube-proxy-tkkc6                          1/1     Running             0               51s
kube-system          kube-scheduler-minikube                   1/1     Running             2 (4m57s ago)   4m28s
local-path-storage   local-path-provisioner-56c4685b7c-r8t2s   1/1     Running             0               12m
triton               mysql                                     0/1     ContainerCreating   0               1s
triton               webapp-mysql-59699d9cb7-9bcpv             0/1     ContainerCreating   0               1s
```

**Step 3.** Creates the objects in `https://raw.githubusercontent.com/projectcalico/calico/v3.33.0/manifests/calico.yaml`, or updates them if they exist.

```bash
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.33.0/manifests/calico.yaml
```

You should see something like:

```text
poddisruptionbudget.policy/calico-kube-controllers created
serviceaccount/calico-kube-controllers created
serviceaccount/calico-node created
serviceaccount/calico-cni-plugin created
configmap/calico-config created
customresourcedefinition.apiextensions.k8s.io/bgpconfigurations.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/bgpfilters.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/bgppeers.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/blockaffinities.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/caliconodestatuses.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/clusterinformations.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/felixconfigurations.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/globalnetworkpolicies.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/globalnetworksets.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/hostendpoints.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/ipamblocks.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/ipamconfigs.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/ipamhandles.crd.projectcalico.org created
… (20 more lines)
```

**Step 4.** Waits until the rollout of the DaemonSet `calico-node` has finished.

```bash
kubectl -n kube-system rollout status ds/calico-node --timeout=180s
```

You should see something like:

```text
Waiting for daemon set "calico-node" rollout to finish: 0 of 3 updated pods are available...
Waiting for daemon set "calico-node" rollout to finish: 1 of 3 updated pods are available...
Waiting for daemon set "calico-node" rollout to finish: 2 of 3 updated pods are available...
daemon set "calico-node" successfully rolled out
```

**Step 5.** Lists the pods in the namespace `triton`.

```bash
kubectl get pods -n triton
```

You should see something like:

```text
NAME                            READY   STATUS              RESTARTS   AGE
mysql                           0/1     ContainerCreating   0          118s
webapp-mysql-59699d9cb7-9bcpv   1/1     Running             0          118s
```

**Step 6.** Restarts every pod of the Deployment `coredns`.

```bash
kubectl -n kube-system rollout restart deployment coredns
```

You should see something like:

```text
deployment.apps/coredns restarted
```

**Step 7.** Waits until the rollout of the Deployment `coredns` has finished.

```bash
kubectl -n kube-system rollout status deployment coredns --timeout=120s
```

You should see something like:

```text
Waiting for deployment spec update to be observed...
Waiting for deployment "coredns" rollout to finish: 1 out of 2 new replicas have been updated...
Waiting for deployment "coredns" rollout to finish: 1 out of 2 new replicas have been updated...
Waiting for deployment "coredns" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "coredns" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "coredns" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "coredns" rollout to finish: 1 of 2 updated replicas are available...
deployment "coredns" successfully rolled out
```

**Step 8.** Sends an HTTP request to `http://…:30081` and prints the answer.

```bash
curl http://$(minikube ip):30081
```

You should see something like:

```text
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   578  100   578    0     0  13493      0 --:--:-- --:--:-- --:--:-- 13761
<!doctype html>
<title>Hello from Flask</title>
<body style="background: #ff3f3f;"></body>
<div style="color: #e4e4e4;
    text-align:  center;
    height: 90px;
    vertical-align:  middle;">

  
    <img src="/static/img/failed.png">
    <!-- <h1> DATABASE CONNECTION FAILED !!</h1> -->
  

  
    <h2> Environment Variables: DB_Host=mysql-service; DB_Database=Not Set; DB_User=root; DB_Password=paswrd; 2003: Can&#39;t connect to MySQL server on &#39;mysql-service:3306&#39; (111 Connection refused) </h2>
… (9 more lines)
```

### If you see something else

- The check says: _Not all nodes are Ready yet. Is a network plugin running on every node?_
- `kubectl describe node minikube-m02` shows why the node is not ready; `kubectl describe pod` on an app pod shows why it cannot start.
- The cluster has no network (CNI) plugin. Install the one from the installation guide, Calico.
- Nodes Ready but the app still cannot find `mysql-service`? CoreDNS started on the old network and kept its old address: `kubectl -n kube-system rollout restart deployment coredns`.

### Why it works

**Why it works.** Kubernetes does not connect pods itself: the container runtime calls a CNI plugin, configured in `/etc/cni/net.d/`, to give each pod an IP address. With no plugin, the nodes report `NetworkReady=false` and go `NotReady`, and new pods cannot start. Installing a network plugin (here Calico) runs an agent on every node that installs its CNI configuration; the nodes become Ready and the pods start.

Pods that were already running keep the addresses the old plugin gave them, and the new plugin does not route those. CoreDNS is one of them, so name lookups such as `mysql-service` time out until it is restarted with `kubectl -n kube-system rollout restart deployment coredns`.

**Note:** this cluster's original plugin was removed for the exercise. On your own kubeadm cluster, the installation guide installs Calico right after `kubeadm init`.

---
