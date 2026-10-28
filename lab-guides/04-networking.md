# Module 4: Services and networking

Each lab below is a practical from this repository, step by step: the command, what it does, and what it printed on the practice cluster. Names with random endings (pod names such as `nginx-7d9c…`), IP addresses and ages will differ on yours.

- [Lab 4.1: A Service with manual endpoints](#lab-41-a-service-with-manual-endpoints)
- [Lab 4.2: Services find pods by selector](#lab-42-services-find-pods-by-selector)
- [Lab 4.3: NodePort](#lab-43-nodeport)
- [Lab 4.4: LoadBalancer](#lab-44-loadbalancer)
- [Lab 4.5: Service manifests from the command line](#lab-45-service-manifests-from-the-command-line)
- [Lab 4.6: Named ports](#lab-46-named-ports)
- [Lab 4.7: Namespaces](#lab-47-namespaces)
- [Lab 4.8: Installing Helm](#lab-48-installing-helm)
- [Lab 4.9: Your first Helm charts](#lab-49-your-first-helm-charts)
- [Lab 4.10: Ingress](#lab-410-ingress)
- [Lab 4.11: Service accounts](#lab-411-service-accounts)
- [Lab 4.12: A custom service account](#lab-412-a-custom-service-account)
- [Lab 4.13: Cluster DNS](#lab-413-cluster-dns)

## Before you start

Start the practice cluster on your Ubuntu server, as in the [README](../README.md#the-practice-cluster):

```bash
git clone https://github.com/kumbulanit/CKA.git && cd CKA
sudo ./setup.sh          # minikube with three nodes, Kubernetes v1.36 (about 10 minutes the first time)
kubectl get nodes         # minikube, minikube-m02, minikube-m03
```

The steps use those node names, and `minikube ssh -n <node>` for commands on a node. Run `kubectl` as your own user on the server; commands on the control plane's files (`/etc/kubernetes/manifests`, the kubelet) go through `minikube ssh` with `sudo`. The outputs were recorded in Desired Labs, where the terminal is already root on `minikube` and the API server answers on port 6443 (8443 on minikube): addresses, ports and ages on yours will differ.

## Lab 4.1: A Service with manual endpoints

### What you will do

Follow [03-service-and-endpoints.md](https://github.com/kumbulanit/CKA/blob/main/04-networking/03-service-and-endpoints.md),
steps 1 to 6:

1. Create the pods **backend-pod-1** and **backend-pod-2** from `nginx`, and **frontend-pod** from
   `ubuntu` running `sleep 3600`.
2. Inside frontend-pod, install curl (`apt-get update && apt-get -y install curl`) and curl
   backend-pod-1's IP address.
3. Write **service.yaml**: a Service **kplabs-service** with port **8080** → targetPort **80** and no
   selector. Apply it and describe it: it has no endpoints.
4. Write **endpoint.yaml**: an Endpoints object **kplabs-service** with backend-pod-1's IP and port 80.
   Apply it.
5. From frontend-pod, curl the service's IP on port 8080.

Press **Check** now; step 7 (deleting everything) comes after the check passes.

### Step by step

**Step 1.** Starts the pod `backend-pod-1` from the image `nginx`.

```bash
kubectl run backend-pod-1 --image=nginx
```

You should see something like:

```text
pod/backend-pod-1 created
```

**Step 2.** Starts the pod `backend-pod-2` from the image `nginx`.

```bash
kubectl run backend-pod-2 --image=nginx
```

You should see something like:

```text
pod/backend-pod-2 created
```

**Step 3.** Starts the pod `frontend-pod` from the image `ubuntu`.

```bash
kubectl run frontend-pod --image=ubuntu --command -- sleep 3600
```

You should see something like:

```text
pod/frontend-pod created
```

**Step 4.** Waits until the pods `backend-pod-1`, `backend-pod-2`, `frontend-pod` are Ready.

```bash
kubectl wait --for=condition=Ready pod/backend-pod-1 pod/backend-pod-2 pod/frontend-pod --timeout=180s
```

You should see something like:

```text
pod/backend-pod-1 condition met
pod/backend-pod-2 condition met
pod/frontend-pod condition met
```

**Step 5.** Lists the pods, with IP address and node.

```bash
kubectl get pods -o wide
```

You should see something like:

```text
NAME            READY   STATUS    RESTARTS   AGE   IP           NODE           NOMINATED NODE   READINESS GATES
backend-pod-1   1/1     Running   0          39s   10.244.1.2   minikube-m02   <none>           <none>
backend-pod-2   1/1     Running   0          39s   10.244.2.2   minikube-m03   <none>           <none>
frontend-pod    1/1     Running   0          39s   10.244.1.3   minikube-m02   <none>           <none>
```

**Step 6.** Saves `$BACKEND_POD_1_IP`: prints one field of the pod `backend-pod-1`.

```bash
BACKEND_POD_1_IP=$(kubectl get pod backend-pod-1 -o jsonpath='{.status.podIP}')
```

It prints nothing when it works.

**Step 7.** Runs a command inside the pod `frontend-pod`.

```bash
kubectl exec frontend-pod -- bash -c "apt-get update && apt-get -y install curl && curl $BACKEND_POD_1_IP"
```

You should see something like:

```text
Get:1 http://ports.ubuntu.com/ubuntu-ports resolute InRelease [136 kB]
Get:2 http://ports.ubuntu.com/ubuntu-ports resolute-updates InRelease [137 kB]
Get:3 http://ports.ubuntu.com/ubuntu-ports resolute-backports InRelease [137 kB]
Get:4 http://ports.ubuntu.com/ubuntu-ports resolute-security InRelease [137 kB]
Get:5 http://ports.ubuntu.com/ubuntu-ports resolute/multiverse arm64 Packages [298 kB]
Get:6 http://ports.ubuntu.com/ubuntu-ports resolute/main arm64 Packages [1860 kB]
Get:7 http://ports.ubuntu.com/ubuntu-ports resolute/universe arm64 Packages [19.9 MB]
Get:8 http://ports.ubuntu.com/ubuntu-ports resolute/restricted arm64 Packages [231 kB]
Get:9 http://ports.ubuntu.com/ubuntu-ports resolute-updates/main arm64 Packages [957 kB]
Get:10 http://ports.ubuntu.com/ubuntu-ports resolute-updates/restricted arm64 Packages [848 kB]
Get:11 http://ports.ubuntu.com/ubuntu-ports resolute-updates/multiverse arm64 Packages [26.3 kB]
Get:12 http://ports.ubuntu.com/ubuntu-ports resolute-updates/universe arm64 Packages [417 kB]
Get:13 http://ports.ubuntu.com/ubuntu-ports resolute-backports/universe arm64 Packages [3309 B]
Get:14 http://ports.ubuntu.com/ubuntu-ports resolute-security/main arm64 Packages [771 kB]
Get:15 http://ports.ubuntu.com/ubuntu-ports resolute-security/universe arm64 Packages [254 kB]
Get:16 http://ports.ubuntu.com/ubuntu-ports resolute-security/multiverse arm64 Packages [24.5 kB]
Get:17 http://ports.ubuntu.com/ubuntu-ports resolute-security/restricted arm64 Packages [813 kB]
Fetched 27.0 MB in 14s (1875 kB/s)
… (235 more lines)
```

**Step 8.** Writes the file `service.yaml`.

```bash
cat > service.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
   name: kplabs-service
spec:
   ports:
   - port: 8080
     targetPort: 80
EOF
```

It prints nothing when it works.

**Step 9.** Creates the objects in `service.yaml`, or updates them if they exist.

```bash
kubectl apply -f service.yaml
```

You should see something like:

```text
service/kplabs-service created
```

**Step 10.** Lists the Services.

```bash
kubectl get service
```

You should see something like:

```text
NAME             TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
kplabs-service   ClusterIP   10.96.187.132   <none>        8080/TCP   0s
kubernetes       ClusterIP   10.96.0.1       <none>        443/TCP    98s
```

**Step 11.** Shows the details of the Service `kplabs-service`, with its recent events at the bottom.

```bash
kubectl describe service kplabs-service
```

You should see something like:

```text
Name:                     kplabs-service
Namespace:                default
Labels:                   <none>
Annotations:              <none>
Selector:                 <none>
Type:                     ClusterIP
IP Family Policy:         SingleStack
IP Families:              IPv4
IP:                       10.96.187.132
IPs:                      10.96.187.132
Port:                     <unset>  8080/TCP
TargetPort:               80/TCP
Endpoints:                <none>
Session Affinity:         None
Internal Traffic Policy:  Cluster
Events:                   <none>
```

**Step 12.** Writes the file `endpoint.yaml`.

```bash
cat > endpoint.yaml <<EOF
apiVersion: v1
kind: Endpoints
metadata:
  name: kplabs-service
subsets:
  - addresses:
      - ip: $BACKEND_POD_1_IP
    ports:
      - port: 80
EOF
```

It prints nothing when it works.

**Step 13.** Creates the objects in `endpoint.yaml`, or updates them if they exist.

```bash
kubectl apply -f endpoint.yaml
```

You should see something like:

```text
Warning: v1 Endpoints is deprecated in v1.33+; use discovery.k8s.io/v1 EndpointSlice
endpoints/kplabs-service created
```

**Step 14.** Saves `$SERVICE_IP`: prints one field of the Service `kplabs-service`.

```bash
SERVICE_IP=$(kubectl get svc kplabs-service -o jsonpath='{.spec.clusterIP}')
```

It prints nothing when it works.

**Step 15.** Runs a command inside the pod `frontend-pod`.

```bash
kubectl exec frontend-pod -- curl -s $SERVICE_IP:8080
```

You should see something like:

```text
command terminated with exit code 7
```

### If you see something else

- The check says: _There is no Service kplabs-service with port 8080 and targetPort 80._
- The check says: _kplabs-service should have no selector; its endpoints come from endpoint.yaml._
- The check says: _kplabs-service has no endpoint with backend-pod-1's IP address. Apply endpoint.yaml._
- The check says: _frontend-pod cannot curl the service on port 8080. Is curl installed in frontend-pod (step 2)?_
- `kubectl get pods -o wide` shows each pod's IP address.
- A Service without a selector gets no endpoints by itself. An Endpoints object with the same name as the Service supplies them.

### Why it works

**Why it works.** A Service is a stable virtual IP (the ClusterIP) and port. kube-proxy on every node sends traffic for that IP:port to the Service's endpoints. Normally the endpoints come from the selector; this Service has none, so it stays empty until you create an Endpoints object with the same name. Port 8080 on the Service maps to targetPort 80 on the pod.

**Note:** Endpoints is deprecated since v1.33 in favour of EndpointSlice; the control plane mirrors your Endpoints into an EndpointSlice, which is what kube-proxy reads. Selector-less Services are used to point at things outside the cluster, such as an external database.

---

## Lab 4.2: Services find pods by selector

![How traffic reaches a pod: a Service selects pods by label; NodePort opens a port on every node](../images/services.svg)

*How traffic reaches a pod: a Service selects pods by label; NodePort opens a port on every node*

### What you will do

Follow [04-service-selector.md](https://github.com/kumbulanit/CKA/blob/main/04-networking/04-service-selector.md):

1. Write and apply **demo-deployment.yaml**: a Deployment **nginx-deployment** with 3 replicas of
   `nginx:1.27`, label `app: nginx`, containerPort 80.
2. Write and apply **service-selector.yaml**: a Service **kplabs-service-selector** that selects
   `app: nginx`, port 80 → 80. Describe it and count its endpoints.
3. Scale the deployment to **10** replicas and describe the service again.
4. Create a pod **manual-pod** from `nginx`, label it `app=nginx`, and see it join the endpoints.
5. Delete the service, the deployment and manual-pod.

### Step by step

**Step 1.** Writes the file `demo-deployment.yaml`.

```bash
cat > demo-deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.27
        ports:
        - containerPort: 80
EOF
```

It prints nothing when it works.

**Step 2.** Creates the objects in `demo-deployment.yaml`, or updates them if they exist.

```bash
kubectl apply -f demo-deployment.yaml
```

You should see something like:

```text
deployment.apps/nginx-deployment created
```

**Step 3.** Writes the file `service-selector.yaml`.

```bash
cat > service-selector.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
   name: kplabs-service-selector
spec:
   selector:
     app: nginx
   ports:
   - port: 80
     targetPort: 80
EOF
```

It prints nothing when it works.

**Step 4.** Creates the objects in `service-selector.yaml`, or updates them if they exist.

```bash
kubectl apply -f service-selector.yaml
```

You should see something like:

```text
service/kplabs-service-selector created
```

**Step 5.** Waits until the rollout of the Deployment `nginx-deployment` has finished.

```bash
kubectl rollout status deployment/nginx-deployment --timeout=180s
```

You should see something like:

```text
Waiting for deployment "nginx-deployment" rollout to finish: 0 of 3 updated replicas are available...
Waiting for deployment "nginx-deployment" rollout to finish: 1 of 3 updated replicas are available...
Waiting for deployment "nginx-deployment" rollout to finish: 2 of 3 updated replicas are available...
deployment "nginx-deployment" successfully rolled out
```

**Step 6.** Shows the details of the Service `kplabs-service-selector`, with its recent events at the bottom.

```bash
kubectl describe service kplabs-service-selector
```

You should see something like:

```text
Name:                     kplabs-service-selector
Namespace:                default
Labels:                   <none>
Annotations:              <none>
Selector:                 app=nginx
Type:                     ClusterIP
IP Family Policy:         SingleStack
IP Families:              IPv4
IP:                       10.96.29.12
IPs:                      10.96.29.12
Port:                     <unset>  80/TCP
TargetPort:               80/TCP
Endpoints:                10.244.1.4:80,10.244.2.3:80,10.244.2.4:80
Session Affinity:         None
Internal Traffic Policy:  Cluster
Events:                   <none>
```

**Step 7.** Sets the Deployment `nginx-deployment` to 10 replicas.

```bash
kubectl scale deployment/nginx-deployment --replicas=10
```

You should see something like:

```text
deployment.apps/nginx-deployment scaled
```

**Step 8.** Waits until the rollout of the Deployment `nginx-deployment` has finished.

```bash
kubectl rollout status deployment/nginx-deployment --timeout=180s
```

You should see something like:

```text
Waiting for deployment "nginx-deployment" rollout to finish: 3 out of 10 new replicas have been updated...
Waiting for deployment "nginx-deployment" rollout to finish: 3 of 10 updated replicas are available...
Waiting for deployment "nginx-deployment" rollout to finish: 4 of 10 updated replicas are available...
Waiting for deployment "nginx-deployment" rollout to finish: 5 of 10 updated replicas are available...
Waiting for deployment "nginx-deployment" rollout to finish: 6 of 10 updated replicas are available...
Waiting for deployment "nginx-deployment" rollout to finish: 7 of 10 updated replicas are available...
Waiting for deployment "nginx-deployment" rollout to finish: 8 of 10 updated replicas are available...
Waiting for deployment "nginx-deployment" rollout to finish: 9 of 10 updated replicas are available...
deployment "nginx-deployment" successfully rolled out
```

**Step 9.** Shows the details of the Service `kplabs-service-selector`, with its recent events at the bottom.

```bash
kubectl describe service kplabs-service-selector
```

You should see something like:

```text
Name:                     kplabs-service-selector
Namespace:                default
Labels:                   <none>
Annotations:              <none>
Selector:                 app=nginx
Type:                     ClusterIP
IP Family Policy:         SingleStack
IP Families:              IPv4
IP:                       10.96.29.12
IPs:                      10.96.29.12
Port:                     <unset>  80/TCP
TargetPort:               80/TCP
Endpoints:                10.244.1.4:80,10.244.2.3:80,10.244.2.4:80 + 7 more...
Session Affinity:         None
Internal Traffic Policy:  Cluster
Events:                   <none>
```

**Step 10.** Starts the pod `manual-pod` from the image `nginx`.

```bash
kubectl run manual-pod --image=nginx
```

You should see something like:

```text
pod/manual-pod created
```

**Step 11.** Adds the label `app=nginx` to the pods `manual-pod`, `app=nginx`.

```bash
kubectl label pods manual-pod app=nginx
```

You should see something like:

```text
pod/manual-pod labeled
```

**Step 12.** Waits until the pod `manual-pod` is Ready.

```bash
kubectl wait --for=condition=Ready pod/manual-pod --timeout=120s
```

You should see something like:

```text
pod/manual-pod condition met
```

**Step 13.** Shows the details of the Service `kplabs-service-selector`, with its recent events at the bottom.

```bash
kubectl describe service kplabs-service-selector
```

You should see something like:

```text
Name:                     kplabs-service-selector
Namespace:                default
Labels:                   <none>
Annotations:              <none>
Selector:                 app=nginx
Type:                     ClusterIP
IP Family Policy:         SingleStack
IP Families:              IPv4
IP:                       10.96.29.12
IPs:                      10.96.29.12
Port:                     <unset>  80/TCP
TargetPort:               80/TCP
Endpoints:                10.244.1.4:80,10.244.2.3:80,10.244.2.4:80 + 8 more...
Session Affinity:         None
Internal Traffic Policy:  Cluster
Events:                   <none>
```

**Step 14.** Shows the details of the Endpoints `kplabs-service-selector`, with its recent events at the bottom.

```bash
kubectl describe endpoints kplabs-service-selector
```

You should see something like:

```text
Warning: v1 Endpoints is deprecated in v1.33+; use discovery.k8s.io/v1 EndpointSlice
Name:         kplabs-service-selector
Namespace:    default
Labels:       endpoints.kubernetes.io/managed-by=endpoint-controller
Annotations:  endpoints.kubernetes.io/last-change-trigger-time: 2026-10-27T23:12:36Z
Subsets:
  Addresses:          10.244.1.4,10.244.1.5,10.244.1.6,10.244.1.7,10.244.1.8,10.244.2.3,10.244.2.4,10.244.2.5,10.244.2.6,10.244.2.7,10.244.2.8
  NotReadyAddresses:  <none>
  Ports:
    Name     Port  Protocol
    ----     ----  --------
    <unset>  80    TCP

Events:  <none>
```

**Step 15.** Deletes the Service `kplabs-service-selector`.

```bash
kubectl delete service kplabs-service-selector
```

You should see something like:

```text
service "kplabs-service-selector" deleted from default namespace
```

**Step 16.** Deletes the objects in `demo-deployment.yaml`.

```bash
kubectl delete -f demo-deployment.yaml
```

You should see something like:

```text
deployment.apps "nginx-deployment" deleted from default namespace
```

**Step 17.** Deletes the pod `manual-pod`.

```bash
kubectl delete pod manual-pod
```

You should see something like:

```text
pod "manual-pod" deleted from default namespace
```

### If you see something else

- The check says: _/root/service-selector.yaml is missing, or is not the Service kplabs-service-selector selecting app=nginx._
- The check says: _nginx-deployment has not been scaled to 10 replicas yet._
- The check says: _manual-pod has not run yet._
- The check says: _The service, the deployment or manual-pod is still there. The last step deletes them._
- `kubectl describe service kplabs-service-selector` lists the Endpoints: one IP per matching ready pod.
- `kubectl label pods manual-pod app=nginx` makes the pod match the selector, so it gets traffic too.

### Why it works

**Why it works.** The Service's selector `app: nginx` is evaluated continuously: every ready pod with that label becomes an endpoint. Scaling to 10 adds 7 endpoints, and labelling manual-pod `app=nginx` adds an 11th, even though no Deployment owns it. Traffic to the Service is spread across all of them.

**In the exam:** a Service with no endpoints almost always means its selector does not match the pods' labels; compare `kubectl describe svc` with `kubectl get pods --show-labels`.

---

## Lab 4.3: NodePort

### What you will do

Follow [05-nodeport.md](https://github.com/kumbulanit/CKA/blob/main/04-networking/05-nodeport.md):

1. Create a pod **nodeport-pod** from `nginx` with the label `type=publicpod`.
2. Write and apply **nodeport.yaml**: a Service **kplabs-nodeport** of type NodePort that selects
   `type: publicpod`, port 80 → 80.
3. Find the node port with `kubectl get service`, and the worker IPs with `kubectl get nodes -o wide`.
   Instead of a browser, use `curl http://minikube-m02:<NODEPORT>`.
4. Delete the pod and the service.

### Step by step

**Step 1.** Starts the pod `nodeport-pod` from the image `nginx`.

```bash
kubectl run nodeport-pod --labels="type=publicpod" --image=nginx
```

You should see something like:

```text
pod/nodeport-pod created
```

**Step 2.** Lists the pods with their labels.

```bash
kubectl get pods --show-labels
```

You should see something like:

```text
NAME            READY   STATUS              RESTARTS   AGE    LABELS
backend-pod-1   1/1     Running             0          102s   run=backend-pod-1
backend-pod-2   1/1     Running             0          102s   run=backend-pod-2
frontend-pod    1/1     Running             0          102s   run=frontend-pod
nodeport-pod    0/1     ContainerCreating   0          0s     type=publicpod
```

**Step 3.** Writes the file `nodeport.yaml`.

```bash
cat > nodeport.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
   name: kplabs-nodeport
spec:
   selector:
     type: publicpod
   type: NodePort
   ports:
   - port: 80
     targetPort: 80
EOF
```

It prints nothing when it works.

**Step 4.** Creates the objects in `nodeport.yaml`, or updates them if they exist.

```bash
kubectl apply -f nodeport.yaml
```

You should see something like:

```text
service/kplabs-nodeport created
```

**Step 5.** Lists the Services.

```bash
kubectl get service
```

You should see something like:

```text
NAME              TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
kplabs-nodeport   NodePort    10.96.21.142    <none>        80:30985/TCP   0s
kplabs-service    ClusterIP   10.96.187.132   <none>        8080/TCP       39s
kubernetes        ClusterIP   10.96.0.1       <none>        443/TCP        2m17s
```

**Step 6.** Lists the nodes, with IP addresses and versions.

```bash
kubectl get nodes -o wide
```

You should see something like:

```text
NAME           STATUS   ROLES           AGE     VERSION   INTERNAL-IP     EXTERNAL-IP   OS-IMAGE                       KERNEL-VERSION                               CONTAINER-RUNTIME
minikube       Ready    control-plane   2m19s   v1.36.4   192.168.147.4   <none>        Debian GNU/Linux 13 (trixie)   7.2.9-orbstack-00391-g2b298d05fbd4 (arm64)   containerd://2.3.4
minikube-m02   Ready    <none>          2m8s    v1.36.4   192.168.147.3   <none>        Debian GNU/Linux 13 (trixie)   7.2.9-orbstack-00391-g2b298d05fbd4 (arm64)   containerd://2.3.4
minikube-m03   Ready    <none>          2m8s    v1.36.4   192.168.147.2   <none>        Debian GNU/Linux 13 (trixie)   7.2.9-orbstack-00391-g2b298d05fbd4 (arm64)   containerd://2.3.4
```

**Step 7.** Waits until the pod `nodeport-pod` is Ready.

```bash
kubectl wait --for=condition=Ready pod/nodeport-pod --timeout=120s
```

You should see something like:

```text
pod/nodeport-pod condition met
```

**Step 8.** Sends an HTTP request to `http://minikube-m02:…` and prints the answer.

```bash
curl -s http://minikube-m02:$(kubectl get svc kplabs-nodeport -o jsonpath='{.spec.ports[0].nodePort}') | head -4
```

You should see something like:

```text
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
```

**Step 9.** Deletes the pod `nodeport-pod`.

```bash
kubectl delete pod nodeport-pod
```

You should see something like:

```text
pod "nodeport-pod" deleted from default namespace
```

**Step 10.** Deletes the objects in `nodeport.yaml`.

```bash
kubectl delete -f nodeport.yaml
```

You should see something like:

```text
service "kplabs-nodeport" deleted from default namespace
```

### If you see something else

- The check says: _/root/nodeport.yaml is missing, or is not a NodePort Service selecting type=publicpod._
- The check says: _nodeport-pod has not run yet._
- The check says: _nodeport-pod or kplabs-nodeport is still there. The last step deletes them._
- `kubectl get service kplabs-nodeport` shows `80:3XXXX/TCP`; the second number is the node port, open on every node.
- `curl http://minikube-m02:<NODEPORT>` and `curl http://minikube-m03:<NODEPORT>` both reach the pod.

### Why it works

**Why it works.** A NodePort Service is a ClusterIP Service plus a port (30000–32767 by default) opened on every node. kube-proxy forwards traffic arriving at `<any node>:<nodePort>` to the Service's pods, wherever they run.

**In practice:** NodePort is the simplest way to reach a Service from outside the cluster; you set a fixed port with `nodePort:` under `ports`.

---

## Lab 4.4: LoadBalancer

### What you will do

Follow [06-loadbalancer.md](https://github.com/kumbulanit/CKA/blob/main/04-networking/06-loadbalancer.md):

1. Create a pod **lb-pod** from `nginx` with the label `type=loadbalanced`.
2. Write and apply **elb-service.yaml**: a Service **kplabs-loadbalancer** of type LoadBalancer that
   selects `type: loadbalanced`, port 80.
3. Describe it and get it: `EXTERNAL-IP` stays `<pending>` because nothing here provides load
   balancers. Curl its node port on minikube-m02 instead.
4. Delete the pod and the service.

### Step by step

**Step 1.** Starts the pod `lb-pod` from the image `nginx`.

```bash
kubectl run lb-pod --labels="type=loadbalanced" --image=nginx
```

You should see something like:

```text
pod/lb-pod created
```

**Step 2.** Lists the pods with their labels.

```bash
kubectl get pods --show-labels
```

You should see something like:

```text
NAME            READY   STATUS              RESTARTS   AGE    LABELS
backend-pod-1   1/1     Running             0          108s   run=backend-pod-1
backend-pod-2   1/1     Running             0          108s   run=backend-pod-2
frontend-pod    1/1     Running             0          108s   run=frontend-pod
lb-pod          0/1     ContainerCreating   0          0s     type=loadbalanced
```

**Step 3.** Writes the file `elb-service.yaml`.

```bash
cat > elb-service.yaml <<'EOF'
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
EOF
```

It prints nothing when it works.

**Step 4.** Creates the objects in `elb-service.yaml`, or updates them if they exist.

```bash
kubectl apply -f elb-service.yaml
```

You should see something like:

```text
service/kplabs-loadbalancer created
```

**Step 5.** Shows the details of the Service `kplabs-loadbalancer`, with its recent events at the bottom.

```bash
kubectl describe service kplabs-loadbalancer
```

You should see something like:

```text
Name:                     kplabs-loadbalancer
Namespace:                default
Labels:                   <none>
Annotations:              <none>
Selector:                 type=loadbalanced
Type:                     LoadBalancer
IP Family Policy:         SingleStack
IP Families:              IPv4
IP:                       10.96.38.128
IPs:                      10.96.38.128
Port:                     <unset>  80/TCP
TargetPort:               80/TCP
NodePort:                 <unset>  30621/TCP
Endpoints:                
Session Affinity:         None
External Traffic Policy:  Cluster
Internal Traffic Policy:  Cluster
Events:                   <none>
```

**Step 6.** Lists the Service `kplabs-loadbalancer`.

```bash
kubectl get service kplabs-loadbalancer
```

You should see something like:

```text
NAME                  TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)        AGE
kplabs-loadbalancer   LoadBalancer   10.96.38.128   <pending>     80:30621/TCP   0s
```

**Step 7.** Waits until the pod `lb-pod` is Ready.

```bash
kubectl wait --for=condition=Ready pod/lb-pod --timeout=120s
```

You should see something like:

```text
pod/lb-pod condition met
```

**Step 8.** Sends an HTTP request to `http://minikube-m02:…` and prints the answer.

```bash
curl -s http://minikube-m02:$(kubectl get svc kplabs-loadbalancer -o jsonpath='{.spec.ports[0].nodePort}') | head -4
```

You should see something like:

```text
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
```

**Step 9.** Deletes the pod `lb-pod`.

```bash
kubectl delete pod lb-pod
```

You should see something like:

```text
pod "lb-pod" deleted from default namespace
```

**Step 10.** Deletes the objects in `elb-service.yaml`.

```bash
kubectl delete -f elb-service.yaml
```

You should see something like:

```text
service "kplabs-loadbalancer" deleted from default namespace
```

### If you see something else

- The check says: _/root/elb-service.yaml is missing, or is not a LoadBalancer Service selecting type=loadbalanced._
- The check says: _lb-pod has not run yet._
- The check says: _lb-pod or kplabs-loadbalancer is still there. The last step deletes them._
- A LoadBalancer Service is a NodePort Service plus a request to the cloud for an external load balancer.
- `kubectl get service kplabs-loadbalancer` shows the node port after `80:`.

### Why it works

**Why it works.** A LoadBalancer Service is a NodePort Service that also asks a cloud controller to create an external load balancer pointing at the node ports. On a cloud cluster `EXTERNAL-IP` gets filled in. On kubeadm (and here) nothing answers the request, so it stays `<pending>`, but the node port works as usual.

**In practice:** on your own machines, add-ons such as MetalLB provide LoadBalancer IPs.

---

## Lab 4.5: Service manifests from the command line

### What you will do

Follow [07-service-manifest-cli.md](https://github.com/kumbulanit/CKA/blob/main/04-networking/07-service-manifest-cli.md):

1. Create a pod **nginx** from `nginx`, and apply **service-deployment.yaml**: a Deployment
   **kplabs-deployment** with 3 replicas, label `tier: frontend`, container `nginx` from `nginx`.
2. With `kubectl expose ... --dry-run=client -o yaml`, save a Service **nginx-service** for the pod
   (port 80 → 80) to **service-01.yaml**, apply it and describe it.
3. Print a NodePort version, then create **nginx-nodeport-service** with `kubectl expose`.
4. Expose the deployment as **nginx-deployment-service** and describe it.
5. Delete the pod, the deployment and the three services.

### Step by step

**Step 1.** Starts the pod `nginx` from the image `nginx`.

```bash
kubectl run nginx --image=nginx
```

You should see something like:

```text
pod/nginx created
```

**Step 2.** Writes the file `service-deployment.yaml`.

```bash
cat > service-deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kplabs-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      tier: frontend
  template:
    metadata:
      labels:
        tier: frontend
    spec:
      containers:
      - name: nginx
        image: nginx
EOF
```

It prints nothing when it works.

**Step 3.** Creates the objects in `service-deployment.yaml`, or updates them if they exist.

```bash
kubectl apply -f service-deployment.yaml
```

You should see something like:

```text
deployment.apps/kplabs-deployment created
```

**Step 4.** Creates a Service in front of the pod `nginx` on port 80.

```bash
kubectl expose pod nginx --name nginx-service --port=80 --target-port=80 --dry-run=client -o yaml
```

You should see something like:

```text
apiVersion: v1
kind: Service
metadata:
  labels:
    run: nginx
  name: nginx-service
spec:
  ports:
  - port: 80
    protocol: TCP
    targetPort: 80
  selector:
    run: nginx
status:
  loadBalancer: {}
```

**Step 5.** Creates a Service in front of the pod `nginx` on port 80.

```bash
kubectl expose pod nginx --name nginx-service --port=80 --target-port=80 --dry-run=client -o yaml > service-01.yaml
```

It prints nothing when it works.

**Step 6.** Creates the objects in `service-01.yaml`, or updates them if they exist.

```bash
kubectl apply -f service-01.yaml
```

You should see something like:

```text
service/nginx-service created
```

**Step 7.** Shows the details of the Service `nginx-service`, with its recent events at the bottom.

```bash
kubectl describe service nginx-service
```

You should see something like:

```text
Name:                     nginx-service
Namespace:                default
Labels:                   run=nginx
Annotations:              <none>
Selector:                 run=nginx
Type:                     ClusterIP
IP Family Policy:         SingleStack
IP Families:              IPv4
IP:                       10.96.227.212
IPs:                      10.96.227.212
Port:                     <unset>  80/TCP
TargetPort:               80/TCP
Endpoints:                
Session Affinity:         None
Internal Traffic Policy:  Cluster
Events:                   <none>
```

**Step 8.** Creates a Service in front of the pod `nginx` on port 80 (type NodePort).

```bash
kubectl expose pod nginx --name nginx-nodeport-service --port=80 --target-port=80 --type=NodePort --dry-run=client -o yaml
```

You should see something like:

```text
apiVersion: v1
kind: Service
metadata:
  labels:
    run: nginx
  name: nginx-nodeport-service
spec:
  ports:
  - port: 80
    protocol: TCP
    targetPort: 80
  selector:
    run: nginx
  type: NodePort
status:
  loadBalancer: {}
```

**Step 9.** Creates a Service in front of the pod `nginx` on port 80 (type NodePort).

```bash
kubectl expose pod nginx --name nginx-nodeport-service --port=80 --target-port=80 --type=NodePort
```

You should see something like:

```text
service/nginx-nodeport-service exposed
```

**Step 10.** Lists the Services.

```bash
kubectl get service
```

You should see something like:

```text
NAME                     TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
kplabs-service           ClusterIP   10.96.187.132   <none>        8080/TCP       51s
kubernetes               ClusterIP   10.96.0.1       <none>        443/TCP        2m29s
nginx-nodeport-service   NodePort    10.96.124.141   <none>        80:31509/TCP   0s
nginx-service            ClusterIP   10.96.227.212   <none>        80/TCP         0s
```

**Step 11.** Creates a Service in front of the Deployment `kplabs-deployment` on port 80.

```bash
kubectl expose deployment kplabs-deployment --name nginx-deployment-service --port=80 --target-port=80
```

You should see something like:

```text
service/nginx-deployment-service exposed
```

**Step 12.** Waits until the rollout of the Deployment `kplabs-deployment` has finished.

```bash
kubectl rollout status deployment/kplabs-deployment --timeout=180s
```

You should see something like:

```text
Waiting for deployment "kplabs-deployment" rollout to finish: 0 of 3 updated replicas are available...
Waiting for deployment "kplabs-deployment" rollout to finish: 1 of 3 updated replicas are available...
Waiting for deployment "kplabs-deployment" rollout to finish: 2 of 3 updated replicas are available...
deployment "kplabs-deployment" successfully rolled out
```

**Step 13.** Shows the details of the Service `nginx-deployment-service`, with its recent events at the bottom.

```bash
kubectl describe service nginx-deployment-service
```

You should see something like:

```text
Name:                     nginx-deployment-service
Namespace:                default
Labels:                   <none>
Annotations:              <none>
Selector:                 tier=frontend
Type:                     ClusterIP
IP Family Policy:         SingleStack
IP Families:              IPv4
IP:                       10.96.200.246
IPs:                      10.96.200.246
Port:                     <unset>  80/TCP
TargetPort:               80/TCP
Endpoints:                10.244.1.9:80,10.244.1.10:80,10.244.2.12:80
Session Affinity:         None
Internal Traffic Policy:  Cluster
Events:                   <none>
```

**Step 14.** Deletes the pod `nginx`.

```bash
kubectl delete pod nginx
```

You should see something like:

```text
pod "nginx" deleted from default namespace
```

**Step 15.** Deletes the Deployment `kplabs-deployment`.

```bash
kubectl delete deployment kplabs-deployment
```

You should see something like:

```text
deployment.apps "kplabs-deployment" deleted from default namespace
```

**Step 16.** Deletes the Service `nginx-service`.

```bash
kubectl delete service nginx-service
```

You should see something like:

```text
service "nginx-service" deleted from default namespace
```

**Step 17.** Deletes the Service `nginx-nodeport-service`.

```bash
kubectl delete service nginx-nodeport-service
```

You should see something like:

```text
service "nginx-nodeport-service" deleted from default namespace
```

**Step 18.** Deletes the Service `nginx-deployment-service`.

```bash
kubectl delete service nginx-deployment-service
```

You should see something like:

```text
service "nginx-deployment-service" deleted from default namespace
```

### If you see something else

- The check says: _/root/service-01.yaml is missing, or is not the Service nginx-service._
- The check says: _kplabs-deployment has not run with 3 replicas yet._
- The check says: _Some of the objects are still there. The last step deletes them._
- `kubectl expose pod nginx --name nginx-service --port=80 --target-port=80 --dry-run=client -o yaml > service-01.yaml` writes the manifest.
- `kubectl expose` copies the selector from the pod's labels or the deployment's selector, so you never type it.
- `kubectl expose ... --dry-run=client -o yaml` is the quickest way to write a Service manifest. Try step 2.

### Why it works

**Why it works.** `kubectl expose` builds a Service from an existing object: it copies the pod's labels or the Deployment's selector as the Service selector. With `--dry-run=client -o yaml` it only prints the manifest, so you can save and edit it.

**In the exam:** `kubectl expose` is much faster than writing a Service by hand, and it never gets the selector wrong.

---

## Lab 4.6: Named ports

### What you will do

Follow [08-named-port.md](https://github.com/kumbulanit/CKA/blob/main/04-networking/08-named-port.md):

1. Create a pod **nginx** from `nginx` with port 80, expose it as the NodePort Service **first-svc**
   (port 80 → targetPort 80), look at its YAML and curl it on minikube-m02.
2. Save a pod **nginx2** (`nginx`, port 80) to **pod_named.yaml** with `--dry-run=client -o yaml`, name
   its port **custom-http**, and apply it.
3. Expose nginx2 as the NodePort Service **named-svc** with `--target-port=custom-http`, and curl it
   on minikube-m02. Leave everything running.

### Step by step

**Step 1.** Starts the pod `nginx` from the image `nginx`.

```bash
kubectl run nginx --image=nginx --port=80
```

You should see something like:

```text
pod/nginx created
```

**Step 2.** Creates a Service in front of the pod `nginx` on port 80 (type NodePort).

```bash
kubectl expose pod nginx --name first-svc --port=80 --target-port=80 --type=NodePort
```

You should see something like:

```text
service/first-svc exposed
```

**Step 3.** Lists the Services.

```bash
kubectl get svc
```

You should see something like:

```text
NAME             TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
first-svc        NodePort    10.96.155.141   <none>        80:31755/TCP   1s
kplabs-service   ClusterIP   10.96.187.132   <none>        8080/TCP       57s
kubernetes       ClusterIP   10.96.0.1       <none>        443/TCP        2m35s
```

**Step 4.** Shows the Service `first-svc` as YAML, as the API server stores it.

```bash
kubectl get svc first-svc -o yaml
```

You should see something like:

```text
apiVersion: v1
kind: Service
metadata:
  creationTimestamp: "2026-10-27T23:12:57Z"
  labels:
    run: nginx
  name: first-svc
  namespace: default
  resourceVersion: "1377"
  uid: 86fc9ae3-b552-432f-a756-ef40483f19fd
spec:
  clusterIP: 10.96.155.141
  clusterIPs:
  - 10.96.155.141
  externalTrafficPolicy: Cluster
  internalTrafficPolicy: Cluster
  ipFamilies:
  - IPv4
… (12 more lines)
```

**Step 5.** Lists the nodes, with IP addresses and versions.

```bash
kubectl get nodes -o wide
```

You should see something like:

```text
NAME           STATUS   ROLES           AGE     VERSION   INTERNAL-IP     EXTERNAL-IP   OS-IMAGE                       KERNEL-VERSION                               CONTAINER-RUNTIME
minikube       Ready    control-plane   2m37s   v1.36.4   192.168.147.4   <none>        Debian GNU/Linux 13 (trixie)   7.2.9-orbstack-00391-g2b298d05fbd4 (arm64)   containerd://2.3.4
minikube-m02   Ready    <none>          2m26s   v1.36.4   192.168.147.3   <none>        Debian GNU/Linux 13 (trixie)   7.2.9-orbstack-00391-g2b298d05fbd4 (arm64)   containerd://2.3.4
minikube-m03   Ready    <none>          2m26s   v1.36.4   192.168.147.2   <none>        Debian GNU/Linux 13 (trixie)   7.2.9-orbstack-00391-g2b298d05fbd4 (arm64)   containerd://2.3.4
```

**Step 6.** Waits until the pod `nginx` is Ready.

```bash
kubectl wait --for=condition=Ready pod/nginx --timeout=120s
```

You should see something like:

```text
pod/nginx condition met
```

**Step 7.** Sends an HTTP request to `http://minikube-m02:…` and prints the answer.

```bash
curl -s http://minikube-m02:$(kubectl get svc first-svc -o jsonpath='{.spec.ports[0].nodePort}') | head -4
```

You should see something like:

```text
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
```

**Step 8.** Writes the manifest of the pod `nginx2` without creating it.

```bash
kubectl run nginx2 --image=nginx --port=80 --dry-run=client -o yaml > pod_named.yaml
```

It prints nothing when it works.

**Step 9.** Edits `pod_named.yaml`: `- containerPort: 80` becomes `- containerPort: 80       name: custom-http`. The edit: name the port.

```bash
sed -i 's/^    - containerPort: 80$/    - containerPort: 80\n      name: custom-http/' pod_named.yaml
```

It prints nothing when it works.

**Step 10.** Creates the objects in `pod_named.yaml`, or updates them if they exist.

```bash
kubectl apply -f pod_named.yaml
```

You should see something like:

```text
pod/nginx2 created
```

**Step 11.** Creates a Service in front of the pod `nginx2` on port 80 (type NodePort).

```bash
kubectl expose pod nginx2 --name named-svc --port=80 --target-port=custom-http --type=NodePort
```

You should see something like:

```text
service/named-svc exposed
```

**Step 12.** Lists the Services.

```bash
kubectl get svc
```

You should see something like:

```text
NAME             TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
first-svc        NodePort    10.96.155.141   <none>        80:31755/TCP   3s
kplabs-service   ClusterIP   10.96.187.132   <none>        8080/TCP       59s
kubernetes       ClusterIP   10.96.0.1       <none>        443/TCP        2m37s
named-svc        NodePort    10.96.209.105   <none>        80:31027/TCP   0s
```

**Step 13.** Waits until the pod `nginx2` is Ready.

```bash
kubectl wait --for=condition=Ready pod/nginx2 --timeout=120s
```

You should see something like:

```text
pod/nginx2 condition met
```

**Step 14.** Sends an HTTP request to `http://minikube-m02:…` and prints the answer.

```bash
curl -s http://minikube-m02:$(kubectl get svc named-svc -o jsonpath='{.spec.ports[0].nodePort}') | head -4
```

You should see something like:

```text
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
```

### If you see something else

- The check says: _There is no NodePort Service first-svc with targetPort 80._
- The check says: _The pod nginx2 (from pod_named.yaml) does not name its port custom-http._
- The check says: _There is no NodePort Service named-svc with targetPort custom-http._
- The check says: _named-svc does not answer on its node port on minikube-m02. Is nginx2 running?_
- `kubectl expose pod nginx --name first-svc --port=80 --target-port=80 --type=NodePort` creates the first Service.
- In pod_named.yaml, add `name: custom-http` under `- containerPort: 80`, at the same indentation.

### Why it works

**Why it works.** `targetPort` can be a number or the name of a container port. With `--target-port=custom-http`, the Service looks up which port each pod calls `custom-http`. If a new version of the pod moves to port 8080 but keeps the name, the Service needs no change.

**In the exam:** a named targetPort that matches no port name in the pod leaves the Service with no working endpoints.

---

## Lab 4.7: Namespaces

### What you will do

Follow [09-namespaces.md](https://github.com/kumbulanit/CKA/blob/main/04-networking/09-namespaces.md):

1. List the namespaces, and the pods in `kube-system`.
2. Create the namespace **teama**.
3. Create a pod **nginx** from `nginx` in teama and list the pods there. Leave it running.

### Step by step

**Step 1.** Lists the namespaces.

```bash
kubectl get namespace
```

You should see something like:

```text
NAME                 STATUS   AGE
default              Active   2m42s
kube-node-lease      Active   2m42s
kube-public          Active   2m42s
kube-system          Active   2m42s
local-path-storage   Active   2m38s
```

**Step 2.** Lists the pods in the namespace `kube-system`.

```bash
kubectl get pods -n kube-system
```

You should see something like:

```text
NAME                               READY   STATUS    RESTARTS   AGE
coredns-589f44dc88-v29q7           1/1     Running   0          2m32s
coredns-589f44dc88-x6nbd           1/1     Running   0          2m32s
etcd-minikube                      1/1     Running   0          2m41s
kindnet-v4qvn                      1/1     Running   0          2m19s
kindnet-vvprk                      1/1     Running   0          2m17s
kindnet-w4mxf                      1/1     Running   0          2m18s
kube-apiserver-minikube            1/1     Running   0          2m41s
kube-controller-manager-minikube   1/1     Running   0          2m41s
kube-proxy-nwcfq                   1/1     Running   0          2m32s
kube-proxy-pkg5q                   1/1     Running   0          2m31s
kube-proxy-tr6fd                   1/1     Running   0          2m31s
kube-scheduler-minikube            1/1     Running   0          2m41s
```

**Step 3.** Creates the namespace `teama`.

```bash
kubectl create namespace teama
```

You should see something like:

```text
namespace/teama created
```

**Step 4.** Lists the namespaces.

```bash
kubectl get namespace
```

You should see something like:

```text
NAME                 STATUS   AGE
default              Active   2m42s
kube-node-lease      Active   2m42s
kube-public          Active   2m42s
kube-system          Active   2m42s
local-path-storage   Active   2m38s
teama                Active   0s
```

**Step 5.** Starts the pod `nginx` from the image `nginx` in the namespace `teama`.

```bash
kubectl run nginx --image=nginx --namespace teama
```

You should see something like:

```text
pod/nginx created
```

**Step 6.** Lists the pods in the namespace `teama`.

```bash
kubectl get pods --namespace teama
```

You should see something like:

```text
NAME    READY   STATUS              RESTARTS   AGE
nginx   0/1     ContainerCreating   0          0s
```

### If you see something else

- The check says: _There is no namespace called teama._
- The check says: _There is no running pod nginx in the namespace teama._
- `kubectl create namespace teama` creates it.
- `--namespace teama` (or `-n teama`) works on every kubectl command, including `kubectl run`.

### Why it works

**Why it works.** A namespace is a scope for names: the pod `nginx` in teama is a different object from a pod `nginx` in default. Most objects are namespaced (pods, Services, Deployments); some are cluster-wide (nodes, namespaces, PersistentVolumes). `kubectl api-resources --namespaced=false` lists the cluster-wide ones.

**In the exam:** every question names its namespace; forgetting `-n` is a common way to lose marks.

---

## Lab 4.8: Installing Helm

### What you will do

Follow [10-install-helm.md](https://github.com/kumbulanit/CKA/blob/main/04-networking/10-install-helm.md)
on minikube: add Helm's apt repository with its signing key, install the `helm` package, and
check it with `helm version`.

### Step by step

**Step 1.** Installs `curl`, `gpg`, `apt-transport-https`.

```bash
sudo apt-get install curl gpg apt-transport-https --yes
```

You should see something like:

```text
Reading package lists...
Building dependency tree...
Reading state information...
curl is already the newest version (8.14.1-2+deb13u7).
The following additional packages will be installed:
  dirmngr gnupg gnupg-l10n gnupg-utils gpg-agent gpg-wks-client gpgconf gpgsm
  gpgv libassuan9 libgcrypt20 libgpg-error-l10n libgpg-error0 libksba8
  libnpth0t64 libreadline8t64 pinentry-curses readline-common
Suggested packages:
  dbus-user-session libpam-systemd pinentry-gnome3 tor gpg-wks-server
  parcimonie xloadimage scdaemon tpm2daemon rng-tools pinentry-doc
  readline-doc
The following NEW packages will be installed:
  apt-transport-https dirmngr gnupg gnupg-l10n gnupg-utils gpg gpg-agent
  gpg-wks-client gpgconf gpgsm gpgv libassuan9 libgcrypt20 libgpg-error-l10n
  libgpg-error0 libksba8 libnpth0t64 libreadline8t64 pinentry-curses
  readline-common
0 upgraded, 20 newly installed, 0 to remove and 23 not upgraded.
… (124 more lines)
```

**Step 2.** Writes the file `/usr/share/keyrings/helm.gpg`.

```bash
curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
```

It prints nothing when it works.

**Step 3.** Writes the file `/etc/apt/sources.list.d/helm-stable-debian.list`.

```bash
echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
```

You should see something like:

```text
deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main
```

**Step 4.** Refreshes the list of packages.

```bash
sudo apt-get update
```

You should see something like:

```text
Hit:1 http://deb.debian.org/debian trixie InRelease
Hit:2 http://deb.debian.org/debian trixie-updates InRelease
Hit:3 http://deb.debian.org/debian-security trixie-security InRelease
Get:4 https://packages.buildkite.com/helm-linux/helm-debian/any any InRelease [29.3 kB]
Get:5 https://packages.buildkite.com/helm-linux/helm-debian/any any/main arm64 Packages [3630 B]
Fetched 33.0 kB in 4s (8536 B/s)
Reading package lists...
```

**Step 5.** Installs `helm`.

```bash
sudo apt-get install helm
```

You should see something like:

```text
Reading package lists...
Building dependency tree...
Reading state information...
The following NEW packages will be installed:
  helm
0 upgraded, 1 newly installed, 0 to remove and 23 not upgraded.
Need to get 17.9 MB of archives.
After this operation, 61.2 MB of additional disk space will be used.
Get:1 https://packages.buildkite.com/helm-linux/helm-debian/any any/main arm64 helm arm64 4.3.0-1 [17.9 MB]
debconf: unable to initialize frontend: Dialog
debconf: (Dialog frontend will not work on a dumb terminal, an emacs shell buffer, or without a controlling terminal.)
debconf: falling back to frontend: Readline
debconf: unable to initialize frontend: Readline
debconf: (Can't locate Term/ReadLine.pm in @INC (you may need to install the Term::ReadLine module) (@INC entries checked: /etc/perl /usr/local/lib/aarch64-linux-gnu/perl/5.40.1 /usr/local/share/perl/5.40.1 /usr/lib/aarch64-linux-gnu/perl5/5.40 /usr/share/perl5 /usr/lib/aarch64-linux-gnu/perl-base /usr/lib/aarch64-linux-gnu/perl/5.40 /usr/share/perl/5.40 /usr/local/lib/site_perl) at /usr/share/perl5/Debconf/FrontEnd/Readline.pm line 8, <STDIN> line 1.)
debconf: falling back to frontend: Teletype
debconf: unable to initialize frontend: Teletype
debconf: (This frontend requires a controlling tty.)
debconf: falling back to frontend: Noninteractive
… (6 more lines)
```

**Step 6.** Prints the Helm version.

```bash
helm version
```

You should see something like:

```text
version.BuildInfo{Version:"v4.3.0", GitCommit:"bec5b06ed841fe5269972d864d5177944fd5970f", GitTreeState:"clean", GoVersion:"go1.27.1", KubeClientVersion:"v1.37"}
```

### If you see something else

- The check says: _The helm package is not installed. Add the apt repository and run `sudo apt-get install helm`._
- The check says: _`helm version` does not work._
- The repository line needs `signed-by=/usr/share/keyrings/helm.gpg`, the key file the `curl ... | gpg --dearmor` step writes.
- Run `sudo apt-get update` after adding the repository, then `sudo apt-get install helm`.

### Why it works

**Why it works.** Helm is a client-only tool: it renders charts into Kubernetes manifests and applies them with your kubeconfig. Installing it from its apt repository means `apt upgrade` keeps it current. The key added with `signed-by=` makes apt trust packages from that repository only.

**Note:** Helm's old `baltocdn.com` apt repository no longer serves packages; the repository now lives at packages.buildkite.com.

---

## Lab 4.9: Your first Helm charts

### What you will do

Follow [11-first-helm-chart.md](https://github.com/kumbulanit/CKA/blob/main/04-networking/11-first-helm-chart.md):

1. Add the `jenkins` repository (https://charts.jenkins.io), install the chart `jenkins/jenkins` as
   the release **my-jenkins**, list the releases, and uninstall it.
2. Add the `grafana` repository (https://grafana.github.io/helm-charts), install `grafana/grafana` as
   **my-release**, look at `helm list`, `helm status` and `helm get values`, and uninstall it.

### Step by step

**Step 1.** Adds a chart repository.

```bash
helm repo add jenkins https://charts.jenkins.io
```

You should see something like:

```text
"jenkins" has been added to your repositories
```

**Step 2.** Downloads the latest chart lists.

```bash
helm repo update
```

You should see something like:

```text
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "jenkins" chart repository
Update Complete. ⎈Happy Helming!⎈
```

**Step 3.** Installs the chart as the release `my-jenkins`.

```bash
helm install my-jenkins jenkins/jenkins
```

You should see something like:

```text
NAME: my-jenkins
LAST DEPLOYED: Tue Oct 27 23:13:29 2026
NAMESPACE: default
STATUS: deployed
REVISION: 1
DESCRIPTION: Install complete
NOTES:
1. Get your 'admin' user password by running:
  kubectl exec --namespace default -it svc/my-jenkins -c jenkins -- /bin/cat /run/secrets/additional/chart-admin-password && echo
2. Get the Jenkins URL to visit by running these commands in the same shell:
  echo http://127.0.0.1:8080
  kubectl --namespace default port-forward svc/my-jenkins 8080:8080

3. Login with the password from step 1 and the username: admin
4. Configure security realm and authorization strategy
5. Use Jenkins Configuration as Code by specifying configScripts in your values.yaml file, see documentation: http://127.0.0.1:8080/configuration-as-code and examples: https://github.com/jenkinsci/configuration-as-code-plugin/tree/master/demos

For more information on running Jenkins on Kubernetes, visit:
… (7 more lines)
```

**Step 4.** Lists the installed releases.

```bash
helm list
```

You should see something like:

```text
NAME          NAMESPACE    REVISION    UPDATED                                    STATUS      CHART             APP VERSION
my-jenkins    default      1           2026-10-27 23:13:29.563296417 +0000 UTC    deployed    jenkins-5.10.0    2.580.1
```

**Step 5.** Removes the release `my-jenkins` and everything it created.

```bash
helm uninstall my-jenkins
```

You should see something like:

```text
release "my-jenkins" uninstalled
```

**Step 6.** Adds a chart repository.

```bash
helm repo add grafana https://grafana.github.io/helm-charts
```

You should see something like:

```text
"grafana" has been added to your repositories
```

**Step 7.** Downloads the latest chart lists.

```bash
helm repo update
```

You should see something like:

```text
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "grafana" chart repository
...Successfully got an update from the "jenkins" chart repository
Update Complete. ⎈Happy Helming!⎈
```

**Step 8.** Installs the chart as the release `my-release`.

```bash
helm install my-release grafana/grafana
```

You should see something like:

```text
level=WARN msg="this chart is deprecated"
NAME: my-release
LAST DEPLOYED: Tue Oct 27 23:13:34 2026
NAMESPACE: default
STATUS: deployed
REVISION: 1
DESCRIPTION: Install complete
NOTES:
1. Get your 'admin' user password by running:

   kubectl get secret --namespace default my-release-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo


2. The Grafana server can be accessed via port 80 on the following DNS name from within your cluster:

   my-release-grafana.default.svc.cluster.local

   Get the Grafana URL to visit by running these commands in the same shell:
… (8 more lines)
```

**Step 9.** Lists the installed releases.

```bash
helm list
```

You should see something like:

```text
NAME          NAMESPACE    REVISION    UPDATED                                    STATUS      CHART              APP VERSION
my-release    default      1           2026-10-27 23:13:34.320284126 +0000 UTC    deployed    grafana-10.5.15    12.3.1
```

**Step 10.** Shows the state of the release `my-release`.

```bash
helm status my-release
```

You should see something like:

```text
NAME: my-release
LAST DEPLOYED: Tue Oct 27 23:13:34 2026
NAMESPACE: default
STATUS: deployed
REVISION: 1
DESCRIPTION: Install complete
RESOURCES:
==> v1/ClusterRole
NAME                             CREATED AT
my-release-grafana-clusterrole   2026-10-27T23:13:34Z

==> v1/Deployment
NAME                 READY   UP-TO-DATE   AVAILABLE   AGE
my-release-grafana   0/1     1            0           0s

==> v1/Pod(related)
NAME                                READY   STATUS              RESTARTS   AGE
my-release-grafana-8d89b5f8-zfp9q   0/1     ContainerCreating   0          0s
… (49 more lines)
```

**Step 11.** Shows the values of a release.

```bash
helm get values my-release --all | head -30
```

You should see something like:

```text
COMPUTED VALUES:
admin:
  existingSecret: ""
  passwordKey: admin-password
  userKey: admin-user
adminUser: admin
affinity: {}
alerting: {}
assertNoLeakedSecrets: true
automountServiceAccountToken: true
autoscaling:
  behavior: {}
  enabled: false
  maxReplicas: 5
  minReplicas: 1
  targetCPU: "60"
  targetMemory: ""
containerSecurityContext:
… (12 more lines)
```

**Step 12.** Removes the release `my-release` and everything it created.

```bash
helm uninstall my-release
```

You should see something like:

```text
release "my-release" uninstalled
```

### If you see something else

- The check says: _The jenkins and grafana repositories are not both added (`helm repo add`)._
- The check says: _The release my-jenkins has not been installed yet._
- The check says: _The release my-release has not been installed yet._
- The check says: _my-jenkins or my-release is still installed. Uninstall it with `helm uninstall`._
- `helm repo add <name> <url>`, then `helm repo update`, then `helm install <release> <repo>/<chart>`.
- `helm list` shows the releases in the current namespace; `helm uninstall <release>` removes everything a release created.

### Why it works

**Why it works.** A chart is a package of templated manifests; a repository is an index of charts. `helm install <release> <repo>/<chart>` renders the chart with its default values and creates the objects, all labelled with the release name. `helm uninstall` deletes exactly what that release created.

**In practice:** `helm show values <chart>` lists what you can change, and `--set key=value` or `-f values.yaml` changes it at install time.

---

## Lab 4.10: Ingress

![Ingress: one node port, two websites, chosen by the HTTP Host header](../images/ingress.svg)

*Ingress: one node port, two websites, chosen by the HTTP Host header*

### What you will do

Follow [12-ingress.md](https://github.com/kumbulanit/CKA/blob/main/04-networking/12-ingress.md)
and [13-deploy-ingress-controller.md](https://github.com/kumbulanit/CKA/blob/main/04-networking/13-deploy-ingress-controller.md),
steps 1 to 6:

1. Create the pods **service-pod-1** and **service-pod-2** from `nginx` and expose them as
   **service1** and **service2** (port 80). Check them from a **frontend-pod** (`ubuntu`, with curl).
2. Write and apply **ingress.yaml**: the Ingress **name-virtual-host-ingress** with
   `ingressClassName: nginx`, sending `website01.example.internal` to service1 and
   `website02.example.internal` to service2.
3. Install the ingress-nginx controller with Helm, exposed on node port **30080**.
4. Change each pod's index.html to `This is Website 1` and `This is Website 2`.
5. Check with `curl -H "Host: website01.example.internal" http://minikube-m02:30080` (and website02).

Press **Check** now; step 7 (uninstall and delete) comes after the check passes.

### Step by step

**Step 1.** Starts the pod `service-pod-1` from the image `nginx`.

```bash
kubectl run service-pod-1 --image=nginx
```

You should see something like:

```text
pod/service-pod-1 created
```

**Step 2.** Starts the pod `service-pod-2` from the image `nginx`.

```bash
kubectl run service-pod-2 --image=nginx
```

You should see something like:

```text
pod/service-pod-2 created
```

**Step 3.** Creates a Service in front of the pod `service-pod-1` on port 80.

```bash
kubectl expose pod service-pod-1 --name service1 --port=80 --target-port=80
```

You should see something like:

```text
service/service1 exposed
```

**Step 4.** Creates a Service in front of the pod `service-pod-2` on port 80.

```bash
kubectl expose pod service-pod-2 --name service2 --port=80 --target-port=80
```

You should see something like:

```text
service/service2 exposed
```

**Step 5.** Lists the Services.

```bash
kubectl get services
```

You should see something like:

```text
NAME             TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
first-svc        NodePort    10.96.155.141   <none>        80:31755/TCP   39s
kplabs-service   ClusterIP   10.96.187.132   <none>        8080/TCP       95s
kubernetes       ClusterIP   10.96.0.1       <none>        443/TCP        3m13s
named-svc        NodePort    10.96.209.105   <none>        80:31027/TCP   36s
service1         ClusterIP   10.96.252.93    <none>        80/TCP         0s
service2         ClusterIP   10.96.209.166   <none>        80/TCP         0s
```

**Step 6.** Starts the pod `frontend-pod` from the image `ubuntu`.

```bash
kubectl run frontend-pod --image=ubuntu --command -- sleep 36000
```

You should see something like:

```text
Error from server (AlreadyExists): pods "frontend-pod" already exists
```

**Step 7.** Waits until the pods `service-pod-1`, `service-pod-2`, `frontend-pod` are Ready.

```bash
kubectl wait --for=condition=Ready pod/service-pod-1 pod/service-pod-2 pod/frontend-pod --timeout=180s
```

You should see something like:

```text
pod/service-pod-1 condition met
pod/service-pod-2 condition met
pod/frontend-pod condition met
```

**Step 8.** Runs a command inside the pod `frontend-pod`.

```bash
kubectl exec frontend-pod -- bash -c "apt-get update && apt-get -y install curl nano && curl -s $(kubectl get svc service1 -o jsonpath='{.spec.clusterIP}') | head -4 && curl -s $(kubectl get svc service2 -o jsonpath='{.spec.clusterIP}') | head -4"
```

You should see something like:

```text
Hit:1 http://ports.ubuntu.com/ubuntu-ports resolute InRelease
Hit:2 http://ports.ubuntu.com/ubuntu-ports resolute-updates InRelease
Hit:3 http://ports.ubuntu.com/ubuntu-ports resolute-backports InRelease
Hit:4 http://ports.ubuntu.com/ubuntu-ports resolute-security InRelease
Reading package lists...
Reading package lists...
Building dependency tree...
Reading state information...
curl is already the newest version (8.18.0-1ubuntu2.8).
Solving dependencies...
Suggested packages:
  hunspell
The following NEW packages will be installed:
  nano
0 upgraded, 1 newly installed, 0 to remove and 0 not upgraded.
Need to get 288 kB of archives.
After this operation, 934 kB of additional disk space will be used.
Get:1 http://ports.ubuntu.com/ubuntu-ports resolute-updates/main arm64 nano arm64 8.7.1-1ubuntu0.1 [288 kB]
… (27 more lines)
```

**Step 9.** Writes the file `ingress.yaml`.

```bash
cat > ingress.yaml <<'EOF'
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
EOF
```

It prints nothing when it works.

**Step 10.** Creates the objects in `ingress.yaml`, or updates them if they exist.

```bash
kubectl apply -f ingress.yaml
```

You should see something like:

```text
ingress.networking.k8s.io/name-virtual-host-ingress created
```

**Step 11.** Lists the Ingress.

```bash
kubectl get ingress
```

You should see something like:

```text
NAME                        CLASS   HOSTS                                                   ADDRESS   PORTS   AGE
name-virtual-host-ingress   nginx   website01.example.internal,website02.example.internal             80      0s
```

**Step 12.** Shows the details of the Ingress `name-virtual-host-ingress`, with its recent events at the bottom.

```bash
kubectl describe ingress name-virtual-host-ingress
```

You should see something like:

```text
Name:             name-virtual-host-ingress
Labels:           <none>
Namespace:        default
Address:          
Ingress Class:    nginx
Default backend:  <default>
Rules:
  Host                        Path  Backends
  ----                        ----  --------
  website01.example.internal  
                              /   service1:80 (10.244.1.14:80)
  website02.example.internal  
                              /   service2:80 (10.244.1.15:80)
Annotations:                  <none>
Events:                       <none>
```

**Step 13.** Upgrades the release `--install`.

```bash
helm upgrade --install ingress-nginx ingress-nginx --repo https://kubernetes.github.io/ingress-nginx --namespace ingress-nginx --create-namespace \
  --set controller.service.type=NodePort --set controller.service.nodePorts.http=30080
```

You should see something like:

```text
Release "ingress-nginx" does not exist. Installing it now.
NAME: ingress-nginx
LAST DEPLOYED: Tue Oct 27 23:13:50 2026
NAMESPACE: ingress-nginx
STATUS: deployed
REVISION: 1
DESCRIPTION: Install complete
TEST SUITE: None
NOTES:
The ingress-nginx controller has been installed.
Get the application URL by running these commands:
  export HTTP_NODE_PORT=30080
  export HTTPS_NODE_PORT=$(kubectl get service --namespace ingress-nginx ingress-nginx-controller --output jsonpath="{.spec.ports[1].nodePort}")
  export NODE_IP="$(kubectl get nodes --output jsonpath="{.items[0].status.addresses[1].address}")"

  echo "Visit http://${NODE_IP}:${HTTP_NODE_PORT} to access your application via HTTP."
  echo "Visit https://${NODE_IP}:${HTTPS_NODE_PORT} to access your application via HTTPS."

… (36 more lines)
```

**Step 14.** Lists the installed releases.

```bash
helm list --all-namespaces
```

You should see something like:

```text
NAME             NAMESPACE        REVISION    UPDATED                                   STATUS      CHART                   APP VERSION
ingress-nginx    ingress-nginx    1           2026-10-27 23:13:50.19652985 +0000 UTC    deployed    ingress-nginx-4.15.1    1.15.1
```

**Step 15.** Lists the ingressclass.

```bash
kubectl get ingressclass
```

You should see something like:

```text
NAME    CONTROLLER             PARAMETERS   AGE
nginx   k8s.io/ingress-nginx   <none>       4s
```

**Step 16.** Lists the Services in the namespace `ingress-nginx`.

```bash
kubectl get service -n ingress-nginx
```

You should see something like:

```text
NAME                                 TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                      AGE
ingress-nginx-controller             NodePort    10.96.151.244   <none>        80:30080/TCP,443:31679/TCP   4s
ingress-nginx-controller-admission   ClusterIP   10.96.180.22    <none>        443/TCP                      4s
```

**Step 17.** Waits until the rollout of the Deployment `ingress-nginx-controller` has finished.

```bash
kubectl -n ingress-nginx rollout status deployment/ingress-nginx-controller --timeout=240s
```

You should see something like:

```text
Waiting for deployment "ingress-nginx-controller" rollout to finish: 0 of 1 updated replicas are available...
deployment "ingress-nginx-controller" successfully rolled out
```

**Step 18.** Creates the objects in `ingress.yaml`, or updates them if they exist.

```bash
kubectl apply -f ingress.yaml
```

You should see something like:

```text
ingress.networking.k8s.io/name-virtual-host-ingress unchanged
```

**Step 19.** Runs a command inside the pod `service-pod-1`.

```bash
kubectl exec service-pod-1 -- bash -c 'cd /usr/share/nginx/html && echo "This is Website 1" > index.html'
```

It prints nothing when it works.

**Step 20.** Runs a command inside the pod `service-pod-2`.

```bash
kubectl exec service-pod-2 -- bash -c 'cd /usr/share/nginx/html && echo "This is Website 2" > index.html'
```

It prints nothing when it works.

**Step 21.** Waits 10 seconds.

```bash
sleep 10
```

It prints nothing when it works.

**Step 22.** Sends an HTTP request to `http://minikube-m02:30080` and prints the answer.

```bash
curl -H "Host: website01.example.internal" http://minikube-m02:30080
```

You should see something like:

```text
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100    18  100    18    0     0   2265      0 --:--:-- --:--:-- --:--:--  2571
This is Website 1
```

**Step 23.** Sends an HTTP request to `http://minikube-m02:30080` and prints the answer.

```bash
curl -H "Host: website02.example.internal" http://minikube-m02:30080
```

You should see something like:

```text
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100    18  100    18    0     0   1633      0 --:--:-- --:--:-- --:--:--  1800
This is Website 2
```

### If you see something else

- The check says: _There is no Ingress name-virtual-host-ingress with ingressClassName nginx._
- The check says: _The ingress-nginx controller is not installed in the namespace ingress-nginx with node port 30080._
- The check says: _curl -H "Host: website01.example.internal" http://minikube-m02:30080 does not show "This is Website 1" (or website02 "This is Website 2") yet._
- An Ingress does nothing until a controller runs: `kubectl get ingressclass` shows `nginx` once ingress-nginx is installed.
- `kubectl exec service-pod-1 -- bash -c 'echo "This is Website 1" > /usr/share/nginx/html/index.html'` changes the page without an interactive shell.

### Why it works

**Why it works.** An Ingress is only a set of rules: host and path → Service. An Ingress controller (here ingress-nginx, exposed on node port 30080) reads those rules and does the routing. It picks the backend from the HTTP Host header, so one IP and port serve both websites. `ingressClassName: nginx` says which controller should handle the Ingress.

**Note:** ingress-nginx is retired; the Gateway API is its successor and is on the current CKA curriculum.

---

## Lab 4.11: Service accounts

### What you will do

Follow [14-service-accounts.md](https://github.com/kumbulanit/CKA/blob/main/04-networking/14-service-accounts.md)
and [15-service-accounts-pointers.md](https://github.com/kumbulanit/CKA/blob/main/04-networking/15-service-accounts-pointers.md):

1. List the service accounts in all namespaces.
2. Create a pod **app-pod** from `nginx` and describe it to see its service account.
3. Inside app-pod, go to `/var/run/secrets/kubernetes.io/serviceaccount/`, read the token, and call
   `https://kubernetes.default.svc/api/v1` with curl, `--cacert ca.crt` and the token.
4. Create the namespace **kplabs-test**, check that it got a `default` service account, and create a
   pod **nginx-pod** from `nginx` in it. Look at its mounted token too. Leave both pods running.

### Step by step

**Step 1.** Lists the service accounts in every namespace.

```bash
kubectl get serviceaccount --all-namespaces
```

You should see something like:

```text
NAMESPACE            NAME                                          AGE
default              default                                       10m
ingress-nginx        default                                       7m31s
ingress-nginx        ingress-nginx                                 6m54s
kube-node-lease      default                                       10m
kube-public          default                                       10m
kube-system          attachdetach-controller                       10m
kube-system          bootstrap-signer                              10m
kube-system          certificate-controller                        10m
kube-system          clusterrole-aggregation-controller            10m
kube-system          coredns                                       10m
kube-system          cronjob-controller                            10m
kube-system          daemon-set-controller                         10m
kube-system          default                                       10m
kube-system          deployment-controller                         10m
kube-system          device-taint-eviction-controller              10m
kube-system          disruption-controller                         10m
kube-system          endpoint-controller                           10m
… (32 more lines)
```

**Step 2.** Starts the pod `app-pod` from the image `nginx`.

```bash
kubectl run app-pod --image=nginx
```

You should see something like:

```text
pod/app-pod created
```

**Step 3.** Waits until the pod `app-pod` is Ready.

```bash
kubectl wait --for=condition=Ready pod/app-pod --timeout=120s
```

You should see something like:

```text
pod/app-pod condition met
```

**Step 4.** Lists the pods.

```bash
kubectl get pods
```

You should see something like:

```text
NAME            READY   STATUS    RESTARTS   AGE
app-pod         1/1     Running   0          3s
backend-pod-1   1/1     Running   0          10m
backend-pod-2   1/1     Running   0          10m
frontend-pod    1/1     Running   0          10m
nginx           1/1     Running   0          8m27s
nginx2          1/1     Running   0          8m24s
service-pod-1   1/1     Running   0          7m48s
service-pod-2   1/1     Running   0          7m48s
```

**Step 5.** Shows the details of the pod `app-pod`, with its recent events at the bottom.

```bash
kubectl describe pod app-pod
```

You should see something like:

```text
Name:             app-pod
Namespace:        default
Priority:         0
Service Account:  default
Node:             minikube-m03/192.168.147.2
Start Time:       Tue, 27 Oct 2026 23:21:21 +0000
Labels:           run=app-pod
Annotations:      <none>
Status:           Running
IP:               10.244.2.19
IPs:
  IP:  10.244.2.19
Containers:
  app-pod:
    Container ID:   containerd://abd8a9b9bec52f81635a443c24727ae9c0e8a9859eab5e573027141a4ee17ac9
    Image:          nginx
    Image ID:       docker.io/library/nginx@sha256:4c41e2d0a3a55b325ed572cd0200bdb72af1433c3daa2bca6ef8eea68ce504a2
    Port:           <none>
… (34 more lines)
```

**Step 6.** Runs a command inside the pod `app-pod`.

```bash
kubectl exec app-pod -- bash -c 'cd /var/run/secrets/kubernetes.io/serviceaccount/ && ls && token=$(cat token) && echo $token && curl -s --cacert ca.crt -H "Authorization: Bearer $token" https://kubernetes.default.svc/api/v1 | head -20'
```

You should see something like:

```text
ca.crt
namespace
token
eyJhbGciOiJSUzI1NiIsImtpZCI6InBPMkVYZDdZRWllXzlidlVQcUUxWXZuZ25CTkxjQjRIVUF2RzRWNmhleGcifQ.eyJhdWQiOlsiaHR0cHM6Ly9rdWJlcm5ldGVzLmRlZmF1bHQuc3ZjLmNsdXN0ZXIubG9jYWwiXSwiZXhwIjoxODI0Njc5MjgxLCJpYXQiOjE3OTMxNDMyODEsImlzcyI6Imh0dHBzOi8va3ViZXJuZXRlcy5kZWZhdWx0LnN2Yy5jbHVzdGVyLmxvY2FsIiwianRpIjoiODczNGQzMTYtNzYxYi00ZTY2LTgzZDEtZjQ1ZTBhZTQzOGE1Iiwia3ViZXJuZXRlcy5pbyI6eyJuYW1lc3BhY2UiOiJkZWZhdWx0Iiwibm9kZSI6eyJuYW1lIjoibWluaWt1YmUtbTAzIiwidWlkIjoiY2Y1YzFlMjYtODFjNS00MGNlLTg3ODItODM1ZDg0YWU4ZjIwIn0sInBvZCI6eyJuYW1lIjoiYXBwLXBvZCIsInVpZCI6IjE2MDM3N2Q4LWVhZGQtNDJkNy04MWM4LWJlMDU3MzBiYzk1YyJ9LCJzZXJ2aWNlYWNjb3VudCI6eyJuYW1lIjoiZGVmYXVsdCIsInVpZCI6IjM0OTAzM2IxLTljMDUtNDRmMi1hYWQzLWFmZDczNzgzM2QyMyJ9LCJ3YXJuYWZ0ZXIiOjE3OTMxNDY4ODh9LCJuYmYiOjE3OTMxNDMyODEsInN1YiI6InN5c3RlbTpzZXJ2aWNlYWNjb3VudDpkZWZhdWx0OmRlZmF1bHQifQ.ytTeaMI3qU7vdHLp1ME91J9TyEznOfa10vVe9eSfbhUWtrx019cY94IqefkxfsaTdClWbCkYTnqSbfFjfgANm6xoStmYFVx-vLBDuCqTlyDAOe4VMNkLIjyYPauacmgsm2KGmKoNR3PsqAMthzgYc2x7H2NbTdFXniYUDFz8hRAMht2PvvZYcSw02HygYq9In44T5N2WLCuazW0a8RQca9gTS0T1h62Zy2S3CKeAinDgVSpXPUCYB6jCPRykoU2PZXcauPcRP__NgMV6yYTULXiL0eetxscruyO_hzNQ5ryOId52jQ8kAh-n6dVygmG8ds503ZxTV-aK-3WnvGfBDg
{
  "kind": "APIResourceList",
  "groupVersion": "v1",
  "resources": [
    {
      "name": "bindings",
      "singularName": "binding",
      "namespaced": true,
      "kind": "Binding",
      "verbs": [
        "create"
      ]
    },
    {
… (6 more lines)
```

**Step 7.** Lists the service accounts.

```bash
kubectl get serviceaccount
```

You should see something like:

```text
NAME      AGE
default   10m
```

**Step 8.** Lists the service accounts in the namespace `kube-system`.

```bash
kubectl get sa -n kube-system
```

You should see something like:

```text
NAME                                          AGE
attachdetach-controller                       10m
bootstrap-signer                              10m
certificate-controller                        10m
clusterrole-aggregation-controller            10m
coredns                                       11m
cronjob-controller                            10m
daemon-set-controller                         10m
default                                       10m
deployment-controller                         10m
device-taint-eviction-controller              10m
disruption-controller                         10m
endpoint-controller                           10m
endpointslice-controller                      10m
endpointslicemirroring-controller             10m
ephemeral-volume-controller                   10m
expand-controller                             10m
generic-garbage-collector                     10m
… (24 more lines)
```

**Step 9.** Creates the namespace `kplabs-test`.

```bash
kubectl create namespace kplabs-test
```

You should see something like:

```text
namespace/kplabs-test created
```

**Step 10.** Lists the service accounts in the namespace `kplabs-test`.

```bash
kubectl get sa -n kplabs-test
```

You should see something like:

```text
NAME      AGE
default   0s
```

**Step 11.** Starts the pod `nginx-pod` from the image `nginx` in the namespace `kplabs-test`.

```bash
kubectl run nginx-pod -n kplabs-test --image=nginx
```

You should see something like:

```text
pod/nginx-pod created
```

**Step 12.** Waits until the pod `nginx-pod` is Ready in the namespace `kplabs-test`.

```bash
kubectl -n kplabs-test wait --for=condition=Ready pod/nginx-pod --timeout=120s
```

You should see something like:

```text
pod/nginx-pod condition met
```

**Step 13.** Lists the pods in the namespace `kplabs-test`.

```bash
kubectl get pods -n kplabs-test
```

You should see something like:

```text
NAME        READY   STATUS    RESTARTS   AGE
nginx-pod   1/1     Running   0          2s
```

**Step 14.** Shows the details of the pod `nginx-pod` in the namespace `kplabs-test`, with its recent events at the bottom.

```bash
kubectl describe pod nginx-pod -n kplabs-test
```

You should see something like:

```text
Name:             nginx-pod
Namespace:        kplabs-test
Priority:         0
Service Account:  default
Node:             minikube-m03/192.168.147.2
Start Time:       Tue, 27 Oct 2026 23:21:24 +0000
Labels:           run=nginx-pod
Annotations:      <none>
Status:           Running
IP:               10.244.2.20
IPs:
  IP:  10.244.2.20
Containers:
  nginx-pod:
    Container ID:   containerd://61a94fcb33ed62001ad4def5f1ce2c57ecca5460f0279bbb18c8bc6f76110197
    Image:          nginx
    Image ID:       docker.io/library/nginx@sha256:4c41e2d0a3a55b325ed572cd0200bdb72af1433c3daa2bca6ef8eea68ce504a2
    Port:           <none>
… (34 more lines)
```

**Step 15.** Runs a command inside the pod `nginx-pod`.

```bash
kubectl exec nginx-pod -n kplabs-test -- bash -c 'cd /var/run/secrets/kubernetes.io/serviceaccount/ && ls && cat token'
```

You should see something like:

```text
ca.crt
namespace
token
eyJhbGciOiJSUzI1NiIsImtpZCI6InBPMkVYZDdZRWllXzlidlVQcUUxWXZuZ25CTkxjQjRIVUF2RzRWNmhleGcifQ.eyJhdWQiOlsiaHR0cHM6Ly9rdWJlcm5ldGVzLmRlZmF1bHQuc3ZjLmNsdXN0ZXIubG9jYWwiXSwiZXhwIjoxODI0Njc5Mjg0LCJpYXQiOjE3OTMxNDMyODQsImlzcyI6Imh0dHBzOi8va3ViZXJuZXRlcy5kZWZhdWx0LnN2Yy5jbHVzdGVyLmxvY2FsIiwianRpIjoiNmYzNjNlMTctYzZmNy00MTE3LTlhYWItZGFhZDgwMWJhZTAzIiwia3ViZXJuZXRlcy5pbyI6eyJuYW1lc3BhY2UiOiJrcGxhYnMtdGVzdCIsIm5vZGUiOnsibmFtZSI6Im1pbmlrdWJlLW0wMyIsInVpZCI6ImNmNWMxZTI2LTgxYzUtNDBjZS04NzgyLTgzNWQ4NGFlOGYyMCJ9LCJwb2QiOnsibmFtZSI6Im5naW54LXBvZCIsInVpZCI6ImRhNWU2ZmRiLWJmZGItNDJhYi05MDUwLTk5NjE1NTRmZmI3NCJ9LCJzZXJ2aWNlYWNjb3VudCI6eyJuYW1lIjoiZGVmYXVsdCIsInVpZCI6IjQyYmExM2MzLWY0YzItNGZjMi05ODA2LTRiYWU3NDA2ZmQwOSJ9LCJ3YXJuYWZ0ZXIiOjE3OTMxNDY4OTF9LCJuYmYiOjE3OTMxNDMyODQsInN1YiI6InN5c3RlbTpzZXJ2aWNlYWNjb3VudDprcGxhYnMtdGVzdDpkZWZhdWx0In0.BOFKFxoCbeshFhwl9DOC3_guFBAROsWWYKALiL8NH1kCFY43Rc_Zh9qBclax6gbCixT1Za9B0VzkYlWcOD8ZIh-Fm70t4GdoVhf9jbqcQt1omB-7ykPR9EO5FRXNaq9vrbSP0eK68R40QnjbwzZVHJG1b_5rEVa2YG-zbGoHyNoZeYQWNLiWnkd3nrWc5xnsQzB4kIWrqffuiRJxMaIzfTqeRUXCkrBkFNV3jwevUk00T8ggEd_yN-LAMt-VUR6pLiUn71CF58nx_Bne2sluPQorJC-KW_wuRVyrYtGE1kFDpErGxUn-5P39ZKLj5wayjqnY3tR8gDZo1Ix3mnzZ_w@@PB-STEP end@@
```

### If you see something else

- The check says: _There is no running pod app-pod using the default service account._
- The check says: _The namespace kplabs-test (with its default service account) does not exist._
- The check says: _There is no running pod nginx-pod in kplabs-test._
- Every namespace gets a service account called `default`, and every pod uses it unless it names another.
- Inside the pod: `curl --cacert ca.crt -H "Authorization: Bearer $(cat token)" https://kubernetes.default.svc/api/v1`.

### Why it works

**Why it works.** Every namespace gets a service account called `default`, and each pod uses one. The kubelet mounts a short-lived token for it, plus the cluster CA and the namespace, at /var/run/secrets/kubernetes.io/serviceaccount/. With that token a process inside the pod can call the API server at `https://kubernetes.default.svc`. What it is allowed to do depends on RBAC (the Security module).

**Note:** since v1.24 service accounts no longer get a long-lived token Secret; `kubectl create token <sa>` issues one on demand.

---

## Lab 4.12: A custom service account

### What you will do

Follow [16-service-accounts-practical.md](https://github.com/kumbulanit/CKA/blob/main/04-networking/16-service-accounts-practical.md):

1. Create the service account **custom-sa**.
2. Save a pod **custom-pod** (`nginx`) to **custom-pod-sa.yaml** with `--dry-run=client -o yaml`, and
   add `serviceAccountName: custom-sa` under `spec`.
3. Apply it and print its service account with `-o jsonpath='{.spec.serviceAccountName}'`.

### Step by step

**Step 1.** Creates the service account `custom-sa`.

```bash
kubectl create serviceaccount custom-sa
```

You should see something like:

```text
serviceaccount/custom-sa created
```

**Step 2.** Writes the manifest of the pod `custom-pod` without creating it.

```bash
kubectl run custom-pod --image=nginx --dry-run=client -o yaml > custom-pod-sa.yaml
```

It prints nothing when it works.

**Step 3.** Edits `custom-pod-sa.yaml`: `spec:` becomes `spec:   serviceAccountName: custom-sa`. The edit: add the service account.

```bash
sed -i 's/^spec:$/spec:\n  serviceAccountName: custom-sa/' custom-pod-sa.yaml
```

It prints nothing when it works.

**Step 4.** Creates the objects in `custom-pod-sa.yaml`, or updates them if they exist.

```bash
kubectl apply -f custom-pod-sa.yaml
```

You should see something like:

```text
pod/custom-pod created
```

**Step 5.** Prints one field of the pod `custom-pod`.

```bash
kubectl get pod custom-pod -o jsonpath='{.spec.serviceAccountName}'
```

You should see something like:

```text
custom-sa@@PB-STEP end@@
```

### If you see something else

- The check says: _There is no service account called custom-sa._
- The check says: _/root/custom-pod-sa.yaml is missing, or has no `serviceAccountName: custom-sa`._
- The check says: _The pod custom-pod does not use the service account custom-sa._
- `kubectl create serviceaccount custom-sa` creates it.
- `serviceAccountName` goes directly under `spec`, next to `containers`. A running pod's service account cannot be changed; delete and recreate it.

### Why it works

**Why it works.** `spec.serviceAccountName` picks the identity the pod's processes use toward the API server. Giving each application its own service account lets you grant it exactly the permissions it needs with RBAC, instead of sharing `default`.

**In the exam:** a pod's service account cannot be changed while it runs; delete the pod and create it again (or edit its Deployment's template).

---

## Lab 4.13: Cluster DNS

![Inside the cluster: DNS finds the Service, kube-proxy picks a pod, the CNI carries the packet](../images/cluster-network.svg)

*Inside the cluster: DNS finds the Service, kube-proxy picks a pod, the CNI carries the packet*

### What you will do

Follow [17-dns-for-service-discovery.md](https://github.com/kumbulanit/CKA/blob/main/04-networking/17-dns-for-service-discovery.md),
section 4:

1. Look at CoreDNS's configuration: the ConfigMap **coredns** in `kube-system`.
2. Test DNS from a temporary pod: `kubectl run dnstest --image=busybox:1.37 --rm -it --restart=Never -- nslookup kubernetes.default`.

### Step by step

**Step 1.** Shows the ConfigMap `coredns` in the namespace `kube-system` as YAML, as the API server stores it.

```bash
kubectl get configmap coredns -n kube-system -o yaml
```

You should see something like:

```text
apiVersion: v1
data:
  Corefile: |
    .:53 {
        errors
        health {
           lameduck 5s
        }
        ready
        kubernetes cluster.local in-addr.arpa ip6.arpa {
           pods insecure
           fallthrough in-addr.arpa ip6.arpa
           ttl 30
        }
        prometheus :9153
        forward . /etc/resolv.conf {
           max_concurrent 1000
        }
… (15 more lines)
```

**Step 2.** Starts a throwaway pod `dnstest` that runs one command and is deleted afterwards.

```bash
kubectl run dnstest --image=busybox:1.37 --rm -i --restart=Never -- nslookup kubernetes.default
```

You should see something like:

```text
All commands and output from this session will be recorded in container logs, including credentials and sensitive information passed through the command prompt.
If you don't see a command prompt, try pressing enter.
pod "dnstest" deleted from default namespace
pod default/dnstest terminated (Error)
```

### If you see something else

- The check says: _The pod dnstest has not run yet._
- The check says: _dnstest is still there. `--rm` deletes it when the command ends; delete it with `kubectl delete pod dnstest`._
- `kubectl get configmap coredns -n kube-system -o yaml` prints the Corefile.
- `kubernetes.default` is the Service `kubernetes` in the namespace `default`; the pod's search domains complete it to `kubernetes.default.svc.cluster.local`.

### Why it works

**Why it works.** CoreDNS runs in kube-system and answers DNS for the cluster. Every pod's /etc/resolv.conf points at it and has search domains such as `default.svc.cluster.local`, so `kubernetes.default` becomes `kubernetes.default.svc.cluster.local`, the API server's Service. The ConfigMap holds CoreDNS's Corefile; its `kubernetes` block answers for Services and pods.

**In the exam:** a throwaway pod with `nslookup` (`kubectl run ... --rm -it --restart=Never`) is the standard way to test DNS.

---
