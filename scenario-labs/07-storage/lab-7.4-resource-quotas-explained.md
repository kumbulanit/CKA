# Lab 7.4 explained: resource quotas

This page goes with [Lab 7.4](./lab-7.4-resource-quotas.md). The lab has the commands; this page explains them: what happens in the cluster, why it matters for the Shop, what usually goes wrong, and what the exam asks. There is nothing to paste here.

## In short

Three environments share one cluster's CPU, memory and disks. **Requests and limits** say what each container needs and may use. A **ResourceQuota** caps a whole namespace: pods, CPU, memory, claims and storage. A **LimitRange** gives containers sensible defaults, so they fit the quota rules. In this lab every environment gets the same budget, and you watch the quota refuse pods and a claim.

## The ideas behind this lab

### Requests and limits, in full

| | Request | Limit |
| --- | --- | --- |
| Means | What the container needs for sure | The most it may use |
| Used by | The scheduler: a pod only goes to a node with that much **unreserved** room | The kubelet and the kernel, while it runs |
| CPU over it | Fine: it may use idle CPU | It is slowed down (throttled), not killed |
| Memory over it | Fine, while the node has memory | The container is killed (`OOMKilled`) and restarted |

Requests are reservations, not use: a node can look busy to the scheduler (all reserved) while its CPU is idle.

### QoS classes

Kubernetes sorts each pod into a **Quality of Service** class from its requests and limits:

| Class | When | Under memory pressure on the node |
| --- | --- | --- |
| `Guaranteed` | Every container has requests equal to limits, for CPU and memory | Evicted last |
| `Burstable` | Some requests or limits, not equal | In between |
| `BestEffort` | No requests and no limits at all | Evicted first |

The Shop's pods are `Burstable`: their limits are higher than their requests.

### ResourceQuota

A ResourceQuota is checked when an object is **created** (by the API server's admission step). It counts what already exists in the namespace, and refuses anything that would go over:

| Kind of limit | Example in `env-quota` |
| --- | --- |
| Number of objects | `pods: 10`, `persistentvolumeclaims: 2` |
| Total compute | `requests.cpu: 1`, `limits.memory: 2Gi`... |
| Total storage | `requests.storage: 2Gi` |

One important side effect: once a quota sets `requests.cpu` (or memory), **every new pod** in that namespace must state that request. A pod without one is refused.

### LimitRange

A LimitRange works per container: it fills in a **default request** and **default limit** for containers that set none, and can set a minimum and maximum. With it, pods that forget their resources still get values, and still pass the quota. The Shop's LimitRange gives 25m CPU and 32Mi as requests, 100m and 64Mi as limits.

## Step by step

### Step 1: set them on the three parts

`kubectl set resources` adds requests and limits to the frontend and the database (the backend got them in Lab 6.3). The changed pod templates roll out new pods. The database restarts, but its data is now on a disk (Lab 7.2), so nothing is lost.

### Step 2: look at the QoS class

`-o custom-columns=...:.status.qosClass` shows the class Kubernetes worked out for each pod: all `Burstable`.

### Step 3: give DEV a budget

The LimitRange and the quota are applied together, LimitRange first in the command, so that new pods get defaults. `kubectl describe resourcequota` shows `Used` against `Hard` for every line. The database's 1Gi claim counts towards `requests.storage` and `persistentvolumeclaims`. The quota does not touch existing objects; it only judges new ones.

### Step 4: apply both files in the other two environments

The same files in `uat` and `prod` give each environment the same budget. Custom columns show the used pods and claims per namespace: 5 pods and 1 claim each.

### Step 5: ask for too many pods

Scaling the UAT frontend to 12 asks for 10 more pods, but the namespace may only have 10 in total. The ReplicaSet creates pods until the quota is full; every further attempt is refused. The Deployment shows `3/12`, and the pods it could not create do not exist at all, so `kubectl get pods` shows no error. Only the events (`FailedCreate ... exceeded quota`) say why. This "missing pods, no error" pattern is a classic troubleshooting case (Lab 8.1).

### Step 6: go back to 2

Scaling down frees the quota again.

### Step 7: ask for too much storage

A 5Gi claim in `dev` would bring the total to 6Gi, over the 2Gi budget. The API server refuses it at once, with the reason in the error: `requested: requests.storage=5Gi, used: 1Gi, limited: 2Gi`. Nothing is created. A claim is checked directly, because you create it yourself; pods of a Deployment are created by a controller, which is why their refusals only show up in events.

## When something goes wrong

| What you see | What it means | What to do |
| --- | --- | --- |
| Fewer pods than asked, no pods in error | The quota refused the rest | `kubectl get events -n NS`; `kubectl describe resourcequota -n NS` |
| `must specify limits.cpu` or `requests.memory` | The quota covers compute, and the pod sets no value | Add requests and limits, or a LimitRange with defaults |
| Pods `Pending` with `Insufficient cpu` | Requests are too big for the free room on the nodes | Lower the requests, or add capacity |
| A container restarts with `OOMKilled` | It used more memory than its limit | Raise the memory limit, or fix the program |
| A claim refused with `exceeded quota` | The storage budget is full | Delete unused claims, or raise the quota |

## For the exam

- `kubectl create quota NAME --hard=pods=10,requests.cpu=1,requests.memory=1Gi -n NS` writes a ResourceQuota in one line.
- `kubectl describe resourcequota -n NS` shows used against hard.
- `kubectl set resources deployment NAME --requests=cpu=...,memory=... --limits=...`.
- A LimitRange with `default` and `defaultRequest` is the fix when a quota rejects pods without resources.
- Know the three QoS classes and how each is decided.

## Check your understanding

1. What does the scheduler use: requests or limits?
2. A container uses more memory than its limit. What happens? And more CPU?
3. Why do Deployment pods refused by a quota not show up as errors in `kubectl get pods`?
4. A quota sets `requests.cpu`. What happens to a new pod without a CPU request?
5. All containers of a pod have requests equal to limits. Which QoS class does it get?

<details><summary>Answers</summary>

1. Requests.
2. Memory: the container is killed (`OOMKilled`) and restarted. CPU: it is slowed down, not killed.
3. They were never created: the ReplicaSet's create requests were refused, which only shows in the events.
4. It is refused, unless a LimitRange fills in a default request.
5. `Guaranteed`.

</details>

**Back to:** [Lab 7.4](./lab-7.4-resource-quotas.md) · **Next:** [Lab 8.1 explained](../08-troubleshooting/lab-8.1-break-and-fix-explained.md)
