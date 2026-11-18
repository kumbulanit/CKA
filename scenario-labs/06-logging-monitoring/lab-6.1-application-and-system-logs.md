# Lab 6.1: Application and system components logging

**The situation:** a user phones: "the Shop is slow, and sometimes I get an error". You are the operations team. Where do you look?

**Goal:** read the logs of the Shop's own parts, follow one request through all of them, and read the logs of the cluster's own parts.

**Outline topic:** Logging / Monitoring: *Application and system components logging*.

**What you learn:** `kubectl logs` and its options, events, the logs of the control plane pods, the logs of the kubelet.

📘 **More detail:** [Lab 6.1 explained](./lab-6.1-application-and-system-logs-explained.md): what happens in the cluster at each step, common mistakes and exam notes.

| Where to look | What it tells you | Command |
| --- | --- | --- |
| **Application logs** | What your program says | `kubectl logs` |
| **Events** | What Kubernetes did with the pod | `kubectl get events`, `kubectl describe` |
| **System component logs** | What the cluster's own parts say | `kubectl logs -n kube-system`, `journalctl -u kubelet` |

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

## Part A: the logs of the Shop

### Step 1: read the logs of the backend

**📋 Copy and paste into your terminal:**

```bash
kubectl logs deployment/backend -n prod --tail=4
```

**What this does:** Shows the log (what the program printed) of one pod of the Deployment `backend` in the namespace `prod`: only the last 4 lines.

**👀 You should see** the last four log lines of one PROD backend pod, something like *(do not paste)*:

```text
Found 2 pods, using pod/backend-59df57cf8c-f4ssd
13/Nov/2026:15:03:42 +0000: Successfully connected to PostgreSQL 16.16 on aarch64-unknown-linux-musl, ...
13/Nov/2026:15:03:42 +0000: Config reloaded
13/Nov/2026:15:03:42 +0000: Schema cache queried in 5.7 milliseconds
13/Nov/2026:15:03:42 +0000: Schema cache loaded 1 Relations, 0 Relationships, 0 Functions, ...
```

Useful options:

| Option | Meaning |
| --- | --- |
| `--tail=20` | Only the last 20 lines |
| `-f` | Keep following (stop with Ctrl+C) |
| `--since=10m` | Only the last 10 minutes |
| `--previous` | The logs of the container **before** its last restart |
| `-l app=backend --prefix` | All pods with this label, with the pod name in front |

### Step 2: follow one request through all three parts

Send one request to the PROD Shop through its hostname (Lab 3.2), then look at the last log line of each part.

In this example the request arrived at 15:04:05. One frontend pod and one backend pod show it. The other two pods show an older line: the Service sent this request to their neighbour (load balancing, Lab 3.2).

**📋 Copy and paste into your terminal:**

```bash
curl -s -o /dev/null http://shop.local/api/items
sleep 2
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller --tail=20 | grep "GET /api/items" | tail -1
kubectl logs -n prod -l app=frontend --tail=1 --prefix
kubectl logs -n prod -l app=backend --tail=1 --prefix
```

**What this does:**

- `curl -s -o /dev/null http://shop.local/api/items`: Asks for `http://shop.local/api/items`, as a web browser would, and prints the answer.
- `sleep 2`: Waits 2 seconds, to give Kubernetes time.
- `kubectl logs -n ingress-nginx ... | grep "GET /api/items" | tail -1`: Shows the log (what the program printed) of the Ingress controller, keeps only the requests for `/api/items`, and shows the last one. (The controller also logs its own status lines, so its very last line is not always your request.)
- `kubectl logs -n prod -l app=frontend --tail=1 --prefix`: Shows the log (what the program printed) of all pods with the label `app=frontend` in the namespace `prod`: only the last line, with the pod name in front of each line.
- `kubectl logs -n prod -l app=backend --tail=1 --prefix`: Shows the log (what the program printed) of all pods with the label `app=backend` in the namespace `prod`: only the last line, with the pod name in front of each line.

**👀 You should see** the last line of the Ingress controller and of every frontend and backend pod. Find your request in them: `GET /api/items` at the Ingress and at one frontend pod, and `GET /items` at one backend pod, all at the same second *(do not paste)*:

