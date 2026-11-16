# Lab 6.4 explained: Prometheus

This page goes with [Lab 6.4](./lab-6.4-prometheus.md). The lab has the commands; this page explains them: what happens in the cluster, why it matters for the Shop, what usually goes wrong, and what the exam asks. There is nothing to paste here.

## In short

**Prometheus** collects numbers (metrics) from many targets every few seconds and stores them **with their history**, so you can ask what happened yesterday evening. It finds its targets through the Kubernetes API. In this lab you install it with **Helm**, ask it two questions in its language, **PromQL**, and remove it again.

## The ideas behind this lab

### Metrics, logs and events

| | Answers | Example from the Shop |
| --- | --- | --- |
| **Metrics** | How much, how often, over time | Backend restarts per hour, CPU use yesterday at 19:00 |
| **Logs** | What exactly happened, line by line | The error message of one failed request |
| **Events** | What Kubernetes did, the last hour | A probe failed, a pod was killed |

Metrics are cheap to keep for a long time, and are what alerts watch. Logs explain *why*, once a metric says *that* something is wrong.

### How Prometheus works

| Piece | Job |
| --- | --- |
| **Targets** | Programs that show their numbers as text on an HTTP page, usually `/metrics` |
| **Scraping** | Prometheus **pulls**: every interval (often 15 to 60 seconds) it fetches every target's page |
| **Service discovery** | It asks the Kubernetes API which pods, Services and nodes exist, so new targets are found by themselves |
| **Time series database** | Every number is stored with a time stamp and **labels** (namespace, pod, container...), on Prometheus's own disk |
| **PromQL** | The query language: select series by labels, then count, sum, average, or compute rates |
| **Alertmanager** | Sends notifications when an alert rule fires (switched off in the lab) |
| **Grafana** | Draws dashboards from Prometheus (not installed in the lab) |

### Where the Kubernetes numbers come from

| Exporter | Measures | Installed as |
| --- | --- | --- |
| **node-exporter** | Each node's CPU, memory, disk, network | A DaemonSet: one per node |
| **kube-state-metrics** | The state of Kubernetes objects: pods per namespace, restarts, desired and available replicas | A Deployment, reading the API |
| The kubelet (cAdvisor) | Each container's CPU and memory | Built into every kubelet |

### Helm

**Helm** is a package manager for Kubernetes. A **chart** is a package of YAML templates; installing it with your settings (`--set`) creates a **release**: all the Deployments, Services, ConfigMaps and RBAC objects of the application, under one name. `helm uninstall` removes them all again. The CKA asks for basic Helm use (install, upgrade, uninstall, list).

## Step by step

### Step 1: install Prometheus with Helm

`helm repo add` and `helm repo update` tell Helm where the community charts are and fetch their index. `helm install prometheus prometheus-community/prometheus -n monitoring` installs the chart as the release `prometheus`. The three `--set` options keep it small for the course server: no persistent disk (the data lives only as long as the pod), no Alertmanager, no Pushgateway.

### Step 2: wait for the pods

Three node-exporter pods (one per node, a DaemonSet), one kube-state-metrics pod, and the Prometheus server. The server pod shows `2/2`: Prometheus itself, plus a small helper container that reloads its configuration when it changes.

### Step 3: reach Prometheus on localhost

The Prometheus Service is a ClusterIP Service, so `kubectl port-forward` connects port 9090 on your server to it (as in Lab 1.6). `/-/ready` is Prometheus's own readiness page. In a real cluster you would reach it through an Ingress, with a login in front.

### Step 4: ask a question: how many pods has each environment?

`kube_pod_info` is a series from kube-state-metrics: one entry per pod, with labels such as `namespace` and `pod`. `{namespace=~"dev|uat|prod"}` filters by label with a regular expression; `count by (namespace) (...)` counts entries per namespace. The query goes to Prometheus's HTTP API (`/api/v1/query`), and `jq` turns the JSON answer into readable lines. Five pods per environment: 2 frontends, 2 backends, 1 database.

### Step 5: ask another question: which Shop containers restarted?

`kube_pod_container_status_restarts_total` is a **counter**: it only goes up. Its current value is the number of restarts. In real use you ask how fast it rises, with `increase(...[1h])` (restarts in the last hour) or `rate(...)`, and an alert rule fires when it rises too fast. That is how "the Shop was slow yesterday" becomes "the backend restarted 12 times between 19:00 and 20:00".

### Step 6: clean up

`kill %1` stops the port-forward, `helm uninstall` removes every object of the release, and deleting the namespace removes what is left. Prometheus uses a lot of memory, which the storage labs need.

## When something goes wrong

| What you see | What it means | What to do |
| --- | --- | --- |
| `helm repo add` fails | No internet access, or a typing mistake in the address | Check the address and the connection |
| Pods `Pending` | Not enough memory or CPU on the nodes | Watch the trainer's demo instead; remove it again |
| The query answer is empty | Prometheus has not scraped yet, or the query has a typo | Wait a minute; check label names and quotes |
| `curl: (7) Failed to connect to localhost port 9090` | The port-forward is not running | Start it again (Step 3) |
| `cannot re-use a name that is still in use` | A release called `prometheus` already exists | `helm list -A`; uninstall it first |

## For the exam

- Prometheus itself is not an exam task. Know what it is for, how it differs from the Metrics Server, and `kubectl top` well.
- Helm basics are in the curriculum: `helm repo add`, `helm repo update`, `helm install NAME CHART -n NS --set key=value`, `helm list -A`, `helm upgrade`, `helm uninstall`.
- A DaemonSet that runs on every node (like node-exporter) is a pattern you may be asked to create.

## Check your understanding

1. Why can Prometheus answer "what happened yesterday" when the Metrics Server cannot?
2. Does Prometheus wait for targets to send numbers?
3. Which exporter tells Prometheus how many pods each namespace has?
4. What does a Helm release contain?
5. Why is the restart counter more useful as `increase(...[1h])` than as its raw value?

<details><summary>Answers</summary>

1. It stores every number with a time stamp in its own database; the Metrics Server only keeps the latest value.
2. No, it pulls: it fetches each target's numbers on a schedule.
3. kube-state-metrics, which reads the state of the objects from the API.
4. All the Kubernetes objects the chart created with your settings, managed together under one name.
5. The raw value only grows; the increase shows how many restarts happened in a period, which is what tells you something is wrong now.

</details>

**Back to:** [Lab 6.4](./lab-6.4-prometheus.md) · **Next:** [Lab 7.1 explained](../07-storage/lab-7.1-storage-architecture-explained.md)
