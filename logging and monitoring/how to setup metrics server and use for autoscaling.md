### Setting Up Metrics Server in Kubernetes and Using It for Autoscaling

The Metrics Server is essential for enabling Kubernetes' autoscaling features like the Horizontal Pod Autoscaler (HPA). Below is a step-by-step guide on how to set up the Metrics Server in your Kubernetes cluster and configure it to use with autoscaling.

### Step 1: Deploy the Metrics Server
**on minikube use below commands** (the course's cluster; on a kubeadm cluster, skip to the next commands)

```
minikube addons enable metrics-server
kubectl get deployment metrics-server -n kube-system
kubectl top nodes
```



**on other kubernetes use the below**


1. **Apply the release manifest**:
   - The Metrics Server project publishes one manifest with the Deployment, Service, and Role-based Access Control (RBAC) configurations it needs.
   ```sh
   kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
   ```

2. **Allow the kubelets' self-signed certificates (kubeadm clusters)**:
   - kubeadm gives each kubelet a self-signed serving certificate, which the Metrics Server refuses by default (its pod stays `0/1` with `x509` errors in its logs). For a lab cluster, tell it to skip that check:
   ```sh
   kubectl -n kube-system patch deployment metrics-server --type=json \
     -p '[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
   ```

3. **Verify the installation**:
   - Check if the Metrics Server is running correctly.
   ```sh
   kubectl get deployment metrics-server -n kube-system
   ```
   - The output should show that the Metrics Server deployment is up and running.

### Step 2: Verify Metrics Collection

1. **View node metrics**:
   - After the Metrics Server is up, you can check the resource usage of your nodes.
   ```sh
   kubectl top nodes
   ```
   - This command will display the current CPU and memory usage of each node in the cluster.

2. **View pod metrics**:
   - Similarly, you can view the resource usage of pods.
   ```sh
   kubectl top pods --all-namespaces
   ```
   - This will show the CPU and memory usage for each pod in all namespaces.

### Step 3: Set Up Horizontal Pod Autoscaler (HPA)

The Horizontal Pod Autoscaler (HPA) automatically scales the number of pod replicas based on observed CPU or memory utilization, using the metrics provided by the Metrics Server.

1. **Create a sample deployment**:
   - Deploy a sample application (e.g., an NGINX deployment). The HPA calculates utilisation as a percentage of the CPU **request**, so the containers must have one:
   ```sh
   kubectl create deployment nginx --image=nginx
   kubectl set resources deployment nginx --requests=cpu=50m
   ```

2. **Expose the deployment**:
   - Create a service to expose the NGINX deployment.
   ```sh
   kubectl expose deployment nginx --port=80 --target-port=80
   ```

3. **Create an HPA based on CPU utilization**:
   - Set up the HPA to scale the number of replicas based on CPU usage.
   ```sh
   kubectl autoscale deployment nginx --cpu-percent=50 --min=1 --max=10
   ```

   In this example, the HPA is configured to maintain an average CPU utilization of 50% across all pods. If the CPU usage exceeds this threshold, the HPA will increase the number of replicas, up to a maximum of 10. If CPU usage drops, the HPA will scale down to a minimum of 1 replica.

4. **Verify the HPA configuration**:
   - Check the status of the HPA.
   ```sh
   kubectl get hpa
   ```
   - The output will show the current CPU utilization and the number of replicas.

### Step 4: Test the Autoscaling

1. **Simulate a load on the application**:
   - To see the HPA in action, simulate a load on the NGINX application. This can be done using tools like `kubectl run` or external load generators.

   Example:
   ```sh
   kubectl run -i --tty load-generator --rm --image=busybox:1.37 --restart=Never -- /bin/sh -c "while true; do wget -q -O- http://nginx.default.svc.cluster.local; done"
   ```
   Press Ctrl+C to stop the load (the pod is deleted when it exits).

2. **Observe the scaling behavior**:
   - As the CPU utilization increases due to the simulated load, the HPA should automatically scale the number of replicas of the NGINX deployment.
   - You can monitor this by repeatedly running:
   ```sh
   kubectl get hpa
   kubectl get pods -l app=nginx
   ```

3. **Scale down**:
   - Once the load is reduced or removed, the HPA will gradually scale down the number of replicas based on the decrease in CPU utilization.

   

### Conclusion

Setting up the Metrics Server in Kubernetes is a straightforward process, and it is essential for enabling autoscaling features like the Horizontal Pod Autoscaler. By following these steps, you can deploy the Metrics Server, verify its functionality, and set up an HPA to automatically adjust the number of pod replicas based on real-time metrics. This ensures that your applications can efficiently handle varying loads, scaling up during peak demand and scaling down to save resources during low demand.