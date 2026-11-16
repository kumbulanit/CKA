# Workshop 1 explained: start, the whole Shop in one command

This page goes with [Workshop 1](./lab-w1-start.md). The workshop page has the commands; this page explains them: what the build script does, why the day starts this way, and what to look for in the walk-through. There is nothing to paste here.

## In short

The joint workshop day brings two groups together, so everyone first needs the same, complete Shop. One script builds it with everything from the course; another checks it. Then the pairs walk through it: the person from the new group explains, the person from the first group asks. That walk-through is the recap of the whole course.

## The ideas behind this workshop

### One known starting point

Practice tasks only make sense if everyone starts from the same state. Servers from the course may have extra objects, leftovers from labs, or missing pieces; servers of the new group may have no Shop at all. `deploy-shop.sh` builds the Shop in a namespace exactly as it stands at the end of the course, and `check-shop.sh` proves it works.

### What `deploy-shop.sh` builds, and where you met each part

| Order | What it creates | Course lab |
| --- | --- | --- |
| 1 | The namespace | Lab 1.1 |
| 2 | The database password (Secret) | Lab 1.5 |
| 3 | The storage class and the disk (PV) | Labs 7.2 and 7.3 |
| 4 | The LimitRange and the quota | Lab 7.4 |
| 5 | The three parts: ConfigMaps, Services, the database's claim, Deployments with probes and resources (in `dev` the frontend also gets NodePort 30080) | Labs 1.3 to 1.8, 7.2 |
| 6 | The NetworkPolicies | Lab 3.1 |

The order matters for the same reasons as in the course: the quota and LimitRange must be in place before the pods (so every pod gets its requests and limits), and the Secret and the disk must exist before the database pod can start. An existing Secret is kept, so running the script again does not change a password.

### What `check-shop.sh` checks

Eight checks, from the bottom up: the nodes, each Deployment's ready pods, each Service's ready endpoints, and finally a real request through frontend → backend → database. It is the same order as the troubleshooting method (Lab 8.1): when a check fails, the first failing line tells you where to start.

## Step by step

### Before you start

Every workshop works in `dev`. Setting the namespace once saves typing `-n dev`, but the tasks in Workshop 2 name it anyway.

### Step 1: build the Shop

Only for servers without a Shop. The script is safe to run more than once: it applies files, so existing objects are updated, not duplicated. The database starts last, because it waits for its disk and password; the backends may show `0/1` for a short while until the database is ready.

### Step 2: check the Shop

`All 8 checks passed` is the baseline for the day. If a check fails, fix it before Workshop 2: tasks built on a broken Shop teach the wrong lessons.

### Step 3: look at what you have

`kubectl get deployments,services,pvc,networkpolicies,resourcequota` lists five kinds in one command. The four questions make the pair read the output as a map of the Shop.

<details><summary>What good answers look like</summary>

1. `db` (1 pod), `backend` (2 pods), `frontend` (2 pods).
2. The Service `frontend`: in `dev` it is the NodePort Service on port 30080.
3. On the PersistentVolume bound to the claim `db-data`: a folder on one node (Lab 7.2).
4. Only pods with the label `app=backend`, on port 5432: the NetworkPolicy `allow-backend-to-db` (Lab 3.1).

</details>

### Step 4: open the Shop

`kubectl port-forward` makes the frontend reachable on `localhost:8080` of your server, as in Lab 1.6. The request still goes through nginx to the backend and the database, so the items prove the whole path works. `kill %1` stops the port-forward.

## When something goes wrong

| What you see | What it means | What to do |
| --- | --- | --- |
| `deploy-shop.sh` stops with a connection error | The cluster is not running | `cd ~/CKA && sudo ./setup.sh`, then run it again |
| The database pod stays `Pending` | Its disk is on a node that is cordoned or tainted | `kubectl describe pod`; `kubectl uncordon` the node |
| A check fails right after the build | The backend is still connecting | Wait 30 seconds and check again |
| `port-forward` says the port is in use | An old port-forward still runs | `kill %1`, or use another port |

## For the exam

- The exam has no build script: you create objects one by one, often from a short task text. The walk-through is practice in reading a namespace quickly: one `kubectl get` with several kinds shows a lot.
- Explaining a setup out loud is the best test of understanding. If you cannot say why an object is there, look it up in its course lab.

## Check your understanding

1. Why does the quota come before the Deployments in the build order?
2. What does the last check of `check-shop.sh` prove that the others do not?
3. Which object decides who may talk to the database?
4. The database pod is `Pending` after the build. Name two possible reasons.

<details><summary>Answers</summary>

1. With a quota on CPU and memory, every pod needs requests and limits; the LimitRange (applied with the quota) gives defaults, so the pods are not refused.
2. That a real request travels the whole path: frontend → backend → database, and back.
3. The NetworkPolicy `allow-backend-to-db`.
4. Any two of: its disk's node is cordoned, tainted or full; the claim is not bound; the Secret is missing.

</details>

**Back to:** [Workshop 1](./lab-w1-start.md) · **Next:** [Workshop 2 explained](./lab-w2-challenge-rounds-explained.md)