```text
192.168.49.1 - - [13/Nov/2026:15:04:05 +0000] "GET /api/items HTTP/1.1" 200 123 "-" "curl/8.5.0" 82 0.072 [prod-frontend-80] ...
[pod/frontend-7df5f9757c-g2ph4/frontend] 10.244.120.91 - - [13/Nov/2026:15:04:05 +0000] "GET /api/items HTTP/1.1" 200 123 "-" "curl/8.5.0" ...
[pod/frontend-7df5f9757c-s2jrb/frontend] 10.244.120.91 - - [13/Nov/2026:15:02:32 +0000] "GET /api/items HTTP/1.1" 200 123 "-" "curl/8.5.0" ...
[pod/backend-59df57cf8c-d7dbk/backend] 10.244.151.51 - shop [13/Nov/2026:15:04:05 +0000] "GET /items HTTP/1.0" 200 - "" "curl/8.5.0"
[pod/backend-59df57cf8c-f4ssd/backend] 13/Nov/2026:15:03:42 +0000: Schema cache loaded 1 Relations, ...
```

If `curl` says it could not resolve `shop.local`, your server forgot the name. Add it again with the `echo` command of Lab 3.2, Step 8.

![One request in the logs of the Ingress controller, the frontend and the backend](../images/request-logs.png)

That is the path of every request: **Ingress → frontend → backend → database**. When the Shop is broken, you walk this path and find where the request stops.

### Step 3: read the events

**📋 Copy and paste into your terminal:**

```bash
kubectl get events -n prod --sort-by=.lastTimestamp | tail -5
```

**What this does:** Lists the events (what Kubernetes did, step by step) in the namespace `prod`, oldest first. `| tail` shows only the last 5 lines.

**👀 You should see** the last five things that happened in `prod`, something like *(do not paste)*:

```text
20s   Normal    Pulled              pod/backend-59df57cf8c-d7dbk   Container image "postgrest/postgrest:v12.2.3" already present on machine
13s   Normal    Killing             pod/backend-976f8c445-fssvd    Stopping container backend
13s   Normal    ScalingReplicaSet   deployment/backend             Scaled down replica set backend-976f8c445 from 1 to 0
13s   Normal    SuccessfulDelete    replicaset/backend-976f8c445   Deleted pod: backend-976f8c445-fssvd
12s   Warning   Unhealthy           pod/backend-976f8c445-fssvd    Readiness probe failed: ...
```

Events are kept for about one hour. `Normal` is information. `Warning` is where you look first.

## Part B: the logs of the cluster itself

### Step 4: the control plane pods

The parts of the control plane are pods too, so `kubectl logs` works on them:

**📋 Copy and paste into your terminal:**

```bash
kubectl logs -n kube-system kube-scheduler-minikube --tail=3
kubectl logs -n kube-system kube-controller-manager-minikube --tail=3
```

**What this does:**

- `kubectl logs -n kube-system kube-scheduler-minikube --tail=3`: Shows the log (what the program printed) of the pod `kube-scheduler-minikube` in the namespace `kube-system`: only the last 3 lines.
- `kubectl logs -n kube-system ...`: Shows the log (what the program printed) of the pod `kube-controller-manager-minikube` in the namespace `kube-system`: only the last 3 lines.

**👀 You should see** the last lines of the scheduler and the controller manager. When a pod stays `Pending` and the events say nothing, the scheduler's log is the place to look.

Lines that start with `E` (error) are not always a problem. Read the time at the start of the line and what it says. Lines you will often see on a healthy cluster:

| The line says | Meaning |
| --- | --- |
| scheduler: `"Failed to watch" ... User "system:kube-scheduler" cannot list resource ...`, with a time from when the cluster started | At start-up the scheduler asked before its access rules were loaded. It tried again a second later, and it worked. Only a problem if these lines keep coming **now**. |
| controller manager: `... is not as new as written version ...` | Two updates of the same object crossed. The controller simply tries again. |
| controller manager: `"Cleaning CSR as it is more than approvedExpiration duration old and approved." csr="thabo"` | Housekeeping: an approved certificate request is deleted after 1 hour (Lab 5.2). The certificate Thabo got stays valid. |

### Step 5: the kubelet

The **kubelet** is not a pod. It is a service on every node, so its log is on the node, in `journalctl`:

**📋 Copy and paste into your terminal:**

```bash
minikube ssh -n minikube-m02 -- sudo journalctl -u kubelet --no-pager -n 5
```

**What this does:** Shows the last 5 lines of the kubelet's log on the node `minikube-m02`. The kubelet is a service on the node, not a pod, so `kubectl logs` cannot show it: `journalctl` reads it on the node.

