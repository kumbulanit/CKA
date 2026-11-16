# Lab 5.1: Authentication, authorization and RBAC: a developer and PROD

**The situation:** until now you did everything as the cluster administrator. A developer, **Thabo**, joins the team. He must be able to change everything in `dev`, but only look in `prod`. And the Shop's own pods should have no more rights than they need.

**Goal:** give Thabo the right access, and give the PROD backend its own identity.

**Outline topic:** 5. Security: *Authentication, Authorization and RBAC*.

**What you learn:** the difference between authentication and authorization, Roles, ClusterRoles, RoleBindings, `kubectl auth can-i`, ServiceAccounts.

📘 **More detail:** [Lab 5.1 explained](./lab-5.1-authentication-authorization-rbac-explained.md): what happens in the cluster at each step, common mistakes and exam notes.

Every request to the cluster passes two gates:

| Gate | The question | How |
| --- | --- | --- |
| **Authentication** | **Who** are you? | A certificate (people) or a token (pods). Lab 5.2. |
| **Authorization** | **May** you do this? | RBAC: role-based access control. This lab. |

RBAC has two kinds of objects:

| Object | What it says |
| --- | --- |
| **Role** / **ClusterRole** | **What** may be done (for example: read pods) |
| **RoleBinding** | **Who** gets that role, in **which namespace** |

Kubernetes has ready-made ClusterRoles. You use two of them: `edit` (change most things) and `view` (only look, and no Secrets).

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
cd ~/CKA/scenario-labs/05-security
kubectl config set-context --current --namespace=dev
```

**What this does:**

- `cd ~/CKA/scenario-labs/05-security`: Goes to the folder `~/CKA/scenario-labs/05-security`.
- `kubectl config set-context --current --namespace=dev`: Makes `dev` your working namespace: commands without `-n` now work in `dev`.

**👀 You should see** *(do not paste)*:

```text
Context "minikube" modified.
```

💡 **Tip:** `kubens dev` does the same as the second line (see the shortcuts in [setup, Step 5](../00-setup.md)).

## Step 0: who are you now?

**📋 Copy and paste into your terminal:**

```bash
kubectl auth whoami
```

**What this does:** Shows who you are logged in as, and your groups.

**👀 You should see** your user and its groups *(do not paste)*:

```text
ATTRIBUTE                                           VALUE
Username                                            minikube-user
Groups                                              [system:masters system:authenticated]
Extra: authentication.kubernetes.io/credential-id   [X509SHA256=fc355da1f973862b...]
```

The group `system:masters` is the administrator group: it may do everything.

## Part A: give Thabo his access

### Step 1: bind the roles

**📋 Copy and paste into your terminal:**

```bash
kubectl create rolebinding thabo-edit -n dev --clusterrole=edit --user=thabo
kubectl create rolebinding thabo-view -n prod --clusterrole=view --user=thabo
```

**What this does:**

- `kubectl create rolebinding thabo-edit ...`: Gives the user `thabo` the role `edit` in the namespace `dev` (a RoleBinding called `thabo-edit`).
- `kubectl create rolebinding thabo-view ...`: Gives the user `thabo` the role `view` in the namespace `prod` (a RoleBinding called `thabo-view`).

**👀 You should see** *(do not paste)*:

```text
rolebinding.rbac.authorization.k8s.io/thabo-edit created
rolebinding.rbac.authorization.k8s.io/thabo-view created
```

### Step 2: ask what Thabo may do

`kubectl auth can-i` answers `yes` or `no`. With `--as=thabo` you ask it for Thabo.

**📋 Copy and paste into your terminal:**

```bash
kubectl auth can-i create deployments -n dev --as=thabo
kubectl auth can-i get pods -n prod --as=thabo
kubectl auth can-i delete pods -n prod --as=thabo
kubectl auth can-i get secrets -n prod --as=thabo
kubectl auth can-i get nodes --as=thabo
```

**What this does:**

- `kubectl auth can-i create deployments -n dev --as=thabo`: Asks: may `thabo` create deployments in the namespace `dev`? The answer is `yes` or `no`.
- `kubectl auth can-i get pods -n prod --as=thabo`: Asks: may `thabo` get pods in the namespace `prod`? The answer is `yes` or `no`.
- `kubectl auth can-i delete pods -n prod --as=thabo`: Asks: may `thabo` delete pods in the namespace `prod`? The answer is `yes` or `no`.
- `kubectl auth can-i get secrets -n prod --as=thabo`: Asks: may `thabo` get secrets in the namespace `prod`? The answer is `yes` or `no`.
- `kubectl auth can-i get nodes --as=thabo`: Asks: may `thabo` get nodes? The answer is `yes` or `no`.

**👀 You should see** *(do not paste)*:

```text
yes
yes
no
no
Warning: resource 'nodes' is not namespace scoped

