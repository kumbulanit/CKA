#### Verify Default Service Account In Namespace
```sh
kubectl get serviceaccount
kubectl get sa
kubectl get sa -n kube-system
```
#### Create New Namespace
```sh
kubectl create namespace kplabs-test
```
#### Verify if Default Service Account Gets Created in Namespace
```sh
kubectl get sa -n kplabs-test
```
#### Create New Pod in Newly Created Namespace
```sh
kubectl run nginx-pod -n kplabs-test --image=nginx
kubectl get pods -n kplabs-test
kubectl describe pod nginx-pod -n kplabs-test
```
#### Verify if Mounted Token is Available inside Pod
On the server, open a shell in `nginx-pod`:
```sh
kubectl exec -it nginx-pod -n kplabs-test -- bash
```
These commands run inside the pod `nginx-pod`, not on the server: the token is a file mounted in the pod (the folder does not exist on the server). Leave the pod with `exit`:
```sh
cd /var/run/secrets/kubernetes.io/serviceaccount/
ls
cat token
exit
```
