# Lab 3.2 explained: service discovery, scaling and load balancing

This page goes with [Lab 3.2](./lab-3.2-service-discovery-scaling-load-balancing.md). The lab has the commands; this page explains them: what happens in the cluster, why it matters for the Shop, what usually goes wrong, and what the exam asks. There is nothing to paste here.

## In short

A Service spreads requests over all its ready pods, and finds new pods by itself when you scale. That covers traffic **inside** the cluster and simple access from outside (NodePort). Real users want a **name**: an **Ingress** is a set of rules ("this hostname goes to that Service"), and an **Ingress controller** is the web server that follows them. In this lab PROD gets the name `shop.local`.

## The ideas behind this lab

### Service discovery: names instead of addresses

A pod finds another part of the application by its **Service name**, and the Service finds its pods by their **labels**. Neither side needs to know an IP address. When you scale, the new pods carry the same label, the EndpointSlice controller adds them to the Service, and clients start reaching them without any change.

### Load balancing by a Service

kube-proxy's rules choose one of the ready pods **for each new connection**, at random (in the default iptables mode). Two consequences:

- Many short connections (like the 20 `curl` requests in the lab) spread out roughly evenly, but not exactly: 9 and 10, or 7, 5, 6 and 2.
- One long connection that sends many requests stays on one pod. Balancing per request needs something that understands HTTP: an Ingress controller, a Gateway, or a service mesh.

### Scaling

`kubectl scale` changes the number of pods by hand. The HorizontalPodAutoscaler (Lab 6.3) does the same automatically, based on CPU use. Either way, the Service follows.

### Getting traffic in from outside

| Way | How users reach it | Good for |
| --- | --- | --- |
| `NodePort` Service | Any node's address and a high port, such as `:30080` | Tests, simple setups |
| `LoadBalancer` Service | An address from the cloud provider's load balancer | One Service on a cloud |
| **Ingress** | A hostname and path, on ports 80 and 443, through one controller | Many websites and APIs behind one entry point |

### Ingress and Ingress controller

The **Ingress** object is only rules. Nothing happens until an **Ingress controller** runs: a program (here ingress-nginx, a configured nginx) that watches all Ingress objects and turns them into its own configuration. An **IngressClass** names a controller; `ingressClassName: nginx` says which controller should follow this Ingress.

The controller sends each request **directly to the pods** of the Service named in the rule (it reads the Service's endpoints), and balances **per request**. The newer **Gateway API** does the same job with more features and is in the current CKA curriculum; the idea is the same: rules, plus a controller that follows them.

## Step by step

### Step 1: send 20 requests and see who answered

The loop sends 20 separate requests to the NodePort. Each one is a new connection, so kube-proxy picks a frontend pod each time. `kubectl logs -l app=frontend --prefix` reads the logs of all frontend pods at once and puts each pod's name in front of its lines; counting the lines per pod shows how the requests were spread.

### Step 2: scale up

Scaling to 4 adds two pods. `kubectl get endpointslices -l kubernetes.io/service-name=frontend` shows the Service's slice with four addresses: the Service found the new pods by their label. You changed nothing in the Service.

### Step 3: send 20 requests again

The `sleep 60` lets the logs from Step 1 fall outside the time window (`--since=30s`), so only the new requests are counted. Now four pods share the work.

### Step 4: go back to 2

Scaling down removes two pods and their addresses from the Service.

### Step 5: switch on the Ingress controller

`minikube addons enable ingress` installs ingress-nginx in its own namespace, `ingress-nginx`. On minikube the controller listens on ports 80 and 443 of the node, so the node's address is the entry point. The two `Completed` pods were one-time setup jobs (they create the certificates for the controller's admission check). `kubectl get ingressclass` shows the class `nginx`, marked as the default.

Why the wait and the `sleep`? `minikube addons enable` returns as soon as it has created the objects, before the controller runs. And every new Ingress is first sent to the controller's **admission webhook**, a check that rejects broken rules. Until the controller answers on that port, creating an Ingress fails with `failed calling webhook ... connection refused`. The webhook needs a few seconds more than the pod's readiness, hence the extra `sleep`. The same thing happens with other add-ons that bring a webhook (cert-manager, for example).

