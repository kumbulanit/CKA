

https://kubernetes.io/docs/reference/kubernetes-api/

https://github.com/kubernetes/community/blob/master/contributors/devel/sig-architecture/api-conventions.md#metadata



### 03-first-pod-yaml.yaml file
```sh
apiVersion: v1
kind: Pod
metadata:
  name: nginxwebserver
spec:
  containers:
  -  image: nginx
     name: democontainer
```

This is also the file [`03-first-pod-yaml.yaml`](./03-first-pod-yaml.yaml) in this folder: `kubectl apply -f 03-first-pod-yaml.yaml`

```sh
kubectl apply -f 03-first-pod-yaml.yaml
```

#### List the Running Pods
```sh
kubectl get pods
```
#### Delete the Resources Created via 03-first-pod-yaml.yaml
```sh
kubectl delete -f 03-first-pod-yaml.yaml
```
