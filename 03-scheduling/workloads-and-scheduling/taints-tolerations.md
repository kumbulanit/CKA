#### Step 1: Taint a worker node
```sh
kubectl taint nodes node01 key=value:NoSchedule
kubectl describe node node01 | grep Taints
```

#### Step 2: Create pods and see where they run
New pods without a toleration are not scheduled on node01:
```sh
kubectl create deployment nginx --image=nginx --replicas=4
kubectl get pods -o wide
```

#### Step 3: A pod that tolerates the taint
##### toleration-pod.yaml
```sh
apiVersion: v1
kind: Pod
metadata:
  name: tolerated-pod
spec:
  containers:
  - name: nginx
    image: nginx
  tolerations:
  - key: key
    operator: Equal
    value: value
    effect: NoSchedule
  nodeSelector:
    kubernetes.io/hostname: node01
```

This is also the file [`toleration-pod.yaml`](./toleration-pod.yaml) in this folder: `kubectl apply -f toleration-pod.yaml`

```sh
kubectl apply -f toleration-pod.yaml
kubectl get pods -o wide
```

#### Step 4: Remove the taint and clean up
```sh
kubectl taint nodes node01 key=value:NoSchedule-
kubectl delete deployment nginx
kubectl delete -f toleration-pod.yaml
```
