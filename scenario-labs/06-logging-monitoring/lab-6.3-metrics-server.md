# Lab 6.3: Metrics Server: measure the Shop, and let it grow by itself

**The situation:** the logs say **what** happened. They do not say **how much** CPU and memory the Shop uses. And when the Shop is busy, somebody has to add pods by hand (Lab 3.2).

**Goal:** measure the CPU and memory of the Shop, and let Kubernetes add backend pods by itself when the Shop is busy.

**Outline topic:** Logging / Monitoring: *Metrics Server*.

**What you learn:** Metrics Server, `kubectl top`, CPU requests, the HorizontalPodAutoscaler (HPA).

📘 **More detail:** [Lab 6.3 explained](./lab-6.3-metrics-server-explained.md): what happens in the cluster at each step, common mistakes and exam notes.

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

The Metrics Server needs a minute or more for its first measurements. This box waits for it:

**📋 Copy and paste into your terminal:**

```bash
kubectl wait --for=condition=Available apiservice/v1beta1.metrics.k8s.io --timeout=180s
kubectl top nodes
kubectl top pods
```

**What this does:**

- `kubectl wait --for=condition=Available apiservice/v1beta1.metrics.k8s.io ...`: Waits until the Metrics API answers (at most 3 minutes). The Metrics Server adds its numbers to the API server as an extra API, `metrics.k8s.io`, and that API is only `Available` once the first measurements are in.
- `kubectl top nodes`: Shows how much CPU and memory the nodes use right now.
- `kubectl top pods`: Shows how much CPU and memory the pods use right now.

**👀 You should see** (after about a minute; your numbers differ) *(do not paste)*:

```text
apiservice.apiregistration.k8s.io/v1beta1.metrics.k8s.io condition met
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

**⌨️ Command line option** *(read only: the same as the YAML below, made with a command)*:

```bash
kubectl autoscale deployment backend --min=2 --max=5 --cpu-percent=25
```

**What this does:**

- `kubectl autoscale deployment backend ...`: Creates the autoscaler `backend` for the Deployment `backend`: between 2 and 5 pods, aiming for 25% CPU.

If kubectl says `--cpu-percent` is deprecated, use `--cpu=25%` instead: newer kubectl versions use that name.

💡 Add `--dry-run=client -o yaml` to print the YAML without creating anything. With `> file.yaml` at the end, that is the fastest way to start a YAML file in the exam.

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
kubectl autoscale deployment backend --min=2 --max=5 --cpu=25%
```

Older versions of `kubectl` write it `--cpu-percent=25`. Version v1.36 still accepts that, but warns that it is deprecated.

An HPA only works when the pods have a CPU **request**. Without it, `TARGETS` stays `<unknown>`.

✅ **Check:** you saw `REPLICAS` go above 2 while the load ran, and you deleted the `load` pod.

## More practice

The Shop part of the lab is done. These exercises use test pods in `dev`, and the clean-up at the end removes them.

### 🟡 Practice 1: `kubectl top` like in the exam

A classic exam task: "write the name of the pod that uses the most CPU into a file".

**📋 Copy and paste into your terminal:**

```bash
kubectl top pods -A --sort-by=memory | head -6
kubectl top pods -n prod --containers
kubectl top pods -n kube-system --sort-by=cpu --no-headers | head -1 | awk '{print $1}' > /tmp/top-pod.txt
cat /tmp/top-pod.txt
```

**What this does:**

- `kubectl top pods -A --sort-by=memory | head -6`: Shows the 5 pods of the whole cluster that use the most memory (and the header).
- `kubectl top pods -n prod --containers`: Shows the PROD pods, one line per **container**.
- `kubectl top pods -n kube-system --sort-by=cpu --no-headers | head -1 | awk '{print $1}' > /tmp/top-pod.txt`: Takes the system pod with the most CPU, keeps only its name (`awk '{print $1}'`), and writes it into `/tmp/top-pod.txt`.
- `cat /tmp/top-pod.txt`: Shows what is in the file.

**👀 You should see** the busiest pods first, and one pod name in the file, often `kube-apiserver-minikube`.

### 🟡 Practice 2: why the autoscaler did what it did

**📋 Copy and paste into your terminal:**

```bash
kubectl describe hpa backend | sed -n '/Conditions/,$p'
```

**What this does:** Shows the details of the autoscaler `backend`, from the line `Conditions` to the end.

**👀 You should see** three conditions (`AbleToScale`, `ScalingActive`, `ScalingLimited`), and at the bottom the events of Step 5, such as `New size: 4; reason: cpu resource utilization (percentage of request) above target`. When an autoscaler does not do what you expect, this is the first place to look.

### 🟡 Practice 3: a container that uses more memory than its limit

A **CPU** limit slows a container down. A **memory** limit is hard: go over it, and the container is killed.

**⌨️ Command line option** *(read only: the same as the YAML below, made with commands)*:

```bash
kubectl run memhog -n dev --image=polinux/stress --dry-run=client -o yaml --command -- stress --vm 1 --vm-bytes 100M --vm-hang 1 > memhog.yaml
kubectl set resources -f memhog.yaml --local --requests=memory=25Mi --limits=memory=50Mi -o yaml | kubectl apply -f -
```

