> This lesson uses the minikube node names: `minikube` is the control plane, `minikube-m02` and `minikube-m03` the workers (`controlplane`, `node01` and `node02` on a kubeadm cluster).

#### Step 1: Taint a worker node
```sh
kubectl taint nodes minikube-m02 key=value:NoSchedule
kubectl describe node minikube-m02 | grep Taints
```

#### Step 2: Create pods and see where they run
New pods without a toleration are not scheduled on minikube-m02:
```sh
kubectl create deployment nginx --image=nginx --replicas=4
kubectl get pods -o wide
```

#### Step 3: A pod that tolerates the taint
##### 19-taints-and-tolerations-practical.yaml
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
    kubernetes.io/hostname: minikube-m02
```

This is also the file [`19-taints-and-tolerations-practical.yaml`](./19-taints-and-tolerations-practical.yaml) in this folder: `kubectl apply -f 19-taints-and-tolerations-practical.yaml`

```sh
kubectl apply -f 19-taints-and-tolerations-practical.yaml
kubectl get pods -o wide
```

#### Step 4: Remove the taint and clean up
```sh
kubectl taint nodes minikube-m02 key=value:NoSchedule-
kubectl delete deployment nginx
kubectl delete -f 19-taints-and-tolerations-practical.yaml
```