no
```

![What Thabo may and may not do](../images/can-i.png)

| Question | Answer | Why |
| --- | --- | --- |
| Create deployments in `dev`? | yes | `edit` in `dev` |
| Look at pods in `prod`? | yes | `view` in `prod` |
| Delete pods in `prod`? | no | `view` only looks |
| Read Secrets in `prod`? | no | `view` does not include Secrets |
| Look at the nodes? | no | Nobody gave him that |

### Step 3: write your own Role

The ready-made roles are not always right. In `uat`, Thabo may only look at **pods**. Nothing else.

**📋 Copy and paste into your terminal:**

```bash
kubectl create role pod-reader -n uat --verb=get,list,watch --resource=pods
kubectl create rolebinding thabo-pod-reader -n uat --role=pod-reader --user=thabo
```

**What this does:**

- `kubectl create role pod-reader ...`: Creates a Role called `pod-reader` in the namespace `uat`: it allows `get,list,watch` on `pods`.
- `kubectl create rolebinding thabo-pod-reader ...`: Gives the user `thabo` the role `pod-reader` in the namespace `uat` (a RoleBinding called `thabo-pod-reader`).

**👀 You should see** *(do not paste)*:

```text
role.rbac.authorization.k8s.io/pod-reader created
rolebinding.rbac.authorization.k8s.io/thabo-pod-reader created
```

**📋 Copy and paste into your terminal:**

```bash
kubectl auth can-i list pods -n uat --as=thabo
kubectl auth can-i list services -n uat --as=thabo
```

**What this does:**

- `kubectl auth can-i list pods -n uat --as=thabo`: Asks: may `thabo` list pods in the namespace `uat`? The answer is `yes` or `no`.
- `kubectl auth can-i list services -n uat --as=thabo`: Asks: may `thabo` list services in the namespace `uat`? The answer is `yes` or `no`.

**👀 You should see** *(do not paste)*:

```text
yes
no
```

## Part B: an identity for the backend (ServiceAccount)

People get users. **Pods** get a **ServiceAccount**. Every pod runs as the ServiceAccount `default`, unless you say something else. The PROD backend gets its own.

### Step 4: create it and give it to the backend

**📋 Copy and paste into your terminal:**

```bash
kubectl create serviceaccount backend -n prod
kubectl set serviceaccount deployment backend backend -n prod
kubectl rollout status deployment/backend -n prod
```

**What this does:**

- `kubectl create serviceaccount backend -n prod`: Creates a ServiceAccount (an identity for pods) called `backend` in the namespace `prod`.
- `kubectl set serviceaccount deployment ...`: Makes the pods of the Deployment `backend` in the namespace `prod` run as the ServiceAccount `backend`.
- `kubectl rollout status deployment/backend -n prod`: Waits until the new pods of the Deployment `backend` in the namespace `prod` are all ready, and says when it is done.

**👀 You should see** (the last line) *(do not paste)*:

```text
deployment "backend" successfully rolled out
```

**📋 Copy and paste into your terminal:**

```bash
kubectl get pods -n prod -l app=backend -o custom-columns=NAME:.metadata.name,SERVICEACCOUNT:.spec.serviceAccountName
```

**What this does:** Lists the pods with the label `app=backend` in the namespace `prod`, showing only the columns named in the command.

**👀 You should see** *(do not paste)*:

```text
NAME                       SERVICEACCOUNT
backend-59df57cf8c-d7dbk   backend
backend-59df57cf8c-f4ssd   backend
```

### Step 5: what may the backend do in the cluster?

**📋 Copy and paste into your terminal:**

```bash
kubectl auth can-i list pods -n prod --as=system:serviceaccount:prod:backend
```

**What this does:** Asks: may `system:serviceaccount:prod:backend` list pods in the namespace `prod`? The answer is `yes` or `no`.

**👀 You should see** *(do not paste)*:

```text
no
```

Good. The backend only needs its database. It has no business with the Kubernetes API, so it gets no rights. That is **least privilege**: give only what is needed.

💡 **Exam tip:** the four commands to know by heart: `kubectl create role`, `kubectl create rolebinding`, `kubectl create clusterrole`, `kubectl create clusterrolebinding`. Always check your work with `kubectl auth can-i ... --as=...`.

✅ **Check:** Step 2 gives `yes, yes, no, no, no`.

**Next:** [Lab 5.2: TLS access to the API](./lab-5.2-tls-access-to-the-api.md)
