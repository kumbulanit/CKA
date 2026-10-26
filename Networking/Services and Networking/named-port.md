
### First Use-Case

##### Step 1: Create POD and Service
```sh
kubectl run nginx --image=nginx --port=80
kubectl expose pod nginx --name first-svc --port=80 --target-port=80 --type=NodePort

kubectl get svc
kubectl get svc first-svc -o yaml
```

##### Step 2: Verify the Connectivity
```sh
kubectl get nodes -o wide

curl <WORKER-NODE-IP>:<NODEPORT>
```
The service's `targetPort` is the number 80.

### Second Use-Case

##### Step 1: Create POD and Service
```sh
kubectl run nginx2 --image=nginx --port=80 --dry-run=client -o yaml > pod_named.yaml
```
Add a name to the port, under spec.containers.ports, so it looks like this:

```sh
    ports:
    - containerPort: 80
      name: custom-http
```
```sh
kubectl apply -f pod_named.yaml
```
```sh
kubectl expose pod nginx2 --name named-svc --port=80 --target-port=custom-http --type=NodePort
```
##### Step 2: Verify the Connectivity
```sh
kubectl get svc
curl <WORKER-NODE-IP>:<NODEPORT>
```

This time the service's `targetPort` is the name `custom-http`. The service follows the name, so the pod can change its port number without the service changing.
