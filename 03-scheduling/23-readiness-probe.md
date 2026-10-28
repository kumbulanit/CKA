#### 23-readiness-probe.yaml

```sh
apiVersion: v1
kind: Pod
metadata:
  name: readiness
spec:
  containers:
  - name: readiness
    image: ubuntu
    tty: true
    readinessProbe:
     exec:
       command:
       - cat
       - /tmp/healthy
     initialDelaySeconds: 5
     periodSeconds: 5
```

This is also the file [`23-readiness-probe.yaml`](./23-readiness-probe.yaml) in this folder: `kubectl apply -f 23-readiness-probe.yaml`

#### Create the file at the readiness probe path
```sh
kubectl exec readiness -- touch /tmp/healthy
```
#### Verify if POD is ready:
```sh
kubectl get pods
```
