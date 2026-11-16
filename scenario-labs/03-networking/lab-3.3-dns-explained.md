# Lab 3.3 explained: DNS for service discovery

This page goes with [Lab 3.3](./lab-3.3-dns.md). The lab has the commands; this page explains them: what happens in the cluster, why it matters for the Shop, what usually goes wrong, and what the exam asks. There is nothing to paste here.

## In short

**CoreDNS** is the cluster's DNS server. Every Service gets a name, `<service>.<namespace>.svc.cluster.local`. Each pod is told to ask CoreDNS, and to try short names in its **own namespace first**. That is why the backend's setting `db` reaches the `db` of its own environment, in `dev`, `uat` and `prod` alike.

## The ideas behind this lab

### The moving parts

| Part | What it is |
| --- | --- |
| **CoreDNS** | A Deployment in `kube-system` (two pods on most clusters, one on minikube) that answers DNS questions |
| **kube-dns** | The Service in front of CoreDNS. Its ClusterIP (`10.96.0.10`) is the address every pod asks. The name is historical: CoreDNS replaced an older server called kube-dns |
| **The Corefile** | CoreDNS's settings, in the ConfigMap `coredns` in `kube-system` |
| **The kubelet** | Writes each pod's `/etc/resolv.conf` when it starts the pod |

CoreDNS watches the API server for Services and their endpoints, and answers from that. A new Service has a name within seconds; nothing has to be registered by hand.

### The names Kubernetes gives

| Name | Answer |
| --- | --- |
| `db.dev.svc.cluster.local` | The ClusterIP of the Service `db` in `dev` |
| A headless Service (`clusterIP: None`) | The IPs of its ready pods, not one ClusterIP |
| `kubernetes.default.svc.cluster.local` | The API server, from inside the cluster |

`svc` says "a Service", and `cluster.local` is the cluster's domain, set when the cluster is built.

### Short names and the search list

A pod's `/etc/resolv.conf` has a `search` line. When a program asks for a short name, the resolver tries it with each ending in turn:

1. `db.dev.svc.cluster.local` (the pod's own namespace first)
2. `db.svc.cluster.local`
3. `db.cluster.local`
4. `db` as it is

The first one that exists wins. So `db` in a `dev` pod means `db.dev...`, and `db.prod` (namespace added) matches at step 2 as `db.prod.svc.cluster.local`.

`options ndots:5` means: a name with fewer than 5 dots is treated as possibly short, and the search list is tried first. That is why `google.com` from a pod is first tried as `google.com.dev.svc.cluster.local` and so on, before the real lookup: a few extra queries, normally harmless.

## Step by step

### Step 1: meet the DNS server of the cluster

The CoreDNS pods carry the label `k8s-app=kube-dns`, and the Service `kube-dns` has ports 53 (DNS, over UDP and TCP) and 9153 (CoreDNS's own metrics, for Prometheus).

### Step 2: see how a pod is told to use it

`cat /etc/resolv.conf` inside a frontend pod shows the three lines the kubelet wrote: ask `10.96.0.10`, try these endings, use `ndots:5`. A pod in `prod` has `prod.svc.cluster.local` as its first ending. This one line is the whole reason the Shop's files work in every environment.

### Step 3: the full name of a Service

`nslookup db.dev.svc.cluster.local` from a throwaway busybox pod returns the ClusterIP of the `db` Service in `dev`. The `Server` line confirms who answered: CoreDNS at `10.96.0.10`.

### Step 4: the same short name, three different answers

Three Services named `db`, each with its own ClusterIP. The backends all ask for `db`, and each one's search list sends it to the one in its own namespace.

### Step 5: reach another namespace on purpose

`frontend.uat.svc.cluster.local` resolves from a `dev` pod: DNS answers for every namespace. Resolving a name says nothing about whether the connection is **allowed**: after Lab 3.1, the NetworkPolicies decide that.

### Step 6: when DNS is broken

Three checks, in order:

1. **Are the CoreDNS pods running?** If not, nothing resolves.
2. **Does the `kube-dns` Service have endpoints?** If its EndpointSlice is empty, pods ask an address with nobody behind it.
3. **What do the CoreDNS logs say?** Errors about the upstream server, or about a loop.

Then test from a pod: if `kubernetes.default` resolves but your Service does not, the problem is the name or the namespace, not DNS.

## When something goes wrong

| What you see | What it means | What to do |
| --- | --- | --- |
| `db` does not resolve, `db.prod` does | The client is in another namespace | Use `name.namespace` |
| Nothing resolves, `kubernetes.default` included | CoreDNS is down, or the `kube-dns` Service has no endpoints | Check the CoreDNS pods and the EndpointSlice |
| Names stopped working after a NetworkPolicy change | An Egress policy blocks port 53 to CoreDNS | Allow UDP and TCP 53 to `k8s-app: kube-dns` |
| CoreDNS in `CrashLoopBackOff`, logs mention a loop | CoreDNS forwards to itself through the node's DNS settings | Fix the `forward` target in the Corefile |
| Outside names are slow | `ndots:5` makes several lookups first | Normal; a trailing dot (`google.com.`) skips the search list |

## For the exam

- Know the name forms: `svc`, `svc.ns`, `svc.ns.svc.cluster.local`.
- Test DNS from a throwaway pod: `kubectl run tmp --rm -it --image=busybox:1.36 --restart=Never -- nslookup NAME`.
- CoreDNS's settings are in the ConfigMap `coredns` in `kube-system`; after an edit, its `reload` plugin applies the change, or restart the Deployment.
- When "the Service does not work", tell DNS problems (name does not resolve) from Service problems (resolves, no endpoints) from policy problems (resolves, times out).

## Check your understanding

1. Which address does every pod ask for DNS, and what is behind it?
2. Why does the backend in `prod` reach the PROD database with the short name `db`?
3. How do you reach the Service `frontend` in `uat` from a pod in `dev`?
4. A name resolves, but the connection times out. Is it DNS?
5. What are the first three things to check when no name resolves?

<details><summary>Answers</summary>

1. `10.96.0.10`, the ClusterIP of the `kube-dns` Service, with the CoreDNS pods behind it.
2. Its `search` list tries `prod.svc.cluster.local` first, so `db` becomes `db.prod.svc.cluster.local`.
3. By `frontend.uat`, or the full name `frontend.uat.svc.cluster.local` (if the network policies allow it).
4. No. DNS worked; look at endpoints and network policies.
5. The CoreDNS pods, the endpoints of the `kube-dns` Service, and the CoreDNS logs.

</details>

**Back to:** [Lab 3.3](./lab-3.3-dns.md) · **Next:** [Lab 4.1 explained](../04-scheduling/lab-4.1-node-selectors-explained.md)
