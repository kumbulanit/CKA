# Workshop 2: Three challenge rounds

Work in **pairs**: one person types, the other reads the task and checks. Swap after every round.

📘 **More detail:** [Workshop 2 explained](./lab-w2-challenge-rounds-explained.md): what happens in the cluster at each step, common mistakes and exam notes.

- Each round has 5 tasks and takes about 30 minutes. The trainer goes through the answers after each round.
- All tasks are in the namespace **`dev`**, on the Shop.
- Try first. Open **Show the answer** only when you are stuck for more than 5 minutes.

Before each round, make sure the Shop works:

**📋 Copy and paste into your terminal:**

```bash
~/CKA/scenario-labs/scripts/check-shop.sh dev
```

**What this does:** Runs the course script that checks every part of the Shop in `dev` and prints OK or FAIL for each check.

**👀 You should see** (last line) *(do not paste)*:

```text
All 8 checks passed. The Shop works.
```

---

> **How to use this lab**
>
> - **📋 Copy and paste into your terminal:** copy the whole grey box (the copy button is in its top right corner), paste it into the terminal of your server, and press Enter.
> - **👀 You should see** *(do not paste)*: what the command prints. Names that end in random letters, IP addresses and ages are different on your server. That is normal.
> - **📖 Read only:** something to look at. Do not paste it.
> - **💡 Tip:** a shortcut or an extra. You do not need it to finish the lab.

## Round 1: workloads and scheduling

### Task 1.1

Scale the `frontend` Deployment in `dev` to **3** replicas.

<details><summary>Show the answer</summary>

```bash
kubectl scale deployment frontend -n dev --replicas=3
kubectl get deployment frontend -n dev
```

</details>

### Task 1.2

Add the environment variable `SHOP_ENV=dev` to the `frontend` Deployment. Check that a frontend pod has it.

<details><summary>Show the answer</summary>

```bash
kubectl set env deployment/frontend -n dev SHOP_ENV=dev
kubectl rollout status deployment/frontend -n dev
kubectl exec deployment/frontend -n dev -- env | grep SHOP_ENV
```

</details>

### Task 1.3

Create a pod named `toolbox` in `dev` with the image `busybox:1.36` that runs `sleep 3600` and has the labels `app=toolbox` and `team=platform`.

<details><summary>Show the answer</summary>

```bash
kubectl run toolbox -n dev --image=busybox:1.36 --labels=app=toolbox,team=platform -- sleep 3600
kubectl get pod toolbox -n dev --show-labels
```

</details>

### Task 1.4

Make the `toolbox` pod run on the node `minikube` (the control plane) only. A pod cannot be moved: delete it and create it again with a node selector on the label `kubernetes.io/hostname`.

<details><summary>Show the answer</summary>

```bash
kubectl delete pod toolbox -n dev
kubectl run toolbox -n dev --image=busybox:1.36 --labels=app=toolbox,team=platform \
  --overrides='{"spec":{"nodeSelector":{"kubernetes.io/hostname":"minikube"}}}' -- sleep 3600
kubectl get pod toolbox -n dev -o wide
```

</details>

### Task 1.5

Change the readiness probe of the `frontend` Deployment so that it checks every **3** seconds (it is 5 now).

<details><summary>Show the answer</summary>

```bash
kubectl patch deployment frontend -n dev --type=json \
  -p '[{"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/periodSeconds","value":3}]'
kubectl describe deployment frontend -n dev | grep Readiness
```

`kubectl edit deployment frontend -n dev` also works: change `periodSeconds: 5` under `readinessProbe` to `3`, save and quit.

</details>

🧹 **Clean up round 1:**

**📋 Copy and paste into your terminal:**

```bash
kubectl delete pod toolbox -n dev
kubectl scale deployment frontend -n dev --replicas=2
```

**What this does:**

- `kubectl delete pod toolbox -n dev`: Deletes the pod `toolbox` in the namespace `dev`.
- `kubectl scale deployment frontend -n dev --replicas=2`: Changes the number of pods of the Deployment `frontend` in the namespace `dev` to 2.

