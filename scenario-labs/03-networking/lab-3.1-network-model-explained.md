# Lab 3.1 explained: the container network model

This page goes with [Lab 3.1](./lab-3.1-network-model.md). The lab has the commands; this page explains them: what happens in the cluster, why it matters for the Shop, what usually goes wrong, and what the exam asks. There is nothing to paste here.

## In short

In Kubernetes every pod has its own IP address, and every pod can reach every other pod, on any node, in any namespace. A **network plugin** (Calico on the course cluster) builds that network. Because "everyone can reach everyone" is too open, **NetworkPolicies** act as a firewall for pods. In this lab you close PROD completely, then open exactly the three paths the Shop needs.

## The ideas behind this lab

### The rules of the Kubernetes network

1. Every pod gets its own IP address. Containers in one pod share it.
2. Every pod can reach every other pod by its IP, across nodes, **without address translation**: the address a pod sees for itself is the address others use.
3. Nodes can reach every pod, and pods can reach the nodes.

Kubernetes sets the rules but does not build the network. A **CNI plugin** (Container Network Interface) does, every time a pod starts: the kubelet asks the plugin to give the pod an address and connect it.

### How Calico connects pods

| Piece | What it does |
| --- | --- |
| Address blocks | Each node gets a block of pod addresses (here `10.244.205.x` on one node, `10.244.151.x` on another) |
| A virtual cable (veth pair) | Connects each pod's network to its node |
| Routes | Each node knows which block lives on which node, and sends packets there |
| `calico-node` (DaemonSet) | Runs on every node: sets up the routes and enforces the NetworkPolicies |

So a packet from a frontend pod on `minikube-m03` to a backend pod on `minikube-m02` leaves the pod, is routed from node to node, and arrives at the backend pod with the original addresses intact.

### NetworkPolicies: allow lists for pods

| Rule | Meaning |
| --- | --- |
| By default nothing is isolated | Every pod accepts traffic from everywhere |
| A policy **selects** pods (`podSelector`) | Those pods become isolated for the directions it lists (`Ingress`, `Egress`) |
| An isolated pod only accepts what some policy **allows** | Everything else is dropped |
| Policies only add allowances | There are no "deny" rules; the "deny" comes from being selected |
| Several policies combine | A pod accepts the union of everything they allow |

The **plugin** enforces policies. Kubernetes stores them, but if the plugin does not support them (Flannel, for example), they are accepted and silently ignored. Calico enforces them, which is why `setup.sh` chose it.

### Who is "from"

In `from:`, a `podSelector` on its own means **pods with these labels in the same namespace** as the policy. To allow pods from another namespace you add a `namespaceSelector`. That is exactly why a test pod in `dev` is blocked by PROD's policies even if it had the right label.

## Step by step

### Step 1: every pod has its own address

`-o wide` shows each pod's IP and node. The first part of the address tells you the node: each node hands out addresses from its own block.

### Step 2: see the network plugin

One `calico-node` pod per node: a DaemonSet. Their IPs are the nodes' own addresses (`192.168.49.x`), because they run in the node's network, where they can change routes and firewall rules.

### Step 3: a pod reaches a pod on another node, by IP

`jsonpath='{.items[0].status.podIP}'` reads the IP of the first backend pod into a shell variable. The frontend calls it directly, with no Service in between, and gets the items, even across nodes. That is rule 2. Real applications use the Service name instead, because pod IPs change (Lab 1.4).

### Step 4: see the problem

A throwaway busybox pod in `dev` reads the PROD backend by its full Service name, `backend.prod`. Nothing stops it: a namespace is not a network boundary. A careless test in DEV could just as well write into the PROD database.

### Step 5: close everything in PROD (default deny)

`podSelector: {}` selects **every** pod in the namespace, and `policyTypes: [Ingress]` with no `ingress:` rules allows nothing in. Every PROD pod is now isolated for incoming traffic. Outgoing traffic (Egress) is not restricted, so PROD pods can still look up names in DNS and make connections out; only the answers coming **in** to PROD pods are filtered by these rules, and replies to connections a pod opened itself are always allowed.

