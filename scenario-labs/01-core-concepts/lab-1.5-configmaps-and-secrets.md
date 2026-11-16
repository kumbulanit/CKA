# Lab 1.5: Application configuration: settings, the web page and the password

**The situation:** The backend does not know where its database is, and the frontend still shows the standard nginx page.

**Goal:** give the backend its settings and the database password, and give the frontend the Shop web page.

**Outline topic:** 1. Core concepts: *Application lifecycle management* (configuring applications).

**What you learn:** ConfigMaps, Secrets, environment variables, files mounted from a ConfigMap.

📘 **More detail:** [Lab 1.5 explained](./lab-1.5-configmaps-and-secrets-explained.md): what happens in the cluster at each step, common mistakes and exam notes.

Settings do not belong inside the image. Kubernetes keeps them apart:

- a **ConfigMap** holds normal settings;
- a **Secret** holds passwords and keys.

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
cd ~/CKA/scenario-labs/01-core-concepts
kubectl config set-context --current --namespace=dev
```

**What this does:**

- `cd ~/CKA/scenario-labs/01-core-concepts`: Goes to the folder `~/CKA/scenario-labs/01-core-concepts`.
- `kubectl config set-context --current --namespace=dev`: Makes `dev` your working namespace: commands without `-n` now work in `dev`.

**👀 You should see** *(do not paste)*:

```text
Context "minikube" modified.
```

💡 **Tip:** `kubens dev` does the same as the second line (see the shortcuts in [setup, Step 5](../00-setup.md)).

## Part A: the backend

### Step 1: create the ConfigMap with the backend settings

**📋 Copy and paste into your terminal:**

```bash
cat backend-config.yaml
```

**What this does:** Shows what is in the file `backend-config.yaml`.

**👀 You should see** *(do not paste)*:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: backend-config
data:
  PGRST_DB_URI: "postgres://shop@db:5432/shop"
  PGRST_DB_ANON_ROLE: "shop"
  PGRST_DB_SCHEMAS: "public"
  PGRST_ADMIN_SERVER_PORT: "3001"
  PGRST_LOG_LEVEL: "info"
```

The first setting tells the backend where the database is: user `shop`, on the Service named `db`, port `5432`.

**📋 Copy and paste into your terminal:**

```bash
kubectl apply -f backend-config.yaml
```

**What this does:** Creates (or updates) what is described in `backend-config.yaml`.

**👀 You should see** *(do not paste)*:

```text
configmap/backend-config created
```

### Step 2: create the Secret with the database password

**📋 Copy and paste into your terminal:**

```bash
kubectl create secret generic db-secret --from-literal=password=dev-pass-123
```

**What this does:** Creates a Secret called `db-secret`, with the key `password`.

**👀 You should see** *(do not paste)*:

```text
secret/db-secret created
```

A Secret is stored encoded (base64), not as plain text. Read it back:

**📋 Copy and paste into your terminal:**

```bash
kubectl get secret db-secret -o jsonpath="{.data.password}" | base64 -d; echo
```

**What this does:** Reads the key `password` of the Secret `db-secret` and decodes it (Secrets are stored encoded with base64).

**👀 You should see** *(do not paste)*:

```text
dev-pass-123
```

### Step 3: give both to the backend

This file is the backend Deployment from Lab 1.3, with these lines added at the end:

**📖 Read only (do not paste):**

```yaml
        envFrom:
        - configMapRef:
            name: backend-config        # all the settings
        env:
        - name: PGPASSWORD              # the database password
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: password
```

**📋 Copy and paste into your terminal:**

```bash
kubectl apply -f backend-deployment-with-config.yaml
kubectl rollout status deployment/backend
```

**What this does:**

- `kubectl apply -f backend-deployment-with-config.yaml`: Creates (or updates) what is described in `backend-deployment-with-config.yaml`.
- `kubectl rollout status deployment/backend`: Waits until the new pods of the Deployment `backend` are all ready, and says when it is done.

**👀 You should see** (the last line, after about 40 seconds) *(do not paste)*:

```text
deployment "backend" successfully rolled out
```

### Step 4: check that the pod has the settings

**📋 Copy and paste into your terminal:**

```bash
kubectl describe deployment backend | grep -A4 "Environment Variables from"
```

**What this does:** Shows where the backend's pods get their settings (environment variables) from. `| grep` keeps only that part of the long answer.

