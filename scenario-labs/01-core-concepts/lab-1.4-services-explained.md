# Lab 1.4 explained: Services

This page goes with [Lab 1.4](./lab-1.4-services.md). The lab has the commands; this page explains them: what happens in the cluster, why it matters for the Shop, what usually goes wrong, and what the exam asks. There is nothing to paste here.

## In short

Pods come and go, and every new pod has a new IP address. A **Service** is a fixed name and a fixed address in front of a group of pods. It finds its pods by their label, and sends each connection to one of them. With Services, the frontend can find the backend, and you can open the frontend from outside the cluster.

## The ideas behind this lab

### What a Service gives you

| A Service has | Example | Changes when pods are replaced? |
| --- | --- | --- |
| A name | `backend` | No |
| A virtual IP address (the ClusterIP) | `10.103.30.79` | No, not while the Service exists |
| A port | `3000` | No |
| A list of pods behind it (endpoints) | `10.244.151.1`, `10.244.205.194` | Yes, all the time, by itself |

Clients only use the first three. Kubernetes keeps the fourth up to date.

### How the pieces work together

1. The Service says: "my pods are the ones with `app=backend`".
2. The **EndpointSlice controller** (in the controller manager) watches the pods. Every pod with that label that is **ready** goes into the Service's EndpointSlice. A pod that is deleted or not ready is removed.
3. **kube-proxy**, on every node, reads the Services and EndpointSlices and writes network rules into that node's kernel: "traffic to `10.103.30.79:3000` goes to one of these pod addresses".
4. **CoreDNS** gives the Service a name: `backend.dev.svc.cluster.local` points to the ClusterIP.

Nothing actually listens on the ClusterIP. It only exists as rules on every node. That is why you cannot `ping` it, but you can connect to its port.

### port and targetPort

| Field | Meaning in the Shop |
| --- | --- |
| `port` | The port clients use on the Service: `backend:3000` |
| `targetPort` | The port the container listens on |
| `nodePort` | (NodePort only) the port on every node, from outside: `30080` |

In the Shop, `port` and `targetPort` are the same number, which keeps things simple. They do not have to be: a Service can take traffic on port 80 and send it to a container on 8080.

### The Service types

| Type | Reachable from | In the Shop |
| --- | --- | --- |
| `ClusterIP` (the default) | Only inside the cluster | `backend`: only the frontend needs it |
| `NodePort` | Also from outside, on a port (30000–32767) of every node | `frontend` in `dev`: you open it from your server |
| `LoadBalancer` | From outside, through a load balancer of the cloud provider | Not used: there is no cloud. Lab 3.2 uses an Ingress instead |

Each type builds on the one before: a NodePort Service also has a ClusterIP, and a LoadBalancer Service also has a NodePort.

## Step by step

### Step 1: look at the two Services

The two files are short: a name, a type, a selector and the ports. The selector is the only link between a Service and its pods. There is no list of pods in the file, and none is needed.

### Step 2: create them

`kubectl get services` shows each Service's ClusterIP, taken from the Service range (`10.96.0.0/12` on minikube). `80:30080/TCP` means: port 80 on the ClusterIP, port 30080 on every node.

### Step 3: see which pods are behind each Service

`kubectl get endpointslices` shows the pod addresses behind each Service. They are exactly the pod IPs from `kubectl get pods -o wide`. Delete a backend pod now, and within seconds its address is replaced by the new pod's address: that is how the Service keeps up with self-healing from Lab 1.3.

An EndpointSlice with no addresses means the Service has no ready pods: the most common reason a Service "does not work" (Lab 8.1).

### Step 4: find the backend by name (DNS)

`kubectl run dns-test --rm -i ...` starts a throwaway pod, runs one command in it, shows the output and deletes the pod (`--rm`). `nslookup` asks the cluster DNS (CoreDNS, at `10.96.0.10`) for the backend's full name, and gets the ClusterIP back. Inside `dev`, the short name `backend` works too, because every pod's DNS settings try its own namespace first (Lab 3.3).

### Step 5: call the backend from the frontend

`kubectl exec deployment/frontend -- curl ...` runs `curl` inside one of the frontend pods. The request goes: name `backend` → DNS → ClusterIP → kube-proxy rules → one backend pod. The backend answers with an error, because it has no settings yet; but an answer **from the backend** proves the path works.

### Step 6: open the frontend from your server

`$(minikube ip)` is replaced by the address of the control plane node (`192.168.49.2`), which your server can reach over Docker's network. Port 30080 is open on every node, so any node's address would work. kube-proxy sends the request to one of the frontend pods, which answers with nginx's standard page. The Shop page comes in Lab 1.5.

## When something goes wrong

| What you see | What it means | What to do |
| --- | --- | --- |
| The EndpointSlice shows no addresses | No pod has the Service's label, or none is ready | Compare `kubectl get pods --show-labels` with the Service's selector |
| `curl: (6) Could not resolve host: backend` | The name is wrong, or the Service is in another namespace | Use `backend.<namespace>`, or check `kubectl get svc` |
| `Connection refused` | The Service works, but `targetPort` is not where the container listens | Fix `targetPort` |
| `provided port is already allocated` | Another Service already uses NodePort 30080 | Remove the other one, or choose another nodePort |

## For the exam

- `kubectl expose deployment NAME --port=P --target-port=T` creates a Service with the right selector for you. Add `--type=NodePort` for a NodePort Service.
- When a Service gives no answer, run `kubectl get endpointslices` first: empty endpoints mean a label or readiness problem, not a network problem.
- Know the full DNS name: `<service>.<namespace>.svc.cluster.local`.

## Check your understanding

1. How does a Service know which pods are its own?
2. A backend pod is replaced. What changes in the Service, and what stays the same?
3. Why can you not ping a ClusterIP?
4. What is the difference between `port` and `targetPort`?
5. Why is the backend a ClusterIP Service and the frontend a NodePort Service?

<details><summary>Answers</summary>

1. By its selector: every ready pod with matching labels.
2. Its EndpointSlice gets the new pod's address. The name, the ClusterIP and the port stay the same.
3. Nothing listens on it: it only exists as forwarding rules for its ports, written by kube-proxy.
4. `port` is what clients use on the Service; `targetPort` is where the container listens.
5. Only the frontend calls the backend, from inside the cluster. People open the frontend from outside.

</details>

**Back to:** [Lab 1.4](./lab-1.4-services.md) · **Next:** [Lab 1.5 explained](./lab-1.5-configmaps-and-secrets-explained.md)
