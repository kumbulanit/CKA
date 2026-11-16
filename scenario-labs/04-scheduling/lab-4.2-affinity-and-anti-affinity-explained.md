# Lab 4.2 explained: affinity and anti-affinity

This page goes with [Lab 4.2](./lab-4.2-affinity-and-anti-affinity.md). The lab has the commands; this page explains them: what happens in the cluster, why it matters for the Shop, what usually goes wrong, and what the exam asks. There is nothing to paste here.

## In short

**Affinity** rules are a richer form of placement than a nodeSelector. **Node affinity** draws pods to nodes by their labels, as a hard rule (`required`) or a wish (`preferred`). **Pod affinity** places pods near other pods; **pod anti-affinity** keeps them apart. In this lab PROD **prefers** its node instead of needing it, and the two DEV backend pods are kept on different nodes.

## The ideas behind this lab

### Required and preferred

| Kind | Name starts with | In the scheduler | If nothing matches |
| --- | --- | --- | --- |
| Hard rule | `requiredDuringScheduling...` | A **filter** (like a nodeSelector) | The pod stays `Pending` |
| Wish | `preferredDuringScheduling...` | A **score**, with a `weight` from 1 to 100 | The pod runs on another node |

The second half of the name is always `...IgnoredDuringExecution`: the rule is only checked when the pod is placed. If a label changes later, running pods are not moved.

### Node affinity: more than a nodeSelector

Node affinity uses `matchExpressions` with operators: `In`, `NotIn`, `Exists`, `DoesNotExist`, `Gt`, `Lt`. So it can say "env is prod or staging", "not the control plane", "any node that has a GPU label". Expressions inside one term must all match; several terms are alternatives.

### Pod affinity and anti-affinity

These look at **other pods**, not at node labels:

- **Pod affinity:** "put me in the same place as pods with label X" (the backend next to its cache, to keep calls fast).
- **Pod anti-affinity:** "do not put me in the same place as pods with label X" (two copies of the backend apart, so one failure cannot take both).

"The same place" is defined by the **topologyKey**: a node label. Nodes with the same value of that label count as one place.

| topologyKey | One "place" is | Anti-affinity means |
| --- | --- | --- |
| `kubernetes.io/hostname` | One node | Not on the same node |
| `topology.kubernetes.io/zone` | One zone (a data centre) | Not in the same zone |

### Preferred anti-affinity is a strong wish, not a guarantee

The Shop uses **preferred** pod anti-affinity. With three nodes and room on them, the scheduler always finds a node without a backend pod, so the two pods end up apart. If only one node had room, both would still start there, rather than one staying `Pending`. A **required** anti-affinity would guarantee the spread, at the cost of `Pending` pods when there are fewer usable nodes than copies.

## Step by step

### Step 1: look at the rule

`nodeSelector: null` removes the hard rule from Lab 4.1 (in a patch, `null` deletes a field). The node affinity then says: prefer nodes whose label `env` is `prod`, with the highest weight, 100.

### Step 2: give it to the PROD frontend and backend

Both Deployments get new pods, and the scheduler's score sends them to `minikube-m03`, the only node with `env=prod`. The result looks the same as with the nodeSelector; the difference only shows when `minikube-m03` is drained or full: the new pods then start elsewhere instead of waiting. The database is not patched and stays where it is: it has one copy and its data on its node (more on that in Module 7).

### Step 3: see where the two DEV backend pods are

Without a rule, the scheduler's default spreading usually puts the two copies on different nodes, but nothing guarantees it. Luck is not a plan.

### Step 4: look at the rule

`podAntiAffinity` with `labelSelector: app: backend` and `topologyKey: kubernetes.io/hostname`: prefer a node that has no pod with `app=backend` yet. The label selector looks at pods **in the same namespace** by default, so DEV backends only avoid DEV backends.

### Step 5: give it to the DEV backend

The rolling update creates the new pods one at a time. When the second new pod is placed, the first one already runs on some node, so the score sends the second elsewhere. The two DEV backend pods now run on different nodes. With `minikube` (the control plane) taking pods on the course cluster, there are three possible places.

## When something goes wrong

| What you see | What it means | What to do |
| --- | --- | --- |
| A pod `Pending` with a `required` rule | No node matches the hard rule | Check the node labels; or use `preferred` |
| Both backends on one node despite preferred anti-affinity | Only one node had room, or the labels in `labelSelector` do not match the pods | Check free resources and the pod labels |
| The patch fails with a validation error | Wrong indentation, or a field at the wrong level | Compare with `kubectl explain pod.spec.affinity` |
| Pods did not move after the patch | They only move if the template changed and new pods were made | `kubectl rollout status`, then check the new pods |

## For the exam

- Learn the names in two halves: `required` or `preferred`, then `DuringSchedulingIgnoredDuringExecution`.
- `required` uses `nodeSelectorTerms` with `matchExpressions`; `preferred` uses a list of `weight` plus `preference`. Copy the layout from the documentation page "Assigning Pods to Nodes", or use `kubectl explain`.
- Pod anti-affinity needs a `topologyKey`; `kubernetes.io/hostname` means "per node".
- When a pod is `Pending`, the event names the affinity rule that failed.

## Check your understanding

1. What is the difference between `required...` and `preferred...` node affinity?
2. What does `IgnoredDuringExecution` mean?
3. Why did PROD switch from a nodeSelector to preferred node affinity?
4. What does `topologyKey: kubernetes.io/hostname` mean in the backend's anti-affinity?
5. Can both DEV backend pods ever end up on the same node with this rule?

<details><summary>Answers</summary>

1. `required` is a hard filter (no match: `Pending`); `preferred` is a weighted wish (no match: another node).
2. The rule is only checked when the pod is placed; running pods are not moved if labels change later.
3. So that PROD can still start on another node when `minikube-m03` is drained or broken.
4. One node is one "place": two backend pods should not be on the same node.
5. Yes, if only one node has room, because the rule is preferred. A required rule would leave the second pod `Pending` instead.

</details>

**Back to:** [Lab 4.2](./lab-4.2-affinity-and-anti-affinity.md) · **Next:** [Lab 4.3 explained](./lab-4.3-taints-and-tolerations-explained.md)
