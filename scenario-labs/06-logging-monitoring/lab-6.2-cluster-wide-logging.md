# Lab 6.2: Cluster-wide logging architecture

**The situation:** the Shop has many pods, on three nodes, in three environments. Pods are deleted and replaced all the time. `kubectl logs` shows one pod at a time, and when a pod is gone, so is its log. You need to know where logs really live, and how a cluster keeps them.

**Goal:** find the log files on the nodes, see what happens to them, and understand how a cluster-wide logging system collects them.

**Outline topic:** Logging / Monitoring: *Cluster wide logging architecture*.

**What you learn:** where container logs are stored, log rotation, node-level logging agents (DaemonSet), sidecars.

📘 **More detail:** [Lab 6.2 explained](./lab-6.2-cluster-wide-logging-explained.md): what happens in the cluster at each step, common mistakes and exam notes.

> **How to use this lab**
>
> - **📋 Copy and paste into your terminal:** copy the whole grey box (the copy button is in its top right corner), paste it into the terminal of your server, and press Enter.
> - **👀 You should see** *(do not paste)*: what the command prints. Names that end in random letters, IP addresses and ages are different on your server. That is normal.
> - **📖 Read only:** something to look at. Do not paste it.
> - **💡 Tip:** a shortcut or an extra. You do not need it to finish the lab.

## How a log line travels

**📖 Read only (do not paste):**

```text
your program  →  writes to its screen (stdout)
                     ↓
container runtime →  saves it in a file on the NODE:  /var/log/pods/...
                     ↓
kubectl logs      →  the kubelet reads that file for you
```

Kubernetes itself does **not** store logs in a central place. The files are on the node, and they go when the pod goes.

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

## Step 1: find the log files of the Shop on a node

**📋 Copy and paste into your terminal:**

```bash
minikube ssh -n minikube-m03 -- "sudo ls /var/log/pods | grep prod"
```

**What this does:** On the node `minikube-m03`: lists the log folders of the pods, only those of `prod`.

**👀 You should see** one folder for every PROD pod on that node. The name is built from the namespace, the pod name and an ID *(do not paste)*:

```text
prod_backend-59df57cf8c-d7dbk_512c16ab-3a44-4f88-8302-aefd83e222fe
prod_backend-59df57cf8c-f4ssd_3b48a0a8-d705-4d00-a14c-6717ba79def4
prod_frontend-7df5f9757c-g2ph4_f2b9bc64-d4f4-430f-bd8a-cc47970216a1
prod_frontend-7df5f9757c-s2jrb_76a8e625-6ac9-4a22-8d9b-f0f269f265fc
```

## Step 2: read a log file straight from the node

**📋 Copy and paste into your terminal:**

```bash
minikube ssh -n minikube-m03 -- "sudo sh -c 'tail -n 2 /var/log/pods/prod_frontend-*/frontend/0.log'"
```

**What this does:** On the node `minikube-m03`: shows the last 2 lines of the log files `/var/log/pods/prod_frontend-*/frontend/0.log`.

**👀 You should see** the last two lines of each frontend log file. They are the same lines that `kubectl logs` shows, with a time and the word `stdout` or `stderr` in front *(do not paste)*:

```text
==> /var/log/pods/prod_frontend-7df5f9757c-g2ph4_f2b9bc64-d4f4-430f-bd8a-cc47970216a1/frontend/0.log <==
2026-11-13T15:01:43.575007427Z stderr F 2026/11/13 15:01:43 [notice] 1#1: start worker process 24
2026-11-13T15:04:05.656660462Z stdout F 10.244.120.91 - - [13/Nov/2026:15:04:05 +0000] "GET /api/items HTTP/1.1" 200 123 "-" "curl/8.5.0" "192.168.49.1"
```

This file is all there is. `kubectl logs` only reads it.

## Step 3: see that the log dies with the pod

