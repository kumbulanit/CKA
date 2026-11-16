# Lab 4.2: Affinity and anti-affinity rules

**The situation:** two problems. First: the PROD frontend can **only** run on `minikube-m03`, so if that node breaks, PROD is down. Second: nothing stops both backend pods from landing on the same node, and then one broken node takes the whole backend with it.

**Goal:** make "run on the PROD node" a **wish** instead of a rule, and keep the two backend pods on **different** nodes.

**Outline topic:** 4. Scheduling: *Affinity and anti-affinity rules*.

**What you learn:** node affinity (required and preferred), pod anti-affinity.

📘 **More detail:** [Lab 4.2 explained](./lab-4.2-affinity-and-anti-affinity-explained.md): what happens in the cluster at each step, common mistakes and exam notes.

| Rule | It says | Example |
| --- | --- | --- |
| **Node affinity** | "Put me on a node with this label" | PROD pods on the PROD node |
| **Pod affinity** | "Put me near pods with this label" | The backend next to its cache |
| **Pod anti-affinity** | "Put me away from pods with this label" | The two backend pods on different nodes |

Each can be a hard rule (`required...`) or a wish (`preferred...`).

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

## Part A: node affinity for PROD

### Step 1: look at the rule

**📋 Copy and paste into your terminal:**

```bash
cat prod-affinity.yaml
```

**What this does:** Shows what is in the file `prod-affinity.yaml`.

**👀 You should see** *(do not paste)*:

```yaml
# prefer nodes with the label env=prod, but run somewhere else if there is none
spec:
  template:
    spec:
      nodeSelector: null
      affinity:
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            preference:
              matchExpressions:
              - key: env
                operator: In
                values:
                - prod
```

| Line | Meaning |
| --- | --- |
| `nodeSelector: null` | Take the hard rule of Lab 4.1 away |
| `preferredDuringScheduling...` | A wish: the scheduler tries, but may choose another node |
| `...IgnoredDuringExecution` | Pods that already run are not moved when a label changes |
| `key: env`, `values: prod` | The label to look for on the node |

### Step 2: give it to the PROD frontend and backend

**📋 Copy and paste into your terminal:**

```bash
kubectl patch deployment frontend -n prod --patch-file prod-affinity.yaml
kubectl patch deployment backend -n prod --patch-file prod-affinity.yaml
kubectl rollout status deployment/frontend -n prod
kubectl rollout status deployment/backend -n prod
kubectl get pods -n prod -o wide
```

**What this does:**

- `kubectl patch deployment frontend ...`: Changes the Deployment `frontend` in the namespace `prod`: adds the lines of the file `prod-affinity.yaml` to it.
- `kubectl patch deployment backend ...`: Changes the Deployment `backend` in the namespace `prod`: adds the lines of the file `prod-affinity.yaml` to it.
- `kubectl rollout status deployment/frontend -n prod`: Waits until the new pods of the Deployment `frontend` in the namespace `prod` are all ready, and says when it is done.
- `kubectl rollout status deployment/backend -n prod`: Waits until the new pods of the Deployment `backend` in the namespace `prod` are all ready, and says when it is done.
- `kubectl get pods -n prod -o wide`: Lists the pods in the namespace `prod`, with extra columns such as the IP address and the node.

**👀 You should see** the PROD frontend and backend on `minikube-m03` *(do not paste)*:

```text
NAME                        READY   STATUS    RESTARTS   AGE     IP               NODE           NOMINATED NODE   READINESS GATES
backend-64c47cb7d8-cvpkm    1/1     Running   0          2m15s   10.244.151.36    minikube-m03   <none>           <none>
backend-64c47cb7d8-rsdrp    1/1     Running   0          79s     10.244.151.39    minikube-m03   <none>           <none>
db-747c44dc87-rg87j         1/1     Running   0          6h4m    10.244.205.212   minikube-m02   <none>           <none>
frontend-5fddf7f475-5248t   1/1     Running   0          2m15s   10.244.151.37    minikube-m03   <none>           <none>
frontend-5fddf7f475-rwg72   1/1     Running   0          70s     10.244.151.38    minikube-m03   <none>           <none>
```

The result looks the same as with the node selector. The difference shows when the node is not there: these pods would start on another node. (You did not change the database, so it stays where it is.)

## Part B: anti-affinity for the DEV backend

### Step 3: see where the two DEV backend pods are

**📋 Copy and paste into your terminal:**

```bash
kubectl get pods -n dev -l app=backend -o wide
```

**What this does:** Lists the pods with the label `app=backend` in the namespace `dev`, with extra columns such as the IP address and the node.

Look at the `NODE` column. Maybe they are on different nodes, maybe on the same one. It is luck. You want a rule.

### Step 4: look at the rule

**📋 Copy and paste into your terminal:**

```bash
cat backend-anti-affinity.yaml
```

**What this does:** Shows what is in the file `backend-anti-affinity.yaml`.

**👀 You should see** *(do not paste)*:

```yaml
# keep the backend pods away from each other: prefer a node that has no backend pod yet
spec:
  template:
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              topologyKey: kubernetes.io/hostname
              labelSelector:
                matchLabels:
                  app: backend
```

| Line | Meaning |
| --- | --- |
| `podAntiAffinity` | Stay **away** from certain pods |
| `labelSelector: app: backend` | ...from pods with this label (the other backend pods) |
| `topologyKey: kubernetes.io/hostname` | "Away" means: on another **node** |

### Step 5: give it to the DEV backend

**📋 Copy and paste into your terminal:**

```bash
kubectl patch deployment backend -n dev --patch-file backend-anti-affinity.yaml
kubectl rollout status deployment/backend -n dev
kubectl get pods -n dev -l app=backend -o wide
```

**What this does:**

- `kubectl patch deployment backend ...`: Changes the Deployment `backend` in the namespace `dev`: adds the lines of the file `backend-anti-affinity.yaml` to it.
- `kubectl rollout status deployment/backend -n dev`: Waits until the new pods of the Deployment `backend` in the namespace `dev` are all ready, and says when it is done.
- `kubectl get pods -n dev -l app=backend -o wide`: Lists the pods with the label `app=backend` in the namespace `dev`, with extra columns such as the IP address and the node.

**👀 You should see** the two backend pods on **two different nodes** *(do not paste)*:

```text
NAME                       READY   STATUS    RESTARTS   AGE   IP               NODE           NOMINATED NODE   READINESS GATES
backend-7c9d8b6f5d-h4n2k   1/1     Running   0          40s   10.244.205.225   minikube-m02   <none>           <none>
backend-7c9d8b6f5d-w8p3x   1/1     Running   0          22s   10.244.120.70    minikube       <none>           <none>
```

![The two backend pods run on different nodes](../images/anti-affinity.png)

Now one broken node can never take both backend pods.

💡 **Exam tip:** the long names are easier in two halves. First half: `required` (a rule) or `preferred` (a wish). Second half, always the same: `DuringSchedulingIgnoredDuringExecution`. Find the layout with `kubectl explain pod.spec.affinity.nodeAffinity`.

✅ **Check:** the two DEV backend pods are on different nodes, and the PROD frontend and backend are on `minikube-m03`.

**Next:** [Lab 4.3: Taints and tolerations](./lab-4.3-taints-and-tolerations.md)