**👀 You should see** the last five log lines of the kubelet on `minikube-m02`. When a node is `NotReady`, this is the log to read.

### Step 6: when the API server itself is down

If the API server does not run, `kubectl logs` cannot work. Then you read the container's log on the node, with `crictl`:

**📋 Copy and paste into your terminal:**

```bash
minikube ssh -- "sudo crictl ps --name kube-apiserver -q | xargs sudo crictl logs --tail 3"
```

**What this does:** On the control plane node: finds the API server container with `crictl` and shows its last 3 log lines.

**👀 You should see** the last three log lines of the API server, read straight from the node.

## Where each log lives

| Part | It is | Read its log with |
| --- | --- | --- |
| Your application | A pod | `kubectl logs <pod>` |
| API server, scheduler, controller manager, etcd | Static pods in `kube-system` | `kubectl logs -n kube-system <pod>`, or `crictl logs` on the node |
| kubelet, container runtime | Services on the node | `journalctl -u kubelet`, `journalctl -u containerd` |

💡 **Tip:** add `-f` to follow a log live: `kubectl logs -n prod deployment/backend -f`. New lines appear as they come. Stop with **Ctrl+C**.

💡 **Exam tip:** a pod that keeps restarting has lost its logs. Use `kubectl logs <pod> --previous` to read what it said before it died.

✅ **Check:** you found the same request in the logs of the Ingress controller, the frontend and the backend, and you read the kubelet's log on a node.

## More practice

The Shop part of the lab is done. These exercises use small test pods in `dev`, and the clean-up at the end removes them.

### 🟡 Practice 1: the options of `kubectl logs` you use most

**📋 Copy and paste into your terminal:**

```bash
kubectl logs -n prod -l app=backend --since=10m --timestamps --prefix | tail -4
kubectl logs -n prod deployment/frontend --tail=20 | grep -c "GET /api/"
```

**What this does:**

- `kubectl logs -n prod -l app=backend --since=10m --timestamps --prefix`: Shows the log lines of **all** PROD backend pods from the last 10 minutes. `--timestamps` adds the time Kubernetes received each line; `--prefix` adds the pod name. `| tail -4` keeps the last 4 lines.
- `kubectl logs -n prod deployment/frontend --tail=20 | grep -c "GET /api/"`: Counts how many of the last 20 lines of one frontend pod are requests for `/api/`.

**👀 You should see** four lines that each start with `[pod/backend-...]` and a time, then a number.

| Option | Use it for |
| --- | --- |
| `--tail=N` | Only the last N lines |
| `--since=10m`, `--since-time=...` | Only what is new |
| `-f` | Keep following (stop with Ctrl+C) |
| `-l app=x --prefix` | All pods with a label, each line with its pod name |
| `-c name`, `--all-containers` | Pods with more than one container |
| `--previous` | The container **before** the last restart |

### 🟡 Practice 2: the log of a container that crashed

When a container crashes and restarts, `kubectl logs` shows the **new** one. The error is often in the old one.

**📋 Copy and paste into your terminal:**

```bash
kubectl run crasher -n dev --image=busybox:1.36 -- sh -c 'echo "starting, attempt at $(date +%T)"; echo "error: cannot open /etc/app/config" >&2; sleep 5; exit 1'
sleep 40
kubectl get pod crasher -n dev
kubectl logs crasher -n dev
kubectl logs crasher -n dev --previous
```

**What this does:**

- `kubectl run crasher ...`: Starts a pod that prints two lines, waits 5 seconds and stops with an error. Kubernetes restarts it again and again.
- `sleep 40`: Waits 40 seconds, so that it crashes a few times.
- `kubectl get pod crasher -n dev`: Shows the pod.
- `kubectl logs crasher -n dev`: Shows the log of the container that runs now.
- `kubectl logs crasher -n dev --previous`: Shows the log of the container before it.

**👀 You should see** `CrashLoopBackOff` or `Error` with a `RESTARTS` number above 0, and two logs with **different** times. Both contain the error: the program writes it to `stderr`, and Kubernetes keeps `stdout` and `stderr` together.

### 🟡 Practice 3: a pod with two containers

**⌨️ Command line option:** none. `kubectl run` makes a pod with one container; for two, the YAML is the only way.

**📋 Copy and paste into your terminal:**

