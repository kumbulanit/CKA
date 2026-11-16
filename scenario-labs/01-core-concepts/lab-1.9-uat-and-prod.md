# Lab 1.9: The Shop in UAT and PROD

**The situation:** The Shop works in `dev`. Testers need it in `uat`, and customers in `prod`.

**Goal:** put the same Shop in the other two environments, `uat` and `prod`.

**Outline topic:** 1. Core concepts: *Namespaces*, *Deployment of applications and services*.

**What you learn:** deploying the same files into another namespace, and how namespaces keep environments apart.

There is no pipeline in this course. You move the application yourself, with `kubectl`. That is also how the exam works.

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

## Step 1: look at the Shop as files

The folder `shop` holds the Shop exactly as you built it in this module: five files.

**📋 Copy and paste into your terminal:**

```bash
ls shop
```

**What this does:** Lists the files in `shop`.

**👀 You should see** *(do not paste)*:

```text
01-config.yaml  02-services.yaml  03-database.yaml  04-backend.yaml  05-frontend.yaml
```

| File | What is in it | You made it in |
| --- | --- | --- |
| `01-config.yaml` | The three ConfigMaps | Labs 1.5 and 1.6 |
| `02-services.yaml` | The three Services | Labs 1.4 and 1.6 |
| `03-database.yaml` | The database Deployment | Lab 1.6 |
| `04-backend.yaml` | The backend Deployment, with settings and health checks | Labs 1.5 and 1.7 |
| `05-frontend.yaml` | The frontend Deployment, with the web page | Lab 1.5 |

None of the files names a namespace. You choose the namespace when you apply them.

## Step 2: build UAT

Each environment gets its **own password**. Then comes the Shop.

**📋 Copy and paste into your terminal:**

```bash
kubectl create secret generic db-secret -n uat --from-literal=password=uat-pass-123
kubectl apply -f shop/ -n uat
```

**What this does:**

- `kubectl create secret generic ...`: Creates a Secret called `db-secret` in the namespace `uat`, with the key `password`.
- `kubectl apply -f shop/ -n uat`: Creates (or updates) what is described in every file of the folder `shop/` in the namespace `uat`.

**👀 You should see** *(do not paste)*:

```text
secret/db-secret created
configmap/backend-config created
configmap/frontend-config created
configmap/db-init created
service/db created
service/backend created
service/frontend created
deployment.apps/db created
deployment.apps/backend created
deployment.apps/frontend created
```

- `-f shop/` means: every file in the folder `shop`.
- `-n uat` means: into the namespace `uat`.

## Step 3: build PROD

The same two commands, with `prod`:

**📋 Copy and paste into your terminal:**

```bash
kubectl create secret generic db-secret -n prod --from-literal=password=prod-pass-123
kubectl apply -f shop/ -n prod
```

**What this does:**

- `kubectl create secret generic ...`: Creates a Secret called `db-secret` in the namespace `prod`, with the key `password`.
- `kubectl apply -f shop/ -n prod`: Creates (or updates) what is described in every file of the folder `shop/` in the namespace `prod`.

**👀 You should see** the same ten lines as for UAT, from `secret/db-secret created` to `deployment.apps/frontend created`.

## Step 4: wait and check both

**📋 Copy and paste into your terminal:**

```bash
kubectl rollout status deployment/backend -n uat
kubectl rollout status deployment/backend -n prod
kubectl get pods -n uat
kubectl get pods -n prod
```

**What this does:**

- `kubectl rollout status deployment/backend -n uat`: Waits until the new pods of the Deployment `backend` in the namespace `uat` are all ready, and says when it is done.
- `kubectl rollout status deployment/backend -n prod`: Waits until the new pods of the Deployment `backend` in the namespace `prod` are all ready, and says when it is done.
- `kubectl get pods -n uat`: Lists the pods in the namespace `uat`.
- `kubectl get pods -n prod`: Lists the pods in the namespace `prod`.

**👀 You should see** five pods in each, all `1/1 Running` *(do not paste)*:

```text
NAME                        READY   STATUS    RESTARTS   AGE
backend-c5d9479f-9dg5w      1/1     Running   0          35s
backend-c5d9479f-dg6mv      1/1     Running   0          35s
db-747c44dc87-drvlh         1/1     Running   0          35s
frontend-5f69b684d8-8tqmw   1/1     Running   0          35s
frontend-5f69b684d8-ggcnx   1/1     Running   0          35s
NAME                        READY   STATUS    RESTARTS   AGE
backend-c5d9479f-vkqfh      1/1     Running   0          33s
backend-c5d9479f-vs47x      1/1     Running   0          33s
db-747c44dc87-rg87j         1/1     Running   0          33s
frontend-5f69b684d8-d8wqg   1/1     Running   0          32s
frontend-5f69b684d8-g5n6w   1/1     Running   0          32s
```

If a backend pod shows `0/1`, wait 30 seconds and look again: it waits for its database.

## Step 5: test the Shop in PROD

The frontend in `uat` and `prod` has no node port. Test it from inside a frontend pod:

**📋 Copy and paste into your terminal:**

```bash
kubectl exec -n prod deployment/frontend -- curl -s http://localhost/api/items; echo
```

**What this does:** From inside a PROD frontend pod, asks for the items. The request goes frontend → backend → database, all in `prod`.

**👀 You should see** *(do not paste)*:

```text
[{"id":1,"name":"Coffee","price":35},
 {"id":2,"name":"Tea","price":25},
 {"id":3,"name":"Muffin","price":30}]
```

## Step 6: three Shops, kept apart

**📋 Copy and paste into your terminal:**

```bash
kubectl get deployments -A | grep -E "NAMESPACE|dev|uat|prod"
```

**What this does:** Lists the Deployments in all namespaces. `| grep` keeps only the lines with `NAMESPACE` or `dev` or `uat` or `prod`.

**👀 You should see** the same three Deployments in each environment *(do not paste)*:

```text
NAMESPACE     NAME                      READY   UP-TO-DATE   AVAILABLE   AGE
dev           backend                   2/2     2            2           34m
dev           db                        1/1     1            1           32m
dev           frontend                  2/2     2            2           34m
prod          backend                   2/2     2            2           60s
prod          db                        1/1     1            1           60s
prod          frontend                  2/2     2            2           60s
uat           backend                   2/2     2            2           75s
uat           db                        1/1     1            1           75s
uat           frontend                  2/2     2            2           75s
```

The names are the same (`backend`, `db`, `frontend`), and that is fine: a name only has to be unique **inside its namespace**. The backend in `prod` talks to the `db` in `prod`, because the short name `db` is looked up in its own namespace first.

💡 **Exam tip:** `-A` (or `--all-namespaces`) shows a kind of object in all namespaces at once: `kubectl get pods -A`.

✅ **Check:** Step 5 gives the three items.

**The Shop at the end of this module:** it runs in `dev`, `uat` and `prod`. In the next modules you look after the cluster under it, and make PROD ready for real users.

**Next:** [Lab 2.1: Installing the cluster](../02-installation/lab-2.1-installing-the-cluster.md)
