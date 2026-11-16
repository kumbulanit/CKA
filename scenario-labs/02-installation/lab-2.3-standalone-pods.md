# Lab 2.3: Standalone pods: pods without a Deployment

**The situation:** you want to test something in the Shop quickly, without changing its Deployments.

**Goal:** run a pod that belongs to nobody, see how it differs from the Shop's pods, and run a pod straight from a file on a node (a static pod).

**Outline topic:** 2. Installation, Configuration & Validation: *Standalone pods*.

**What you learn:** standalone pods, owner references, static pods and mirror pods.

📘 **More detail:** [Lab 2.3 explained](./lab-2.3-standalone-pods-explained.md): what happens in the cluster at each step, common mistakes and exam notes.

| Kind of pod | Who looks after it | When it dies |
| --- | --- | --- |
| Pod of a **Deployment** | The Deployment (through a ReplicaSet) | A new one is made |
| **Standalone** pod | Nobody | It is gone |
| **Static** pod | The kubelet of **one node**, from a file on that node | The kubelet starts it again |

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
cd ~/CKA/scenario-labs/02-installation
kubectl config set-context --current --namespace=dev
```

**What this does:**

- `cd ~/CKA/scenario-labs/02-installation`: Goes to the folder `~/CKA/scenario-labs/02-installation`.
- `kubectl config set-context --current --namespace=dev`: Makes `dev` your working namespace: commands without `-n` now work in `dev`.

**👀 You should see** *(do not paste)*:

```text
Context "minikube" modified.
```

💡 **Tip:** `kubens dev` does the same as the second line (see the shortcuts in [setup, Step 5](../00-setup.md)).

## Part A: a standalone pod

### Step 1: start a toolbox pod

A standalone pod is handy for a quick test. This one is a toolbox for the Shop:

**📋 Copy and paste into your terminal:**

```bash
kubectl run toolbox -n dev --image=busybox:1.36 -- sleep 3600
kubectl wait pod/toolbox -n dev --for=condition=Ready --timeout=120s
kubectl get pods -n dev
```

**What this does:**

- `kubectl run toolbox -n ...`: Starts one pod called `toolbox` in the namespace `dev` from the image `busybox:1.36`, which runs `sleep 3600`.
- `kubectl wait pod/toolbox -n ...`: Waits until the pod `toolbox` is ready in the namespace `dev`.
- `kubectl get pods -n dev`: Lists the pods in the namespace `dev`.

**👀 You should see** the `toolbox` pod next to the Shop's pods. Look at the names: the Shop's pods have random letters at the end, the standalone pod has exactly the name you gave it.

```text
NAME                        READY   STATUS    RESTARTS   AGE
backend-c5d9479f-j422x      1/1     Running   0          40m
backend-c5d9479f-rslxf      1/1     Running   0          40m
db-6df5dcf549-wqt4q         1/1     Running   0          40m
frontend-77994594d8-5s89x   1/1     Running   0          40m
frontend-77994594d8-n9nzj   1/1     Running   0          40m
toolbox                     1/1     Running   0          8s
```

### Step 2: use it

**📋 Copy and paste into your terminal:**

```bash
kubectl exec toolbox -n dev -- wget -q -O- http://backend:3000/items
```

**What this does:** From inside the toolbox pod, asks the backend for its items, by its name `backend`. `wget -q -O-` does the same as `curl -s`: busybox has no `curl`.

**👀 You should see** the items of the Shop.

### Step 3: who owns the pods?

**📋 Copy and paste into your terminal:**

```bash
kubectl get pods -n dev -o custom-columns=NAME:.metadata.name,OWNER:.metadata.ownerReferences[0].kind
```

**What this does:** Lists the pods in the namespace `dev`, showing only the columns named in the command.

**👀 You should see** *(do not paste)*:

```text
NAME                        OWNER
backend-c5d9479f-j422x      ReplicaSet
backend-c5d9479f-rslxf      ReplicaSet
db-6df5dcf549-wqt4q         ReplicaSet
frontend-77994594d8-5s89x   ReplicaSet
frontend-77994594d8-n9nzj   ReplicaSet
toolbox                     <none>
```

The Shop's pods have an owner. The toolbox has `<none>`.

### Step 4: delete it

**📋 Copy and paste into your terminal:**

```bash
kubectl delete pod toolbox -n dev --now
kubectl get pods -n dev
```

**What this does:**

- `kubectl delete pod toolbox -n dev --now`: Deletes the pod `toolbox` in the namespace `dev`, at once.
- `kubectl get pods -n dev`: Lists the pods in the namespace `dev`.

**👀 You should see** only the five Shop pods. The toolbox does not come back: nobody owns it.

That is why the Shop runs as Deployments, and why you never run a real application as a standalone pod.

## Part B: a static pod

A **static pod** is started by the kubelet of one node, from a YAML file in a folder on that node. No API server is needed. That is how the control plane itself starts (Lab 2.1, Step 3).

### Step 5: put a pod file on a worker node

Open a shell on the node `minikube-m02`:

**📋 Copy and paste into your terminal:**

```bash
minikube ssh -n minikube-m02
```

**What this does:** Opens a shell on the node `minikube-m02`. Your prompt changes; `exit` brings you back.

Your prompt changes to `docker@minikube-m02`. Now, **on the node**:

**📋 Copy and paste into the node's terminal** (your prompt shows `docker@...`)**:**

```bash
sudo mkdir -p /etc/kubernetes/manifests
cat <<'YAML' | sudo tee /etc/kubernetes/manifests/static-web.yaml
apiVersion: v1
kind: Pod
metadata:
  name: static-web
