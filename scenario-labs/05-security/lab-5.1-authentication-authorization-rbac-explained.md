# Lab 5.1 explained: authentication, authorization and RBAC

This page goes with [Lab 5.1](./lab-5.1-authentication-authorization-rbac.md). The lab has the commands; this page explains them: what happens in the cluster, why it matters for the Shop, what usually goes wrong, and what the exam asks. There is nothing to paste here.

## In short

Every request to the API server passes two gates: **authentication** (who are you?) and **authorization** (may you do this?). **RBAC** answers the second question with two kinds of objects: **Roles** say *what* may be done, **RoleBindings** say *who* gets it and *where*. In this lab the developer Thabo gets full access in `dev`, read-only access in `prod`, and the PROD backend gets its own identity with no rights at all.

## The ideas behind this lab

### The path of every request

1. **Authentication:** the API server finds out who sent the request: from a client certificate (people, Lab 5.2), a token (pods, through their ServiceAccount), or another configured method. The result is a **username** and a list of **groups**.
2. **Authorization:** RBAC checks whether that user or one of its groups is allowed this **verb** on this **resource** in this **namespace**. If nothing allows it, the answer is `Forbidden` (HTTP 403).
3. **Admission:** further checks and changes (quotas, Lab 7.4; default values; policies), then the object is stored in etcd.

Kubernetes has **no user objects**. A user like `thabo` only exists as a name inside a certificate the cluster trusts. RBAC simply matches that name.

### The four RBAC objects

| Object | Scope | Says |
| --- | --- | --- |
| **Role** | One namespace | Which verbs on which resources are allowed, in that namespace |
| **ClusterRole** | The whole cluster | The same, for the whole cluster, or as a reusable template |
| **RoleBinding** | One namespace | Gives a Role or a ClusterRole to users, groups or ServiceAccounts, **in that namespace** |
| **ClusterRoleBinding** | The whole cluster | Gives a ClusterRole everywhere, including cluster-wide resources such as nodes |

The useful trick in this lab: a **RoleBinding can point at a ClusterRole**. The ClusterRole `edit` is defined once for the cluster, and the RoleBinding `thabo-edit` grants it **only in `dev`**.

### RBAC only allows

There are no "deny" rules. Everything is forbidden until some binding allows it, and permissions from several bindings add up. To take a right away, you delete or change the binding that gave it.

### Verbs and resources

A rule lists **verbs** (`get`, `list`, `watch`, `create`, `update`, `patch`, `delete`) and **resources** (`pods`, `deployments`, `secrets`...). `get` reads one object by name; `list` reads all of them; `watch` follows changes (`kubectl get -w`). Reading pods with `kubectl get pods` needs `list`.

### The ready-made ClusterRoles

| ClusterRole | Gives |
| --- | --- |
| `cluster-admin` | Everything, everywhere |
| `admin` | Everything in a namespace, including its RoleBindings |
| `edit` | Change most objects in a namespace; not Roles and RoleBindings |
| `view` | Read most objects in a namespace; **not Secrets** |

### ServiceAccounts: identities for pods

Pods are not people, but they can call the API too, with a token that Kubernetes puts into every pod. Each pod runs as a **ServiceAccount**; without a choice, the namespace's `default` one. Its full name for RBAC is `system:serviceaccount:<namespace>:<name>`.

## Step by step

### Step 0: who are you now?

`kubectl auth whoami` asks the API server how it sees you: the user `minikube-user` in the group `system:masters`. That group is special: it is allowed everything, before RBAC is even checked. Your kubeconfig's certificate makes you a full administrator, which is why everything worked so far.

### Step 1: bind the roles

`kubectl create rolebinding thabo-edit -n dev --clusterrole=edit --user=thabo` creates a RoleBinding in `dev` that gives the ClusterRole `edit` to the user `thabo`. The second command does the same with `view` in `prod`. Thabo has no certificate yet (Lab 5.2), but RBAC does not need one: it only needs the name.

### Step 2: ask what Thabo may do

`kubectl auth can-i VERB RESOURCE -n NS --as=thabo` asks the API server to run the authorization check for Thabo, without doing anything. `--as` is **impersonation**: allowed for you because you are an administrator. The five answers follow from the two bindings: `edit` in `dev`, `view` in `prod`, nothing for Secrets in `prod`, and nothing for nodes, which are a cluster-wide resource that only a ClusterRoleBinding could grant.

### Step 3: write your own Role

`kubectl create role pod-reader -n uat --verb=get,list,watch --resource=pods` writes a Role allowing exactly three verbs on one resource, in `uat`. The RoleBinding gives it to Thabo. He can list pods in `uat`, but not Services: nothing allows it.

### Step 4: create it and give it to the backend

`kubectl create serviceaccount backend -n prod` creates the identity. `kubectl set serviceaccount deployment backend backend -n prod` sets `serviceAccountName: backend` in the pod template, which rolls out new pods running as that identity. The custom columns confirm it.

### Step 5: what may the backend do in the cluster?

`--as=system:serviceaccount:prod:backend` asks the same question for the backend's identity: no. The backend talks to its database, never to the Kubernetes API, so it gets no rights at all: **least privilege**. If an attacker ever took over a backend pod, its token would be worth nothing against the cluster.

## When something goes wrong

| What you see | What it means | What to do |
| --- | --- | --- |
| `Error from server (Forbidden): ... cannot list resource "pods"` | No binding allows it | `kubectl auth can-i ... --as=USER`; add the missing Role or binding |
| `can-i` says `yes` but in the wrong namespace | The RoleBinding is in another namespace | Check `-n` on the RoleBinding |
| A ClusterRoleBinding was used instead of a RoleBinding | The user got the rights in **every** namespace | Delete it; use a RoleBinding per namespace |
| `Warning: resource 'nodes' is not namespace scoped` | Nodes have no namespace; `-n` is ignored | Normal |
| A pod's API calls are refused | Its ServiceAccount has no rights | Bind a Role to `system:serviceaccount:NS:NAME` |

## For the exam

- The four commands: `kubectl create role`, `rolebinding`, `clusterrole`, `clusterrolebinding`, with `--verb`, `--resource`, `--user`, `--group`, `--serviceaccount=NS:NAME`.
- Check every RBAC task with `kubectl auth can-i VERB RESOURCE -n NS --as=USER` (for a ServiceAccount: `--as=system:serviceaccount:NS:NAME`).
- A RoleBinding to a ClusterRole grants it in one namespace only. Nodes, PersistentVolumes and namespaces themselves need a ClusterRoleBinding.
- `kubectl create serviceaccount NAME`, and `serviceAccountName:` in the pod spec (or `kubectl set serviceaccount`).

## Check your understanding

1. What is the difference between authentication and authorization?
2. Where is the user `thabo` stored in the cluster?
3. Why could Thabo create Deployments in `dev` but not delete pods in `prod`?
4. Why does `view` in `prod` not let him read the database password?
5. Why does the PROD backend get a ServiceAccount with no rights?

<details><summary>Answers</summary>

1. Authentication finds out who you are; authorization decides whether you may do what you ask.
2. Nowhere: Kubernetes has no user objects. The name only appears in RoleBindings and, later, in his certificate.
3. A RoleBinding gives him `edit` in `dev`; in `prod` he only has `view`, which cannot delete.
4. `view` deliberately excludes Secrets.
5. It never needs the Kubernetes API. With no rights, its token is useless to an attacker: least privilege.

</details>

**Back to:** [Lab 5.1](./lab-5.1-authentication-authorization-rbac.md) · **Next:** [Lab 5.2 explained](./lab-5.2-tls-access-to-the-api-explained.md)
