# Lab 2.3 explained: standalone pods and static pods

This page goes with [Lab 2.3](./lab-2.3-standalone-pods.md). The lab has the commands; this page explains them: what happens in the cluster, why it matters for the Shop, what usually goes wrong, and what the exam asks. There is nothing to paste here.

## In short

Most pods are made and looked after by a controller. A **standalone pod** has no owner: handy for a quick test, gone for good when deleted. A **static pod** is started by one node's kubelet from a file on that node, without the API server; the API server only shows a read-only **mirror** of it. The control plane itself runs as static pods.

## The ideas behind this lab

### Three kinds of pods

| Kind | Made by | Looked after by | You see it with `kubectl` as |
| --- | --- | --- | --- |
| Pod of a Deployment | The ReplicaSet controller | The ReplicaSet: replaced if it dies | A normal pod with an owner |
| Standalone pod | You (`kubectl run`, a Pod YAML) | Nobody | A normal pod without an owner |
| Static pod | The kubelet, from a file on the node | That kubelet: restarted if it dies | A **mirror pod**, named `<name>-<node>` |

### Owner references

Every pod made by a controller carries an **owner reference**: a field in its metadata that names its owner (`ReplicaSet backend-c5d9479f`). The ReplicaSet in turn has an owner reference to its Deployment. Owner references do two jobs:

- the controller knows which pods are its own;
- **garbage collection**: delete the Deployment, and Kubernetes deletes the ReplicaSets and pods it owns.

A standalone pod has none, so nothing replaces it, and nothing cleans it up but you.

### Static pods and mirror pods

The kubelet watches a folder on its node (on kubeadm and minikube: `/etc/kubernetes/manifests`, set by `staticPodPath` in `/var/lib/kubelet/config.yaml`). For every pod file it finds, it runs that pod itself. It then tells the API server about it by creating a **mirror pod**, so that `kubectl get pods` can show it. The mirror is only a picture: deleting it with `kubectl` does not stop the real pod, and the kubelet simply makes the mirror again.

This is how the control plane starts before there is an API server to ask, and why `kube-apiserver-minikube` ends in the node's name.

## Step by step

### Step 1: start a toolbox pod

`kubectl run toolbox --image=busybox:1.36 -- sleep 3600` makes one pod with no controller. `busybox` is a tiny image full of small tools (`wget`, `nslookup`, `sh`). The command `sleep 3600` keeps it alive for an hour, so you can run things inside it. `kubectl wait --for=condition=Ready` waits for the pod instead of guessing with `sleep`.

### Step 2: use it

`kubectl exec toolbox -- wget -q -O- http://backend:3000/items` asks the backend from inside the cluster, through its Service, without touching the Shop's Deployments. This is the main use of a toolbox pod: testing names, Services and network rules from the inside. busybox has `wget`, not `curl`.

### Step 3: who owns the pods?

`-o custom-columns=...:.metadata.ownerReferences[0].kind` prints one field of each pod. The Shop's pods are owned by ReplicaSets; the toolbox by nobody.

### Step 4: delete it

`--now` deletes at once instead of waiting for the usual grace period. The toolbox is gone for good, which is fine for a test pod and fatal for an application.

### Step 5: put a pod file on a worker node

`minikube ssh -n minikube-m02` opens a shell on the worker. The pod file is written into the kubelet's static pod folder with `sudo tee`, because the folder belongs to `root`. There is no `namespace` in the file, so the mirror pod appears in `default`.

### Step 6: see the pod appear

The kubelet checks its folder regularly; within seconds it starts the pod and creates the mirror pod `static-web-minikube-m02` (the pod name plus the node name). No `kubectl apply` was involved: the API server only learned about the pod afterwards.

### Step 7: try to delete it

`kubectl delete` removes the mirror pod, but the real pod keeps running on the node, and the kubelet recreates the mirror. After 10 seconds it is listed again.

### Step 8: remove it the right way: remove the file

Deleting the file is the only way. The kubelet notices, stops the pod, and removes the mirror. The same is true for the control plane: to change the API server's settings, you edit its file on the control plane node, and the kubelet restarts it.

## When something goes wrong

| What you see | What it means | What to do |
| --- | --- | --- |
| The static pod never appears | The file is in the wrong folder, or has a YAML error | `sudo grep staticPodPath /var/lib/kubelet/config.yaml` on the node; check the file |
| A static pod comes back after `kubectl delete` | That is what static pods do | Remove the file on the node |
| `exec: "curl": executable file not found` in busybox | busybox has no `curl` | Use `wget -q -O-` |
| The toolbox is `Completed` after an hour | `sleep 3600` ended | Delete it and start a new one |

## For the exam

- "Create a static pod on node X": find the folder (`staticPodPath` in `/var/lib/kubelet/config.yaml` on that node), and write the pod file there, **on that node** (ssh to it). Writing it on the control plane does nothing for node X.
- `kubectl run NAME --image=IMAGE --dry-run=client -o yaml` gives you a pod file to copy into the static pod folder.
- A pod whose name ends in a node name is usually a static pod.
- `kubectl run tmp --rm -it --image=busybox:1.36 --restart=Never -- sh` gives a throwaway shell inside the cluster for testing.

## Check your understanding

1. What happens when a standalone pod's node fails?
2. What are owner references used for?
3. Why can the API server run in a pod?
4. You delete a mirror pod with `kubectl`. What happens to the real pod?
5. How do you change a setting of the kube-scheduler on a kubeadm cluster?

<details><summary>Answers</summary>

1. It is gone; nothing replaces it.
2. Controllers find their own pods by them, and garbage collection deletes owned objects when the owner is deleted.
3. It is a static pod: the kubelet starts it from a file on the node, without needing the API server.
4. Nothing: it keeps running, and the kubelet recreates the mirror.
5. Edit `/etc/kubernetes/manifests/kube-scheduler.yaml` on the control plane node; the kubelet restarts the scheduler with the new settings.

</details>

**Back to:** [Lab 2.3](./lab-2.3-standalone-pods.md) · **Next:** [Lab 2.4 explained](./lab-2.4-control-plane-high-availability-explained.md)
