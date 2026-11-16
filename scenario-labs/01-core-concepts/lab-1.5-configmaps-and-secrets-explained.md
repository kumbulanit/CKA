# Lab 1.5 explained: configuration with ConfigMaps and Secrets

This page goes with [Lab 1.5](./lab-1.5-configmaps-and-secrets.md). The lab has the commands; this page explains them: what happens in the cluster, why it matters for the Shop, what usually goes wrong, and what the exam asks. There is nothing to paste here.

## In short

An image should be the same in every environment. What differs (the database address, the log level, the password, the web page) comes from outside the image. A **ConfigMap** holds ordinary settings and files; a **Secret** holds passwords and keys. Pods read them as **environment variables** or as **files**.

## The ideas behind this lab

### Why settings live outside the image

If the database password were inside the backend image, you would need one image for `dev` and another for `prod`, and anyone who can download the image can read the password. With ConfigMaps and Secrets, one image (`postgrest/postgrest:v12.2.3`) runs everywhere, and each namespace has its own settings. Lab 1.9 builds on exactly this.

### ConfigMap and Secret side by side

| | ConfigMap | Secret |
| --- | --- | --- |
| For | Settings, whole configuration files | Passwords, keys, certificates |
| Stored as | Plain text | base64-encoded text |
| Visible with `kubectl get -o yaml` | Yes, readable | Yes, encoded |
| Size limit | 1 MiB | 1 MiB |

**base64 is not encryption.** Anyone who may read a Secret can decode it in one command, as Step 2 shows. Secrets are protected by **who may read them** (RBAC, Lab 5.1), and on real clusters also by encryption in etcd, which an administrator turns on.

### Two ways into a pod

| Way | In the Shop | When the value changes |
| --- | --- | --- |
| **Environment variables**: `envFrom` (all keys) or `env` with `valueFrom` (one key) | The backend's settings and password | The container keeps the old value until it restarts |
| **Files**: a volume from the ConfigMap, mounted in the container | The frontend's web page and nginx settings | Mounted files update after a short delay, but **not** when they are mounted with `subPath`, as in the Shop |

Because the Shop mounts its files with `subPath`, any change to `frontend-config` needs new pods: `kubectl rollout restart deployment/frontend`. nginx also only reads its settings at start.

## Step by step

### Step 1: create the ConfigMap with the backend settings

PostgREST reads its settings from environment variables whose names start with `PGRST_`. The most important one, `PGRST_DB_URI`, says: connect as user `shop` to the host `db` on port 5432, database `shop`. `db` is the name of a Service that does not exist yet: it comes in Lab 1.6. Kubernetes does not check that; the backend finds out when it tries to connect.

`PGRST_ADMIN_SERVER_PORT: 3001` turns on a small second port with health pages (`/live`, `/ready`). Lab 1.7 uses them for the health checks.

### Step 2: create the Secret with the database password

`kubectl create secret generic db-secret --from-literal=password=...` makes a Secret without a file, and encodes the value for you. Reading it back with `jsonpath` and `base64 -d` shows how thin the protection is. In a YAML file you would have to write the value base64-encoded yourself (or use the `stringData:` field, which takes plain text).

### Step 3: give both to the backend

The new Deployment file differs from Lab 1.3 in two blocks:

- `envFrom: configMapRef: backend-config` turns **every** key of the ConfigMap into an environment variable with the same name.
- `env: PGPASSWORD valueFrom: secretKeyRef` takes **one** key (`password`) from the Secret and gives it the name the program expects (`PGPASSWORD`, read by the PostgreSQL client library).

Applying the file changes the pod template, so the Deployment makes a **new ReplicaSet** and replaces the pods one by one: a rolling update (Lab 1.8). That is why you wait with `rollout status`. It takes a little longer than usual, because the backend keeps retrying its missing database.

### Step 4: check that the pod has the settings

`kubectl describe deployment backend` shows the pod template, including where each environment variable comes from: all keys of the ConfigMap `backend-config` (`Environment Variables from`), and `PGPASSWORD` from the key `password` of the Secret `db-secret`. It shows the sources, not the values: the values are in the ConfigMap and the Secret themselves.

Why not look inside a running pod with `kubectl exec deployment/backend -- env`? The PostgREST image contains only the PostgREST program: no shell, no `env`, no `ls`. Such minimal images are common, because they are small and give an attacker nothing to work with. You can only look inside them from outside: with `describe`, with logs, or with a debug container (`kubectl debug`). Inside the container, the password is plain text: the program needs it that way.

### Step 5: create the ConfigMap with the web page

A ConfigMap can hold whole files: here `index.html` (the Shop page) and `default.conf` (nginx's settings). The key `location /api/` in `default.conf` is the important line: nginx passes every request under `/api/` to `http://backend:3000/`. So the browser only ever talks to the frontend, and the frontend talks to the backend by its Service name from Lab 1.4.

### Step 6: mount the files in the frontend

A **volume** of type `configMap` turns the ConfigMap's keys into files. `mountPath` with `subPath` places one file at an exact path, without hiding the other files in that folder. Without `subPath`, mounting at `/etc/nginx/conf.d/` would replace the whole folder with the ConfigMap's files.

### Step 7: open the Shop page

The page now comes from the ConfigMap. Change the ConfigMap, restart the frontend, and the page changes, with the same image.

### Step 8: call the backend through the frontend

The request goes: your server → NodePort 30080 → a frontend pod → nginx sees `/api/` → Service `backend` → a backend pod → it tries the Service `db` → no database. The error message comes from the backend, so the first two hops work. The last part of the Shop is the database, in Lab 1.6.

## When something goes wrong

| What you see | What it means | What to do |
| --- | --- | --- |
| `CreateContainerConfigError` | The pod needs a ConfigMap or Secret (or a key in it) that does not exist | `kubectl describe pod`: the event names it; create it or fix the name |
| The pods still use old settings | Environment variables are read at start | `kubectl rollout restart deployment/backend` |
| The web page did not change after editing the ConfigMap | Files mounted with `subPath` do not update | `kubectl rollout restart deployment/frontend` |
| `rollout status` takes long | The backend waits for its database | Normal until Lab 1.6; it still finishes |

## For the exam

- `kubectl create configmap NAME --from-literal=K=V --from-file=FILE` and `kubectl create secret generic NAME --from-literal=K=V` are faster than YAML.
- Know both forms: `envFrom` for all keys, `env.valueFrom.configMapKeyRef` or `secretKeyRef` for one key.
- To read a Secret: `kubectl get secret NAME -o jsonpath='{.data.KEY}' | base64 -d`.
- A Secret mounted as a volume is a common task: the files appear under the `mountPath`, one per key.

## Check your understanding

1. Why does the database password not go into the backend image?
2. Is a Secret encrypted?
3. You change a value in `backend-config`. When does the backend see it?
4. What does the line `location /api/` in the nginx settings do for the Shop?
5. A pod shows `CreateContainerConfigError`. What is the likely cause?

<details><summary>Answers</summary>

1. So one image runs in every environment with its own password, and the image itself holds no secret.
2. No, only base64-encoded. It is protected by who may read it, and by etcd encryption where an administrator has turned that on.
3. Only after the pods restart: environment variables are set when the container starts.
4. It passes every request under `/api/` to the backend Service, so the browser only talks to the frontend.
5. A ConfigMap or Secret (or one of its keys) that the pod refers to does not exist.

</details>

**Back to:** [Lab 1.5](./lab-1.5-configmaps-and-secrets.md) · **Next:** [Lab 1.6 explained](./lab-1.6-the-database-explained.md)
