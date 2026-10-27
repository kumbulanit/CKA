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

The steps below use the node names of the lessons. On minikube, `controlplane` is `minikube` (`minikube ssh`), `node01` is `minikube-m02` (`minikube ssh -n minikube-m02`) and `node02` is `minikube-m03`; run `kubectl` as your own user on the server. The outputs were recorded in Desired Labs, whose nodes have the lessons' names. In Desired Labs, starting the lab gives you that cluster, with `root@controlplane` in the terminal.

## Lab 4.1: A Service with manual endpoints

### What you will do

Follow [serviceandendpoints.md](https://github.com/kumbulanit/CKA/blob/main/Networking/Services%20and%20Networking/serviceandendpoints.md),
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
NAME            READY   STATUS    RESTARTS   AGE   IP           NODE     NOMINATED NODE   READINESS GATES
backend-pod-1   1/1     Running   0          28s   10.244.2.2   node01   <none>           <none>
backend-pod-2   1/1     Running   0          28s   10.244.1.2   node02   <none>           <none>
frontend-pod    1/1     Running   0          28s   10.244.2.3   node01   <none>           <none>
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
Get:5 http://ports.ubuntu.com/ubuntu-ports resolute/main arm64 Packages [1860 kB]
Get:6 http://ports.ubuntu.com/ubuntu-ports resolute/universe arm64 Packages [19.9 MB]
Get:7 http://ports.ubuntu.com/ubuntu-ports resolute/restricted arm64 Packages [231 kB]
Get:8 http://ports.ubuntu.com/ubuntu-ports resolute/multiverse arm64 Packages [298 kB]
Get:9 http://ports.ubuntu.com/ubuntu-ports resolute-updates/universe arm64 Packages [417 kB]
Get:10 http://ports.ubuntu.com/ubuntu-ports resolute-updates/main arm64 Packages [955 kB]
Get:11 http://ports.ubuntu.com/ubuntu-ports resolute-updates/multiverse arm64 Packages [26.3 kB]
Get:12 http://ports.ubuntu.com/ubuntu-ports resolute-updates/restricted arm64 Packages [848 kB]
Get:13 http://ports.ubuntu.com/ubuntu-ports resolute-backports/universe arm64 Packages [3309 B]
Get:14 http://ports.ubuntu.com/ubuntu-ports resolute-security/universe arm64 Packages [254 kB]
Get:15 http://ports.ubuntu.com/ubuntu-ports resolute-security/main arm64 Packages [771 kB]
Get:16 http://ports.ubuntu.com/ubuntu-ports resolute-security/multiverse arm64 Packages [24.5 kB]
Get:17 http://ports.ubuntu.com/ubuntu-ports resolute-security/restricted arm64 Packages [813 kB]
Fetched 27.0 MB in 7s (4075 kB/s)
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
NAME             TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)    AGE
kplabs-service   ClusterIP   10.96.31.229   <none>        8080/TCP   0s
kubernetes       ClusterIP   10.96.0.1      <none>        443/TCP    79s
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
IP:                       10.96.31.229
IPs:                      10.96.31.229
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