**What this does:**

- `kubectl run memhog ... --dry-run=client -o yaml ... > memhog.yaml`: Writes the YAML of the pod into a file, without creating it.
- `kubectl set resources -f memhog.yaml --local ... | kubectl apply -f -`: Adds the memory request and limit to the YAML in the file (`--local`: in the file, not in the cluster), and creates the pod. (`kubectl set resources` cannot change a pod that already runs.)

**📋 Copy and paste into your terminal:**

```bash
kubectl apply -n dev -f - <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: memhog
spec:
  containers:
  - name: memhog
    image: polinux/stress
    command: ["stress", "--vm", "1", "--vm-bytes", "100M", "--vm-hang", "1"]   # tries to use 100M
    resources:
      requests:
        memory: 25Mi
      limits:
        memory: 50Mi                                                           # but may use only 50Mi
YAML
sleep 30
kubectl get pod memhog -n dev
kubectl describe pod memhog -n dev | grep -A4 "Last State"
```

**What this does:**

- `kubectl apply -n dev -f - <<'YAML' ...`: Creates the pod `memhog`: a program that tries to use 100M of memory, in a container that may use 50Mi.
- `sleep 30`: Waits 30 seconds.
- `kubectl get pod memhog -n dev`: Shows the pod.
- `kubectl describe pod memhog -n dev | grep -A4 "Last State"`: Shows how the last container ended.

**👀 You should see** `OOMKilled` or `CrashLoopBackOff`, and *(do not paste)*:

```text
    Last State:     Terminated
      Reason:       OOMKilled
      Exit Code:    137
```

`OOMKilled` (out of memory) with exit code `137`: the kernel killed it. The fix is a bigger limit, or a program that uses less.

### 🔵 Optional 4: a CPU limit slows down, it does not kill

**📋 Copy and paste into your terminal:**

```bash
kubectl run spinner -n dev --image=busybox:1.36 --dry-run=client -o yaml --command -- sh -c 'while true; do :; done' > spinner.yaml
kubectl set resources -f spinner.yaml --local --requests=cpu=50m --limits=cpu=100m -o yaml | kubectl apply -f -
sleep 75
kubectl top pod spinner -n dev
kubectl get pod spinner -n dev
```

**What this does:**

- `kubectl run spinner ... > spinner.yaml`: Writes the YAML of a pod that keeps one CPU as busy as it can.
- `kubectl set resources ... | kubectl apply -f -`: Gives it a CPU limit of 100m (a tenth of one CPU), and creates it.
- `sleep 75`: Waits 75 seconds, so that the Metrics Server has measured it.
- `kubectl top pod spinner -n dev`: Shows its CPU use.
- `kubectl get pod spinner -n dev`: Shows the pod.

**👀 You should see** about `100m` of CPU, never much more, and the pod still `Running` with 0 restarts. The kernel **throttles** it: it may only run a tenth of the time.

### 🔵 Optional 5: challenge

Without looking at the answer: make an autoscaler for the DEV **frontend**: 2 to 4 pods, 50% CPU. Look at `kubectl get hpa`. Why does `TARGETS` say `<unknown>`? Fix it.

<details><summary>Show the answer</summary>

**📋 Copy and paste into your terminal:**

```bash
kubectl autoscale deployment frontend --min=2 --max=4 --cpu-percent=50
sleep 30
kubectl get hpa frontend
```

**What this does:** Creates the autoscaler `frontend`, waits 30 seconds and shows it.

**👀 You should see** `cpu: <unknown>/50%`. The frontend has no CPU **request**, so "50%" means nothing. (`kubectl describe hpa frontend` says `missing request for cpu`.) Give it one:

**📋 Copy and paste into your terminal:**

```bash
kubectl set resources deployment frontend --requests=cpu=25m,memory=32Mi
kubectl rollout status deployment/frontend
sleep 60
kubectl get hpa frontend
```

**What this does:**

- `kubectl set resources deployment frontend --requests=...`: Gives the frontend containers a CPU and memory request. This starts a rolling update.
- `kubectl rollout status deployment/frontend`: Waits until the new pods are ready.
- `sleep 60`: Waits 60 seconds, so that the Metrics Server has measured the new pods.
- `kubectl get hpa frontend`: Shows the autoscaler again.

**👀 You should see** a number such as `cpu: 4%/50%`.

</details>

🧹 **Clean up the practice:**

**📋 Copy and paste into your terminal:**

```bash
kubectl delete pod memhog spinner -n dev --now --ignore-not-found
kubectl delete hpa frontend -n dev --ignore-not-found
rm -f memhog.yaml spinner.yaml /tmp/top-pod.txt
```

**What this does:**

- `kubectl delete pod memhog spinner ...`: Deletes the two test pods, at once.
- `kubectl delete hpa frontend ...`: Deletes the autoscaler of the challenge, if you made it. The autoscaler `backend` stays.
- `rm -f ...`: Deletes the files of this practice.

**Next:** [Lab 6.4: Prometheus](./lab-6.4-prometheus.md)
