
#### List the Worker Node
```sh
kubectl get nodes 
```
#### Create a new POD from Nginx Image
```sh
kubectl run mywebserver --image=nginx
```
#### List  the PODS that are currently running.
```sh
kubectl get pods
```
#### Connect inside the POD
```sh
kubectl exec -it mywebserver -- bash
```
This opens a shell inside the pod: what you type now runs in the pod's container, not on the server (try `ls /` and `hostname`). Leave the pod with `exit` or CTRL+D.

From the server, you can also run one command in the pod without opening a shell:
```sh
kubectl exec -it mywebserver -- ls -l /
```
#### Delete the POD
```sh
kubectl delete pod mywebserver
```

