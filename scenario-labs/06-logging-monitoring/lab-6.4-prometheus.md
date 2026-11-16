# Lab 6.4: Prometheus: numbers with a history

**The situation:** the user phoned about the Shop being slow **yesterday evening**. `kubectl top` only shows **now**. You need the numbers of yesterday.

**Goal:** install Prometheus, and ask it questions about the Shop.

**Outline topic:** Logging / Monitoring: *Prometheus*.

**What you learn:** what Prometheus is, how it collects numbers, a first query.

| | Metrics Server (Lab 6.3) | Prometheus |
| --- | --- | --- |
| Keeps a history | No, only now | Yes, days or weeks |
| What it measures | CPU and memory | Anything: requests, errors, restarts, disk, ... |
| Used by | `kubectl top`, the autoscaler | Dashboards (Grafana) and alerts |

Prometheus **pulls**: every few seconds it visits each target and asks for its numbers. It finds the targets by itself, through the Kubernetes API.

⚠️ Prometheus needs memory. If your server has less than 8 GB, watch the trainer do this lab on the screen instead.

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

## Step 1: install Prometheus with Helm

Helm is a package manager for Kubernetes. It was installed by `setup.sh`. Here you only use it to install one package.

**📋 Copy and paste into your terminal:**

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
kubectl create namespace monitoring
helm install prometheus prometheus-community/prometheus -n monitoring \
  --set server.persistentVolume.enabled=false \
  --set alertmanager.enabled=false \
  --set prometheus-pushgateway.enabled=false
```

**What this does:**

- `helm repo add prometheus-community ...`: Tells Helm where to find the charts of `prometheus-community`.
- `helm repo update`: Downloads the newest list of charts.
- `kubectl create namespace monitoring`: Creates the namespace `monitoring`.
- `helm install prometheus prometheus-community/prometheus ...`: Installs the chart `prometheus-community/prometheus` as a release called `prometheus` in the namespace `monitoring`; each `--set` changes one setting.

**👀 You should see** (among other lines) *(do not paste)*:

```text
NAME: prometheus
NAMESPACE: monitoring
STATUS: deployed
```

## Step 2: wait for the pods

**📋 Copy and paste into your terminal:**

```bash
kubectl rollout status deployment/prometheus-server -n monitoring
kubectl get pods -n monitoring
```

**What this does:**

- `kubectl rollout status deployment/prometheus-server ...`: Waits until the new pods of the Deployment `prometheus-server` in the namespace `monitoring` are all ready, and says when it is done.
- `kubectl get pods -n monitoring`: Lists the pods in the namespace `monitoring`.

**👀 You should see** the server, one `node-exporter` on every node (a DaemonSet, as in Lab 6.2) and `kube-state-metrics` *(do not paste)*:

```text
NAME                                             READY   STATUS    RESTARTS   AGE
prometheus-kube-state-metrics-6b8d9c7f5d-x2k4p   1/1     Running   0          90s
prometheus-prometheus-node-exporter-4mz8q        1/1     Running   0          90s
prometheus-prometheus-node-exporter-b7v2n        1/1     Running   0          90s
prometheus-prometheus-node-exporter-kq9wd        1/1     Running   0          90s
prometheus-server-7d9f8c6b54-h8n3t               2/2     Running   0          90s
```

| Pod | What it gives Prometheus |
| --- | --- |
| `node-exporter` | Numbers about each node: CPU, memory, disk |
| `kube-state-metrics` | Numbers about Kubernetes objects: how many pods, restarts, replicas |
| `prometheus-server` | Collects and stores everything, and answers questions |

## Step 3: reach Prometheus on localhost

**📋 Copy and paste into your terminal:**

```bash
kubectl port-forward -n monitoring service/prometheus-server 9090:80 > /dev/null 2>&1 &
sleep 3
curl -s http://localhost:9090/-/ready; echo
```

**What this does:**

- `kubectl port-forward -n monitoring ...`: Connects port 9090 of your server (`localhost:9090`) to the Service `prometheus-server` in `monitoring`. The `&` at the end keeps it running in the background.
- `sleep 3`: Waits 3 seconds, to give Kubernetes time.
- `curl -s http://localhost:9090/-/ready; echo`: Asks for `http://localhost:9090/-/ready`, as a web browser would, and prints the answer.

**👀 You should see** *(do not paste)*:

```text
Prometheus Server is Ready.
```

If your server has a desktop, open `http://localhost:9090` in its browser to see the Prometheus page.

## Step 4: ask a question: how many pods has each environment?

Questions to Prometheus are written in its own language, **PromQL**.

**📋 Copy and paste into your terminal:**

```bash
curl -s 'http://localhost:9090/api/v1/query' --data-urlencode 'query=count by (namespace) (kube_pod_info{namespace=~"dev|uat|prod"})' | jq -r '.data.result[] | "\(.metric.namespace): \(.value[1]) pods"'
```

**What this does:** Asks for `http://localhost:9090/api/v1/query`, as a web browser would, and prints the answer. `| jq` picks the parts we want out of the JSON answer.

**👀 You should see** the three environments of the Shop *(do not paste)*:

```text
dev: 5 pods
prod: 5 pods
uat: 5 pods
```

If the answer is empty, Prometheus has not collected its first numbers yet. Wait one minute and ask again.

## Step 5: ask another question: which Shop containers restarted?

**📋 Copy and paste into your terminal:**

```bash
curl -s 'http://localhost:9090/api/v1/query' --data-urlencode 'query=kube_pod_container_status_restarts_total{namespace="prod"}' | jq -r '.data.result[] | "\(.metric.pod): \(.value[1]) restarts"'
```

**What this does:** Asks for `http://localhost:9090/api/v1/query`, as a web browser would, and prints the answer. `| jq` picks the parts we want out of the JSON answer.

**👀 You should see** every PROD pod with its number of restarts *(do not paste)*:

```text
backend-64c47cb7d8-cvpkm: 0 restarts
backend-64c47cb7d8-rsdrp: 0 restarts
db-747c44dc87-rg87j: 0 restarts
frontend-5fddf7f475-5248t: 0 restarts
frontend-5fddf7f475-rwg72: 0 restarts
```

A number that goes up here is the first sign of a problem. In a real cluster an **alert** watches it for you, and **Grafana** draws it as a graph.

## Step 6: clean up

Prometheus uses memory that the next labs need. Remove it:

**📋 Copy and paste into your terminal:**

```bash
kill %1
helm uninstall prometheus -n monitoring
kubectl delete namespace monitoring
```

**What this does:**

- `kill %1`: Stops the command that runs in the background (the port-forward).
- `helm uninstall prometheus -n monitoring`: Removes the release `prometheus` in the namespace `monitoring` and everything it installed.
- `kubectl delete namespace monitoring`: Deletes the namespace `monitoring` and everything in it.

**👀 You should see** *(do not paste)*:

```text
release "prometheus" uninstalled
namespace "monitoring" deleted
```

💡 **Exam tip:** Prometheus is not part of the exam tasks. Know what it is for, and know `kubectl top` (Lab 6.3) well.

✅ **Check:** Step 4 gave a number of pods for `dev`, `uat` and `prod`, and Prometheus is removed again.

**Next:** [Lab 7.1: Storage architecture](../07-storage/lab-7.1-storage-architecture.md)