**👀 You should see** *(do not paste)*:

```text
    Environment Variables from:
      backend-config  ConfigMap  Optional: false
    Environment:
      PGPASSWORD:  <set to the key 'password' in secret 'db-secret'>  Optional: false
    Mounts:        <none>
```

Every key of the ConfigMap `backend-config` becomes a setting, and `PGPASSWORD` comes from the Secret `db-secret`.

💡 **Tip:** why not look inside the pod with `kubectl exec deployment/backend -- env`? The backend image is very small: it holds only the PostgREST program, without a shell or tools such as `env`. Many production images are built like that.

## Part B: the frontend

### Step 5: create the ConfigMap with the web page

This ConfigMap holds two **files**: the Shop web page (`index.html`) and the nginx settings (`default.conf`). The nginx settings send everything under `/api/` to the backend Service.

**📋 Copy and paste into your terminal:**

```bash
kubectl apply -f frontend-config.yaml
kubectl describe configmap frontend-config | grep -A14 "^default.conf"
```

**What this does:**

- `kubectl apply -f frontend-config.yaml`: Creates (or updates) what is described in `frontend-config.yaml`.
- `kubectl describe configmap frontend-config | grep -A14 "^default.conf"`: Shows the ConfigMap `frontend-config`. `| grep` keeps only the file `default.conf` (the nginx settings) and the 14 lines after its name.

**👀 You should see** the nginx settings *(do not paste)*:

```text
default.conf:
----
server {
  listen 80;
  # the web page
  location / {
    root /usr/share/nginx/html;
    index index.html;
  }
  # everything under /api/ goes to the backend Service
  location /api/ {
    proxy_pass http://backend:3000/;
  }
}
```

### Step 6: mount the files in the frontend

This file is the frontend Deployment from Lab 1.3, with the ConfigMap mounted as two files:

**📖 Read only (do not paste):**

```yaml
        volumeMounts:
        - name: config
          mountPath: /usr/share/nginx/html/index.html   # the web page
          subPath: index.html
        - name: config
          mountPath: /etc/nginx/conf.d/default.conf     # the nginx settings
          subPath: default.conf
      volumes:
      - name: config
        configMap:
          name: frontend-config
```

**📋 Copy and paste into your terminal:**

```bash
kubectl apply -f frontend-deployment-with-config.yaml
kubectl rollout status deployment/frontend
sleep 15
```

**What this does:**

- `kubectl apply -f frontend-deployment-with-config.yaml`: Creates (or updates) what is described in `frontend-deployment-with-config.yaml`.
- `kubectl rollout status deployment/frontend`: Waits until the new pods of the Deployment `frontend` are all ready, and says when it is done.
- `sleep 15`: Waits 15 seconds, until the old pods are gone everywhere. Right after an update, a request can still be sent to a pod that is stopping, and then it hangs.

**👀 You should see** (the last line) *(do not paste)*:

```text
deployment "frontend" successfully rolled out
```

### Step 7: open the Shop page

**📋 Copy and paste into your terminal:**

```bash
curl -s http://$(minikube ip):30080 | grep "<h1>"
```

**What this does:** Opens the Shop page, as a web browser would. `| grep` keeps only the title line (`<h1>`).

**👀 You should see** *(do not paste)*:

```text
  <h1>Shop</h1>
```

The standard nginx page is gone. This is the Shop page from the ConfigMap.

### Step 8: call the backend through the frontend

**📋 Copy and paste into your terminal:**

```bash
curl -s http://$(minikube ip):30080/api/items; echo
```

**What this does:** Asks the Shop for its items. The frontend passes the request on to the backend.

**👀 You should see** *(do not paste)*:

```text
{"code":"PGRST002","details":null,"hint":null,"message":"Could not query the database for the schema cache. Retrying."}
```

Read the message: the request went **frontend → backend**, and the backend now tries to reach its database. There is none yet. That is the last piece, in the next lab.

💡 **Exam tip:** create a ConfigMap in one line:

**📖 Read only (do not paste):**

```text
kubectl create configmap my-config --from-literal=KEY=value --from-file=file.conf
```

✅ **Check:** Step 4 shows the ConfigMap `backend-config` and the Secret `db-secret`, and Step 7 shows `<h1>Shop</h1>`.

**The Shop so far:** frontend and backend run with their settings. Only the database is missing.

**Next:** [Lab 1.6: The database](./lab-1.6-the-database.md)