Follow [service-selector.md](https://github.com/kumbulanit/CKA/blob/main/Networking/Services%20and%20Networking/service-selector.md):

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
IP:                       10.96.23.3
IPs:                      10.96.23.3
Port:                     <unset>  80/TCP
TargetPort:               80/TCP
Endpoints:                10.244.1.3:80,10.244.2.4:80,10.244.1.4:80
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
IP:                       10.96.23.3
IPs:                      10.96.23.3
Port:                     <unset>  80/TCP
TargetPort:               80/TCP
Endpoints:                10.244.1.3:80,10.244.2.4:80,10.244.1.4:80 + 7 more...
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
IP:                       10.96.23.3
IPs:                      10.96.23.3
Port:                     <unset>  80/TCP
TargetPort:               80/TCP
Endpoints:                10.244.1.3:80,10.244.2.4:80,10.244.1.4:80 + 8 more...
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
Annotations:  endpoints.kubernetes.io/last-change-trigger-time: 2026-10-27T05:53:40Z
Subsets:
  Addresses:          10.244.1.3,10.244.1.4,10.244.1.5,10.244.1.6,10.244.1.7,10.244.1.8,10.244.2.4,10.244.2.5,10.244.2.6,10.244.2.7,10.244.2.8
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

Follow [nodeport.md](https://github.com/kumbulanit/CKA/blob/main/Networking/Services%20and%20Networking/nodeport.md):

1. Create a pod **nodeport-pod** from `nginx` with the label `type=publicpod`.
2. Write and apply **nodeport.yaml**: a Service **kplabs-nodeport** of type NodePort that selects
   `type: publicpod`, port 80 → 80.
3. Find the node port with `kubectl get service`, and the worker IPs with `kubectl get nodes -o wide`.
   Instead of a browser, use `curl http://node01:<NODEPORT>`.
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
NAME            READY   STATUS              RESTARTS   AGE   LABELS
backend-pod-1   1/1     Running             0          75s   run=backend-pod-1
backend-pod-2   1/1     Running             0          75s   run=backend-pod-2
frontend-pod    1/1     Running             0          75s   run=frontend-pod
nodeport-pod    0/1     ContainerCreating   0          0s    type=publicpod
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
NAME              TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)        AGE
kplabs-nodeport   NodePort    10.96.41.111   <none>        80:30850/TCP   0s
kplabs-service    ClusterIP   10.96.31.229   <none>        8080/TCP       33s
kubernetes        ClusterIP   10.96.0.1      <none>        443/TCP        112s
```

**Step 6.** Lists the nodes, with IP addresses and versions.

```bash
kubectl get nodes -o wide
```

You should see something like:

```text
NAME           STATUS   ROLES           AGE    VERSION   INTERNAL-IP     EXTERNAL-IP   OS-IMAGE                       KERNEL-VERSION                               CONTAINER-RUNTIME
controlplane   Ready    control-plane   113s   v1.36.4   192.168.147.3   <none>        Debian GNU/Linux 13 (trixie)   7.2.9-orbstack-00391-g2b298d05fbd4 (arm64)   containerd://2.3.4
node01         Ready    <none>          103s   v1.36.4   192.168.147.4   <none>        Debian GNU/Linux 13 (trixie)   7.2.9-orbstack-00391-g2b298d05fbd4 (arm64)   containerd://2.3.4
node02         Ready    <none>          103s   v1.36.4   192.168.147.2   <none>        Debian GNU/Linux 13 (trixie)   7.2.9-orbstack-00391-g2b298d05fbd4 (arm64)   containerd://2.3.4
```

**Step 7.** Waits until the pod `nodeport-pod` is Ready.

```bash
kubectl wait --for=condition=Ready pod/nodeport-pod --timeout=120s
```

You should see something like:

```text
pod/nodeport-pod condition met
```

**Step 8.** Sends an HTTP request to `http://node01:…` and prints the answer.

```bash
curl -s http://node01:$(kubectl get svc kplabs-nodeport -o jsonpath='{.spec.ports[0].nodePort}') | head -4
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
- `curl http://node01:<NODEPORT>` and `curl http://node02:<NODEPORT>` both reach the pod.

### Why it works

**Why it works.** A NodePort Service is a ClusterIP Service plus a port (30000–32767 by default) opened on every node. kube-proxy forwards traffic arriving at `<any node>:<nodePort>` to the Service's pods, wherever they run.

**In practice:** NodePort is the simplest way to reach a Service from outside the cluster; you set a fixed port with `nodePort:` under `ports`.

---

## Lab 4.4: LoadBalancer

### What you will do

Follow [loadbalancer.md](https://github.com/kumbulanit/CKA/blob/main/Networking/Services%20and%20Networking/loadbalancer.md):

1. Create a pod **lb-pod** from `nginx` with the label `type=loadbalanced`.
2. Write and apply **elb-service.yaml**: a Service **kplabs-loadbalancer** of type LoadBalancer that
   selects `type: loadbalanced`, port 80.
3. Describe it and get it: `EXTERNAL-IP` stays `<pending>` because nothing here provides load
   balancers. Curl its node port on node01 instead.
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
NAME            READY   STATUS              RESTARTS   AGE   LABELS
backend-pod-1   1/1     Running             0          81s   run=backend-pod-1
backend-pod-2   1/1     Running             0          81s   run=backend-pod-2
frontend-pod    1/1     Running             0          81s   run=frontend-pod
lb-pod          0/1     ContainerCreating   0          1s    type=loadbalanced
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
IP:                       10.96.248.204
IPs:                      10.96.248.204
Port:                     <unset>  80/TCP
TargetPort:               80/TCP
NodePort:                 <unset>  32649/TCP
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
NAME                  TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
kplabs-loadbalancer   LoadBalancer   10.96.248.204   <pending>     80:32649/TCP   0s
```

**Step 7.** Waits until the pod `lb-pod` is Ready.

```bash
kubectl wait --for=condition=Ready pod/lb-pod --timeout=120s
```

You should see something like:

```text
pod/lb-pod condition met
```

**Step 8.** Sends an HTTP request to `http://node01:…` and prints the answer.

```bash
curl -s http://node01:$(kubectl get svc kplabs-loadbalancer -o jsonpath='{.spec.ports[0].nodePort}') | head -4
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

Follow [service-manifest-cli.md](https://github.com/kumbulanit/CKA/blob/main/Networking/Services%20and%20Networking/service-manifest-cli.md):

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
IP:                       10.96.92.49
IPs:                      10.96.92.49
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
NAME                     TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)        AGE
kplabs-service           ClusterIP   10.96.31.229   <none>        8080/TCP       44s
kubernetes               ClusterIP   10.96.0.1      <none>        443/TCP        2m3s
nginx-nodeport-service   NodePort    10.96.110.2    <none>        80:31013/TCP   0s
nginx-service            ClusterIP   10.96.92.49    <none>        80/TCP         0s
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
IP:                       10.96.196.126
IPs:                      10.96.196.126
Port:                     <unset>  80/TCP
TargetPort:               80/TCP
Endpoints:                10.244.2.9:80,10.244.1.12:80,10.244.2.10:80
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

Follow [named-port.md](https://github.com/kumbulanit/CKA/blob/main/Networking/Services%20and%20Networking/named-port.md):

1. Create a pod **nginx** from `nginx` with port 80, expose it as the NodePort Service **first-svc**
   (port 80 → targetPort 80), look at its YAML and curl it on node01.
2. Save a pod **nginx2** (`nginx`, port 80) to **pod_named.yaml** with `--dry-run=client -o yaml`, name
   its port **custom-http**, and apply it.
3. Expose nginx2 as the NodePort Service **named-svc** with `--target-port=custom-http`, and curl it
   on node01. Leave everything running.

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
NAME             TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)        AGE
first-svc        NodePort    10.96.10.190   <none>        80:31309/TCP   0s
kplabs-service   ClusterIP   10.96.31.229   <none>        8080/TCP       50s
kubernetes       ClusterIP   10.96.0.1      <none>        443/TCP        2m9s
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
  creationTimestamp: "2026-10-27T05:54:01Z"
  labels:
    run: nginx
  name: first-svc
  namespace: default
  resourceVersion: "1337"
  uid: 6188f3ab-d7da-4e07-beff-829c2fa3030a
spec:
  clusterIP: 10.96.10.190
  clusterIPs:
  - 10.96.10.190
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
controlplane   Ready    control-plane   2m10s   v1.36.4   192.168.147.3   <none>        Debian GNU/Linux 13 (trixie)   7.2.9-orbstack-00391-g2b298d05fbd4 (arm64)   containerd://2.3.4
node01         Ready    <none>          2m      v1.36.4   192.168.147.4   <none>        Debian GNU/Linux 13 (trixie)   7.2.9-orbstack-00391-g2b298d05fbd4 (arm64)   containerd://2.3.4
node02         Ready    <none>          2m      v1.36.4   192.168.147.2   <none>        Debian GNU/Linux 13 (trixie)   7.2.9-orbstack-00391-g2b298d05fbd4 (arm64)   containerd://2.3.4
```

**Step 6.** Waits until the pod `nginx` is Ready.

```bash
kubectl wait --for=condition=Ready pod/nginx --timeout=120s
```

You should see something like:

```text
pod/nginx condition met
```

**Step 7.** Sends an HTTP request to `http://node01:…` and prints the answer.

```bash
curl -s http://node01:$(kubectl get svc first-svc -o jsonpath='{.spec.ports[0].nodePort}') | head -4
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
NAME             TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)        AGE
first-svc        NodePort    10.96.10.190   <none>        80:31309/TCP   2s
kplabs-service   ClusterIP   10.96.31.229   <none>        8080/TCP       52s
kubernetes       ClusterIP   10.96.0.1      <none>        443/TCP        2m11s
named-svc        NodePort    10.96.10.16    <none>        80:32137/TCP   0s
```

**Step 13.** Waits until the pod `nginx2` is Ready.

```bash
kubectl wait --for=condition=Ready pod/nginx2 --timeout=120s
```

You should see something like:

```text
pod/nginx2 condition met
```

**Step 14.** Sends an HTTP request to `http://node01:…` and prints the answer.

```bash
curl -s http://node01:$(kubectl get svc named-svc -o jsonpath='{.spec.ports[0].nodePort}') | head -4
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
- The check says: _named-svc does not answer on its node port on node01. Is nginx2 running?_
- `kubectl expose pod nginx --name first-svc --port=80 --target-port=80 --type=NodePort` creates the first Service.
- In pod_named.yaml, add `name: custom-http` under `- containerPort: 80`, at the same indentation.

### Why it works

**Why it works.** `targetPort` can be a number or the name of a container port. With `--target-port=custom-http`, the Service looks up which port each pod calls `custom-http`. If a new version of the pod moves to port 8080 but keeps the name, the Service needs no change.

**In the exam:** a named targetPort that matches no port name in the pod leaves the Service with no working endpoints.

---

## Lab 4.7: Namespaces

### What you will do

Follow [namespace.md](https://github.com/kumbulanit/CKA/blob/main/Networking/Services%20and%20Networking/namespace.md):

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
default              Active   2m15s
kube-node-lease      Active   2m15s
kube-public          Active   2m15s
kube-system          Active   2m15s
local-path-storage   Active   2m12s
```

**Step 2.** Lists the pods in the namespace `kube-system`.

```bash
kubectl get pods -n kube-system
```

You should see something like:

```text
NAME                                   READY   STATUS    RESTARTS   AGE
coredns-589f44dc88-2fmhw               1/1     Running   0          2m7s
coredns-589f44dc88-pttj2               1/1     Running   0          2m7s
etcd-controlplane                      1/1     Running   0          2m14s
kindnet-fspqz                          1/1     Running   0          113s
kindnet-rsst9                          1/1     Running   0          112s
kindnet-vhtms                          1/1     Running   0          112s
kube-apiserver-controlplane            1/1     Running   0          2m14s
kube-controller-manager-controlplane   1/1     Running   0          2m14s
kube-proxy-447dj                       1/1     Running   0          2m5s
kube-proxy-h7dp9                       1/1     Running   0          2m7s
kube-proxy-v4kkr                       1/1     Running   0          2m5s
kube-scheduler-controlplane            1/1     Running   0          2m14s
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
default              Active   2m15s
kube-node-lease      Active   2m15s
kube-public          Active   2m15s
kube-system          Active   2m15s
local-path-storage   Active   2m12s
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

Follow [install-helm.md](https://github.com/kumbulanit/CKA/blob/main/Networking/Services%20and%20Networking/install-helm.md)
on controlplane: add Helm's apt repository with its signing key, install the `helm` package, and
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
Fetched 33.0 kB in 4s (7613 B/s)
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

Follow [first-helm-chart.md](https://github.com/kumbulanit/CKA/blob/main/Networking/Services%20and%20Networking/first-helm-chart.md):

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
LAST DEPLOYED: Tue Oct 27 05:54:38 2026
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
my-jenkins    default      1           2026-10-27 05:54:38.449904516 +0000 UTC    deployed    jenkins-5.10.0    2.580.1
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
...Successfully got an update from the "jenkins" chart repository
...Successfully got an update from the "grafana" chart repository
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
LAST DEPLOYED: Tue Oct 27 05:54:59 2026
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
my-release    default      1           2026-10-27 05:54:59.962639744 +0000 UTC    deployed    grafana-10.5.15    12.3.1
```

**Step 10.** Shows the state of the release `my-release`.

```bash
helm status my-release
```

You should see something like:

```text
NAME: my-release
LAST DEPLOYED: Tue Oct 27 05:54:59 2026
NAMESPACE: default
STATUS: deployed
REVISION: 1
DESCRIPTION: Install complete
RESOURCES:
==> v1/Service
NAME                 TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
my-release-grafana   ClusterIP   10.96.65.247   <none>        80/TCP    0s

==> v1/Deployment
NAME                 READY   UP-TO-DATE   AVAILABLE   AGE
my-release-grafana   0/1     1            0           0s

==> v1/Pod(related)
NAME                                  READY   STATUS              RESTARTS   AGE
my-release-grafana-85d4c4b9bc-hfc7z   0/1     ContainerCreating   0          0s
… (48 more lines)
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

Follow [ingress.md](https://github.com/kumbulanit/CKA/blob/main/Networking/Services%20and%20Networking/ingress.md)
and [deploy-ingress-controller.md](https://github.com/kumbulanit/CKA/blob/main/Networking/Services%20and%20Networking/deploy-ingress-controller.md),
steps 1 to 6:

1. Create the pods **service-pod-1** and **service-pod-2** from `nginx` and expose them as
   **service1** and **service2** (port 80). Check them from a **frontend-pod** (`ubuntu`, with curl).
2. Write and apply **ingress.yaml**: the Ingress **name-virtual-host-ingress** with
   `ingressClassName: nginx`, sending `website01.example.internal` to service1 and
   `website02.example.internal` to service2.
3. Install the ingress-nginx controller with Helm, exposed on node port **30080**.
4. Change each pod's index.html to `This is Website 1` and `This is Website 2`.
5. Check with `curl -H "Host: website01.example.internal" http://node01:30080` (and website02).

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
first-svc        NodePort    10.96.209.100   <none>        80:31833/TCP   33s
kplabs-service   ClusterIP   10.96.255.101   <none>        8080/TCP       80s
kubernetes       ClusterIP   10.96.0.1       <none>        443/TCP        2m38s
named-svc        NodePort    10.96.105.181   <none>        80:31853/TCP   30s
service1         ClusterIP   10.96.54.174    <none>        80/TCP         0s
service2         ClusterIP   10.96.180.60    <none>        80/TCP         0s
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
                              /   service1:80 (10.244.3.14:80)
  website02.example.internal  
                              /   service2:80 (10.244.1.16:80)
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
LAST DEPLOYED: Tue Oct 27 12:55:52 2026
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
NAME             NAMESPACE        REVISION    UPDATED                                    STATUS      CHART                   APP VERSION
ingress-nginx    ingress-nginx    1           2026-10-27 12:55:52.950838411 +0000 UTC    deployed    ingress-nginx-4.15.1    1.15.1
```

**Step 15.** Lists the ingressclass.

```bash
kubectl get ingressclass
```

You should see something like:

```text
NAME    CONTROLLER             PARAMETERS   AGE
nginx   k8s.io/ingress-nginx   <none>       15s
```

**Step 16.** Lists the Services in the namespace `ingress-nginx`.

```bash
kubectl get service -n ingress-nginx
```

You should see something like:

```text
NAME                                 TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                      AGE
ingress-nginx-controller             NodePort    10.96.221.42    <none>        80:30080/TCP,443:30724/TCP   15s
ingress-nginx-controller-admission   ClusterIP   10.96.248.157   <none>        443/TCP                      15s
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

**Step 22.** Sends an HTTP request to `http://node01:30080` and prints the answer.

```bash
curl -H "Host: website01.example.internal" http://node01:30080
```

You should see something like:

```text
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100    18  100    18    0     0   1589      0 --:--:-- --:--:-- --:--:--  1636
This is Website 1
```

**Step 23.** Sends an HTTP request to `http://node01:30080` and prints the answer.

```bash
curl -H "Host: website02.example.internal" http://node01:30080
```

You should see something like:

```text
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100    18  100    18    0     0  10928      0 --:--:-- --:--:-- --:--:-- 18000
This is Website 2
```

### If you see something else

- The check says: _There is no Ingress name-virtual-host-ingress with ingressClassName nginx._
- The check says: _The ingress-nginx controller is not installed in the namespace ingress-nginx with node port 30080._
- The check says: _curl -H "Host: website01.example.internal" http://node01:30080 does not show "This is Website 1" (or website02 "This is Website 2") yet._
- An Ingress does nothing until a controller runs: `kubectl get ingressclass` shows `nginx` once ingress-nginx is installed.
- `kubectl exec service-pod-1 -- bash -c 'echo "This is Website 1" > /usr/share/nginx/html/index.html'` changes the page without an interactive shell.

### Why it works

**Why it works.** An Ingress is only a set of rules: host and path → Service. An Ingress controller (here ingress-nginx, exposed on node port 30080) reads those rules and does the routing. It picks the backend from the HTTP Host header, so one IP and port serve both websites. `ingressClassName: nginx` says which controller should handle the Ingress.

**Note:** ingress-nginx is retired; the Gateway API is its successor and is on the current CKA curriculum.

---

## Lab 4.11: Service accounts

### What you will do

Follow [service-account.md](https://github.com/kumbulanit/CKA/blob/main/Networking/Services%20and%20Networking/service-account.md)
and [sa-pointers.md](https://github.com/kumbulanit/CKA/blob/main/Networking/Services%20and%20Networking/sa-pointers.md):

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
default              default                                       4m12s
ingress-nginx        default                                       66s
ingress-nginx        ingress-nginx                                 51s
kube-node-lease      default                                       4m12s
kube-public          default                                       4m12s
kube-system          attachdetach-controller                       4m16s
kube-system          bootstrap-signer                              4m17s
kube-system          certificate-controller                        4m16s
kube-system          clusterrole-aggregation-controller            4m18s
kube-system          coredns                                       4m19s
kube-system          cronjob-controller                            4m17s
kube-system          daemon-set-controller                         4m18s
kube-system          default                                       4m12s
kube-system          deployment-controller                         4m13s
kube-system          device-taint-eviction-controller              4m15s
kube-system          disruption-controller                         4m16s
kube-system          endpoint-controller                           4m17s
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
backend-pod-1   1/1     Running   0          3m47s
backend-pod-2   1/1     Running   0          3m47s
frontend-pod    1/1     Running   0          3m47s
nginx           1/1     Running   0          2m18s
nginx2          1/1     Running   0          2m16s
service-pod-1   1/1     Running   0          105s
service-pod-2   1/1     Running   0          105s
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
Node:             node01/192.168.147.2
Start Time:       Tue, 27 Oct 2026 12:56:59 +0000
Labels:           run=app-pod
Annotations:      <none>
Status:           Running
IP:               10.244.3.16
IPs:
  IP:  10.244.3.16
Containers:
  app-pod:
    Container ID:   containerd://c7e9b25bdce77aed7f934e660e6072bbed30be1b5c1a42a087d1206c02098280
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
eyJhbGciOiJSUzI1NiIsImtpZCI6IkJDWWFjS0ROYTcxS2JiaUFhb3pWaHB2QTIwb0VmcmxzdFRQSzBUTXVvVmcifQ.eyJhdWQiOlsiaHR0cHM6Ly9rdWJlcm5ldGVzLmRlZmF1bHQuc3ZjLmNsdXN0ZXIubG9jYWwiXSwiZXhwIjoxODI0NjQxODIwLCJpYXQiOjE3OTMxMDU4MjAsImlzcyI6Imh0dHBzOi8va3ViZXJuZXRlcy5kZWZhdWx0LnN2Yy5jbHVzdGVyLmxvY2FsIiwianRpIjoiZGZjY2VkOTYtZjBiZC00N2Q1LTlmZmUtYjU2NzUxNzViMWU2Iiwia3ViZXJuZXRlcy5pbyI6eyJuYW1lc3BhY2UiOiJkZWZhdWx0Iiwibm9kZSI6eyJuYW1lIjoibm9kZTAxIiwidWlkIjoiNjAxZjRhOTktNmIyZS00MjAwLTkxMTktNDNkM2NkOGMzMGFkIn0sInBvZCI6eyJuYW1lIjoiYXBwLXBvZCIsInVpZCI6ImY1ZDkxNDljLWM0ZDAtNDA0ZS1hNTAzLWQ0NzA3N2Q2ZWYyNSJ9LCJzZXJ2aWNlYWNjb3VudCI6eyJuYW1lIjoiZGVmYXVsdCIsInVpZCI6ImZjOTE5Y2E4LTFlMTItNDY2Yi1iYzRmLWYzMjA1OWM0ODc5MiJ9LCJ3YXJuYWZ0ZXIiOjE3OTMxMDk0Mjd9LCJuYmYiOjE3OTMxMDU4MjAsInN1YiI6InN5c3RlbTpzZXJ2aWNlYWNjb3VudDpkZWZhdWx0OmRlZmF1bHQifQ.kkLVNubgNHk5NN8mDeoP_IN4Eut5apZPyArxpePWR9euOm1fhA-rAWk9z4OKu2lOl_jpvePOxpwf2qBOZoUuXYZGlYsavmQvf3FBAyxB9ReaT-tIArnpsQ6avv8HlP89bnoLCei1_UiKNZK0MEX3lGnt0by5YfZMszzu3MwoORkVfzYGxkfn9LTc09JNhpioLxf95gRNrbHpBatweVP8RpiAusHqKQ1TfLjIxAgp07Ct5I0h11C2vdAvJsugdJjfj3uaVPQ4_0nhQ7UUQ86YbpvXJ7-hg6xzFYYXUmInHL5ANfomwHEEYL95ftMhPMboPLYU0M9SRSFkMkXTUP2s0w
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
default   4m15s
```

**Step 8.** Lists the service accounts in the namespace `kube-system`.

```bash
kubectl get sa -n kube-system
```

You should see something like:

```text
NAME                                          AGE
attachdetach-controller                       4m19s
bootstrap-signer                              4m20s
certificate-controller                        4m19s
clusterrole-aggregation-controller            4m21s
coredns                                       4m22s
cronjob-controller                            4m20s
daemon-set-controller                         4m21s
default                                       4m15s
deployment-controller                         4m16s
device-taint-eviction-controller              4m18s
disruption-controller                         4m19s
endpoint-controller                           4m20s
endpointslice-controller                      4m17s
endpointslicemirroring-controller             4m18s
ephemeral-volume-controller                   4m19s
expand-controller                             4m20s
generic-garbage-collector                     4m16s
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
No resources found in kplabs-test namespace.
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
Node:             node02/192.168.147.4
Start Time:       Tue, 27 Oct 2026 12:57:02 +0000
Labels:           run=nginx-pod
Annotations:      <none>
Status:           Running
IP:               10.244.1.19
IPs:
  IP:  10.244.1.19
Containers:
  nginx-pod:
    Container ID:   containerd://e424a0489f226a49cea1aaf39d1b857f86bf1952c10a3bcccb7cd038d60002a4
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
eyJhbGciOiJSUzI1NiIsImtpZCI6IkJDWWFjS0ROYTcxS2JiaUFhb3pWaHB2QTIwb0VmcmxzdFRQSzBUTXVvVmcifQ.eyJhdWQiOlsiaHR0cHM6Ly9rdWJlcm5ldGVzLmRlZmF1bHQuc3ZjLmNsdXN0ZXIubG9jYWwiXSwiZXhwIjoxODI0NjQxODIyLCJpYXQiOjE3OTMxMDU4MjIsImlzcyI6Imh0dHBzOi8va3ViZXJuZXRlcy5kZWZhdWx0LnN2Yy5jbHVzdGVyLmxvY2FsIiwianRpIjoiZDg3NjZjZjktNTJmYy00OWUyLTlhOWUtNjI2MTFmZWY0NWNiIiwia3ViZXJuZXRlcy5pbyI6eyJuYW1lc3BhY2UiOiJrcGxhYnMtdGVzdCIsIm5vZGUiOnsibmFtZSI6Im5vZGUwMiIsInVpZCI6ImRhZGY3ZTcxLTgwMjItNGEwZS05MTEwLWQ4ZDEzYzdjMzk3YyJ9LCJwb2QiOnsibmFtZSI6Im5naW54LXBvZCIsInVpZCI6ImZhYjZhMWRjLTA4ZGQtNGFkNC1iZjMyLTE2MGM4MzdlOWY5YyJ9LCJzZXJ2aWNlYWNjb3VudCI6eyJuYW1lIjoiZGVmYXVsdCIsInVpZCI6IjRkYjgxMTIyLTUzNWEtNGMzOC1iMzZkLWE3MDk2OTY2NzhlMSJ9LCJ3YXJuYWZ0ZXIiOjE3OTMxMDk0Mjl9LCJuYmYiOjE3OTMxMDU4MjIsInN1YiI6InN5c3RlbTpzZXJ2aWNlYWNjb3VudDprcGxhYnMtdGVzdDpkZWZhdWx0In0.O5aqmm-9VFJKOqM9Fp0DlomQmRT7jUeTSVAMibiUoUPq7OpHj1IJ7i-neJebRfRmef-oiMDoPrvvqQXsp_qK0La7SQJ9nes06SbOQZLKIhjHJe9xA3HWaXDKHRQWEIQoRmrtqrfEHY9qSynLJyA5PHW1eqXdvl0a7xNjSowx_x6WWorXFjZ8Eq8nfKoGuEfrS-g_Y_OunjVZgn2D3rot0qiRryhTNbE0Karo_s_3HvExSy10iEqmr4X50K9r5sPrYCBMc0MV4FtFPwOMu0zhi7T_6nbffElllwfzXWlr84IomCF_cSGPgaIYunahnwzjS6uy5oLEeTYF_4rPrxEmcw@@PB-STEP end@@
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

Follow [sa-practical.md](https://github.com/kumbulanit/CKA/blob/main/Networking/Services%20and%20Networking/sa-practical.md):

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

Follow [DNS for service discovery.md](https://github.com/kumbulanit/CKA/blob/main/Networking/DNS%20for%20service%20discovery.md),
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
Server:        10.96.0.10
Address:    10.96.0.10:53

** server can't find kubernetes.default: NXDOMAIN

** server can't find kubernetes.default: NXDOMAIN

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
