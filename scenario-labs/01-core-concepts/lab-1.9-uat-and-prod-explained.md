# Lab 1.9 explained: the Shop in UAT and PROD

This page goes with [Lab 1.9](./lab-1.9-uat-and-prod.md). The lab has the commands; this page explains them: what happens in the cluster, why it matters for the Shop, what usually goes wrong, and what the exam asks. There is nothing to paste here.

## In short

The Shop is now five YAML files that name no namespace. Applying them with `-n uat` and `-n prod` builds two more complete, independent copies of the Shop. Only the password differs per environment. Namespaces keep the names apart; the next modules add the walls.

## The ideas behind this lab

### Same files, different place

A YAML file without `metadata.namespace` goes into whatever namespace you give with `-n` (or your current namespace). That makes one set of files reusable across environments. It is the simple version of what tools like Helm and Kustomize do with more control; this course moves the Shop with plain `kubectl`, like the exam.

If a file **does** name a namespace and you give a different one with `-n`, `kubectl` refuses with an error. That is why the Shop's files leave it out.

### What is per environment

| Shared by all three | Different in each |
| --- | --- |
| The images | The Secret `db-secret` (its password) |
| The ConfigMaps' content | The data in each database |
| The Deployments and Services, as files | Every object: each namespace has its own copy |

The Secret is created **before** the files, with its own password per environment, and is not in the `shop` folder. Passwords should not live in files that are copied around.

### How the backend finds the right database

All three backends use the same setting: connect to `db:5432`. The short name `db` is looked up in the backend's **own namespace** first. So the backend in `prod` reaches `db.prod`, and the backend in `dev` reaches `db.dev`. Lab 3.3 shows exactly how (the `search` line in each pod's DNS settings).

### What namespaces do not do

| Separation | Done by a namespace? | Done in |
| --- | --- | --- |
| Names | Yes | |
| Network traffic | No: a `dev` pod can still reach a `prod` pod by its full name or IP | Lab 3.1 (NetworkPolicies) |
| Who may see or change things | No: you are administrator everywhere | Lab 5.1 (RBAC) |
| CPU, memory and disk | No: one environment can use everything | Lab 7.4 (quotas) |
| Nodes | No: all three share the same nodes | Module 4 (scheduling) |

Day 2 and Day 3 add these walls one by one, mostly for `prod`.

## Step by step

### Step 1: look at the Shop as files

The five files are numbered so that `kubectl apply -f shop/` reads them in a sensible order: settings, then Services, then the Deployments. Kubernetes does not need the order (objects can refer to things that come later), but reading top-down is easier for people.

### Step 2: build UAT

`kubectl create secret ... -n uat` makes UAT's own `db-secret`. `kubectl apply -f shop/ -n uat` applies every file in the folder into `uat`: three ConfigMaps, three Services, three Deployments. Within a minute, ten new objects become five new pods.

### Step 3: build PROD

The same two commands with `prod` and another password. PROD is now a third, separate copy, with its own database and its own data.

### Step 4: wait and check both

The backends wait for their databases, so a backend can be `0/1` for a short while: the readiness probe from Lab 1.7 at work.

### Step 5: test the Shop in PROD

In `uat` and `prod` the frontend Service is a **ClusterIP** Service, not a NodePort: port 30080 is already taken by `dev`, and a NodePort number can only be used once in the whole cluster. So you test from inside: `kubectl exec ... curl http://localhost/api/items` asks nginx in a PROD frontend pod, which passes the request to the PROD backend, which reads the PROD database. Lab 3.2 gives PROD a proper name from outside (an Ingress).

### Step 6: three Shops, kept apart

`kubectl get deployments -A` lists Deployments in all namespaces. The same three names appear three times, which is allowed because a name only has to be unique inside its namespace.

## When something goes wrong

| What you see | What it means | What to do |
| --- | --- | --- |
| `db` in `uat` or `prod` shows `CreateContainerConfigError` | The Secret `db-secret` is missing in that namespace | Create it with `-n`, as in Step 2 |
| `the namespace from the provided object "dev" does not match ...` | A file names a namespace, and `-n` names another | Remove `namespace:` from the file, or use the right `-n` |
| Objects ended up in `dev` | `-n` was forgotten | `kubectl delete -f shop/ -n dev` only if you meant to; then apply with the right `-n` |
| `provided port is already allocated` | A NodePort Service was applied in a second namespace | Use ClusterIP in `uat` and `prod`, as the `shop` folder does |

## For the exam

- Read the namespace in every task, and use `-n` on every command. Creating the right object in the wrong namespace scores nothing.
- `kubectl get <kind> -A` shows a kind in all namespaces at once.
- A NodePort number is unique per cluster, not per namespace.
- Short Service names only work inside the same namespace; across namespaces, use `name.namespace`.

## Check your understanding

1. Why do the Shop's files name no namespace?
2. Why is the Secret not in the `shop` folder?
3. The backend in `prod` connects to `db`. Which database does it reach, and why?
4. Why has the PROD frontend no NodePort?
5. Name three things a namespace does **not** separate.

<details><summary>Answers</summary>

1. So the same files can be applied into any namespace with `-n`.
2. Each environment needs its own password, and passwords should not travel inside files that are copied around.
3. The PROD database: a short name is looked up in the pod's own namespace first.
4. NodePort 30080 is already used by `dev`, and a NodePort number can be used only once in the cluster.
5. Any three of: network traffic, access rights, CPU and memory, disk, nodes.

</details>

**Back to:** [Lab 1.9](./lab-1.9-uat-and-prod.md) · **Next:** [Lab 2.1 explained](../02-installation/lab-2.1-installing-the-cluster-explained.md)
