# Lab 6.2 explained: cluster-wide logging architecture

This page goes with [Lab 6.2](./lab-6.2-cluster-wide-logging.md). The lab has the commands; this page explains them: what happens in the cluster, why it matters for the Shop, what usually goes wrong, and what the exam asks. There is nothing to paste here.

## In short

Kubernetes keeps container logs only in files on each node, and deletes them with the pod. For PROD that is not enough: you need logs from all pods and nodes in one place, kept for weeks, and searchable. A **cluster-wide logging** system adds that: an agent on every node (a DaemonSet) reads the files and ships them to a central store. In this lab you find the files, watch a log disappear, and see where an agent would plug in.

## The ideas behind this lab

### The life of a log line on one node

1. The program writes a line to stdout.
2. The container runtime appends it to `/var/log/pods/<namespace>_<pod>_<uid>/<container>/<restart>.log`, with a time stamp and the stream name (`stdout` or `stderr`).
3. The kubelet **rotates** the file: when it reaches `containerLogMaxSize` (10 MiB by default), it starts a new one, and keeps at most `containerLogMaxFiles` (5).
4. When the pod is deleted, its folder is deleted.

`/var/log/containers/` holds links to the same files with readable names. Logging agents usually read from there.

### Why that is not enough

| Problem | Example in the Shop |
| --- | --- |
| Logs die with the pod | The frontend pod with the error was replaced; its log is gone |
| Logs are cut off by rotation | A busy pod keeps only its last ~50 MB, even while it runs |
| Logs are scattered | Two backend pods on two nodes: no single place to search both |
| No history | "What happened yesterday evening?" has no answer |

### Three ways to keep logs

| Way | How | Pros and cons |
| --- | --- | --- |
| **Node-level agent** (the usual way) | A DaemonSet (Fluent Bit, Promtail, Alloy, Vector) on every node mounts the node's log folder, reads every file, adds labels (namespace, pod, container) and ships the lines | Nothing changes in the applications; one pod per node |
| **Sidecar container** | A second container in the pod reads a log **file** the application writes, and prints it to its own stdout (or ships it) | For programs that only write to files; costs one container per pod |
| **Direct from the application** | The program sends logs to the store itself | Rare; ties the program to one log system |

The **central store** is outside Kubernetes' scope: Elasticsearch or OpenSearch (searched with Kibana or OpenSearch Dashboards), or Loki (searched with Grafana). Kubernetes provides the files and the conventions; the rest is tools.

## Step by step

### Step 1: find the log files of the Shop on a node

`minikube ssh -n minikube-m03 -- "sudo ls /var/log/pods | grep prod"` shows one folder per PROD pod on that node, named namespace, pod name and pod UID. The UID makes the name unique, even if a pod with the same name comes back later.

### Step 2: read a log file straight from the node

`tail` on `.../frontend/0.log` shows the raw format: a time stamp, the stream (`stdout`, `stderr`), a flag (`F` for a full line, `P` for part of a long line), and the line itself. nginx writes its start messages to stderr and its access log to stdout. `0.log` means the first run of the container; after a restart there would be `1.log`, which is what `--previous` reads.

### Step 3: see that the log dies with the pod

`jsonpath='{.items[0].metadata.name}'` saves the name of one frontend pod. Its log is readable; you delete the pod; the same command now says `NotFound`. The Deployment has made a new pod with a new name and an empty log. Whatever the old pod knew about the user's error is gone.

### The three ways to keep logs

The table in the lab is the architecture. The node-level agent is the normal choice, because it needs nothing from the applications.

### Step 4: see a node-level agent that is already there

`kubectl get daemonsets -n kube-system` shows `calico-node` and `kube-proxy`: `DESIRED 3`, one pod per node. A log agent is installed exactly the same way: a DaemonSet whose pods mount the node's `/var/log/pods` (with a `hostPath` volume) and read it. When a node joins, it gets an agent pod automatically (Lab 2.2).

### Step 5: how long does a node keep a log?

The kubelet's settings file has no `containerLogMaxSize` or `containerLogMaxFiles`, so the defaults apply: 10 MiB per file, 5 files per container. Old lines are dropped as new ones come, even for a pod that keeps running. An agent must read the files faster than they rotate.

## When something goes wrong

| What you see | What it means | What to do |
| --- | --- | --- |
| `NotFound` from `kubectl logs` | The pod is gone, and its log with it | Only a central log store still has it |
| The oldest lines of a running pod are missing | Rotation dropped them | Normal; ship logs off the node |
| `ls /var/log/pods` shows no Shop folders | You are on a node without Shop pods | `kubectl get pods -o wide` to find the node |
| An application's lines never appear in `kubectl logs` | It writes to a file, not to stdout | Add a sidecar that prints the file (exam topic) |

## For the exam

- The exam does not ask you to install a log system, but it can ask for a **sidecar** that reads a log file: two containers sharing an `emptyDir` volume, one writing the file, one running `tail -F` on it. The YAML is in the documentation page "Logging Architecture".
- `kubectl logs POD -c SIDECAR` reads the sidecar's output.
- Know where the files are: `/var/log/pods/` and `/var/log/containers/` on the node.
- Know the kubelet settings `containerLogMaxSize` and `containerLogMaxFiles`, in `/var/lib/kubelet/config.yaml`.

## Check your understanding

1. Where exactly is a container's log stored?
2. Why is `kubectl logs` not enough for PROD? Give two reasons.
3. Why is a node-level log agent a DaemonSet?
4. When do you need a sidecar instead?
5. A pod runs for a week and logs a lot. Can you read its first log line?

<details><summary>Answers</summary>

1. In a file on its node, under `/var/log/pods/<namespace>_<pod>_<uid>/<container>/`.
2. Any two of: logs are deleted with the pod; rotation drops old lines; logs are spread over many nodes; there is no history to search.
3. It must run on every node, including new ones, to read every node's log files.
4. When the application writes its log to a file instead of stdout.
5. Probably not: after 5 files of 10 MiB, the oldest lines are dropped.

</details>

**Back to:** [Lab 6.2](./lab-6.2-cluster-wide-logging.md) · **Next:** [Lab 6.3 explained](./lab-6.3-metrics-server-explained.md)
