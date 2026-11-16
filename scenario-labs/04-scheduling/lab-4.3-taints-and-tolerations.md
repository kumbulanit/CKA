# Lab 4.3: Taints and tolerations: keep everyone else off the PROD node

**The situation:** the PROD pods prefer `minikube-m03`. But DEV and UAT pods can still land there too, and use the CPU that PROD needs. The node must refuse everyone except PROD.

**Goal:** close `minikube-m03` for all pods, and give only the PROD frontend and backend a pass.

**Outline topic:** 4. Scheduling: *Taints and tolerations*.

**What you learn:** taints, their effects, tolerations.

📘 **More detail:** [Lab 4.3 explained](./lab-4.3-taints-and-tolerations-explained.md): what happens in the cluster at each step, common mistakes and exam notes.

Affinity works from the side of the **pod**: "I want that node". A taint works from the side of the **node**: "I do not want pods".

| Word | On | Think of it as |
| --- | --- | --- |
| **Taint** | A node | A "Keep out" sign |
| **Toleration** | A pod | A pass for that sign |

| Taint effect | Meaning |
| --- | --- |
| `NoSchedule` | No **new** pods without a pass. Pods that already run there stay. |
| `PreferNoSchedule` | Try to keep new pods away, but allow them if there is no other place |
| `NoExecute` | No new pods, **and** pods without a pass that run there are thrown out |

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
cd ~/CKA/scenario-labs/04-scheduling
kubectl config set-context --current --namespace=dev
```

**What this does:**

- `cd ~/CKA/scenario-labs/04-scheduling`: Goes to the folder `~/CKA/scenario-labs/04-scheduling`.
- `kubectl config set-context --current --namespace=dev`: Makes `dev` your working namespace: commands without `-n` now work in `dev`.

**👀 You should see** *(do not paste)*:

```text
Context "minikube" modified.
```

💡 **Tip:** `kubens dev` does the same as the second line (see the shortcuts in [setup, Step 5](../00-setup.md)).

## Step 1: see who is on the PROD node now

**📋 Copy and paste into your terminal:**

```bash
kubectl get pods -A -o wide --field-selector spec.nodeName=minikube-m03 | grep -E "NAMESPACE|dev|uat|prod"
```

**What this does:** Lists the pods in all namespaces, only those on the node `minikube-m03`, with extra columns such as the IP address and the node. `| grep` keeps only the lines with `NAMESPACE` or `dev` or `uat` or `prod`.

**👀 You should see** the PROD pods, and probably some pods of `dev` or `uat` too.

## Step 2: put the taint on the node

**📋 Copy and paste into your terminal:**

```bash
kubectl taint node minikube-m03 dedicated=prod:NoSchedule
kubectl describe node minikube-m03 | grep Taints
```

**What this does:**

- `kubectl taint node minikube-m03 dedicated=prod:NoSchedule`: Puts the taint `dedicated=prod:NoSchedule` on the node `minikube-m03`: new pods without a matching toleration may not start there.
- `kubectl describe node minikube-m03 | grep Taints`: Shows all the details of the node `minikube-m03`. The events at the bottom say what happened to it. `| grep` keeps only the lines with `Taints`.

**👀 You should see** *(do not paste)*:

```text
node/minikube-m03 tainted
Taints:             dedicated=prod:NoSchedule
```

A taint has three parts: a key (`dedicated`), a value (`prod`) and an effect (`NoSchedule`).

## Step 3: DEV and UAT can no longer start there

Restart the DEV and UAT frontend and backend. Their new pods need a node:

**📋 Copy and paste into your terminal:**

```bash
kubectl rollout restart deployment/frontend deployment/backend -n dev
kubectl rollout restart deployment/frontend deployment/backend -n uat
kubectl rollout status deployment/backend -n dev
kubectl rollout status deployment/backend -n uat
kubectl get pods -n dev -o wide
```

**What this does:**

- `kubectl rollout restart deployment/frontend ...`: Replaces the pods of the Deployments `frontend` and `backend` in the namespace `dev` with new ones, one by one.
- `kubectl rollout restart deployment/frontend ...`: Replaces the pods of the Deployments `frontend` and `backend` in the namespace `uat` with new ones, one by one.
- `kubectl rollout status deployment/backend -n dev`: Waits until the new pods of the Deployment `backend` in the namespace `dev` are all ready, and says when it is done.
- `kubectl rollout status deployment/backend -n uat`: Waits until the new pods of the Deployment `backend` in the namespace `uat` are all ready, and says when it is done.
- `kubectl get pods -n dev -o wide`: Lists the pods in the namespace `dev`, with extra columns such as the IP address and the node.

**👀 You should see** no DEV frontend or backend pod on `minikube-m03` any more. They run on `minikube` and `minikube-m02`.

## Step 4: but PROD cannot start there either

The taint keeps **everyone** out who has no pass. Restart the PROD frontend:

**📋 Copy and paste into your terminal:**

```bash
kubectl rollout restart deployment/frontend -n prod
kubectl rollout status deployment/frontend -n prod
kubectl get pods -n prod -l app=frontend -o wide
```

**What this does:**

- `kubectl rollout restart deployment/frontend -n prod`: Replaces the pods of the Deployment `frontend` in the namespace `prod` with new ones, one by one.
- `kubectl rollout status deployment/frontend -n prod`: Waits until the new pods of the Deployment `frontend` in the namespace `prod` are all ready, and says when it is done.
- `kubectl get pods -n prod -l app=frontend -o wide`: Lists the pods with the label `app=frontend` in the namespace `prod`, with extra columns such as the IP address and the node.

**👀 You should see** the new PROD frontend pods on **other** nodes, not on `minikube-m03` *(do not paste)*:

```text
NAME                        READY   STATUS    RESTARTS   AGE   IP               NODE           NOMINATED NODE   READINESS GATES
frontend-6b8f9d7c54-2jq8m   1/1     Running   0          30s   10.244.205.231   minikube-m02   <none>           <none>
frontend-6b8f9d7c54-x9r4t   1/1     Running   0          18s   10.244.120.74    minikube       <none>           <none>
```

They **prefer** `minikube-m03` (Lab 4.2), but the node refuses them, so the scheduler chose another node. With the hard node selector of Lab 4.1 they would be `Pending` now, and the release would hang. That is why a wish was the better choice.

## Step 5: give the PROD pods a pass

**📋 Copy and paste into your terminal:**

```bash
cat prod-toleration.yaml
```

**What this does:** Shows what is in the file `prod-toleration.yaml`.

**👀 You should see** *(do not paste)*:

```yaml
# allowed on nodes with the taint dedicated=prod
spec:
  template:
    spec:
      tolerations:
      - key: dedicated
        operator: Equal
        value: prod
        effect: NoSchedule
