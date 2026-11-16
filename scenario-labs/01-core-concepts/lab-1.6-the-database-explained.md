# Lab 1.6 explained: the database, and the whole Shop

This page goes with [Lab 1.6](./lab-1.6-the-database.md). The lab has the commands; this page explains them: what happens in the cluster, why it matters for the Shop, what usually goes wrong, and what the exam asks. There is nothing to paste here.

## In short

The database is the last part of the Shop, and it uses nothing new: a Deployment, a Service, a Secret and a ConfigMap. Once it runs, one request travels through all three parts. One new thing appears quietly: an `emptyDir` volume, which holds the database's files only as long as the pod lives.

## The ideas behind this lab

### One application, many small objects

| Object | Frontend | Backend | Database |
| --- | --- | --- | --- |
| Deployment | `frontend` (2 pods) | `backend` (2 pods) | `db` (1 pod) |
| Service | `frontend` (NodePort) | `backend` (ClusterIP) | `db` (ClusterIP) |
| ConfigMap | `frontend-config` (page, nginx settings) | `backend-config` (settings) | `db-init` (first data) |
| Secret | | `db-secret` (to log in) | `db-secret` (to set the password) |

The backend and the database read the **same** Secret: one sets the password, the other uses it. Change it in one place, and both agree after a restart.

### How the parts find each other

Each part only knows the **Service name** of the next part: nginx sends `/api/` to `backend:3000`, and the backend connects to `db:5432`. Neither knows a pod, a node or an IP address. That is why any pod of any part can be replaced at any time.

### Why the database has `replicas: 1` and `strategy: Recreate`

A PostgreSQL server owns its data folder alone. Two copies of the same database pod, writing to the same files, would corrupt them. So the database runs as one pod, and the `Recreate` strategy stops the old pod **before** starting a new one during an update. The default strategy (`RollingUpdate`, Lab 1.8) would start the new one first. Real databases with several copies use a **StatefulSet** and replication, which is beyond this course's Shop.

### What `emptyDir` means

An `emptyDir` volume is an empty folder created on the node when the pod starts, shared by the pod's containers, and **deleted when the pod is deleted**. It survives a container restart, but not a new pod. The database keeps its files there for now. Lab 1.7 shows the price, and Module 7 replaces it with a real disk.

### The first data

The official `postgres` image runs every `.sql` file it finds in `/docker-entrypoint-initdb.d`, **only when the data folder is empty**. The ConfigMap `db-init` is mounted there, with `init.sql`: it creates the table `items` and the first three items. With an `emptyDir`, the folder is empty after every new pod, so the three items come back each time, and anything added later is lost.

## Step by step

### Step 1: look at the three files

The new pieces are the environment variables that the `postgres` image reads at its first start: `POSTGRES_USER`, `POSTGRES_DB`, `POSTGRES_PASSWORD` (from the Secret) and `PGDATA` (where to keep the files, one level below the mount point, which PostgreSQL prefers).

### Step 2: start the database

Three files in one `kubectl apply`. Order does not matter to Kubernetes: the ConfigMap, Deployment and Service are stored together, and the pod only starts once its ConfigMap and Secret exist. The Service `db` selects `app=db`, so it gets the database pod as soon as it is ready.

### Step 3: connect the backend

The backend has been retrying its connection since Lab 1.5. `kubectl rollout restart` replaces its pods, so new pods connect at once instead of waiting for the next retry. `rollout restart` changes nothing in your file: it adds a timestamp to the pod template, which counts as a change and starts a rolling update.

### Step 4: the whole Shop works

`curl .../api/items` follows the full path: your server → NodePort 30080 → a frontend pod → nginx sends `/api/items` to the Service `backend` → a backend pod → PostgREST turns `/items` into `SELECT * FROM items` → the Service `db` → the database pod. The answer travels back the same way, as JSON.

### Step 5: add an item

A `POST` with JSON asks PostgREST to insert a row. `201 Created` means the database stored it. The new item lives in the `emptyDir` folder on the database pod's node.

### Step 6: see the Shop in a browser (optional)

`kubectl port-forward service/frontend 8080:80` opens a tunnel from port 8080 on your server, through the API server, to one frontend pod. It is a tool for people, not for real traffic: it goes through `kubectl` and stops when `kubectl` stops. The `&` runs it in the background; `kill %1` stops background job number 1.

### Step 7: look at everything you built

`kubectl get all` lists pods, Services, Deployments and ReplicaSets. Despite its name, it does not list ConfigMaps, Secrets and many other kinds. You see five pods (2 + 2 + 1), three Services and three Deployments, and one ReplicaSet per version of each Deployment (older ones at 0).

## When something goes wrong

| What you see | What it means | What to do |
| --- | --- | --- |
| The `curl` gives an error instead of the items | The backend has not connected yet | Wait 10 seconds and try again |
| `db` pod in `CreateContainerConfigError` | `db-secret` is missing in this namespace | Create it (Lab 1.5, Step 2) |
| The database pod restarts again and again | Its logs say why, often a wrong setting | `kubectl logs deployment/db` |
| `port-forward` says the address is in use | An old port-forward still runs | `kill %1`, or use another local port |

## For the exam

- `kubectl get all` misses ConfigMaps, Secrets, PVCs and more; ask for them by name when you check a namespace.
- `kubectl rollout restart deployment/NAME` is the standard way to make pods pick up changed settings.
- Know `emptyDir`: a scratch folder shared by the containers of one pod, gone with the pod. Tasks with a sidecar container often use it.
- `kubectl port-forward` works for pods, Deployments and Services, and is a fast way to test something from the exam terminal.

## Check your understanding

1. How does the backend find the database?
2. Why does the database run with one pod and `strategy: Recreate`?
3. Where is the Juice stored after Step 5, and what happens to it when the database pod is deleted?
4. Why do the first three items always come back?
5. Does `kubectl get all` show the Secret `db-secret`?

<details><summary>Answers</summary>

1. By the Service name `db`, set in `PGRST_DB_URI` in the ConfigMap `backend-config`.
2. One PostgreSQL server must own its data folder alone; two at once would damage the files. `Recreate` stops the old pod before the new one starts.
3. In the `emptyDir` folder of the database pod, on its node. It is deleted with the pod.
4. The data folder starts empty in every new pod, so `init.sql` from the ConfigMap `db-init` runs again.
5. No. `get all` only shows a few kinds; use `kubectl get secrets`.

</details>

**Back to:** [Lab 1.6](./lab-1.6-the-database.md) · **Next:** [Lab 1.7 explained](./lab-1.7-health-checks-explained.md)
