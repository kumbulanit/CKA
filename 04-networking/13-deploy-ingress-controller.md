> **Note:** the ingress-nginx project has been retired and its repository archived, so it gets no more fixes. It still installs and works for learning Ingress, which is what this lesson uses it for. For new work, use another Ingress controller or the Gateway API (https://gateway-api.sigs.k8s.io/), which the current CKA curriculum also covers.

#### Documentation Referred:

https://kubernetes.io/docs/concepts/services-networking/ingress-controllers/

https://kubernetes.github.io/ingress-nginx/deploy/


#### Step 1: Install Nginx Ingress Controller:
```sh
helm upgrade --install ingress-nginx ingress-nginx --repo https://kubernetes.github.io/ingress-nginx --namespace ingress-nginx --create-namespace \
  --set controller.service.type=NodePort --set controller.service.nodePorts.http=30080
```
On a cloud cluster you can leave out the two `--set` options: the controller then gets a cloud load balancer. A cluster on your own machines, like minikube, has no load balancer, so we expose the controller on node port 30080 instead.

#### Step 2: Verify the Ingress Controller Resource
```sh
helm list --all-namespaces
kubectl get ingressclass
kubectl get service -n ingress-nginx
```
The `ingress-nginx-controller` service should be of type `NodePort` with port `80:30080`.

#### Step 3: Modify Ingress Resource to Add Controller Data

Add following content under .spec section of ingress.yaml file
```sh
ingressClassName: nginx
```

```sh
kubectl apply -f ingress.yaml
```

#### Step 4: Verify the Ingress Controller Setup
From the server, send requests to the controller's node port on a worker, with each host name:
```sh
curl -H "Host: website01.example.internal" http://$(minikube ip -n minikube-m02):30080
curl -H "Host: website02.example.internal" http://$(minikube ip -n minikube-m02):30080
```
Or add the names to `/etc/hosts` on the server, with the worker's address, and use them directly:
```sh
echo "$(minikube ip -n minikube-m02) website01.example.internal website02.example.internal" | sudo tee -a /etc/hosts
curl http://website01.example.internal:30080
```

#### Step 5: Change the Default Nginx Page for Each Service

```sh
kubectl exec -it service-pod-1 -- bash
cd /usr/share/nginx/html
echo "This is Website 1" > index.html
```
```sh
kubectl exec -it service-pod-2 -- bash
cd /usr/share/nginx/html
echo "This is Website 2" > index.html
```

#### Step 6: Verification

```sh
curl -H "Host: website01.example.internal" http://$(minikube ip -n minikube-m02):30080
curl -H "Host: website02.example.internal" http://$(minikube ip -n minikube-m02):30080
```
#### Step 7: Delete All Resource

```sh
helm uninstall ingress-nginx -n ingress-nginx
kubectl delete -f ingress.yaml
kubectl delete service service1
kubectl delete service service2
kubectl delete pod service-pod-1
kubectl delete pod service-pod-2
kubectl delete pod frontend-pod
```
