#### Documentation Referred:

https://kubernetes.io/docs/concepts/services-networking/ingress/#name-based-virtual-hosting


#### Step 1: Create PODS associated with Services
```sh
kubectl run service-pod-1 --image=nginx
kubectl run service-pod-2 --image=nginx
```

#### Step 2: Create Service
```sh
kubectl expose pod service-pod-1 --name service1 --port=80 --target-port=80
kubectl expose pod service-pod-2 --name service2 --port=80 --target-port=80
kubectl get services
```

#### Step 3: Verify Service to POD connectivity
On the server, start a pod to test from, and open a shell in it:
```sh
kubectl run frontend-pod --image=ubuntu --command -- sleep 36000
kubectl exec -it frontend-pod -- bash
```
These commands run inside the pod `frontend-pod`, not on the server: install curl, call both Services, then leave the pod with `exit` (the next step is on the server again):
```sh
apt-get update && apt-get -y install curl
curl <SERVICE-1-IP>
curl <SERVICE-2-IP>
exit
```

#### Step 4: Create Ingress Resource
```sh
nano ingress.yaml
```
```sh
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: name-virtual-host-ingress
spec:
  ingressClassName: nginx
  rules:
  - host: website01.example.internal
    http:
      paths:
      - pathType: Prefix
        path: "/"
        backend:
          service:
            name: service1
            port:
              number: 80
  - host: website02.example.internal
    http:
      paths:
      - pathType: Prefix
        path: "/"
        backend:
          service:
            name: service2
            port:
              number: 80
```

This is also the file [`12-ingress.yaml`](./12-ingress.yaml) in this folder: `kubectl apply -f 12-ingress.yaml`

```sh
kubectl apply -f ingress.yaml
kubectl get ingress
kubectl describe ingress name-virtual-host-ingress
```
