### DaemonSets

A DaemonSet runs one copy of a pod on every node. Kubernetes uses DaemonSets for node agents such as `kube-proxy` and the Calico network plugin: when a node joins the cluster, it gets the pod automatically.

#### Create a DaemonSet

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: kplabs-daemonset
spec:
  selector:
    matchLabels:
      name: kplabs-all-pods
  template:
    metadata:
      labels:
        name: kplabs-all-pods
    spec:
      containers:
      - name: kplabs-pods
        image: nginx
```

This is also the file [`09-daemonsets.yaml`](./09-daemonsets.yaml) in this folder: `kubectl apply -f 09-daemonsets.yaml`

#### Check that every node runs one copy

```sh
kubectl get daemonset kplabs-daemonset
kubectl get pods -l name=kplabs-all-pods -o wide
```

`DESIRED` and `READY` are the number of nodes (3 on the course's minikube cluster), and the `NODE` column shows one pod on each node. Compare with the DaemonSets the cluster runs itself:

```sh
kubectl get daemonsets -n kube-system
```

#### Clean up

```sh
kubectl delete daemonset kplabs-daemonset
```