Note the name of one PROD frontend pod, read its log, delete the pod, and try to read the log again:

**📋 Copy and paste into your terminal:**

```bash
POD=$(kubectl get pods -n prod -l app=frontend -o jsonpath='{.items[0].metadata.name}')
echo $POD
kubectl logs -n prod $POD --tail=1
kubectl delete pod -n prod $POD
kubectl logs -n prod $POD --tail=1
```

**What this does:**

- `POD=$(kubectl get pods -n ...`: Saves the answer of the command in the variable `$POD`, to use in the next lines. The command: reads the pods with the label `app=frontend` in the namespace `prod`, and prints only one value from it.
- `echo $POD`: Prints what is in the variable `$POD`.
- `kubectl logs -n prod $POD --tail=1`: Shows the log (what the program printed) of the pod `$POD` in the namespace `prod`: only the last line.
- `kubectl delete pod -n prod $POD`: Deletes the pod `$POD` in the namespace `prod`.
- `kubectl logs -n prod $POD --tail=1`: Shows the log (what the program printed) of the pod `$POD` in the namespace `prod`: only the last line.

**👀 You should see** the pod name, a log line, the delete, and then *(do not paste)*:

```text
frontend-7df5f9757c-g2ph4
10.244.120.91 - - [13/Nov/2026:15:04:05 +0000] "GET /api/items HTTP/1.1" 200 123 "-" "curl/8.5.0" "192.168.49.1"
pod "frontend-7df5f9757c-g2ph4" deleted from prod namespace
error: error from server (NotFound): pods "frontend-7df5f9757c-g2ph4" not found in namespace "prod"
```

The pod is gone, and its log with it. If that pod had the error the user phoned about, you can no longer read it.

## The three ways to keep logs

| Way | How it works | Used for |
| --- | --- | --- |
| **Node-level agent** | A **DaemonSet** runs one collector pod on every node. It reads all files in `/var/log/pods` and sends them to a central store. | The normal way. Nothing changes in your applications. |
| **Sidecar container** | A second container in the same pod reads the application's log file and writes it to stdout, or sends it on. | Applications that write to a file instead of stdout |
| **The application sends its logs itself** | The program talks to the log store directly | Rare. Ties the application to one log system. |

The central store is not part of Kubernetes. Common choices: Elasticsearch or OpenSearch (with Fluent Bit as the collector), or Loki (with Promtail or Alloy).

## Step 4: see a node-level agent that is already there

You already have pods that run "one on every node". The network plugin works that way:

**📋 Copy and paste into your terminal:**

```bash
kubectl get daemonsets -n kube-system
```

**What this does:** Lists the DaemonSets in the namespace `kube-system`.

**👀 You should see** *(do not paste)*:

```text
NAME          DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR            AGE
calico-node   3         3         3       3            3           kubernetes.io/os=linux   3h
kube-proxy    3         3         3       3            3           kubernetes.io/os=linux   3h
```

`DESIRED 3`: one pod for each of the three nodes. A log collector is installed the same way: as a DaemonSet that mounts `/var/log/pods` of its node.

## Step 5: how long does a node keep a log?

Log files do not grow for ever. The kubelet cuts them off (**rotation**):

**📋 Copy and paste into your terminal:**

```bash
minikube ssh -- "sudo grep -E 'containerLogMaxSize|containerLogMaxFiles' /var/lib/kubelet/config.yaml || echo 'not set: the defaults are 10Mi and 5 files'"
```

**What this does:** On the control plane node: looks in the kubelet settings for the log size and log file limits.

**👀 You should see** *(do not paste)*:

```text
not set: the defaults are 10Mi and 5 files
```

So a node keeps at most 5 files of 10 MB for each container. Older lines are thrown away, even while the pod still runs.

💡 **Exam tip:** the exam does not ask you to install a log system. It can ask you to add a **sidecar** container that reads a log file and prints it. Search the docs for "logging architecture": the sidecar YAML is there.

