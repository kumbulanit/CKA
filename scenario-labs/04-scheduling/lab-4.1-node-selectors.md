# Lab 4.1: Node selectors: send PROD to its own node

**The situation:** PROD shares its nodes with DEV and UAT. A test in DEV that eats all the CPU would slow down real users. PROD should get its own node: `minikube-m03`.

**Goal:** make the PROD frontend run only on `minikube-m03`.

**Outline topic:** 4. Scheduling: *Node selectors*.

**What you learn:** how the scheduler chooses a node, node labels, `nodeSelector`.

📘 **More detail:** [Lab 4.1 explained](./lab-4.1-node-selectors-explained.md): what happens in the cluster at each step, common mistakes and exam notes.

The **scheduler** chooses a node for every new pod. By default it picks any node with enough room. A **nodeSelector** on the pod says: only nodes with this label.

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
cd ~/CKA/scenario-labs/04-scheduling
kubectl config set-context --current --namespace=dev
```

**What this does:**

- `cd ~/CKA/scenario-labs/04-scheduling`: Goes to the folder `~/CKA/scenario-labs/04-scheduling`.
- `kubectl config set-context --current --namespace=dev`: Makes `dev` your working namespace: commands without `-n` now work in `dev`.

**👀 You should see** *(do not paste)*:

```text
Context "minikube" modified.
```

💡 **Tip:** `kubens dev` does the same as the second line (see the shortcuts in [setup, Step 5](../00-setup.md)).

## Step 1: see where the PROD pods run now

**📋 Copy and paste into your terminal:**

```bash
kubectl get pods -n prod -o wide
```

**What this does:** Lists the pods in the namespace `prod`, with extra columns such as the IP address and the node.

**👀 You should see** the PROD pods spread over the nodes, wherever the scheduler found room.

## Step 2: label the node

**📋 Copy and paste into your terminal:**

```bash
kubectl label node minikube-m03 env=prod
kubectl get nodes -L env
```

**What this does:**

- `kubectl label node minikube-m03 env=prod`: Puts the label `env=prod` on the node `minikube-m03`.
- `kubectl get nodes -L env`: Lists the nodes, with a column for the label `env`.

**👀 You should see** *(do not paste)*:

```text
node/minikube-m03 labeled
NAME           STATUS   ROLES           AGE    VERSION   ENV
minikube       Ready    control-plane   6h8m   v1.36.5
minikube-m02   Ready    worker          6h7m   v1.36.5
minikube-m03   Ready    worker          6h7m   v1.36.5   prod
```

![The node minikube-m03 has the label env=prod](../images/node-label.png)

## Step 3: look at the node selector

**⌨️ Command line option** *(read only: the same as the YAML below, made with a command)*:

```bash
kubectl patch deployment frontend -n prod -p '{"spec":{"template":{"spec":{"nodeSelector":{"env":"prod"}}}}}'
```

**What this does:**

- `kubectl patch deployment frontend -n prod -p '...'`: The same patch, written on the command line as JSON instead of in a file.

💡 For a single pod, `kubectl run` takes it too: `--overrides='{"spec":{"nodeSelector":{"env":"prod"}}}'` (you use this in Step 5).

**📋 Copy and paste into your terminal:**

```bash
cat prod-node-selector.yaml
```

**What this does:** Shows what is in the file `prod-node-selector.yaml`.

**👀 You should see** *(do not paste)*:

```yaml
# run only on nodes with the label env=prod
spec:
  template:
    spec:
      nodeSelector:
        env: prod