```bash
kubectl apply -n dev -f - <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: two
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "while true; do echo app: working; sleep 5; done"]
  - name: helper
    image: busybox:1.36
    command: ["sh", "-c", "while true; do echo helper: checking; sleep 5; done"]
YAML
kubectl wait pod/two -n dev --for=condition=Ready --timeout=60s
kubectl logs two -n dev --tail=1
kubectl logs two -n dev -c helper --tail=1
kubectl logs two -n dev --all-containers --prefix --tail=1
```

**What this does:**

- `kubectl apply -n dev -f - <<'YAML' ...`: Creates the pod `two` from the YAML between the two `YAML` lines: two containers, `app` and `helper`.
- `kubectl wait pod/two ...`: Waits until the pod is ready (at most 60 seconds).
- `kubectl logs two -n dev --tail=1`: Asks for the log without saying which container.
- `kubectl logs two -n dev -c helper --tail=1`: Asks for the log of the container `helper`.
- `kubectl logs two -n dev --all-containers --prefix --tail=1`: Asks for the logs of both, each line with its pod and container name.

**👀 You should see** first a line `Defaulted container "app" out of: app, helper`, then the helper's line, then one line of each, marked with `[pod/two/app]` and `[pod/two/helper]`. The exam often has pods with a second container: always check with `-c`.

### 🔵 Optional 4: events, the cluster's own short log

Optional 4 and 5 need the pod `crasher` of Practice 2. The first line below starts it again if it is not there (if you cleaned up already, for example):

**📋 Copy and paste into your terminal:**

```bash
kubectl get pod crasher -n dev >/dev/null 2>&1 || { kubectl run crasher -n dev --image=busybox:1.36 -- sh -c 'echo "starting, attempt at $(date +%T)"; echo "error: cannot open /etc/app/config" >&2; sleep 5; exit 1'; sleep 40; }
kubectl events -n dev --for pod/crasher | tail -4
kubectl get events -A --field-selector type=Warning --sort-by=.lastTimestamp | tail -5
```

**What this does:**

- `kubectl get pod crasher ... || { kubectl run crasher ...; sleep 40; }`: If there is no pod `crasher`, starts it as in Practice 2 and waits 40 seconds. If it is there, does nothing.
- `kubectl events -n dev --for pod/crasher`: Shows only the events of the pod `crasher`. `| tail -4` keeps the last 4.
- `kubectl get events -A --field-selector type=Warning ...`: Shows the **warnings** of all namespaces, newest last.

**👀 You should see** `BackOff` warnings for `crasher` (`Back-off restarting failed container`). Events are kept for one hour only: for older problems you need the logs.

### 🔵 Optional 5: the same crash, seen by the kubelet

**📋 Copy and paste into your terminal:**

```bash
NODE=$(kubectl get pod crasher -n dev -o jsonpath='{.spec.nodeName}'); echo $NODE
minikube ssh -n $NODE -- "sudo journalctl -u kubelet --since '-5 min' --no-pager | grep crasher | tail -3"
```

**What this does:**

- `NODE=$(...)`: Keeps the name of the node where `crasher` runs in the variable `NODE`, and prints it.
- `minikube ssh -n $NODE -- "sudo journalctl -u kubelet ... | grep crasher | tail -3"`: On that node, reads the kubelet's log of the last 5 minutes, and keeps the last 3 lines about `crasher`.

**👀 You should see** long lines from the kubelet about the container of `crasher` that is in back-off. The application log says **why** the program stopped; the kubelet log says what Kubernetes **did** about it.

### 🔵 Optional 6: challenge

Without looking at the answer: for each PROD backend pod, print its name and how many log lines it wrote in the last 10 minutes. Which one got the most work?

<details><summary>Show the answer</summary>

**📋 Copy and paste into your terminal:**

```bash
for p in $(kubectl get pods -n prod -l app=backend -o name); do
  echo "$p $(kubectl logs -n prod $p --since=10m | wc -l)"
done
```

**What this does:** For every PROD backend pod: prints its name and the number of its log lines (`wc -l`) of the last 10 minutes.

**👀 You should see** one line per pod, with numbers close to each other: the Service spreads the requests (Lab 3.2).

</details>

🧹 **Clean up the practice:**

**📋 Copy and paste into your terminal:**

```bash
kubectl delete pod crasher two -n dev --now --ignore-not-found
```

**What this does:** Deletes the two test pods, at once.

**Next:** [Lab 6.2: Cluster-wide logging](./lab-6.2-cluster-wide-logging.md)