✅ **Check:** you can say where a container's log is stored, and why `kubectl logs` is not enough for PROD.

## More practice

The Shop part of the lab is done. These exercises use test pods in `dev`, and the clean-up at the end removes them.

### 🟡 Practice 1: the two log folders on a node

**📋 Copy and paste into your terminal:**

```bash
minikube ssh -n minikube-m03 -- "sudo ls -l /var/log/containers | grep _prod_ | head -3"
```

**What this does:** On the node `minikube-m03`, lists the files in `/var/log/containers`, keeps those of `prod` and shows the first 3.

**👀 You should see** short names that point (`->`) to files in `/var/log/pods/...`. `/var/log/containers` holds one link per container, named `<pod>_<namespace>_<container>-<id>.log`. Logging agents read this folder, because the name tells them the pod and namespace.

### 🟡 Practice 2: one log file per start of a container

**📋 Copy and paste into your terminal:**

```bash
kubectl run restarter -n dev --image=busybox:1.36 --overrides='{"spec":{"nodeSelector":{"kubernetes.io/hostname":"minikube-m02"}}}' -- sh -c 'echo "started at $(date +%T)"; sleep 10; exit 1'
sleep 60
kubectl get pod restarter -n dev
minikube ssh -n minikube-m02 -- "sudo sh -c 'ls /var/log/pods/dev_restarter_*/restarter/'"
```

**What this does:**

- `kubectl run restarter ...`: Starts a pod on `minikube-m02` that prints the time, waits 10 seconds and stops with an error, so it is restarted again and again.
- `sleep 60`: Waits 60 seconds.
- `kubectl get pod restarter -n dev`: Shows the pod and its `RESTARTS`.
- `minikube ssh -n minikube-m02 -- ...`: On the node, lists the log files of the container `restarter`.

**👀 You should see** a few numbered files such as `2.log  3.log`: one per start. The kubelet keeps the current one and the one before (that is what `--previous` reads), and removes older ones.

### 🟡 Practice 3: the sidecar pattern: a program that only writes to a file

Some programs write their log to a file, not to the screen. Then `kubectl logs` shows nothing. The fix: a second container (a **sidecar**) that reads the file and prints it. This is a classic exam task.

**⌨️ Command line option:** none. A pod with two containers and a shared volume needs YAML.

**📋 Copy and paste into your terminal:**

```bash
kubectl apply -n dev -f - <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: file-logger
spec:
  containers:
  - name: app                       # writes its log to a file only
    image: busybox:1.36
    command: ["sh", "-c", "while true; do echo \"$(date +%T) order saved\" >> /var/log/app/app.log; sleep 3; done"]
    volumeMounts:
    - name: logs
      mountPath: /var/log/app
  - name: log-streamer              # the sidecar: prints the file to its own stdout
    image: busybox:1.36
    command: ["sh", "-c", "tail -n +1 -F /var/log/app/app.log"]
    volumeMounts:
    - name: logs
      mountPath: /var/log/app
  volumes:
  - name: logs
    emptyDir: {}                    # a folder both containers share
YAML
kubectl wait pod/file-logger -n dev --for=condition=Ready --timeout=60s
sleep 10
kubectl logs file-logger -n dev -c app
kubectl logs file-logger -n dev -c log-streamer --tail=3
```

**What this does:**

- `kubectl apply -n dev -f - <<'YAML' ...`: Creates the pod `file-logger` from the YAML: the container `app` writes to a file, the container `log-streamer` prints that file, and both mount the same `emptyDir` folder.
- `kubectl wait pod/file-logger ...`: Waits until the pod is ready.
- `sleep 10`: Waits 10 seconds, so that there are some lines.
- `kubectl logs file-logger -n dev -c app`: Shows the log of `app`.
- `kubectl logs file-logger -n dev -c log-streamer --tail=3`: Shows the last 3 lines of the sidecar.