```

This small file is a **patch**: it adds these lines to a Deployment that is already there.

## Step 4: send the PROD frontend to that node

**📋 Copy and paste into your terminal:**

```bash
kubectl patch deployment frontend -n prod --patch-file prod-node-selector.yaml
kubectl rollout status deployment/frontend -n prod
kubectl get pods -n prod -l app=frontend -o wide
```

**What this does:**

- `kubectl patch deployment frontend ...`: Changes the Deployment `frontend` in the namespace `prod`: adds the lines of the file `prod-node-selector.yaml` to it.
- `kubectl rollout status deployment/frontend -n prod`: Waits until the new pods of the Deployment `frontend` in the namespace `prod` are all ready, and says when it is done.
- `kubectl get pods -n prod -l app=frontend -o wide`: Lists the pods with the label `app=frontend` in the namespace `prod`, with extra columns such as the IP address and the node.

**👀 You should see** both frontend pods on `minikube-m03` *(do not paste)*:

```text
NAME                       READY   STATUS    RESTARTS   AGE   IP              NODE           NOMINATED NODE   READINESS GATES
frontend-f44f64b75-kwm4s   1/1     Running   0          39s   10.244.151.31   minikube-m03   <none>           <none>
frontend-f44f64b75-rr6w4   1/1     Running   0          13s   10.244.151.32   minikube-m03   <none>           <none>
```

The Deployment made new pods, and the scheduler had only one node to choose from.

## Step 5: what if no node has the label?

Try it with a test pod that asks for a label no node has:

**📋 Copy and paste into your terminal:**

```bash
kubectl run nowhere -n dev --image=busybox:1.36 --overrides='{"spec":{"nodeSelector":{"env":"moon"}}}' -- sleep 3600
sleep 5
kubectl get pod nowhere -n dev
```

**What this does:**

- `kubectl run nowhere -n ...`: Starts one pod called `nowhere` in the namespace `dev` from the image `busybox:1.36`, which runs `sleep 3600`, with the extra settings given in `--overrides`.
- `sleep 5`: Waits 5 seconds, to give Kubernetes time.
- `kubectl get pod nowhere -n dev`: Lists the pod `nowhere` in the namespace `dev`.

**👀 You should see** *(do not paste)*:

```text
NAME      READY   STATUS    RESTARTS   AGE
nowhere   0/1     Pending   0          5s
```

`Pending` means: the scheduler found no node. Ask why:

**📋 Copy and paste into your terminal:**

```bash
kubectl describe pod nowhere -n dev | tail -3
```

**What this does:** Shows all the details of the pod `nowhere` in the namespace `dev`. The events at the bottom say what happened to it. `| tail` shows only the last 3 lines.

**👀 You should see** (one long line that says) *(do not paste)*:

```text
Warning  FailedScheduling  ...  0/3 nodes are available: 3 node(s) didn't match Pod's node affinity/selector.
```

🧹 **Clean up:**

**📋 Copy and paste into your terminal:**

```bash
kubectl delete pod nowhere -n dev --now
```

**What this does:** Deletes the pod `nowhere` in the namespace `dev`, at once.

A node selector is a **hard rule**. That is its strength, and its risk: if `minikube-m03` breaks, the PROD frontend has nowhere to go. The next lab makes that softer.

💡 **Exam tip:** every node already has useful labels. See them with `kubectl get nodes --show-labels`. The label `kubernetes.io/hostname` is the node's name.

✅ **Check:** both PROD frontend pods run on `minikube-m03`.

## More practice

The Shop part of the lab is done. These exercises use small test pods in `dev`, and each one cleans up after itself, so the Shop stays as it is.

### 🟡 Practice 1: skip the scheduler with `nodeName`

A pod with `nodeName` is not scheduled at all: it goes straight to that node's kubelet.

**📋 Copy and paste into your terminal:**

```bash
kubectl run pinned -n dev --image=busybox:1.36 --overrides='{"spec":{"nodeName":"minikube-m02"}}' -- sleep 3600
sleep 5
kubectl get pod pinned -n dev -o wide
kubectl get events -n dev --field-selector involvedObject.name=pinned | grep -c Scheduled
```

**What this does:**

- `kubectl run pinned ... --overrides='{"spec":{"nodeName":"minikube-m02"}}'`: Starts the pod `pinned` with `nodeName: minikube-m02` already filled in.
- `sleep 5`: Waits 5 seconds, to give Kubernetes time.
- `kubectl get pod pinned -n dev -o wide`: Shows the pod and its node.
- `kubectl get events ... | grep -c Scheduled`: Counts the `Scheduled` events of the pod. The scheduler writes one each time it places a pod.

**👀 You should see** the pod `Running` on `minikube-m02`, and the count `0`: the scheduler never touched this pod.

| | `nodeSelector` | `nodeName` |
| --- | --- | --- |
| Who chooses | The scheduler, among the nodes with the label | You, by name |
| If the node is full or gone | `Pending`, with a reason in `describe` | The kubelet refuses it, or it waits forever |
| Used for | Normal work | Tests and emergencies only |

### 🟡 Practice 2: use a label every node already has

You do not always need your own label. Every node has `kubernetes.io/hostname`:

**📋 Copy and paste into your terminal:**

```bash
kubectl get nodes -L kubernetes.io/hostname,kubernetes.io/os
kubectl run by-hostname -n dev --image=busybox:1.36 --overrides='{"spec":{"nodeSelector":{"kubernetes.io/hostname":"minikube"}}}' -- sleep 3600
sleep 5
kubectl get pod by-hostname -n dev -o wide
```

**What this does:**

- `kubectl get nodes -L ...`: Lists the nodes with two extra columns: the labels `kubernetes.io/hostname` and `kubernetes.io/os`.
- `kubectl run by-hostname ...`: Starts a pod with the node selector `kubernetes.io/hostname=minikube`.
- `sleep 5`: Waits 5 seconds, to give Kubernetes time.
- `kubectl get pod by-hostname -n dev -o wide`: Shows the pod and its node.

**👀 You should see** the pod on the node `minikube`. Unlike `nodeName`, this went through the scheduler: it still checks room, taints and the rest.

### 🟡 Practice 3: fix a `Pending` pod by labelling a node

A `Pending` pod is not lost: the scheduler tries again when the cluster changes.

**📋 Copy and paste into your terminal:**

```bash
kubectl run wants-ssd -n dev --image=busybox:1.36 --overrides='{"spec":{"nodeSelector":{"disk":"ssd"}}}' -- sleep 3600
sleep 5
kubectl get pod wants-ssd -n dev
```

**What this does:** Starts a pod that wants a node with the label `disk=ssd` (no node has it yet), waits 5 seconds and shows it.

**👀 You should see** `Pending`. Now give a node the label:

**📋 Copy and paste into your terminal:**

```bash
kubectl label node minikube-m02 disk=ssd
sleep 5
kubectl get pod wants-ssd -n dev -o wide
```

**What this does:**

- `kubectl label node minikube-m02 disk=ssd`: Puts the label `disk=ssd` on the node `minikube-m02`.
- `sleep 5`: Waits 5 seconds, to give Kubernetes time.
- `kubectl get pod wants-ssd -n dev -o wide`: Shows the pod and its node.

**👀 You should see** the pod `Running` on `minikube-m02`. You did not touch the pod.

### 🔵 Optional 4: remove the label from under a running pod

What happens to the pod if the label goes away?

**📋 Copy and paste into your terminal:**

```bash
kubectl label node minikube-m02 disk-
sleep 10
kubectl get pod wants-ssd -n dev -o wide
```

**What this does:**

- `kubectl label node minikube-m02 disk-`: Removes the label `disk` from the node (the minus at the end means "remove").
- `sleep 10`: Waits 10 seconds, to give Kubernetes time.
- `kubectl get pod wants-ssd -n dev -o wide`: Shows the pod and its node.

**👀 You should see** the pod still `Running` on `minikube-m02`. The scheduler only looks at the label when it **places** a pod. A pod that runs is not moved. You meet this again in Lab 4.2 as `IgnoredDuringExecution`.

### 🔵 Optional 5: challenge

Without looking at the answer: make a Deployment `ssd-web` in `dev` with 3 pods of `nginx:1.27-alpine` that may run **only** on nodes with the label `disk=ssd`. Then label `minikube` with `disk=ssd` and check that all 3 pods run there.

<details><summary>Show the answer</summary>

**📋 Copy and paste into your terminal:**

```bash
kubectl create deployment ssd-web -n dev --image=nginx:1.27-alpine --replicas=3
kubectl patch deployment ssd-web -n dev -p '{"spec":{"template":{"spec":{"nodeSelector":{"disk":"ssd"}}}}}'
kubectl label node minikube disk=ssd
kubectl rollout status deployment/ssd-web -n dev
kubectl get pods -n dev -l app=ssd-web -o wide
```

**What this does:**

- `kubectl create deployment ssd-web ...`: Creates the Deployment `ssd-web` with 3 pods.
- `kubectl patch deployment ssd-web ...`: Adds the node selector `disk=ssd` to its pods.
- `kubectl label node minikube disk=ssd`: Gives the node `minikube` the label.
- `kubectl rollout status deployment/ssd-web -n dev`: Waits until the new pods are ready.
- `kubectl get pods -n dev -l app=ssd-web -o wide`: Shows the pods and their nodes.

**👀 You should see** all 3 `ssd-web` pods on `minikube`.

In the exam, the quick way is often `kubectl create deployment ... --dry-run=client -o yaml > ssd-web.yaml`, then add the two `nodeSelector` lines in the file, then `kubectl apply -f ssd-web.yaml`.

</details>

🧹 **Clean up the practice:**

**📋 Copy and paste into your terminal:**

```bash
kubectl delete pod pinned by-hostname wants-ssd -n dev --now --ignore-not-found
kubectl delete deployment ssd-web -n dev --ignore-not-found
kubectl label node minikube minikube-m02 disk- 2>/dev/null; true
```

**What this does:**

- `kubectl delete pod pinned by-hostname wants-ssd ...`: Deletes the three test pods, at once. `--ignore-not-found` skips the ones you did not make.
- `kubectl delete deployment ssd-web ...`: Deletes the Deployment of the challenge, if you made it.
- `kubectl label node minikube minikube-m02 disk-`: Removes the label `disk` from both nodes. The rest of the line hides the message for a node that has no such label.

**Next:** [Lab 4.2: Affinity and anti-affinity](./lab-4.2-affinity-and-anti-affinity.md)
