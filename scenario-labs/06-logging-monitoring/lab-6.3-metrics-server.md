# Lab 6.3: Metrics Server: measure the Shop, and let it grow by itself

**The situation:** the logs say **what** happened. They do not say **how much** CPU and memory the Shop uses. And when the Shop is busy, somebody has to add pods by hand (Lab 3.2).

**Goal:** measure the CPU and memory of the Shop, and let Kubernetes add backend pods by itself when the Shop is busy.

**Outline topic:** Logging / Monitoring: *Metrics Server*.

**What you learn:** Metrics Server, `kubectl top`, CPU requests, the HorizontalPodAutoscaler (HPA).

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
cd ~/CKA/scenario-labs/06-logging-monitoring
kubectl config set-context --current --namespace=dev
```

**What this does:**

- `cd ~/CKA/scenario-labs/06-logging-monitoring`: Goes to the folder `~/CKA/scenario-labs/06-logging-monitoring`.
- `kubectl config set-context --current --namespace=dev`: Makes `dev` your working namespace: commands without `-n` now work in `dev`.

**👀 You should see** *(do not paste)*:

```text
Context "minikube" modified.
```

💡 **Tip:** `kubens dev` does the same as the second line (see the shortcuts in [setup, Step 5](../00-setup.md)).

## Step 1: switch on the Metrics Server

The Metrics Server measures the CPU and memory of every pod and node.

**📋 Copy and paste into your terminal:**

```bash
minikube addons enable metrics-server
```

**What this does:** Switches on the minikube add-on `metrics-server`.

**👀 You should see** (the last line) *(do not paste)*:

```text
* The 'metrics-server' addon is enabled
```

Wait one minute for the first measurements. Then:

**📋 Copy and paste into your terminal:**

```bash
kubectl top nodes
kubectl top pods
```

**What this does:**

- `kubectl top nodes`: Shows how much CPU and memory the nodes use right now.
- `kubectl top pods`: Shows how much CPU and memory the pods use right now.

**👀 You should see** (your numbers differ) *(do not paste)*:

```text
NAME           CPU(cores)   CPU(%)   MEMORY(bytes)   MEMORY(%)
minikube       428m         10%      1114Mi          22%
minikube-m02   207m         5%       781Mi           15%
minikube-m03   248m         6%       380Mi           7%
NAME                        CPU(cores)   MEMORY(bytes)
backend-c5d9479f-j422x      3m           11Mi
backend-c5d9479f-rslxf      2m           7Mi
db-6df5dcf549-wqt4q         2m           36Mi
frontend-77994594d8-5s89x   0m           4Mi
frontend-77994594d8-n9nzj   0m           5Mi
```

If it says `error: Metrics API not available`, the Metrics Server is still starting. Wait one minute and try again.

## Step 2: tell Kubernetes what the backend needs

The numbers above say what the backend **uses**. An autoscaler also has to know what is **normal** for it. That is the CPU **request**: what one backend pod needs for sure.

**📋 Copy and paste into your terminal:**

```bash
kubectl set resources deployment backend --requests=cpu=50m,memory=64Mi --limits=cpu=200m,memory=128Mi
kubectl rollout status deployment/backend
```

**What this does:**

- `kubectl set resources deployment ...`: Sets the CPU and memory requests and limits of the Deployment `backend`.
- `kubectl rollout status deployment/backend`: Waits until the new pods of the Deployment `backend` are all ready, and says when it is done.

**👀 You should see** *(do not paste)*:

```text
deployment.apps/backend resource requirements updated
deployment "backend" successfully rolled out
```

`50m` means 50 millicores: one twentieth of one CPU. The **limit** is the most the pod may use. (More about requests and limits in Lab 7.4.)

## Step 3: create the autoscaler

The **HorizontalPodAutoscaler** (HPA) looks at how much CPU the pods use, compared with their CPU request. Too high: it adds pods. Low again: it removes them.

**📋 Copy and paste into your terminal:**

```bash
cat backend-hpa.yaml
```

**What this does:** Shows what is in the file `backend-hpa.yaml`.

**👀 You should see** *(do not paste)*:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: backend
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: backend
  minReplicas: 2
  maxReplicas: 5
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 25
```

In words: keep between **2 and 5** backend pods, and aim for **25%** of the CPU request on average.

**📋 Copy and paste into your terminal:**

```bash
kubectl apply -f backend-hpa.yaml
sleep 30
kubectl get hpa
```

**What this does:**

- `kubectl apply -f backend-hpa.yaml`: Creates (or updates) what is described in `backend-hpa.yaml`.
- `sleep 30`: Waits 30 seconds, to give Kubernetes time.
- `kubectl get hpa`: Lists the autoscalers (HPA).

**👀 You should see** *(do not paste)*:

```text
NAME      REFERENCE            TARGETS       MINPODS   MAXPODS   REPLICAS   AGE
backend   Deployment/backend   cpu: 4%/25%   2         5         2          30s
```

`4%/25%`: the backend uses 4% now, the target is 25%. Nothing to do, so 2 pods. If it shows `<unknown>`, the Metrics Server has no numbers yet: wait one minute and look again.

## Step 4: make the Shop busy

This pod asks the Shop for the items, again and again, without stopping. It goes through the frontend, as a real user does.

**📋 Copy and paste into your terminal:**

```bash
kubectl run load --image=busybox:1.36 --restart=Never -- /bin/sh -c "while true; do wget -q -O- http://frontend/api/items > /dev/null; sleep 0.02; done"
```

**What this does:** Starts a pod called `load` that asks the Shop for its items again and again, without stopping. This makes the backend busy.

**👀 You should see** *(do not paste)*:

```text
pod/load created
```

## Step 5: watch the backend grow

Wait about two minutes. Then look:

**📋 Copy and paste into your terminal:**

```bash
kubectl get hpa
kubectl get pods -l app=backend
```

**What this does:**

- `kubectl get hpa`: Lists the autoscalers (HPA).
- `kubectl get pods -l app=backend`: Lists the pods with the label `app=backend`.

**👀 You should see** the CPU above the target, and more than 2 pods (your numbers differ) *(do not paste)*:

```text
NAME      REFERENCE            TARGETS        MINPODS   MAXPODS   REPLICAS   AGE
backend   Deployment/backend   cpu: 33%/25%   2         5         4          3m17s
NAME                      READY   STATUS    RESTARTS   AGE
backend-c979559bb-m89cs   1/1     Running   0          62s
backend-c979559bb-rbq7w   1/1     Running   0          62s
backend-c979559bb-svbvp   1/1     Running   0          3m24s
backend-c979559bb-wg9l4   1/1     Running   0          3m32s
```

Run the two commands again every 30 seconds to follow it.

## Step 6: stop the load

**📋 Copy and paste into your terminal:**

```bash
kubectl delete pod load --now
```

**What this does:** Deletes the pod `load`, at once.

**👀 You should see** *(do not paste)*:

```text
pod "load" deleted from dev namespace
```

The HPA waits **5 minutes** before it removes pods, so that it does not go up and down all the time. You do not have to wait: go on with the next lab, and look again later with `kubectl get hpa`. It will be back at 2.

💡 **Exam tip:** one line creates the same autoscaler:

**📖 Read only (do not paste):**

```text
kubectl autoscale deployment backend --min=2 --max=5 --cpu-percent=25
```

An HPA only works when the pods have a CPU **request**. Without it, `TARGETS` stays `<unknown>`.

✅ **Check:** you saw `REPLICAS` go above 2 while the load ran, and you deleted the `load` pod.

**Next:** [Lab 6.4: Prometheus](./lab-6.4-prometheus.md)