### Step 6: look at the rules

One rule: host `shop.local`, path `/` with `pathType: Prefix` (so every path that starts with `/`, which is all of them), to the Service `frontend` on port 80. More rules could send other names or paths to other Services through the same controller.

### Step 7: create the Ingress in PROD

The Ingress lives in `prod`, next to the Service it names: an Ingress can only send traffic to Services in its own namespace. `ADDRESS` may be empty at first; the controller fills it in when it has picked up the rule.

There is a link to Lab 3.1 here: the controller's pod is in the namespace `ingress-nginx`, not in `prod`. It can still reach the PROD frontend because the policy `allow-frontend` allows port 80 from **anyone**. A stricter policy would have to allow the controller's namespace explicitly.

### Step 8: teach your server the name

`shop.local` is not registered in any DNS. A line in `/etc/hosts` makes your server resolve it to the node's address. In real life, a DNS record points the name at the load balancer in front of the Ingress controller.

### Step 9: open the Shop by name

`curl http://shop.local` resolves the name to the node, connects to port 80, and sends the header `Host: shop.local`. The controller matches the host to the rule, and passes the request to a PROD frontend pod. `/api/items` follows the same path, then nginx in the frontend pod passes it on to the backend as before.

### Step 10: ask without a name

A request to the bare IP address has no matching `Host`, so no rule applies, and the controller answers `404`. The controller decides by name, not by address.

## When something goes wrong

| What you see | What it means | What to do |
| --- | --- | --- |
| `curl: (6) Could not resolve host: shop.local` | The `/etc/hosts` line is missing or wrong | `grep shop.local /etc/hosts`; it must hold the node address |
| `404` with the name | The rule does not match: host typo, or the Ingress is in another namespace | `kubectl describe ingress shop -n prod` |
| `503 Service Temporarily Unavailable` | The rule matches, but the Service has no ready pods, or the name or port is wrong | `kubectl get endpointslices -n prod`; check the Service name and port in the rule |
| Timeouts through the Ingress | A NetworkPolicy blocks the controller | Allow traffic from the `ingress-nginx` namespace |
| The Ingress is ignored | No controller, or a wrong `ingressClassName` | `kubectl get ingressclass`; check the controller pod runs |

## For the exam

- `kubectl create ingress NAME --class=nginx --rule="host/path=service:port"` writes an Ingress; add `--dry-run=client -o yaml` to edit it.
- An Ingress needs a controller; without one, nothing happens. An Ingress and its Service must be in the same namespace.
- Know `pathType`: `Prefix` (this path and everything below it) and `Exact` (only this path).
- The Gateway API (`Gateway`, `HTTPRoute`) is in the current curriculum: same idea, newer objects.
- `kubectl scale deployment NAME --replicas=N`; the Service follows by itself.

## Check your understanding

1. You scale the frontend from 2 to 4. What do you change in the Service?
2. Why were the 20 requests not split exactly 10 and 10?
3. What is the difference between an Ingress and an Ingress controller?
4. Why does `http://<node IP>/` give 404 while `http://shop.local/` works?
5. The Ingress controller runs in `ingress-nginx`. Why could it reach the PROD frontend despite PROD's default deny?

<details><summary>Answers</summary>

1. Nothing. The new pods have the label, so the Service finds them.
2. kube-proxy picks a pod at random for each new connection; random choices are only roughly even.
3. The Ingress is a set of rules; the controller is the program that receives the traffic and follows the rules.
4. The controller chooses a rule by the hostname in the request; the bare address matches no rule.
5. The policy `allow-frontend` allows port 80 from anyone, in any namespace.

</details>

**Back to:** [Lab 3.2](./lab-3.2-service-discovery-scaling-load-balancing.md) · **Next:** [Lab 3.3 explained](./lab-3.3-dns-explained.md)
