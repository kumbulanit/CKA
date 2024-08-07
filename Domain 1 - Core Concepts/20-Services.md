# Kubernetes Services
  - Take me to [Video Tutorial](https://kodekloud.com/topic/services-3/)
  
In this section we will take a look at **`services`** in kubernetes

## Services
- Kubernetes Services enables communication between various components within and outside of the application.

  ![srv1](../../images/srv1.PNG)
  
#### Let's look at some other aspects of networking

## External Communication

- How do we as an **`external user`** access the **`web page`**?

  - From the node (Able to reach the application as expected)
  
    ![srv2](../../images/srv2.PNG)
    
  - From outside world (This should be our expectation, without something in the middle it will not reach the application)
  
    ![srv3](../../images/srv3.PNG)
   
    
 ## Service Types
 
 #### There are 3 types of service types in kubernetes
 
   ![srv-types](../../images/srv-types.PNG)
 
 1. NodePort
    - Where the service makes an internal port accessible on a port on the NODE.
      ```
      apiVersion: v1
      kind: Service
      metadata:
       name: myapp-service
      spec:
       types: NodePort
       ports:
       - targetPort: 80
         port: 80
         nodePort: 30008
      ```
     ![srvnp](../../images/srvnp.PNG)
      
      #### To connect the service to the pod
      ```
      apiVersion: v1
      kind: Service
      metadata:
       name: myapp-service
      spec:
       type: NodePort
       ports:
       - targetPort: 80
         port: 80
         nodePort: 30008
       selector:
         app: myapp
         type: front-end
       ```

    ![srvnp1](../../images/srvnp1.PNG)
      
      #### To create the service
      ```
      $ kubectl create -f service-definition.yaml
      ```
      
      #### To list the services
      ```
      $ kubectl get services
      ```
      
      #### To access the application from CLI instead of web browser
      ```
      To access a Kubernetes application exposed using a NodePort service, follow these steps:


### 4. Accessing the Application

To access the application, you need the external IP address of one of your nodes and the NodePort assigned to your service.

#### Find the NodePort

If you didn't specify a `nodePort` in your YAML file, Kubernetes will assign one automatically. You can find the NodePort by describing the service:

```sh
kubectl get service <my-app-service>
```

This will output something like:

```
NAME             TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)        AGE
my-app-service   NodePort    10.96.0.1     <none>        80:30008/TCP   5m
```

Here, `30008` is the NodePort.

#### Find the Node IP

The IP addresses of the nodes can be obtained using:

```sh
kubectl get nodes -o wide
```

This will output something like:

```
NAME           STATUS   ROLES    AGE   VERSION   INTERNAL-IP    EXTERNAL-IP
node1          Ready    <none>   30d   v1.21.0   192.168.1.1    34.123.45.67
node2          Ready    <none>   30d   v1.21.0   192.168.1.2    34.123.45.68
```

Use the `EXTERNAL-IP` of any of the nodes. If your nodes don't have an external IP, you might need to use the internal IP, depending on your network configuration.

### 5. Access the Application

Open a browser or use a tool like `curl` to access the application:

```sh
curl http://<NodeIP>:<NodePort>
```

For example, if your Node's external IP is `34.123.45.67` and the NodePort is `30008`, you can access the application at:

```sh
http://34.123.45.67:30007
```

### Note

- Ensure your cluster nodes have firewall rules allowing traffic on the NodePort range (default is 30000-32767).
- If you are running Kubernetes locally (e.g., with Minikube), you can use Minikube's IP:

```sh
minikube ip
```

Then access your application at:

```sh
http://<minikube-ip>:<NodePort>
```

By following these steps, you should be able to access your application exposed using a NodePort service in Kubernetes.
            
 1. ClusterIP
    - In this case the service creates a **`Virtual IP`** inside the cluster to enable communication between different services such as a set of frontend servers to a set of backend servers.
    
 1. LoadBalancer
    - Where the service provisions a **`loadbalancer`** for our application in supported cloud providers.
    
K8s Reference Docs:
- https://kubernetes.io/docs/concepts/services-networking/service/
- https://kubernetes.io/docs/tutorials/kubernetes-basics/expose/expose-intro/

