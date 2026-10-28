> This lesson uses the minikube node names: `minikube` is the control plane, `minikube-m02` and `minikube-m03` the workers (`controlplane`, `node01` and `node02` on a kubeadm cluster).


### Step 1: Verify the Label of Node
```sh
kubectl get nodes
kubectl describe node minikube-m02
```

### Step 2: Label Worker Node
```sh
kubectl label node minikube disk=hdd
kubectl label node minikube-m02 disk=ssd
kubectl label node minikube-m03 disk=hdd
```

### Step 3: Create NodeSelector Configuration
```sh
nano nodeselector.yaml
```
```sh
apiVersion: v1
kind: Pod
metadata:
  name: service-pod
spec:
  containers:
  - name: service-pod
    image: nginx
  nodeSelector:
    disk: ssd
```

This is also the file [`11-node-selector-practical-nodeselector.yaml`](./11-node-selector-practical-nodeselector.yaml) in this folder: `kubectl apply -f 11-node-selector-practical-nodeselector.yaml`

```sh
kubectl apply -f nodeselector.yaml
```

### Step 4: Verify
```sh
kubectl get pods -o wide
```

### Step 5: Destroy Resources created in this video
```sh
kubectl delete -f nodeselector.yaml
```

#### Also in this folder

- [`11-node-selector-practical-podtonodes.yaml`](./11-node-selector-practical-podtonodes.yaml): Two pods pinned to the workers by host name (`kubernetes.io/hostname`): `frontend` on `minikube-m02`, `frontendpod` on `minikube-m03`. `kubectl apply -f 11-node-selector-practical-podtonodes.yaml`