**👀 You should see** *(do not paste)*:

```text
pod "toolbox" deleted from dev namespace
deployment.apps/frontend scaled
```

---

## Round 2: networking and security

### Task 2.1

Create a second Service for the frontend in `dev`, named `frontend-nodeport`, of type NodePort on port 80. Open the Shop through it with `curl`.

<details><summary>Show the answer</summary>

```bash
kubectl expose deployment frontend -n dev --name=frontend-nodeport --type=NodePort --port=80
kubectl get service frontend-nodeport -n dev
curl -s http://$(minikube ip):$(kubectl get service frontend-nodeport -n dev -o jsonpath='{.spec.ports[0].nodePort}') | grep "<h1>"
```

</details>

### Task 2.2

From a temporary pod in `dev`, look up the DNS name of the `db` Service. What is its full name?

<details><summary>Show the answer</summary>

```bash
kubectl run dns-test -n dev --rm -it --restart=Never --image=busybox:1.36 -- nslookup db
```

The full name is `db.dev.svc.cluster.local`.

</details>

### Task 2.3

A new pod with the label `app=reports` must be allowed to reach the **database** on port 5432. Add a NetworkPolicy named `allow-reports-to-db` in `dev` for that. Do not change the policies that are there.

<details><summary>Show the answer</summary>

```bash
cat <<'YAML' | kubectl apply -n dev -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-reports-to-db
spec:
  podSelector:
    matchLabels:
      app: db
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: reports
    ports:
    - port: 5432
YAML
kubectl run reports -n dev --rm -it --restart=Never --labels=app=reports --image=busybox:1.36 -- nc -zv -w 3 db 5432
```

The last command prints `db (10.x.x.x:5432) open`.

</details>

### Task 2.4

Create a ServiceAccount named `deployer` in `dev`. It must be allowed to `get`, `list`, `create`, `update` and `patch` **Deployments** in `dev`, and nothing else. Prove it with `kubectl auth can-i`.

<details><summary>Show the answer</summary>

```bash
kubectl create serviceaccount deployer -n dev
kubectl create role deployer -n dev --verb=get,list,create,update,patch --resource=deployments
kubectl create rolebinding deployer -n dev --role=deployer --serviceaccount=dev:deployer
kubectl auth can-i patch deployments -n dev --as=system:serviceaccount:dev:deployer
kubectl auth can-i delete deployments -n dev --as=system:serviceaccount:dev:deployer
kubectl auth can-i get secrets -n dev --as=system:serviceaccount:dev:deployer
```

The answers are `yes`, `no`, `no`.

</details>

### Task 2.5

Which user or ServiceAccount do the `backend` pods in `dev` run as? Does it have a token mounted in the pod? Where?

<details><summary>Show the answer</summary>

```bash
kubectl get deployment backend -n dev -o jsonpath='{.spec.template.spec.serviceAccountName}{"\n"}'
kubectl get pod -n dev -l app=backend -o jsonpath='{.items[0].spec.serviceAccountName}{"\n"}'
kubectl describe pod -n dev -l app=backend | grep -A2 "Mounts:"
```

The token is mounted at `/var/run/secrets/kubernetes.io/serviceaccount`.

</details>

🧹 **Clean up round 2:**

**📋 Copy and paste into your terminal:**

```bash
kubectl delete service frontend-nodeport -n dev
kubectl delete networkpolicy allow-reports-to-db -n dev
kubectl delete rolebinding deployer -n dev
kubectl delete role deployer -n dev
kubectl delete serviceaccount deployer -n dev
```

**What this does:**

