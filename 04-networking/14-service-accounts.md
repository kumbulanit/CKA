#### List service account in all namespaces
```sh
kubectl get serviceaccount --all-namespaces
```

#### Create a Test App Pod
```sh
kubectl run app-pod --image=nginx 
kubectl get pods
```
#### Verify Namespace associated with Pod
```sh
kubectl describe pod app-pod
```
#### Verify Mounted Token in Pod
On the server, open a shell in `app-pod`:
```sh
kubectl exec -it app-pod -- bash
```
These commands run inside the pod `app-pod`, not on the server: the token is a file that Kubernetes mounts in the pod (the folder does not exist on the server):
```sh
cd /var/run/secrets/kubernetes.io/serviceaccount/
ls
cat token
```
#### Connect to Kubernetes Cluster using Token
Still inside the pod, call the API server with the token. Inside the cluster the API server is always reachable as `https://kubernetes.default.svc`:
```sh
token=$(cat token)
echo $token

curl --cacert ca.crt -H "Authorization: Bearer $token" https://kubernetes.default.svc/api/v1
exit
```
`exit` leaves the pod. On the server, outside the pod, `kubectl cluster-info` shows the API server address.

The token in the pod is short-lived (about an hour) and is renewed by the kubelet. Since v1.24, service accounts no longer get a long-lived token Secret; to get a token outside a pod, run `kubectl create token default`.
