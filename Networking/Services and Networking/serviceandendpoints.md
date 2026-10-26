#### Documentation Referred:

https://kubernetes.io/docs/concepts/services-networking/service/

#### Step 1: Creating Backend PODS
```sh
kubectl run backend-pod-1 --image=nginx
kubectl run backend-pod-2 --image=nginx
```
#### Step 2: Creating Frontend PODS
```sh
kubectl run frontend-pod --image=ubuntu --command -- sleep 3600
```
#### Step 3: Test the Connection between Frontend and Backend PODs
```sh
kubectl get pods -o wide
kubectl exec -it frontend-pod -- bash
apt-get update && apt-get -y install curl
curl <BACKEND-POD-1-IP>
```
#### Step 4: Create a new Service

```sh
 nano service.yaml
```
```sh
apiVersion: v1
kind: Service
metadata:
   name: kplabs-service
spec:
   ports:
   - port: 8080
     targetPort: 80
```
```
kubectl apply -f service.yaml
kubectl get service
kubectl describe service kplabs-service
```
#### Step 5: Associate Endpoints with Service
```sh
nano endpoint.yaml
```
```sh
apiVersion: v1
kind: Endpoints
metadata:
  name: kplabs-service
subsets:
  - addresses:
      - ip: <BACKEND-POD-1-IP>
    ports:
      - port: 80
```
```sh
kubectl apply -f endpoint.yaml
```
Since Kubernetes v1.33 the `Endpoints` API is deprecated in favour of `EndpointSlice`, so kubectl prints a warning; it still works. The same thing as an EndpointSlice:
```sh
apiVersion: discovery.k8s.io/v1
kind: EndpointSlice
metadata:
  name: kplabs-service-1
  labels:
    kubernetes.io/service-name: kplabs-service
addressType: IPv4
ports:
  - port: 80
endpoints:
  - addresses:
      - <BACKEND-POD-1-IP>
```
#### Step 6: Test the Connection
```sh
kubectl exec -it frontend-pod -- bash
curl <SERVICE-IP>:8080
```

#### Step 7: Delete the Created Resources
```sh
kubectl delete service kplabs-service
kubectl delete endpoints kplabs-service
kubectl delete pod backend-pod-1
kubectl delete pod backend-pod-2
kubectl delete pod frontend-pod
```
