# Lab 4.1 explained: node selectors

This page goes with [Lab 4.1](./lab-4.1-node-selectors.md). The lab has the commands; this page explains them: what happens in the cluster, why it matters for the Shop, what usually goes wrong, and what the exam asks. There is nothing to paste here.

## In short

The **scheduler** picks a node for every new pod. A **nodeSelector** on a pod limits that choice to nodes with certain labels. You label `minikube-m03` as the PROD node and give the PROD frontend a nodeSelector, so its pods only run there. A nodeSelector is a hard rule: if no node matches, the pod waits, `Pending`.

## The ideas behind this lab

### How the scheduler chooses a node

For every pod without a node, the scheduler runs two rounds:

1. **Filter:** drop every node that cannot run the pod: not enough free CPU or memory (against the pod's requests), a nodeSelector or required affinity that does not match, a taint the pod does not tolerate (Lab 4.3), a port already in use, a volume that cannot be attached there.
2. **Score:** rank the nodes that are left: spread pods of the same Deployment, prefer nodes that match preferred affinity (Lab 4.2), balance the use of resources, prefer nodes that already have the image.

The best node wins, and the scheduler writes its name into the pod (`spec.nodeName`). The kubelet on that node does the rest. If the filter leaves **no** node, the pod stays `Pending` and the scheduler records a `FailedScheduling` event saying why, node by node.

### Node labels

Nodes carry labels like any object. Some come by themselves:

| Label | Example | Set by |
| --- | --- | --- |
| `kubernetes.io/hostname` | `minikube-m03` | The kubelet |
| `kubernetes.io/os`, `kubernetes.io/arch` | `linux`, `amd64` or `arm64` | The kubelet |
| `node-role.kubernetes.io/...` | `worker`, `control-plane` | kubeadm, or you |
| `topology.kubernetes.io/zone` | `eu-west-1a` | Cloud providers |

Your own labels (here `env=prod`) describe purpose or hardware: `disk=ssd`, `gpu=true`.

### nodeSelector

`nodeSelector` lists labels the node **must** have, all of them. It is the simplest placement rule: easy to read, and exactly as strict as it looks. Affinity (Lab 4.2) can say more: "one of these values", "not this value", "preferably".

### It only works one way

A nodeSelector pulls **PROD pods to** the PROD node. It does **not** keep other pods **off** it: DEV and UAT pods may still land on `minikube-m03`. Lab 4.3 adds that half with a taint.

## Step by step

### Step 1: see where the PROD pods run now

The PROD pods are spread over the nodes, wherever the scheduler put them in Lab 1.9 or after later restarts.

### Step 2: label the node

`kubectl label node minikube-m03 env=prod` adds the label; `kubectl get nodes -L env` adds a column for it. Labelling a node moves nothing: it is only information until a pod asks for it.

### Step 3: look at the node selector

The file is a **patch**, not a whole Deployment: only the lines to add, at the right place (`spec.template.spec.nodeSelector`). The nodeSelector goes in the **pod template**, because it is the pods that get placed, not the Deployment.

### Step 4: send the PROD frontend to that node

`kubectl patch --patch-file` merges the file into the live Deployment. The pod template changed, so the Deployment rolls out new pods (Lab 1.8), and for each new pod the scheduler's filter leaves only `minikube-m03`. When the rollout is done, both frontend pods run there. Old pods are only replaced because the template changed; a nodeSelector added to a node or pod later never moves pods that already run.

### Step 5: what if no node has the label?

The test pod asks for `env=moon`. Every node fails the filter, so the pod stays `Pending`, and the event says `0/3 nodes are available: 3 node(s) didn't match Pod's node affinity/selector`. That message format (how many nodes, and why each group was dropped) is the same for every scheduling problem.

`--overrides` lets `kubectl run` add fields it has no option for, as JSON merged into the pod.

### The risk of a hard rule

If `minikube-m03` is drained or breaks, the PROD frontend's new pods have nowhere to go and stay `Pending`. Lab 4.2 replaces the hard rule with a preference.

## When something goes wrong

| What you see | What it means | What to do |
| --- | --- | --- |
| Pods `Pending`, event says `didn't match Pod's node affinity/selector` | No node has the label, or the value is spelled differently | `kubectl get nodes --show-labels`; fix the label or the selector |
| The pods did not move after labelling the node | Labels do not move running pods | Change the pod template (or `rollout restart`) to get new pods |
| `Insufficient cpu` or `Insufficient memory` in the event | The matching node is full | Free room on it, or allow more nodes |
| DEV pods also run on the PROD node | A nodeSelector does not keep others away | Taints (Lab 4.3) |

## For the exam

- `kubectl label node NAME key=value`, `kubectl label node NAME key-` (remove), `kubectl get nodes --show-labels` or `-L key`.
- nodeSelector goes in the pod spec: `spec.nodeSelector` in a Pod, `spec.template.spec.nodeSelector` in a Deployment.
- For a `Pending` pod, read the `FailedScheduling` event: it names the reason for every group of nodes.
- `kubernetes.io/hostname` is a ready-made label for "this exact node".

## Check your understanding

1. In which two rounds does the scheduler choose a node?
2. You label a node `env=prod`. What happens to the pods already on it, and to PROD pods elsewhere?
3. Where in a Deployment does the nodeSelector go, and why there?
4. A pod is `Pending` with `0/3 nodes are available: 3 node(s) didn't match Pod's node affinity/selector`. What do you check?
5. Does the nodeSelector keep DEV pods off `minikube-m03`?

<details><summary>Answers</summary>

1. Filter (which nodes can run it) and score (which of those is best).
2. Nothing happens to running pods. Only new pods are placed by the label.
3. In the pod template, `spec.template.spec.nodeSelector`: pods are placed, not Deployments.
4. The node labels (`kubectl get nodes --show-labels`) against the pod's selector: a missing label or a different value.
5. No. It only draws PROD pods to the node; keeping others away needs a taint.

</details>

**Back to:** [Lab 4.1](./lab-4.1-node-selectors.md) · **Next:** [Lab 4.2 explained](./lab-4.2-affinity-and-anti-affinity-explained.md)
