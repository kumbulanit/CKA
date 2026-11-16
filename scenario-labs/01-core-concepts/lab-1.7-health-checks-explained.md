# Lab 1.7 explained: health checks

This page goes with [Lab 1.7](./lab-1.7-health-checks.md). The lab has the commands; this page explains them: what happens in the cluster, why it matters for the Shop, what usually goes wrong, and what the exam asks. There is nothing to paste here.

## In short

Kubernetes only knows that a container **started**. A **probe** tells it whether the program **works**. A failed **liveness** probe restarts the container; a failed **readiness** probe takes the pod out of its Service, without restarting it. In this lab the backend loses its database, stops getting traffic, and recovers by itself.

## The ideas behind this lab

### Three probes, three questions

| Probe | The question | If it fails | Typical use |
| --- | --- | --- | --- |
| **Liveness** | Is the program stuck or dead? | The kubelet **restarts** the container | A program that can hang |
| **Readiness** | Can it serve a request right now? | The pod is **removed from its Services' endpoints** | Waiting for a database, warming up, too busy |
| **Startup** | Has a slow program finished starting? | Liveness and readiness wait; after too many failures, a restart | Programs that need minutes to start |

The difference that matters: a restart cannot fix a missing database. If the backend's liveness probe checked the database, Kubernetes would restart healthy backends again and again, for a problem that is not theirs. So in the Shop, liveness asks "are you alive?" (`/live`) and readiness asks "can you reach the database?" (`/ready`). PostgREST answers both on its admin port, 3001, which `backend-config` turned on in Lab 1.5.

### Who runs the probes

The **kubelet** on the pod's node runs them, not the control plane. It sends the request every `periodSeconds`, and acts after `failureThreshold` failures in a row (3 by default). For readiness, it marks the pod as not ready; the EndpointSlice controller then removes the pod's address from the Service (Lab 1.4). For liveness, the kubelet kills the container and starts it again in the same pod: `RESTARTS` goes up.

### The settings

| Setting | Default | Meaning |
| --- | --- | --- |
| `initialDelaySeconds` | 0 | Wait this long after the container starts |
| `periodSeconds` | 10 | Check this often |
| `timeoutSeconds` | 1 | An answer later than this counts as a failure |
| `failureThreshold` | 3 | Failures in a row before acting |
| `successThreshold` | 1 | Successes in a row to count as healthy again |

An `httpGet` probe succeeds on any HTTP answer from 200 to 399.

## Step by step

### Step 1: add the probes to the backend

Adding probes changes the pod template, so the Deployment rolls out new pods. New pods only count as available once their readiness probe succeeds. From now on, `rollout status` really means "the new backends can reach the database", not only "they started".

### Step 2: see the probes

`kubectl describe deployment` prints each probe in one line. `delay`, `timeout` and `period` are the settings above; `#failure=3` is the threshold.

### Step 3: take the database away

Scaling `db` to 0 deletes the database pod. Within a few seconds the backend's `/ready` answers `503`; after three failures (about 15 seconds at `periodSeconds: 5`) each backend pod turns `0/1`. They stay `Running` with `RESTARTS 0`: liveness still passes, because the program itself is fine.

What a customer sees now: the frontend still answers, but every `/api/` request fails, because the Service `backend` has no ready pods behind it. That is the honest answer. Without a readiness probe, the Service would keep sending requests to backends that cannot answer them.

### Step 4: read why

`kubectl get events --field-selector reason=Unhealthy` filters the events to failed probes. The message gives the probe type and the reason (`statuscode: 503`). The same lines appear at the bottom of `kubectl describe pod`.

### Step 5: bring the database back

A new database pod starts, with an empty `emptyDir`, so `init.sql` runs again. As soon as the backend can reach it, `/ready` answers `200`, the pods turn `1/1`, and they are back in the Service. Nobody restarted anything.

### Step 6: check the Shop

The three first items are back, but the Juice from Lab 1.6 is gone: the old database pod and its `emptyDir` were deleted. Probes keep the Shop honest, but they do not keep data. That needs storage (Module 7).

## When something goes wrong

| What you see | What it means | What to do |
| --- | --- | --- |
| `RESTARTS` keeps going up | The liveness probe fails | `kubectl describe pod`: check the probe's path and port |
| Pods stay `0/1` with the database running | The backend cannot reach `db`, or the readiness path is wrong | `kubectl logs` on a backend pod; check the database pod is `1/1` |
| `rollout status` never finishes | The new pods never become ready | `kubectl describe pod` on a new pod: read the `Unhealthy` events |
| A slow program is restarted before it is up | Liveness starts too early | Raise `initialDelaySeconds`, or add a startup probe |

## For the exam

- Three kinds of check: `httpGet`, `tcpSocket`, `exec` (plus `grpc`). `kubectl explain pod.spec.containers.livenessProbe` shows the fields.
- "Running but 0/1" means readiness fails; "restarts keep going up" usually means liveness fails or the program crashes.
- Copy a probe from the documentation page "Configure Liveness, Readiness and Startup Probes" and change the path and port.
- A readiness probe never restarts a container. A liveness probe never removes a pod from a Service by itself (the container restarts, and is unready while it does).

## Check your understanding

1. Why does the Shop's liveness probe not check the database?
2. Which part of Kubernetes runs the probes?
3. The backend pods show `0/1 Running` and `RESTARTS 0`. What is going on?
4. During Step 3, what happens to a request to `/api/items`?
5. Why is the Juice gone after Step 5?

<details><summary>Answers</summary>

1. A restart cannot fix a missing database. Kubernetes would keep restarting healthy backends for a problem elsewhere.
2. The kubelet on the pod's node.
3. The readiness probe fails (no database), the liveness probe passes. The pods get no traffic but are not restarted.
4. The frontend answers, but the Service `backend` has no ready pods, so the API request fails.
5. The database pod was deleted, and its `emptyDir` with it. The new pod started from `init.sql`.

</details>

**Back to:** [Lab 1.7](./lab-1.7-health-checks.md) · **Next:** [Lab 1.8 explained](./lab-1.8-releases-and-rollbacks-explained.md)
