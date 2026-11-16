# Lab 1.2: Pods, labels and selectors: the backend runs for the first time

**The situation:** The Shop starts with its backend: the program that answers the web page's questions.

**Goal:** run the first part of the Shop, the **backend**, as one pod in `dev`.

**Outline topic:** 1. Core concepts: *Pods, Labels, Selectors*.

**What you learn:** pods, YAML files, labels, selectors, logs, `describe`.

📘 **More detail:** [Lab 1.2 explained](./lab-1.2-pods-labels-selectors-explained.md): what happens in the cluster at each step, common mistakes and exam notes.

A **pod** is the smallest thing Kubernetes runs: one container (sometimes more) with its own IP address.

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
cd ~/CKA/scenario-labs/01-core-concepts
kubectl config set-context --current --namespace=dev
```

**What this does:**

- `cd ~/CKA/scenario-labs/01-core-concepts`: Goes to the folder `~/CKA/scenario-labs/01-core-concepts`.
- `kubectl config set-context --current --namespace=dev`: Makes `dev` your working namespace: commands without `-n` now work in `dev`.

**👀 You should see** *(do not paste)*:

```text
Context "minikube" modified.
```

💡 **Tip:** `kubens dev` does the same as the second line (see the shortcuts in [setup, Step 5](../00-setup.md)).

## Step 1: look at the file

**📋 Copy and paste into your terminal:**

```bash
cat backend-pod.yaml
```

**What this does:** Shows what is in the file `backend-pod.yaml`.

**👀 You should see** *(do not paste)*:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: backend
  labels:
    app: backend
spec:
  containers:
  - name: backend
    image: postgrest/postgrest:v12.2.3
    ports:
    - containerPort: 3000
```

| Line | Meaning |
| --- | --- |
| `kind: Pod` | What you want to create |
| `name: backend` | Its name |
| `labels: app: backend` | A sticker on the pod. Other objects find the pod by this sticker. |
| `image:` | The program to run |
| `containerPort: 3000` | The port the program listens on |

## Step 2: create the pod

**📋 Copy and paste into your terminal:**

```bash
kubectl apply -f backend-pod.yaml
```

**What this does:** Creates (or updates) what is described in `backend-pod.yaml`.

**👀 You should see** *(do not paste)*:

```text
pod/backend created
```

## Step 3: watch it start

**📋 Copy and paste into your terminal:**

```bash
kubectl get pods -o wide
```

**What this does:** Lists the pods, with extra columns such as the IP address and the node.

**👀 You should see** (after about 30 seconds; run the command again if it says `ContainerCreating`) *(do not paste)*:

```text
NAME      READY   STATUS    RESTARTS   AGE   IP               NODE           NOMINATED NODE   READINESS GATES
backend   1/1     Running   0          32s   10.244.205.193   minikube-m02   <none>           <none>
```

- `STATUS Running`: the program runs.
- `IP`: the pod's own address inside the cluster.
- `NODE`: the scheduler chose this node.

## Step 4: read the logs

**📋 Copy and paste into your terminal:**

```bash
kubectl logs backend | head -3 | cut -c1-120
```

**What this does:** Shows the log (what the program printed) of the pod `backend`. `| head` shows only the first 3 lines; `| cut` keeps only part of each line.

**👀 You should see** *(do not paste)*:

```text
13/Nov/2026:01:17:28 +0000: Starting PostgREST 12.2.3 (519615d)...
13/Nov/2026:01:17:28 +0000: Listening on port 3000
13/Nov/2026:01:17:28 +0000: Failed listening for notifications on the "pgrst" channel. Just "connection to server on
```

The backend started and listens on port 3000. It also complains: **it cannot find a database**. That is correct. There is no database yet. You add it in Lab 1.6.

## Step 5: look at the labels

**📋 Copy and paste into your terminal:**

```bash
kubectl get pods --show-labels
```

**What this does:** Lists the pods, with their labels.

**👀 You should see** *(do not paste)*:

```text
NAME      READY   STATUS    RESTARTS   AGE   LABELS
backend   1/1     Running   0          32s   app=backend
```

Find pods by their label. `-l app=backend` is a **selector**: it selects the pods that have this label.

**📋 Copy and paste into your terminal:**

```bash
kubectl get pods -l app=backend
```

**What this does:** Lists the pods with the label `app=backend`.

**👀 You should see** *(do not paste)*:

```text
NAME      READY   STATUS    RESTARTS   AGE
backend   1/1     Running   0          45s
```

## Step 6: look at all the details

**📋 Copy and paste into your terminal:**

```bash
kubectl describe pod backend
```

**What this does:** Shows all the details of the pod `backend`. The events at the bottom say what happened to it.

Look for these lines in the long answer: `Node:`, `IP:`, `Image:` and, at the bottom, `Events:`. The events tell you what happened to the pod, step by step. When a pod does not start, look here first.

## Step 7: delete the pod

**📋 Copy and paste into your terminal:**

```bash
kubectl delete pod backend
```

**What this does:** Deletes the pod `backend`.

**👀 You should see** *(do not paste)*:

```text
pod "backend" deleted from dev namespace
```

**📋 Copy and paste into your terminal:**

```bash
kubectl get pods
```

**What this does:** Lists the pods.

**👀 You should see** *(do not paste)*:

```text
No resources found in dev namespace.
```

The pod is gone, and nothing brings it back. A pod on its own is not safe. The next lab fixes that.

💡 **Tip:** two shortcuts that `setup.sh` already set up for you:

- Type `k` instead of `kubectl`: `k get pods` is the same as `kubectl get pods`.
- Press **Tab** to finish a word: type `kubectl get po` and press Tab, or `kubectl describe pod back` and press Tab.

💡 **Tip:** `kubectl explain pod.spec.containers` explains every field you can put in a container, without leaving the terminal.

💡 **Exam tip:** you can also create a pod without a file. This writes the YAML for you, so you never start from an empty file:

**📋 Copy and paste into your terminal:**

```bash
kubectl run backend --image=postgrest/postgrest:v12.2.3 --port=3000 --dry-run=client -o yaml
```

**What this does:** Starts one pod called `backend` from the image `postgrest/postgrest:v12.2.3`.

✅ **Check:** you saw the pod `Running`, read its logs, and deleted it.

**Next:** [Lab 1.3: Deployments](./lab-1.3-deployments.md)
