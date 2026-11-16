# Workshop 4: Mock exam solutions

Each answer shows one way to do the task and one command to check it. Give yourself the points only if the check shows what it should.

## Task 1 (4 points)

**📋 Copy and paste:**

```bash
kubectl run web -n exam --image=nginx:1.27-alpine --labels=tier=frontend
```

**Check:**

```bash
kubectl get pod web -n exam --show-labels
```

The pod is `Running` and the labels show `tier=frontend`.

## Task 2 (6 points)

**📋 Copy and paste:**

```bash
kubectl create deployment frontend -n exam --image=nginx:1.27-alpine --replicas=3
kubectl scale deployment frontend -n exam --replicas=4
```

**Check:**

```bash
kubectl get deployment frontend -n exam
```

`READY` shows `4/4`.

## Task 3 (6 points)

`kubectl expose` cannot set the node port, so write the file:

**📋 Copy and paste:**

```bash
cat <<'YAML' | kubectl apply -n exam -f -
apiVersion: v1
kind: Service
metadata:
  name: frontend
spec:
  type: NodePort
  selector:
    app: frontend
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30090
YAML
```

**Check:**

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://$(minikube ip):30090
```

It prints `200`.

## Task 4 (6 points)

**📋 Copy and paste:**

```bash
kubectl create configmap shop-settings -n exam --from-literal=SHOP_NAME="Corner Shop" --from-literal=SHOP_CURRENCY=ZAR
cat <<'YAML' | kubectl apply -n exam -f -
apiVersion: v1
kind: Pod
metadata:
  name: settings
spec:
  containers:
  - name: settings
    image: busybox:1.36
    command: ["sleep", "3600"]
    envFrom:
    - configMapRef:
        name: shop-settings
YAML
```

**Check:**

```bash
kubectl exec settings -n exam -- env | grep SHOP
```

It prints both `SHOP_NAME=Corner Shop` and `SHOP_CURRENCY=ZAR`.

## Task 5 (6 points)

**📋 Copy and paste:**

```bash
cat <<'YAML' | kubectl apply -n exam -f -
apiVersion: v1
kind: Pod
metadata:
  name: secret-reader
spec:
  containers:
  - name: secret-reader
    image: busybox:1.36
    command: ["sleep", "3600"]
    volumeMounts:
    - name: db
      mountPath: /etc/db
  volumes:
  - name: db
    secret:
      secretName: db-secret
YAML
```

**Check:**

```bash
kubectl exec secret-reader -n exam -- cat /etc/db/password
```

It prints `exam-pass-123`.

## Task 6 (8 points)

**📋 Copy and paste:**

```bash
cat <<'YAML' | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: exam-pv
spec:
  capacity:
    storage: 500Mi
  accessModes:
  - ReadWriteOnce
  storageClassName: manual
  hostPath:
    path: /data/exam
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: exam-pvc
  namespace: exam
spec:
  storageClassName: manual
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 200Mi
YAML
```

**Check:**

```bash
kubectl get pvc exam-pvc -n exam
```

`STATUS` shows `Bound` and `VOLUME` shows `exam-pv`.

## Task 7 (6 points)

**📋 Copy and paste:**

```bash
cat <<'YAML' | kubectl apply -n exam -f -
apiVersion: v1
kind: Pod
metadata:
  name: healthy
spec:
  containers:
  - name: healthy
    image: nginx:1.27-alpine
    readinessProbe:
      httpGet:
        path: /
        port: 80
      periodSeconds: 5
YAML
```

**Check:**

```bash
kubectl describe pod healthy -n exam | grep Readiness
```

It shows `http-get http://:80/` and `period=5s`.

## Task 8 (6 points)

**📋 Copy and paste:**

```bash
kubectl set resources deployment frontend -n exam --requests=cpu=50m,memory=32Mi --limits=cpu=100m,memory=64Mi
```

**Check:**

```bash
kubectl get deployment frontend -n exam -o jsonpath='{.spec.template.spec.containers[0].resources}{"\n"}'
```