**👀 You should see** nothing for `app`, and lines like `14:02:11 order saved` from `log-streamer`. Now a node agent can collect these lines too.

### 🔵 Optional 4: build a tiny node-level agent

A real agent (Fluent Bit, the Loki agent) is a **DaemonSet** that reads `/var/log` on every node. Build a very small one that prints the last PROD line of every node:

**⌨️ Command line option:** none. kubectl has no `create daemonset`. The exam trick: `kubectl create deployment log-agent --image=busybox:1.36 --dry-run=client -o yaml > ds.yaml`, then change `kind: Deployment` to `kind: DaemonSet` and remove `replicas` and `strategy`.

**📋 Copy and paste into your terminal:**

```bash
kubectl apply -n dev -f - <<'YAML'
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: log-agent
spec:
  selector:
    matchLabels:
      app: log-agent
  template:
    metadata:
      labels:
        app: log-agent
    spec:
      tolerations:
      - operator: Exists              # run on every node, also the PROD node
      containers:
      - name: agent
        image: busybox:1.36
        command: ["sh", "-c", "tail -n 1 -F /var/log/containers/*_prod_*.log"]
        volumeMounts:
        - name: varlog
          mountPath: /var/log
          readOnly: true
      volumes:
      - name: varlog
        hostPath:
          path: /var/log              # the node's own log folder
YAML
kubectl rollout status daemonset/log-agent -n dev
kubectl get pods -n dev -l app=log-agent -o wide
curl -s -o /dev/null http://shop.local/api/items
sleep 3
kubectl logs -n dev -l app=log-agent --prefix --tail=2
```

**What this does:**

- `kubectl apply -n dev -f - <<'YAML' ...`: Creates the DaemonSet `log-agent`: one pod per node, which mounts the node's `/var/log` (read only) and follows the PROD log files.
- `kubectl rollout status daemonset/log-agent -n dev`: Waits until a pod runs on every node.
- `kubectl get pods -n dev -l app=log-agent -o wide`: Shows the agent pods and their nodes.
- `curl -s -o /dev/null http://shop.local/api/items`: Sends one request to the PROD Shop.
- `sleep 3`: Waits 3 seconds.
- `kubectl logs -n dev -l app=log-agent --prefix --tail=2`: Shows the last 2 lines of every agent.

**👀 You should see** one agent pod per node. An agent on a node with no PROD pod only says it cannot open the file, and keeps trying. The lines in the logs are the **raw** log lines from the files: a time, `stdout` or `stderr`, a letter `F`, then the line itself. A real agent reads the same files, but sends the lines to a central store instead of printing them.

### 🔵 Optional 5: challenge

Without looking at the answer: the PROD frontend writes its access log to the screen. Find, **on the node**, the size of all PROD frontend log files together.

<details><summary>Show the answer</summary>

**📋 Copy and paste into your terminal:**

```bash
minikube ssh -n minikube-m03 -- "sudo du -ch /var/log/pods/prod_frontend-*/ | tail -1"
```

**What this does:** On the node `minikube-m03`, adds up the size of the log folders of the PROD frontend pods (`du -ch`), and shows only the total.

**👀 You should see** a small size and the word `total`. Each container may grow to `containerLogMaxSize` (10Mi by default) times `containerLogMaxFiles` (5) before the oldest file is removed (Step 5).

</details>

🧹 **Clean up the practice:**

**📋 Copy and paste into your terminal:**

```bash
kubectl delete pod restarter file-logger -n dev --now --ignore-not-found
kubectl delete daemonset log-agent -n dev --ignore-not-found
```

**What this does:**

- `kubectl delete pod restarter file-logger ...`: Deletes the two test pods, at once.
- `kubectl delete daemonset log-agent -n dev ...`: Deletes the DaemonSet and its pods.

**Next:** [Lab 6.3: Metrics Server](./lab-6.3-metrics-server.md)
