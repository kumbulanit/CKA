# Lab 4.3 explained: taints and tolerations

This page goes with [Lab 4.3](./lab-4.3-taints-and-tolerations.md). The lab has the commands; this page explains them: what happens in the cluster, why it matters for the Shop, what usually goes wrong, and what the exam asks. There is nothing to paste here.

## In short

A **taint** on a node keeps pods away; a **toleration** on a pod lets it in anyway. Affinity pulls pods **to** a node; a taint pushes everyone else **off** it. In this lab you taint `minikube-m03` so DEV and UAT can no longer start there, then give only the PROD frontend and backend a toleration. Together with Lab 4.2, the node is kept for PROD.

## The ideas behind this lab

### Taints and tolerations

A taint is written `key=value:effect`, for example `dedicated=prod:NoSchedule`. A pod **tolerates** it when one of its tolerations matches:

| Toleration | Matches |
| --- | --- |
| `operator: Equal`, same key, same value, same effect | Exactly this taint |
| `operator: Exists`, same key (no value) | This key with any value |
| `operator: Exists` with no key | Every taint (DaemonSets for system parts often use this) |
| No `effect` in the toleration | That key/value with any effect |

A pod must tolerate **every** taint on a node (of the effects that apply) to be placed there.

### The three effects

| Effect | New pods without a toleration | Pods already running without one |
| --- | --- | --- |
| `NoSchedule` | Not placed there | Stay |
| `PreferNoSchedule` | Avoided, unless there is no other place | Stay |
| `NoExecute` | Not placed there | **Evicted** (after `tolerationSeconds`, if the toleration sets one) |

The Shop uses `NoSchedule`: the node fills with the right pods as pods are replaced, and nothing is thrown out abruptly.

### Taints Kubernetes sets by itself

| Taint | When |
| --- | --- |
| `node-role.kubernetes.io/control-plane:NoSchedule` | On kubeadm control plane nodes: keeps workloads off them (minikube leaves it out, so the course's control plane takes pods) |
| `node.kubernetes.io/unschedulable:NoSchedule` | After `kubectl cordon` (Lab 2.7) |
| `node.kubernetes.io/not-ready:NoExecute`, `unreachable:NoExecute` | When a node stops reporting: its pods are evicted after a grace time (5 minutes by default) and replaced elsewhere |

That last one is how Kubernetes moves pods away from a node that died.

### A toleration is a pass, not a ticket

A toleration only **allows** a pod onto a tainted node; it does not send it there. A PROD pod with a toleration but no affinity could still land on any node. The two halves together give a dedicated node:

| Half | Done by | Effect |
| --- | --- | --- |
| Node affinity (Lab 4.2) | The PROD pods | Drawn to `minikube-m03` |
| Taint + toleration (this lab) | The node, and a pass on PROD pods | Everyone else kept off |

## Step by step

### Step 1: see who is on the PROD node now

DEV and UAT pods may run on `minikube-m03` next to PROD: affinity only pulled PROD there, it kept nobody out.

### Step 2: put the taint on the node

`kubectl taint node minikube-m03 dedicated=prod:NoSchedule` adds the taint; `kubectl describe node | grep Taints` shows it. Nothing moves yet: `NoSchedule` only affects new pods.

### Step 3: DEV and UAT can no longer start there

`rollout restart` gives the DEV and UAT frontends and backends new pods. The scheduler's filter now drops `minikube-m03` for them (they do not tolerate the taint), so they go to the other nodes. Their databases are not restarted, so a DEV or UAT database pod that was already on `minikube-m03` stays there, which is what `NoSchedule` means.

### Step 4: but PROD cannot start there either

The PROD frontend has no toleration yet, so the taint keeps it out too. Its preferred affinity is only a wish, so the scheduler places the new pods on other nodes and the rollout finishes. With the hard nodeSelector of Lab 4.1, the new pods would be `Pending` and the release stuck: a good reason to have chosen a preference.

### Step 5: give the PROD pods a pass

The toleration repeats the taint's key, value and effect with `operator: Equal`. After the patch, new PROD frontend and backend pods pass the filter for `minikube-m03`, and the affinity's score makes it their first choice. The PROD database has no toleration and stays where it is.

### Step 6: the two halves together

Affinity says where PROD wants to go; the taint says who may come in. Only the PROD frontend and backend have both, so only they run on the PROD node.

## When something goes wrong

| What you see | What it means | What to do |
| --- | --- | --- |
| Pods `Pending`, event says `had untolerated taint {dedicated: prod}` | No toleration, and no other node fits | Add a toleration, or make room elsewhere |
| PROD pods with the toleration still run elsewhere | A toleration does not attract | Keep the node affinity from Lab 4.2 |
| DEV pods still on the PROD node after the taint | They were already there; `NoSchedule` does not evict | Restart them, or use `NoExecute` |
| The toleration has no effect | A typo in key, value or effect, or `Equal` without a value | Compare the toleration with `kubectl describe node` |

## For the exam

- `kubectl taint node NAME key=value:Effect`; remove with the same text and a `-` at the end.
- Tolerations go in the pod spec (`spec.template.spec.tolerations` in a Deployment). Copy one from `kubectl explain pod.spec.tolerations` or the documentation page "Taints and Tolerations".
- "Schedule a pod on the control plane node" means: tolerate `node-role.kubernetes.io/control-plane:NoSchedule` (and, usually, select the node).
- `kubectl describe node NAME | grep Taints` is the fastest way to see a node's taints.

## Check your understanding

1. What is the difference between a taint and node affinity?
2. A node gets a `NoSchedule` taint. What happens to the pods already on it?
3. Why did the PROD frontend move off `minikube-m03` in Step 4?
4. Does a toleration make a pod run on the tainted node?
5. Which taint does Kubernetes use to move pods away from a node that died?

<details><summary>Answers</summary>

1. A taint is set on the node and keeps pods away; node affinity is set on the pod and draws it to nodes.
2. Nothing: they keep running. Only new pods are kept out.
3. It had no toleration yet, so the taint kept it out, and its affinity was only a preference.
4. No. It only allows it; affinity or a selector decides where it goes.
5. `node.kubernetes.io/unreachable` or `not-ready`, with the effect `NoExecute`.

</details>

**Back to:** [Lab 4.3](./lab-4.3-taints-and-tolerations.md) · **Next:** [Lab 5.1 explained](../05-security/lab-5.1-authentication-authorization-rbac-explained.md)