```

The toleration repeats the three parts of the taint: key, value, effect.

**📋 Copy and paste into your terminal:**

```bash
kubectl patch deployment frontend -n prod --patch-file prod-toleration.yaml
kubectl patch deployment backend -n prod --patch-file prod-toleration.yaml
kubectl rollout status deployment/frontend -n prod
kubectl rollout status deployment/backend -n prod
kubectl get pods -n prod -o wide
```

**What this does:**

- `kubectl patch deployment frontend ...`: Changes the Deployment `frontend` in the namespace `prod`: adds the lines of the file `prod-toleration.yaml` to it.
- `kubectl patch deployment backend ...`: Changes the Deployment `backend` in the namespace `prod`: adds the lines of the file `prod-toleration.yaml` to it.
- `kubectl rollout status deployment/frontend -n prod`: Waits until the new pods of the Deployment `frontend` in the namespace `prod` are all ready, and says when it is done.
- `kubectl rollout status deployment/backend -n prod`: Waits until the new pods of the Deployment `backend` in the namespace `prod` are all ready, and says when it is done.
- `kubectl get pods -n prod -o wide`: Lists the pods in the namespace `prod`, with extra columns such as the IP address and the node.

**👀 You should see** the PROD frontend and backend back on `minikube-m03` *(do not paste)*:

```text
NAME                        READY   STATUS    RESTARTS   AGE     IP               NODE           NOMINATED NODE   READINESS GATES
backend-64c47cb7d8-cvpkm    1/1     Running   0          2m15s   10.244.151.36    minikube-m03   <none>           <none>
backend-64c47cb7d8-rsdrp    1/1     Running   0          79s     10.244.151.39    minikube-m03   <none>           <none>
db-747c44dc87-rg87j         1/1     Running   0          6h4m    10.244.205.212   minikube-m02   <none>           <none>
frontend-5fddf7f475-5248t   1/1     Running   0          2m15s   10.244.151.37    minikube-m03   <none>           <none>
frontend-5fddf7f475-rwg72   1/1     Running   0          70s     10.244.151.38    minikube-m03   <none>           <none>
```

![The PROD frontend and backend run on the PROD node](../images/prod-node.png)

## Step 6: the two halves together

| | Affinity (Lab 4.2) | Taint + toleration (this lab) |
| --- | --- | --- |
| Who decides | The pod | The node |
| What it does | Pulls the PROD pods **to** the node | Keeps all other pods **off** the node |

A toleration alone does not pull a pod to the node. It only lets it in. You need both halves for a node that is kept for PROD.

💡 **Exam tip:** to remove a taint, repeat the command with a minus at the end: `kubectl taint node minikube-m03 dedicated=prod:NoSchedule-`. To remove a label: `kubectl label node minikube-m03 env-`. **Do not run these now**: the Shop keeps this setup.

✅ **Check:** the PROD frontend and backend pods run on `minikube-m03`, and no DEV or UAT frontend or backend pod does.

**Next:** [Lab 5.1: Authentication, authorization and RBAC](../05-security/lab-5.1-authentication-authorization-rbac.md)