spec:
  containers:
  - name: web
    image: nginx:1.27-alpine
YAML
exit
```

**What this does:**

- `sudo mkdir -p /etc/kubernetes/manifests`: Makes the folder `/etc/kubernetes/manifests`.
- `cat <<'YAML' | sudo ...`: Writes the YAML between the two `YAML` lines into the file `/etc/kubernetes/manifests/static-web.yaml` on this node.
- `exit`: Leaves the node and brings you back to your server.

**👀 You should see** the YAML printed back (`tee` shows what it writes), and then your server's prompt again.

### Step 6: see the pod appear

You did not run `kubectl apply`. The kubelet found the file and started the pod.

**📋 Copy and paste into your terminal:**

```bash
sleep 20
kubectl get pods -n default -o wide
```

**What this does:**

- `sleep 20`: Waits 20 seconds, to give Kubernetes time.
- `kubectl get pods -n default -o wide`: Lists the pods in the namespace `default`, with extra columns such as the IP address and the node.

**👀 You should see** *(do not paste)*:

```text
NAME                      READY   STATUS    RESTARTS   AGE   IP               NODE           NOMINATED NODE   READINESS GATES
static-web-minikube-m02   1/1     Running   0          15s   10.244.205.230   minikube-m02   <none>           <none>
```

The node name is added to the pod name. What you see in `kubectl` is a **mirror pod**: a copy for looking only.

### Step 7: try to delete it

**📋 Copy and paste into your terminal:**

```bash
kubectl delete pod static-web-minikube-m02 -n default --now
sleep 10
kubectl get pods -n default
```

**What this does:**

- `kubectl delete pod static-web-minikube-m02 -n default --now`: Deletes the pod `static-web-minikube-m02` in the namespace `default`, at once.
- `sleep 10`: Waits 10 seconds, to give Kubernetes time.
- `kubectl get pods -n default`: Lists the pods in the namespace `default`.

**👀 You should see** the pod is there again, with a new `AGE`. The kubelet starts it again as long as the file is there.

### Step 8: remove it the right way: remove the file

**📋 Copy and paste into your terminal:**

```bash
minikube ssh -n minikube-m02 -- sudo rm /etc/kubernetes/manifests/static-web.yaml
sleep 20
kubectl get pods -n default
```

**What this does:**

- `minikube ssh -n minikube-m02 ...`: Deletes the file of the static pod on the node `minikube-m02`. The kubelet sees that the file is gone, and stops the pod.
- `sleep 20`: Waits 20 seconds, to give Kubernetes time.
- `kubectl get pods -n default`: Lists the pods in the namespace `default`.

**👀 You should see** *(do not paste)*:

```text
No resources found in default namespace.
```

💡 **Exam tip:** to find the folder for static pods on a node: `sudo grep staticPodPath /var/lib/kubelet/config.yaml`. In the exam, "create a static pod on node01" means: write a YAML file in that folder **on that node**.

✅ **Check:** `kubectl get pods -n default` shows no pods, and `kubectl get pods -n dev` shows the five Shop pods.

**Next:** [Lab 2.4: Control plane high availability](./lab-2.4-control-plane-high-availability.md)
