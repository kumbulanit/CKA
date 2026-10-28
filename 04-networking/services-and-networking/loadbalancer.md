
#### Step 1: Create Sample POD with Label
```sh
kubectl run lb-pod --labels="type=loadbalanced" --image=nginx
kubectl get pods --show-labels
```
#### Step 2: Create LoadBalancer service
```sh
nano elb-service.yaml
```
```sh
apiVersion: v1
kind: Service
metadata:
  name: kplabs-loadbalancer
spec:
  type: LoadBalancer
  ports:
  - port: 80
    protocol: TCP
  selector:
    type: loadbalanced
```

This is also the file [`elb-service.yaml`](./elb-service.yaml) in this folder: `kubectl apply -f elb-service.yaml`

```sh
kubectl apply -f elb-service.yaml
```
#### Step 3: Verify Service Logs
```sh
kubectl describe service kplabs-loadbalancer
kubectl get service kplabs-loadbalancer
```
On a cloud cluster the cloud provider creates a load balancer and fills in `EXTERNAL-IP`. On a cluster on your own machines, like minikube, nothing provides load balancers, so `EXTERNAL-IP` stays `<pending>`. On minikube, run `minikube tunnel` in a second terminal: while it runs, LoadBalancer services get an address (on a kubeadm cluster, add-ons such as MetalLB do this). A LoadBalancer service is also a NodePort service, so `curl http://$(minikube ip -n minikube-m02):<NODEPORT>` works either way.

#### Step 4: Delete the Resources
```sh
kubectl delete pod lb-pod
kubectl delete -f elb-service.yaml
```
