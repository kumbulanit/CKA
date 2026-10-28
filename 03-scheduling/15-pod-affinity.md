### Pod Affinity

Node affinity picks nodes by their labels. **Pod affinity** picks nodes by the pods already running on them: with `topologyKey: kubernetes.io/hostname`, a pod must go to a node that already runs a pod matching the label selector (in the same namespace). The selector below matches any pod whose `app` label is not `frontend`.

#### A pod with pod affinity

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: kplabs-pod-affinity
spec:
  affinity:
    podAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
          - key: app
            operator: NotIn
            values:
            - frontend
        topologyKey: kubernetes.io/hostname
  containers:
  - name: pod-affinity
    image: nginx
```

This is also the file [`15-pod-affinity-podaffinity-required.yaml`](./15-pod-affinity-podaffinity-required.yaml) in this folder: `kubectl apply -f 15-pod-affinity-podaffinity-required.yaml`

The pod has no `app` label, so it matches its own selector. When no other pod matches yet, the scheduler lets such a pod go to any node, so it starts:

```sh
kubectl get pod kplabs-pod-affinity -o wide
kubectl delete pod kplabs-pod-affinity
```

#### Pod affinity in a Deployment: replicas that stay together

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-kubernetes-second
spec:
  replicas: 3
  selector:
    matchLabels:
      app: hello-kubernetes-second
  template:
    metadata:
      labels:
        app: hello-kubernetes-second
    spec:
      affinity:
        podAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: NotIn
                values:
                - frontend
            topologyKey: kubernetes.io/hostname
      containers:
      - name: with-node-anti-affinity
        image: nginx
```

This is also the file [`15-pod-affinity-nodepodaffinity.yaml`](./15-pod-affinity-nodepodaffinity.yaml) in this folder: `kubectl apply -f 15-pod-affinity-nodepodaffinity.yaml`

The first replica can go anywhere; every other replica must go to a node that already runs a matching pod, which is the first replica's node. All three end up on the same node:

```sh
kubectl get pods -l app=hello-kubernetes-second -o wide
kubectl delete deployment hello-kubernetes-second
```

`podAntiAffinity` does the opposite (keeps replicas apart): see [12-affinity-and-anti-affinity.md](./12-affinity-and-anti-affinity.md).