It shows the four values.

## Task 9 (6 points)

**📋 Copy and paste:**

```bash
kubectl label node minikube-m02 disk=fast
cat <<'YAML' | kubectl apply -n exam -f -
apiVersion: v1
kind: Pod
metadata:
  name: fast
spec:
  nodeSelector:
    disk: fast
  containers:
  - name: fast
    image: nginx:1.27-alpine
YAML
```

**Check:**

```bash
kubectl get pod fast -n exam -o wide
```

`NODE` shows `minikube-m02`.

## Task 10 (8 points)

**📋 Copy and paste:**

```bash
cat <<'YAML' | kubectl apply -n exam -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: web-only-from-frontend
spec:
  podSelector:
    matchLabels:
      tier: frontend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - port: 80
YAML
```

**Check:**

```bash
kubectl describe networkpolicy web-only-from-frontend -n exam
```

`PodSelector` is `tier=frontend`, and it allows port `80/TCP` from `PodSelector: app=frontend`.

## Task 11 (8 points)

**📋 Copy and paste:**

```bash
kubectl create serviceaccount viewer -n exam
kubectl create role pod-viewer -n exam --verb=get,list,watch --resource=pods
kubectl create rolebinding viewer-binding -n exam --role=pod-viewer --serviceaccount=exam:viewer
kubectl auth can-i list pods -n exam --as=system:serviceaccount:exam:viewer > ~/exam/task11.txt
```

**Check:**

```bash
cat ~/exam/task11.txt
```

It prints `yes`.

## Task 12 (6 points)

**📋 Copy and paste:**

```bash
kubectl set image deployment/frontend -n exam nginx=nginx:1.28-alpine
kubectl rollout status deployment/frontend -n exam
kubectl rollout undo deployment/frontend -n exam
kubectl rollout status deployment/frontend -n exam
kubectl get deployment frontend -n exam -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}' > ~/exam/task12.txt
```

**Check:**

```bash
cat ~/exam/task12.txt
```

It prints `nginx:1.27-alpine`.

## Task 13 (6 points)

**📋 Copy and paste:**

```bash
kubectl logs deployment/backend -n dev --tail=20 > ~/exam/task13.txt
```

**Check:**

```bash
wc -l ~/exam/task13.txt
```

It shows 20 lines (or fewer, if the pod has printed fewer).

## Task 14 (8 points)

**📋 Copy and paste:**

```bash
kubectl drain minikube-m03 --ignore-daemonsets --delete-emptydir-data --force
kubectl uncordon minikube-m03
```

**Check:**

```bash
kubectl get node minikube-m03
```

`STATUS` shows `Ready`, without `SchedulingDisabled`. (The line `Warning: ignoring DaemonSet-managed Pods: ...` from `kubectl drain` is normal: see Lab 2.7.)

`--force` deletes pods that have no controller (no Deployment brings them back). Your exam pods (`web`, `settings`, `secret-reader`, `healthy`) are such pods: the taint from "Before you start" kept them off this node, so the drain did not touch them. In the real exam, read the task: if it says to drain a node, `--force` is usually what it wants.

## Task 15 (10 points)

Find the cause:

**📋 Copy and paste:**

```bash
kubectl get pods -n exam -l app=broken
kubectl describe pods -n exam -l app=broken | grep -A8 Events
```

The pods show `ImagePullBackOff`: the image name is wrong (`alpnie`, not `alpine`). Fix it:

**📋 Copy and paste:**

```bash
kubectl set image deployment/broken -n exam nginx=nginx:1.27-alpine
echo "The image name was wrong: nginx:1.27-alpnie does not exist" > ~/exam/task15.txt
```

**Check:**

```bash
kubectl get deployment broken -n exam
```

`READY` shows `2/2`.

## Your score

| Points | Result |
| --- | --- |
| 66 or more | Pass. Book the exam. |
| 50 to 65 | Close. Repeat the tasks you lost points on. |
| Under 50 | Go through the course labs once more, then try again. |
