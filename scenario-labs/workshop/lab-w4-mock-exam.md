# Workshop 4: Mock exam (90 minutes)

This is a practice exam on the Shop. Work **alone**. You may use `kubectl explain`, `kubectl <command> --help` and <https://kubernetes.io/docs>, as in the real exam.

- 15 tasks, 100 points. **66 points is a pass**, as in the real exam.
- Do the easy tasks first. Skip a task that takes more than 6 minutes and come back to it.
- The answers are in [lab-w4-mock-exam-solutions.md](./lab-w4-mock-exam-solutions.md). Do not open them before the time is up.

## Before you start

The exam uses its own namespace, `exam`, so it does not touch `dev`, `uat` or `prod`.

**📋 Copy and paste:**

```bash
kubectl create namespace exam
kubectl create secret generic db-secret -n exam --from-literal=password=exam-pass-123
mkdir -p ~/exam
```

**👀 You should see:**

```text
namespace/exam created
secret/db-secret created
```

💡 Save typing, as in the exam:

**📋 Copy and paste:**

```bash
alias k=kubectl
export do="--dry-run=client -o yaml"
```

**👀 You should see** no output.

Start your timer: **90 minutes**.

---

## The tasks

### Task 1 (4 points): a pod

In namespace `exam`, create a pod named `web` with the image `nginx:1.27-alpine` and the label `tier=frontend`.

### Task 2 (6 points): a Deployment

In namespace `exam`, create a Deployment named `frontend` with the image `nginx:1.27-alpine` and **3** replicas. Then scale it to **4** replicas.

### Task 3 (6 points): a Service

Expose the Deployment `frontend` in namespace `exam` with a Service named `frontend` of type **NodePort**, on port **80**, with node port **30090**.

### Task 4 (6 points): a ConfigMap as environment variables

In namespace `exam`, create a ConfigMap named `shop-settings` with the keys `SHOP_NAME=Corner Shop` and `SHOP_CURRENCY=ZAR`. Create a pod named `settings` with the image `busybox:1.36` that runs `sleep 3600` and gets **both keys as environment variables**.

### Task 5 (6 points): a Secret as a file

In namespace `exam`, create a pod named `secret-reader` with the image `busybox:1.36` that runs `sleep 3600`. Mount the Secret `db-secret` as files in the folder `/etc/db`.

### Task 6 (8 points): storage

Create a PersistentVolume named `exam-pv`: 500Mi, access mode `ReadWriteOnce`, hostPath `/data/exam`, storage class name `manual`. In namespace `exam`, create a PersistentVolumeClaim named `exam-pvc` that asks for 200Mi from storage class `manual`. The claim must be **Bound**.

### Task 7 (6 points): a health check

In namespace `exam`, create a pod named `healthy` with the image `nginx:1.27-alpine` and a **readiness probe**: HTTP GET on path `/` and port `80`, every 5 seconds.

### Task 8 (6 points): resources

In namespace `exam`, set these on the container of the Deployment `frontend`: requests `cpu=50m`, `memory=32Mi`; limits `cpu=100m`, `memory=64Mi`.

### Task 9 (6 points): scheduling

Put the label `disk=fast` on the node `minikube-m02`. In namespace `exam`, create a pod named `fast` with the image `nginx:1.27-alpine` that runs **only** on nodes with that label.

### Task 10 (8 points): a NetworkPolicy

In namespace `exam`, create a NetworkPolicy named `web-only-from-frontend`. It must allow traffic to pods with the label `tier=frontend` **only** from pods with the label `app=frontend`, on port **80**.

### Task 11 (8 points): access control

In namespace `exam`, create a ServiceAccount named `viewer`. Create a Role named `pod-viewer` that allows `get`, `list` and `watch` on **pods**. Bind the Role to the ServiceAccount with a RoleBinding named `viewer-binding`. Write the answer of this command to the file `~/exam/task11.txt`:

```text
kubectl auth can-i list pods -n exam --as=system:serviceaccount:exam:viewer
```

### Task 12 (6 points): a release and a rollback

In namespace `exam`, change the image of the Deployment `frontend` to `nginx:1.28-alpine`. Wait until it is done. Then **roll back** to the version before it. Write the image name that runs after the rollback to `~/exam/task12.txt`.

### Task 13 (6 points): logs

The Shop's backend runs in namespace `dev`. Write the **last 20 log lines** of one backend pod to the file `~/exam/task13.txt`.

### Task 14 (8 points): a node

Mark the node `minikube-m03` as **not schedulable** and move its pods away (drain it). Then make it **schedulable** again.

### Task 15 (10 points): troubleshooting

Run this command. It creates a broken Deployment:

**📋 Copy and paste:**

```bash
kubectl create deployment broken -n exam --image=nginx:1.27-alpine --replicas=2 -o yaml --dry-run=client \
  | sed 's/nginx:1.27-alpine/nginx:1.27-alpnie/' | kubectl apply -f -
```

**👀 You should see** *(do not paste)*:

```text
deployment.apps/broken created
```

Find out why its pods do not run and fix the Deployment, so that **2 pods are Running**. Write the cause in one line to `~/exam/task15.txt`.

---

## When the time is up

Check your work with the [solutions](./lab-w4-mock-exam-solutions.md) and add up your points.

🧹 **Clean up when you have finished marking:**

**📋 Copy and paste:**

```bash
kubectl delete namespace exam
kubectl delete pv exam-pv
kubectl label node minikube-m02 disk-
kubectl uncordon minikube-m03
```

**👀 You should see** one line for each command. `not found` or `already uncordoned` is fine: that part was already clean.
