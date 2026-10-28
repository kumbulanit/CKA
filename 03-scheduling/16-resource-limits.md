### Resource Requests and Limits

A container's **requests** are what the scheduler reserves for it on a node (a pod only goes to a node with that much free). Its **limits** are the most it may use: above its memory limit the container is killed (`OOMKilled`), above its CPU limit it is slowed down.

#### A pod without requests or limits

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: kplabs-pod
spec:
  containers:
  - name: kplabs-container
    image: nginx
```

This is also the file [`16-resource-limits-kplabs-pods.yaml`](./16-resource-limits-kplabs-pods.yaml) in this folder: `kubectl apply -f 16-resource-limits-kplabs-pods.yaml`

```sh
kubectl describe pod kplabs-pod | grep -E "Requests|Limits|QoS"
kubectl get pod kplabs-pod -o jsonpath='{.status.qosClass}{"\n"}'
```

There are no requests or limits, so the pod is in the `BestEffort` quality-of-service class: the first to be evicted when a node runs short of memory. Delete it before the next step (the next pod has the same name):

```sh
kubectl delete pod kplabs-pod
```

#### The same pod with requests and limits

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: kplabs-pod
spec:
  containers:
  - name: kplabs-container
    image: nginx
    resources:
      requests:
        memory: "640Mi"
        cpu: "0.5"
      limits:
        memory: "12800Mi"
        cpu: "1"
```

This is also the file [`16-resource-limits-requests-limits.yaml`](./16-resource-limits-requests-limits.yaml) in this folder: `kubectl apply -f 16-resource-limits-requests-limits.yaml`

```sh
kubectl describe pod kplabs-pod | grep -A3 -E "Requests|Limits"
kubectl get pod kplabs-pod -o jsonpath='{.status.qosClass}{"\n"}'
kubectl describe node $(kubectl get pod kplabs-pod -o jsonpath='{.spec.nodeName}') | grep -A8 "Allocated resources"
```

The requests and limits differ, so the class is `Burstable`; requests equal to limits would make it `Guaranteed`. The node's *Allocated resources* now include the pod's 500m CPU and 640Mi memory requests.

```sh
kubectl delete pod kplabs-pod
```
