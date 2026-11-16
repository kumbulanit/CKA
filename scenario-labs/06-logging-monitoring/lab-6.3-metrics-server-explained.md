# Lab 6.3 explained: Metrics Server and autoscaling

This page goes with [Lab 6.3](./lab-6.3-metrics-server.md). The lab has the commands; this page explains them: what happens in the cluster, why it matters for the Shop, what usually goes wrong, and what the exam asks. There is nothing to paste here.

## In short

The **Metrics Server** collects the current CPU and memory use of every pod and node, for `kubectl top` and for autoscalers. The **HorizontalPodAutoscaler** (HPA) compares the backend's CPU use with its CPU **request**, and adds or removes pods to stay near a target. In this lab you put load on the Shop and watch the backend grow from 2 pods to more, by itself.

## The ideas behind this lab

### Where the numbers come from

1. On every node, the **kubelet** measures its containers (through cAdvisor, built into the kubelet).
2. The **Metrics Server** (a small Deployment in `kube-system`) asks every kubelet for those numbers, about every 15 seconds.
3. It serves them through the API server as the **Metrics API** (`metrics.k8s.io`).
4. `kubectl top` and the HPA read the Metrics API.

The Metrics Server keeps **only the latest numbers**, in memory: no history, no graphs, no alerts. It is a sensor for autoscaling, not a monitoring system (that is Prometheus, Lab 6.4). kubeadm clusters do not install it; minikube has it as an addon.

### The units

| Unit | Meaning |
| --- | --- |
| `1` CPU, or `1000m` | One whole CPU core |
| `50m` | 50 millicores: one twentieth of a core |
| `Mi`, `Gi` | Mebibytes, gibibytes (powers of 1024) |

In `kubectl top nodes`, `CPU(%)` and `MEMORY(%)` are shares of what the node offers to pods.

### Requests and limits (a first look)

| Setting | Meaning | Used by |
| --- | --- | --- |
| **request** | What the container is guaranteed, and what the scheduler reserves for it | The scheduler; the HPA's percentages |
| **limit** | The most it may use | The kubelet: CPU above the limit is slowed down; memory above the limit gets the container killed (`OOMKilled`) |

Lab 7.4 goes deeper. For this lab, the key point: the HPA measures **use as a percentage of the request**. Without a request there is no percentage, and the HPA cannot work.

### How the HPA decides

Every 15 seconds, the HPA controller (in the controller manager) works out:

desired pods = current pods × (current average use ÷ target), rounded **up**

With 2 pods using 50% of their request on average and a target of 25%: 2 × 50 ÷ 25 = 4 pods. It always stays between `minReplicas` and `maxReplicas`. To avoid flapping, it scales **up** quickly but waits **5 minutes** of lower use before it scales **down**.

The HPA does not start pods itself: it only changes the `replicas` of the Deployment, exactly as `kubectl scale` would. The Deployment, the scheduler and the Service do the rest, as in Lab 3.2.

## Step by step

### Step 1: switch on the Metrics Server

`minikube addons enable metrics-server` installs it. The first numbers need about a minute: the Metrics Server must collect twice before it can compute a rate of CPU use. Until then, `kubectl top` says `Metrics API not available`.

The Metrics Server does not answer `kubectl top` itself: it registers an extra API with the API server, `metrics.k8s.io`, through an **APIService** object (the aggregation layer). The API server passes every `kubectl top` request on to it. `kubectl wait --for=condition=Available apiservice/v1beta1.metrics.k8s.io` waits until that API answers, which is exactly the moment `kubectl top` starts to work: usually after a minute or a little more.

The control plane node uses the most CPU: it runs the control plane parts.

### Step 2: tell Kubernetes what the backend needs

`kubectl set resources` adds a request (`cpu=50m`, `memory=64Mi`) and a limit (`cpu=200m`, `memory=128Mi`) to the backend's pod template, which rolls out new pods. From now on, the scheduler reserves 50 millicores per backend pod, and the HPA has something to compare against.

### Step 3: create the autoscaler

The HPA object names its target (`Deployment/backend`), the range (2 to 5 pods), and the goal: average CPU use of 25% of the request, so about 12 millicores per pod. `kubectl get hpa` shows `cpu: 4%/25%`: the backend is nearly idle, so it stays at 2. `<unknown>` means the HPA has no numbers yet.

### Step 4: make the Shop busy

The `load` pod asks the frontend for the items about 50 times a second, through the Service `frontend`, as a user would. Each request travels frontend → backend → database, so the backend's CPU use goes up.

### Step 5: watch the backend grow

After a minute or two, the HPA sees use above 25% and raises the Deployment's replicas: `REPLICAS` goes to 3, 4, maybe 5. The new pods join the Service, take part of the load, and the average use per pod comes down towards the target. The numbers in `TARGETS` jump around: they are averages of short samples.

### Step 6: stop the load

Deleting the `load` pod drops the CPU use. The HPA waits 5 minutes (its down-scale stabilisation window) before it removes pods, so that a short quiet moment does not shrink the Shop just before the next rush. Later, `kubectl get hpa` shows 2 replicas again.

## When something goes wrong

| What you see | What it means | What to do |
| --- | --- | --- |
| `error: Metrics API not available` | The Metrics Server is still starting, or is not installed | Wait a minute; `kubectl get pods -n kube-system -l k8s-app=metrics-server` |
| `TARGETS` shows `<unknown>` | No CPU request on the pods, or no numbers yet | Check the request (`kubectl describe deployment backend`); wait a minute |
| `REPLICAS` does not go up | The load is too small, or it does not reach the backend | `kubectl top pods`; check the `load` pod runs |
| It stays at the high number | The 5-minute down-scale wait | Normal |
| The HPA and `kubectl scale` fight | The HPA owns the replicas of its target | Change the HPA's min and max instead |

## For the exam

- `kubectl top nodes` and `kubectl top pods` (with `--sort-by=cpu` or `memory`, `-A`, `--containers`) are common tasks: "which pod uses the most CPU? write its name to a file".
- `kubectl autoscale deployment NAME --min=A --max=B --cpu=C%` creates an HPA in one line. Older kubectl versions use `--cpu-percent=C`, which v1.36 still accepts with a "deprecated" warning.
- An HPA needs the Metrics Server **and** CPU requests on the containers.
- `kubectl set resources deployment NAME --requests=... --limits=...` is the fastest way to add them.

## Check your understanding

1. Where does the Metrics Server get its numbers?
2. Can the Metrics Server tell you the CPU use of yesterday?
3. Why does the HPA need a CPU request?
4. 2 pods, average use 60% of the request, target 25%. How many pods does the HPA want?
5. Why does the HPA wait 5 minutes before removing pods?

<details><summary>Answers</summary>

1. From the kubelet on every node, which measures its containers.
2. No. It keeps only the latest numbers, in memory.
3. It measures use as a percentage of the request; without a request there is no percentage.
4. 2 × 60 ÷ 25 = 4.8, rounded up: 5 (also the maximum).
5. So that the number of pods does not go up and down with every short change in load.

</details>

**Back to:** [Lab 6.3](./lab-6.3-metrics-server.md) · **Next:** [Lab 6.4 explained](./lab-6.4-prometheus-explained.md)
