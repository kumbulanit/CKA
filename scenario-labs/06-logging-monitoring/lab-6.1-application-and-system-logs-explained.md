# Lab 6.1 explained: application and system components logging

This page goes with [Lab 6.1](./lab-6.1-application-and-system-logs.md). The lab has the commands; this page explains them: what happens in the cluster, why it matters for the Shop, what usually goes wrong, and what the exam asks. There is nothing to paste here.

## In short

When something is wrong, there are three places to look: the **application logs** (what your program says), the **events** (what Kubernetes did), and the **system component logs** (what the cluster's own parts say). In this lab you follow one request through the Ingress controller, the frontend and the backend, then read the logs of the control plane, the kubelet, and, with the API server down, the container runtime.

## The ideas behind this lab

### Where logs come from

Kubernetes expects programs in containers to write their log to **stdout** and **stderr** (the screen), not to files. The container runtime saves both streams to a file on the node, and `kubectl logs` asks the kubelet on that node to read the file for you (through the API server). That is why `kubectl logs` works for any program, in any language, without setup.

### Three sources, three tools

| Source | Lives | Read it with | Tells you |
| --- | --- | --- | --- |
| Application logs | Files on the pod's node | `kubectl logs` | What the program did and why it failed |
| Events | Objects in the API (kept about one hour) | `kubectl get events`, `kubectl describe` | What Kubernetes did: scheduled, pulled, started, killed, probe failed |
| Static pod logs (API server, scheduler, controller manager, etcd) | Files on the control plane node | `kubectl logs -n kube-system`, or `crictl logs` on the node | Why the control plane misbehaves |
| kubelet, container runtime | The node's system journal | `journalctl -u kubelet`, `journalctl -u containerd` on the node | Why a node or its pods misbehave |

### The useful options of `kubectl logs`

| Option | Use it when |
| --- | --- |
| `--tail=N` | You only want the latest lines |
| `-f` | You want to watch new lines arrive |
| `--since=10m` | You only want a time window |
| `--previous` | The container restarted, and you need what it said **before** it died |
| `-c NAME` | The pod has several containers |
| `-l LABEL --prefix` | You want all pods of one part, with each pod's name in front |
| `deployment/NAME` | You do not care which pod; kubectl picks one |

## Step by step

### Step 1: read the logs of the backend

`kubectl logs deployment/backend -n prod` picks one of the two backend pods and says which (`Found 2 pods, using ...`). The lines show PostgREST connecting to the database and loading its schema: a healthy start. To see both pods, use `-l app=backend --prefix`.

### Step 2: follow one request through all three parts

One `curl` to `shop.local` creates one line in three logs:

| Log | Line | What it shows |
| --- | --- | --- |
| Ingress controller | `"GET /api/items" 200 ... [prod-frontend-80]` | It matched the rule, and sent the request to the Service `frontend` port 80 in `prod` |
| One frontend pod | `"GET /api/items" 200` | nginx received it and passed it on |
| One backend pod | `"GET /items" 200` | PostgREST answered it (the `/api` part was removed by nginx) |

The time stamps match, which is how you know it is the same request. Only one frontend pod and one backend pod show it: the others still show older lines, because each request went to one pod. Walking this path is the core skill of troubleshooting: find the last place the request reached.

### Step 3: read the events

`kubectl get events --sort-by=.lastTimestamp` puts the newest at the bottom. `Normal` events tell the story (pulled, scaled, deleted); `Warning` events are problems (a failed probe, a failed image pull, a failed scheduling). Events disappear after about an hour, so read them soon after a problem.

### Step 4: the control plane pods

The scheduler and the controller manager are static pods in `kube-system`, so `kubectl logs` reads them like any pod. Their names end in the node name. The scheduler logs why it could not place a pod; the controller manager logs problems with Deployments, ReplicaSets and nodes.

### Step 5: the kubelet

The kubelet is a **systemd service** on each node, not a pod, so `kubectl logs` cannot reach it. `journalctl -u kubelet --no-pager -n 5` reads its last lines from the node's journal. When a node is `NotReady`, or pods on one node will not start, this is the log to read.

### Step 6: when the API server itself is down

`kubectl logs` needs the API server. If the API server is the broken part, you go to the node and ask the container runtime directly: `crictl ps` lists containers (like `docker ps`), and `crictl logs` reads one. The log files are also on disk under `/var/log/pods/`. This is how you find a typo in the API server's static pod file.

### Where each log lives

The table at the end of the lab is worth learning: it answers "where do I look?" for every part of the cluster.

## When something goes wrong

| What you see | What it means | What to do |
| --- | --- | --- |
| `kubectl logs` shows nothing | The program writes nothing to stdout, or has just started | Check `--previous`, or whether it logs to a file |
| `a container name must be specified` | The pod has more than one container | Add `-c NAME` |
| The logs stop at a crash | The container restarted, the new one has a fresh log | `kubectl logs POD --previous` |
| `Could not resolve host: shop.local` | The `/etc/hosts` line is missing | Add it again (Lab 3.2, Step 8) |
| No events at all | Events older than about an hour are gone | Reproduce the problem and look again |
| `kubectl` refused, nothing to read | The API server is down | `crictl ps -a` and `crictl logs` on the control plane node |

## For the exam

- `kubectl logs POD`, `-c`, `--previous`, `-f`, `--tail`, `--since`, `-l ... --prefix`: know them all.
- A task "save the log lines of pod X that contain Y to a file": `kubectl logs X | grep Y > /path/file`.
- The kubelet: `systemctl status kubelet` and `journalctl -u kubelet` on the node; a stopped or misconfigured kubelet makes a node `NotReady`.
- With the API server down: `crictl ps -a`, `crictl logs ID`, and the files in `/var/log/pods/` on the control plane node.

## Check your understanding

1. Where does `kubectl logs` get its lines from?
2. A pod restarted three times. How do you read why it crashed?
3. Why can you not read the kubelet's log with `kubectl logs`?
4. How did you know the three log lines in Step 2 belonged to the same request?
5. `kubectl` is refused. How do you read the API server's log?

<details><summary>Answers</summary>

1. From a file on the pod's node, written by the container runtime from the program's stdout and stderr; the kubelet reads it on request.
2. `kubectl logs POD --previous`, plus the events in `kubectl describe pod`.
3. The kubelet is a service on the node, not a pod; its log is in the node's journal.
4. The same time stamp and the same path, in the Ingress controller, one frontend pod and one backend pod.
5. On the control plane node: `crictl ps` to find the container, `crictl logs` to read it.

</details>

**Back to:** [Lab 6.1](./lab-6.1-application-and-system-logs.md) · **Next:** [Lab 6.2 explained](./lab-6.2-cluster-wide-logging-explained.md)
