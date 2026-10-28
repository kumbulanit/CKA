#### Documentation Referred:

https://kubernetes.io/docs/tutorials/stateless-application/expose-external-ip-address/#creating-a-service-for-an-application-running-in-five-pods



##### 06-expose-pods.yaml

```sh
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod
spec:
  containers:
  -  image: nginx
     name: democontainer
     ports:
       - containerPort: 8080
```

This is also the file [`06-expose-pods.yaml`](./06-expose-pods.yaml) in this folder: `kubectl apply -f 06-expose-pods.yaml`

```sh
kubectl apply -f 06-expose-pods.yaml
```
```sh
kubectl get pods

kubectl describe pod nginx-pod

kubectl explain pod.spec.containers.ports
```
