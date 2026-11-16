# Lab 1.3 explained: Deployments

This page goes with [Lab 1.3](./lab-1.3-deployments.md). The lab has the commands; this page explains them: what happens in the cluster, why it matters for the Shop, what usually goes wrong, and what the exam asks. There is nothing to paste here.

## In short

A **Deployment** keeps a number of identical pods running. You say "2 copies of the backend", and Kubernetes keeps 2, whatever happens to them. This is the first time you see Kubernetes **heal itself**.

## The ideas behind this lab

### Three layers: Deployment, ReplicaSet, pods

| Object | Its job |
| --- | --- |
| **Deployment** | Owns the *version*: which image and settings the pods should have. Handles updates and rollbacks (Lab 1.8). |
| **ReplicaSet** | Owns the *count*: keeps exactly N pods of one version. |
| **Pod** | Runs the container. |

You only write the Deployment. The Deployment controller creates a ReplicaSet, and the ReplicaSet controller creates the pods. Both controllers run inside the **kube-controller-manager**.

You can see the family in the names: `backend` → `backend-d4f84dd6c` (the ReplicaSet: the Deployment name plus a hash of the pod template) → `backend-d4f84dd6c-tnvtd` (the pod: the ReplicaSet name plus a random part).

### The control loop

Every controller runs the same loop, again and again:

1. **Look:** how many pods with my labels exist?
2. **Compare:** I want 2.
3. **Act:** if there is 1, create one. If there are 3, delete one.

That loop is self-healing. It does not matter why a pod is missing: deleted by you, crashed, or on a node that died. The controller only sees "1 instead of 2" and creates one.

### The selector and the template

In the YAML, `selector.matchLabels: app=backend` says which pods belong to this Deployment, and `template` is the pod to create, with the label `app=backend`. They must match: Kubernetes refuses a Deployment whose template labels do not fit its selector. The template is the pod from Lab 1.2, word for word, just moved inside the Deployment.

## Step by step

### Step 1: create the backend Deployment

The API server stores the Deployment. Within a second, the Deployment controller creates a ReplicaSet with `replicas: 2`, the ReplicaSet controller creates two pods, and from there it is Lab 1.2 again: the scheduler places each pod, a kubelet starts it.

### Step 2: see what it made

`kubectl get deployments,replicasets,pods` asks for three kinds in one go.

| Column | Meaning |
| --- | --- |
| `READY 2/2` | 2 pods are ready, out of 2 wanted |
| `UP-TO-DATE` | Pods that already have the newest template |
| `AVAILABLE` | Pods that have been ready long enough to serve users |
| `DESIRED / CURRENT` | (ReplicaSet) wanted, and existing |

The two pods may land on different nodes. Nothing forces that yet; Lab 4.2 does.

### Step 3: delete a pod and watch it come back

You delete one pod. The ReplicaSet controller sees 1 instead of 2 and creates a new pod, with a new name and a new IP address, usually within a second or two. The `AGE` column shows which one is new.

Notice what did *not* survive: the old pod's name and IP address. Anything that talked to that pod by its address has lost it. That is the problem Services solve in the next lab.

### Step 4: scale up and down

`kubectl scale` changes `replicas` in the Deployment. The ReplicaSet follows: up to 3 creates one pod, back to 2 deletes one. Scaling only changes the count, not the version, so no new ReplicaSet is made. Lab 6.3 lets Kubernetes do this by itself, based on CPU use.

### Step 5: create the frontend Deployment

The frontend is the same pattern with another image: `nginx:1.27-alpine`, a web server. `kubectl rollout status` waits until all pods of the newest version are ready, and returns when they are. Scripts use it to wait instead of guessing with `sleep`.

### Step 6: check both parts

Both show `2/2`. The two parts run, but each pod only has a changing IP address, so the frontend cannot reliably find the backend. Lab 1.4 gives them stable names.

## When something goes wrong

| What you see | What it means | What to do |
| --- | --- | --- |
| `READY 0/2` for a long time | The pods cannot start | `kubectl get pods`, then `kubectl describe pod` on one of them |
| `selector does not match template labels` | The labels in `selector` and `template` differ | Make them the same |
| You deleted a pod and it came back | That is the point: the ReplicaSet replaced it | To remove the pods, scale to 0 or delete the Deployment |
| Two ReplicaSets for one Deployment | An update happened (Lab 1.8): the old one is kept at 0 for rollbacks | Normal |

## For the exam

- `kubectl create deployment NAME --image=IMAGE --replicas=N` creates a Deployment in one line; add `--dry-run=client -o yaml` to get the YAML.
- `kubectl scale deployment NAME --replicas=N` is the fastest way to change the count.
- To remove pods managed by a Deployment for good, delete the Deployment, not the pods.
- Know the chain Deployment → ReplicaSet → pod, and which one owns the version and which one owns the count.

## Check your understanding

1. You delete a pod of the backend. Which controller creates the new one?
2. What does the hash in `backend-d4f84dd6c` stand for?
3. You scale from 2 to 3. Does a new ReplicaSet appear?
4. Why is a new pod after self-healing still a problem for the frontend?
5. How do you stop all pods of a Deployment without deleting it?

<details><summary>Answers</summary>

1. The ReplicaSet controller, in the kube-controller-manager.
2. The pod template. A different template (a new image, for example) gives a different hash and a new ReplicaSet.
3. No. Scaling changes the count of the existing ReplicaSet; only a change to the template makes a new one.
4. It has a new IP address. Anything that used the old address loses the backend. Services fix this.
5. `kubectl scale deployment NAME --replicas=0`.

</details>

**Back to:** [Lab 1.3](./lab-1.3-deployments.md) · **Next:** [Lab 1.4 explained](./lab-1.4-services-explained.md)