### Step 6: see that the Shop is closed

The PROD frontend cannot reach the PROD backend: the packets are dropped, so `curl` gets no answer at all and gives up after 5 seconds (`-m 5`), printing `000`. A dropped connection times out; it is not refused. That difference helps when you troubleshoot: a timeout often means a policy, a refusal means nothing listens.

### Step 7: open the three paths

The file holds three policies, separated by `---`:

| Policy | Protects | Allows in |
| --- | --- | --- |
| `allow-frontend` | `app=frontend` | Anyone, on port 80 (no `from`: every source) |
| `allow-frontend-to-backend` | `app=backend` | Only pods with `app=frontend` in `prod`, on port 3000 |
| `allow-backend-to-db` | `app=db` | Only pods with `app=backend` in `prod`, on port 5432 |

Together with `default-deny`, they describe the Shop's request path exactly, and nothing more.

### Step 8: the Shop is open again

`curl http://localhost/api/items` inside a PROD frontend pod: nginx calls the backend (allowed by policy 2), the backend calls the database (allowed by policy 3). The `-m 5` makes `curl` give up after 5 seconds instead of hanging, if something is still blocked.

### Step 9: DEV cannot read PROD any more

The same command as Step 4 now times out: the test pod lives in `dev`, and no PROD policy allows traffic from `dev` to the backend.

### Step 10: only the backend reaches the database

`nc -zv -w 3 db 5432` only tests whether the port accepts a connection. A test pod in `prod` without labels is blocked; the same pod started with `--labels=app=backend` gets through. The policy does not know names or programs: it trusts labels. That is also its weak point: anyone who may create pods in `prod` may give them any label, which is why access control (Lab 5.1) matters too.

### Step 11: do the same for DEV and UAT

The same files work in every namespace, because they name no namespace and select by labels.

## When something goes wrong

| What you see | What it means | What to do |
| --- | --- | --- |
| The Shop still closed after Step 7 | A label or port in a policy does not match | `kubectl get pods -n prod --show-labels`; `kubectl describe networkpolicy -n prod` |
| A request times out (`000`, exit code 28) | A policy drops the traffic | Find which pod is selected and which rule should allow it |
| `Connection refused` | The traffic arrives, but nothing listens on that port | A port problem, not a policy problem |
| Policies have no effect at all | The network plugin does not enforce them | On the course cluster, check that the `calico-node` pods run |
| After adding an **Egress** default deny, names stop resolving | DNS (port 53 to CoreDNS) is blocked | Allow egress to `k8s-app: kube-dns` on UDP and TCP 53 |

## For the exam

- Copy NetworkPolicy YAML from the documentation page "Network Policies" and change it; writing it from memory is slow and error-prone.
- Read the `from` block carefully: `podSelector` alone means the same namespace; `namespaceSelector` and `podSelector` in **one** list item mean "these pods in those namespaces"; in **two** items they mean "these pods OR anything in those namespaces".
- Test both ways: an allowed client must get through, another must time out. A throwaway busybox pod with `--labels` is the fastest test client.
- Check labels first: most policy faults are label mismatches.

## Check your understanding

1. Who gives a pod its IP address?
2. A NetworkPolicy selects the backend pods and allows port 3000 from the frontend. What happens to traffic from the database to the backend?
3. Why was the DEV test pod blocked in Step 9?
4. Why does a blocked request time out instead of being refused?
5. After the PROD default deny, can PROD pods still resolve names?

<details><summary>Answers</summary>

1. The CNI plugin (Calico), when the kubelet asks it at pod start.
2. It is dropped: the backend pods are selected, so only what a policy allows gets in.
3. A `podSelector` in `from` only matches pods in the policy's own namespace, `prod`; the test pod was in `dev`.
4. The packets are dropped silently, so the client hears nothing and waits until its timeout.
5. Yes. The default deny only covers Ingress; outgoing DNS requests and their replies still work.

</details>

**Back to:** [Lab 3.1](./lab-3.1-network-model.md) · **Next:** [Lab 3.2 explained](./lab-3.2-service-discovery-scaling-load-balancing-explained.md)
