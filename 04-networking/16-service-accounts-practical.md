### Documentation Referred:

https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/


#### Create New Service Account
```sh
kubectl create serviceaccount custom-sa
```

#### Generate Base Pod Manifest
```sh
kubectl run custom-pod --image=nginx --dry-run=client -o yaml > custom-pod-sa.yaml
```
#### Final Edited Manifest
```sh
apiVersion: v1
kind: Pod
metadata:
  name: custom-pod
spec:
  serviceAccountName: custom-sa
  containers:
  - image: nginx
    name: custom-pod
```

This is also the file [`16-service-accounts-practical.yaml`](./16-service-accounts-practical.yaml) in this folder: `kubectl apply -f 16-service-accounts-practical.yaml`

```sh
kubectl apply -f custom-pod-sa.yaml
kubectl get pod custom-pod -o jsonpath='{.spec.serviceAccountName}'
```