- `kubectl delete service frontend-nodeport -n dev`: Deletes the Service `frontend-nodeport` in the namespace `dev`.
- `kubectl delete networkpolicy allow-reports-to-db -n dev`: Deletes the network policy `allow-reports-to-db` in the namespace `dev`.
- `kubectl delete rolebinding deployer -n dev`: Deletes the RoleBinding `deployer` in the namespace `dev`.
- `kubectl delete role deployer -n dev`: Deletes the Role `deployer` in the namespace `dev`.
- `kubectl delete serviceaccount deployer -n dev`: Deletes the ServiceAccount `deployer` in the namespace `dev`.

**👀 You should see** five lines, one for each thing deleted.

---

## Round 3: storage and operations

### Task 3.1

Which PersistentVolume holds the `dev` database? On which node is the data, and in which folder?

<details><summary>Show the answer</summary>

```bash
kubectl get pvc db-data -n dev
kubectl describe pv shop-dev-pv | grep -E "Path|Node Affinity|hostname" -A1
```

The volume is `shop-dev-pv`, on node `minikube-m02`, in `/data/shop/dev`.

</details>

### Task 3.2

Add a new item to the Shop: `Sandwich`, price `45`. Then delete the database pod and show that the Sandwich is still there.

<details><summary>Show the answer</summary>

```bash
kubectl exec deployment/db -n dev -- psql -U shop -d shop -c "INSERT INTO items (name, price) VALUES ('Sandwich', 45);"
kubectl delete pod -n dev -l app=db
kubectl rollout status deployment/db -n dev
kubectl exec deployment/db -n dev -- psql -U shop -d shop -c "SELECT * FROM items;"
kubectl rollout restart deployment/backend -n dev
kubectl rollout status deployment/backend -n dev
```

The last two lines restart the backend, as in Lab 7.3. By itself, a backend pod can take several minutes to reconnect to the new database pod, and until then it is not ready.

</details>

### Task 3.3

Release a new frontend image, `nginx:1.28-alpine`, in `dev`. Look at the rollout history. Then roll back.

<details><summary>Show the answer</summary>

```bash
kubectl set image deployment/frontend -n dev frontend=nginx:1.28-alpine
kubectl rollout status deployment/frontend -n dev
kubectl rollout history deployment/frontend -n dev
kubectl rollout undo deployment/frontend -n dev
kubectl rollout status deployment/frontend -n dev
```

As in Lab 1.8, `rollout undo` also prints a `Warning` line about `kubectl apply`. You can ignore it here.

</details>

### Task 3.4

Save the logs of **all** backend pods in `dev` from the last 10 minutes in the file `~/backend.log`.

<details><summary>Show the answer</summary>

```bash
kubectl logs -n dev -l app=backend --since=10m --prefix > ~/backend.log
wc -l ~/backend.log
```

</details>

### Task 3.5

Make a backup of etcd in the file `/var/lib/minikube/etcd/round3.db` on the control plane node, and show its status.

<details><summary>Show the answer</summary>

```bash
kubectl -n kube-system exec etcd-minikube -- etcdctl --endpoints=https://127.0.0.1:2379 \
  --cacert=/var/lib/minikube/certs/etcd/ca.crt \
  --cert=/var/lib/minikube/certs/etcd/server.crt \
  --key=/var/lib/minikube/certs/etcd/server.key \
  snapshot save /var/lib/minikube/etcd/round3.db
kubectl -n kube-system exec etcd-minikube -- etcdutl snapshot status /var/lib/minikube/etcd/round3.db --write-out=table
```

</details>

✅ **Check after round 3:**

**📋 Copy and paste into your terminal:**

```bash
~/CKA/scenario-labs/scripts/check-shop.sh dev
```

**What this does:** Runs the course script that checks every part of the Shop in `dev` and prints OK or FAIL for each check.

**👀 You should see** (last line) *(do not paste)*:

```text
All 8 checks passed. The Shop works.
```

If it says `deployment backend: 0/2 ready` or `1/2 ready`, the backend has not reconnected to the new database pod from Task 3.2 yet. Restart it, then run the check again: `kubectl rollout restart deployment/backend -n dev`, then `kubectl rollout status deployment/backend -n dev`.
