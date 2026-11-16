# Lab 3.3: DNS for service discovery

**The situation:** the backend finds its database with the name `db`. The same name works in `dev`, `uat` and `prod`, and each backend still reaches its own database. How?

**Goal:** see how names are looked up inside the cluster, and reach a Service in another namespace by its full name.

**Outline topic:** 3. Networking: *DNS for service discovery*.

**What you learn:** CoreDNS, the DNS name of a Service, short names and full names, `/etc/resolv.conf` in a pod.

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
cd ~/CKA/scenario-labs/03-networking
kubectl config set-context --current --namespace=dev
```

**What this does:**

- `cd ~/CKA/scenario-labs/03-networking`: Goes to the folder `~/CKA/scenario-labs/03-networking`.
- `kubectl config set-context --current --namespace=dev`: Makes `dev` your working namespace: commands without `-n` now work in `dev`.

**👀 You should see** *(do not paste)*:

```text
Context "minikube" modified.
```

💡 **Tip:** `kubens dev` does the same as the second line (see the shortcuts in [setup, Step 5](../00-setup.md)).

## Step 1: meet the DNS server of the cluster

**📋 Copy and paste into your terminal:**

```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl get service kube-dns -n kube-system
```

**What this does:**

- `kubectl get pods -n kube-system -l k8s-app=kube-dns`: Lists the pods with the label `k8s-app=kube-dns` in the namespace `kube-system`.
- `kubectl get service kube-dns -n kube-system`: Lists the Service `kube-dns` in the namespace `kube-system`.

**👀 You should see** the CoreDNS pod, and its Service with the address `10.96.0.10` *(do not paste)*:

```text
NAME                       READY   STATUS    RESTARTS   AGE
coredns-589f44dc88-2vxh5   1/1     Running   0          3h
NAME       TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)                  AGE
kube-dns   ClusterIP   10.96.0.10   <none>        53/UDP,53/TCP,9153/TCP   3h
```

**CoreDNS** is the DNS server of the cluster. Every time a Service is created, CoreDNS learns its name.

## Step 2: see how a pod is told to use it

**📋 Copy and paste into your terminal:**

```bash
kubectl exec -n dev deployment/frontend -- cat /etc/resolv.conf
```

**What this does:** Shows the DNS settings of a DEV frontend pod: the DNS server it asks (`nameserver`), and the endings it tries after a short name (`search`).

**👀 You should see** *(do not paste)*:

```text
search dev.svc.cluster.local svc.cluster.local cluster.local
nameserver 10.96.0.10
options ndots:5
```

| Line | Meaning |
| --- | --- |
| `nameserver 10.96.0.10` | Ask CoreDNS |
| `search dev.svc.cluster.local ...` | When a short name is used, try it with these endings, in this order |

The first ending is the pod's **own namespace**. That is why `db` means "the `db` in my namespace".

## Step 3: the full name of a Service

**📋 Copy and paste into your terminal:**

```bash
kubectl run dns-test -n dev --rm -i --restart=Never --image=busybox:1.36 -- nslookup db.dev.svc.cluster.local
```

**What this does:** Starts one pod called `dns-test` in the namespace `dev` from the image `busybox:1.36`, which runs `nslookup db.dev.svc.cluster.local`. `--rm` deletes the pod again when it is done.

**👀 You should see** *(do not paste)*:

```text
Server:		10.96.0.10
Address:	10.96.0.10:53

Name:	db.dev.svc.cluster.local
Address: 10.106.127.86

pod "dns-test" deleted from dev namespace
```

The full name is built like this:

**📖 Read only (do not paste):**

```text
db  .  dev  .  svc.cluster.local
 |      |
 |      the namespace
 the Service
```

## Step 4: the same short name, three different answers

Ask for the address of `db` in each environment:

**📋 Copy and paste into your terminal:**

```bash
kubectl get service db -n dev -o jsonpath='{.spec.clusterIP}{"\n"}'
kubectl get service db -n uat -o jsonpath='{.spec.clusterIP}{"\n"}'
kubectl get service db -n prod -o jsonpath='{.spec.clusterIP}{"\n"}'
```

**What this does:**

- `kubectl get service db ...`: Reads the Service `db` in the namespace `dev`, and prints only one value from it.
- `kubectl get service db ...`: Reads the Service `db` in the namespace `uat`, and prints only one value from it.
- `kubectl get service db ...`: Reads the Service `db` in the namespace `prod`, and prints only one value from it.

**👀 You should see** three different addresses (yours differ) *(do not paste)*:

```text
10.101.63.58
10.98.138.63
10.100.171.119
```

Three Services named `db`, one in each namespace. A backend that asks for `db` gets the one in its own namespace. That is how the same files work in every environment.

## Step 5: reach another namespace on purpose

To reach a Service in **another** namespace, add the namespace to the name. From a frontend pod in `dev`, look up the frontend in `uat`:

**📋 Copy and paste into your terminal:**

```bash
kubectl exec -n dev deployment/frontend -- nslookup frontend.uat.svc.cluster.local
```

**What this does:** From a DEV pod, looks up the full DNS name of the UAT frontend.

**👀 You should see** the name and an address *(do not paste)*:

```text
Server:		10.96.0.10
Address:	10.96.0.10:53

Name:	frontend.uat.svc.cluster.local
Address: 10.101.33.208
```

DNS answers for every namespace. Whether the traffic is **allowed** is another question: that is the network policy (Lab 3.1).

## Step 6: when DNS is broken

If names stop working in a cluster, check these three things, in this order:

**📋 Copy and paste into your terminal:**

```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl get endpointslices -n kube-system -l kubernetes.io/service-name=kube-dns
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=3
```

**What this does:**

- `kubectl get pods -n kube-system -l k8s-app=kube-dns`: Lists the pods with the label `k8s-app=kube-dns` in the namespace `kube-system`.
- `kubectl get endpointslices -n ...`: Lists the EndpointSlices (the addresses of the pods behind each Service) with the label `kubernetes.io/service-name=kube-dns` in the namespace `kube-system`.
- `kubectl logs -n kube-system -l k8s-app=kube-dns --tail=3`: Shows the log (what the program printed) of all pods with the label `k8s-app=kube-dns` in the namespace `kube-system`: only the last 3 lines.

**👀 You should see** the CoreDNS pod `Running`, an address behind the `kube-dns` Service, and no errors in the last log lines.

💡 **Exam tip:** the short forms: `db` (same namespace), `db.prod` (another namespace), `db.prod.svc.cluster.local` (the full name). All three work.

✅ **Check:** you can explain why `db` gives a different address in `dev` and in `prod`.

**Next:** [Lab 4.1: Node selectors](../04-scheduling/lab-4.1-node-selectors.md)
