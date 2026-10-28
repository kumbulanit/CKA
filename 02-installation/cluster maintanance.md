### Cluster Maintenance in Kubernetes

Maintaining a Kubernetes cluster involves several activities to ensure its stability, performance, and security. Regular maintenance tasks help prevent issues, manage resources efficiently, and ensure high availability. Here’s a detailed guide on cluster maintenance, including common tasks, best practices, and examples.

---

### 1. **Cluster Upgrades**

**Objective**: Keep the Kubernetes cluster and its components up-to-date with the latest features, security patches, and performance improvements.

**Steps**:
1. **Plan the Upgrade**:
   - Review Kubernetes release notes and documentation for new features and breaking changes.
   - Test the upgrade process in a staging environment before applying it to production.

2. **On the course's minikube cluster**, one command upgrades every node, one minor version at a time (minikube v1.39 goes up to v1.37.0):
     ```sh
     minikube start --kubernetes-version=v1.37.0
     kubectl get nodes
     ```

   **On a kubeadm cluster** (the way the CKA exam does it, on the machines from `sudo ./scripts/one-server.sh`), upgrade node by node as in steps 3 and 4.

3. **kubeadm: Upgrade the Control Plane Node** (on `controlplane`; this example upgrades v1.36 to v1.37):
   - Point the package repository at the next minor version (`pkgs.k8s.io` has one repository per minor version):
     ```sh
     sudo sed -i 's|/v1.36/|/v1.37/|' /etc/apt/sources.list.d/kubernetes.list
     sudo apt update
     apt-cache madison kubeadm
     ```
   - Upgrade kubeadm, check the plan, and apply it:
     ```sh
     sudo apt-mark unhold kubeadm && sudo apt install -y kubeadm='1.37.1-1.1' && sudo apt-mark hold kubeadm
     sudo kubeadm upgrade plan
     sudo kubeadm upgrade apply v1.37.1
     ```
   - Drain the node, upgrade kubelet and kubectl, then make it schedulable again:
     ```sh
     kubectl drain controlplane --ignore-daemonsets
     sudo apt-mark unhold kubelet kubectl && sudo apt install -y kubelet='1.37.1-1.1' kubectl='1.37.1-1.1' && sudo apt-mark hold kubelet kubectl
     sudo systemctl daemon-reload && sudo systemctl restart kubelet
     kubectl uncordon controlplane
     ```
   - **Managed Services**: Use cloud provider tools or console for managed Kubernetes services.

4. **kubeadm: Upgrade Worker Nodes** (one at a time):
   - On the worker (`ssh node01`), switch the repository and upgrade kubeadm as above, then:
     ```sh
     sudo kubeadm upgrade node
     ```
   - From controlplane, drain the node:
     ```sh
     kubectl drain node01 --ignore-daemonsets --delete-emptydir-data
     ```
   - On the worker, upgrade kubelet and kubectl and restart the kubelet:
     ```sh
     sudo apt-mark unhold kubelet kubectl && sudo apt install -y kubelet='1.37.1-1.1' kubectl='1.37.1-1.1' && sudo apt-mark hold kubelet kubectl
     sudo systemctl daemon-reload && sudo systemctl restart kubelet
     ```
   - From controlplane, make it schedulable again:
     ```sh
     kubectl uncordon node01
     ```
   - Repeat for node02. You can only upgrade one minor version at a time (v1.36 to v1.37, not v1.36 to v1.38).

5. **Upgrade Add-ons**:
   - Upgrade add-ons like the network plugin (Calico), the metrics server and storage provisioners. kubeadm upgrades CoreDNS and kube-proxy for you.

6. **Verify Upgrade**:
   - Check the status of nodes and pods.
     ```sh
     kubectl get nodes
     kubectl get pods --all-namespaces
     ```

**Diagram: Upgrade Process**

```plaintext
+-------------------+                +-------------------+
|   Old Control     |                |   New Control     |
|   Plane Version   |                |   Plane Version   |
|                   |                |                   |
|  (e.g., v1.36.5)  |                |  (e.g., v1.37.1)  |
+--------+----------+                +--------+----------+
         |                                  |
         v                                  v
+--------+----------+                +--------+----------+
|   Old Nodes       |                |   New Nodes       |
|   (e.g., v1.36.5) |                |   (e.g., v1.37.1) |
+--------+----------+                +--------+----------+
```

---

### 2. **Resource Management**

**Objective**: Efficiently manage cluster resources, including CPU, memory, and storage, to ensure optimal performance and cost-effectiveness.

**Steps**:
1. **Monitor Resource Usage**:
   - Use monitoring tools like Prometheus and Grafana to track resource utilization.
   - Check resource usage with `kubectl top` (needs the metrics server, see *logging and monitoring*):
     ```sh
     kubectl top nodes
     kubectl top pods
     ```

2. **Scale Resources**:
   - **Horizontal Pod Autoscaling**: Automatically scale the number of pod replicas based on CPU or memory usage.
     ```yaml
     apiVersion: autoscaling/v2
     kind: HorizontalPodAutoscaler
     metadata:
       name: my-app-hpa
     spec:
       scaleTargetRef:
         apiVersion: apps/v1
         kind: Deployment
         name: my-app
       minReplicas: 1
       maxReplicas: 10
       metrics:
       - type: Resource
         resource:
           name: cpu
           target:
             type: Utilization
             averageUtilization: 50
     ```

     This is also the file [`cluster-maintanance-my-app-hpa.yaml`](./cluster-maintanance-my-app-hpa.yaml) in this folder: `kubectl apply -f cluster-maintanance-my-app-hpa.yaml`

3. **Manage Storage**:
   - Monitor and clean up unused PersistentVolumeClaims (PVCs) and volumes.
   - Optimize storage configurations and backups.

4. **Update Resource Requests and Limits**:
   - Adjust resource requests and limits for deployments to match actual usage.

**Diagram: Resource Scaling**

```plaintext
+------------------------+        +------------------------+
|  Deployment with       |        |  Horizontal Pod        |
|  Resource Requests     |        |  Autoscaler             |
|  and Limits            |        |                        |
|  (e.g., 2 replicas)    |        |                        |
+----------+-------------+        +-----------+------------+
           |                                |
           |                                |
           v                                v
+----------+-------------+        +-----------+------------+
|   Pods with Dynamic    |        |   Pods Automatically    |
|   Scaling Based on     |        |   Scaled Up/Down        |
|   Resource Usage       |        |   (e.g., 5 replicas)   |
+------------------------+        +------------------------+
```

---

### 3. **Security Management**

**Objective**: Ensure the security of the cluster by applying patches, configuring security policies, and monitoring for vulnerabilities.

**Steps**:
1. **Apply Security Patches**:
   - Regularly update Kubernetes components and container images to include security patches.

2. **Configure RBAC (Role-Based Access Control)**:
   - Define roles and role bindings to control access to cluster resources.

   **Example Role Definition**:
   ```yaml
   apiVersion: rbac.authorization.k8s.io/v1
   kind: Role
   metadata:
     name: pod-reader
   rules:
   - apiGroups: [""]
     resources: ["pods"]
     verbs: ["get", "list", "watch"]
   ```

   This is also the file [`cluster-maintanance-pod-reader.yaml`](./cluster-maintanance-pod-reader.yaml) in this folder: `kubectl apply -f cluster-maintanance-pod-reader.yaml`

3. **Use Network Policies**:
   - Define network policies to control traffic flow between pods.

   **Example Network Policy**:
   ```yaml
   apiVersion: networking.k8s.io/v1
   kind: NetworkPolicy
   metadata:
     name: allow-ingress
   spec:
     podSelector:
       matchLabels:
         role: frontend
     ingress:
     - from:
       - podSelector:
           matchLabels:
             role: backend
   ```

   This is also the file [`cluster-maintanance-allow-ingress.yaml`](./cluster-maintanance-allow-ingress.yaml) in this folder: `kubectl apply -f cluster-maintanance-allow-ingress.yaml`

4. **Monitor for Vulnerabilities**:
   - Use security scanning tools like Trivy or Clair to scan container images for vulnerabilities.

**Diagram: Security Management**

```plaintext
+------------------------+        +------------------------+
|   Kubernetes Cluster   |        |   Security Policies    |
|                        |        |   (e.g., RBAC, Network |
|                        |        |   Policies)            |
+----------+-------------+        +-----------+------------+
           |                                |
           |                                |
           v                                v
+----------+-------------+        +-----------+------------+
|   Pod Security and      |        |   Vulnerability         |
|   Access Control        |        |   Monitoring            |
|   (e.g., RBAC, Network  |        |   (e.g., Trivy, Clair)  |
|   Policies)             |        |                        |
+------------------------+        +------------------------+
```

---

### 4. **Backup and Disaster Recovery**

**Objective**: Ensure data protection and quick recovery in case of failures or data loss.

**Steps**:
1. **Backup etcd Data**:
   - Regularly back up etcd data to prevent data loss.
   - Use etcd’s built-in snapshot capabilities.

   **On the course's minikube cluster**, run `etcdctl` inside the etcd pod, with minikube's certificate files. The snapshot is saved on the control plane node:
   ```sh
   kubectl -n kube-system exec etcd-minikube -- etcdctl --endpoints=https://127.0.0.1:2379 \
     --cacert=/var/lib/minikube/certs/etcd/ca.crt \
     --cert=/var/lib/minikube/certs/etcd/server.crt \
     --key=/var/lib/minikube/certs/etcd/server.key \
     snapshot save /var/lib/minikube/etcd/etcd-backup.db
   kubectl -n kube-system exec etcd-minikube -- etcdutl snapshot status /var/lib/minikube/etcd/etcd-backup.db --write-out=table
   ```

   **On a kubeadm cluster** (on `controlplane`; install the client first with `sudo apt install -y etcd-client`):
   ```sh
   sudo ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 \
     --cacert=/etc/kubernetes/pki/etcd/ca.crt \
     --cert=/etc/kubernetes/pki/etcd/server.crt \
     --key=/etc/kubernetes/pki/etcd/server.key \
     snapshot save /opt/etcd-backup.db
   ```

   Check the snapshot:
   ```sh
   sudo etcdutl snapshot status /opt/etcd-backup.db --write-out=table
   ```
   (If `etcdutl` is not installed, `sudo ETCDCTL_API=3 etcdctl snapshot status /opt/etcd-backup.db --write-out=table` works with older clients.)

2. **Backup Kubernetes Resources**:
   - Use tools like Velero to back up Kubernetes resources and volumes.

   **Example Velero Backup**:
   ```sh
   velero backup create my-backup --include-namespaces my-namespace
   ```

3. **Test Recovery Procedures**:
   - Regularly test backup restoration to ensure the recovery process works as expected.

**Diagram: Backup and Recovery**

```plaintext
+---------------------+        +---------------------+
|   Kubernetes        |        |   Backup Storage    |
|   Cluster           |        |   (e.g., S3, GCS)   |
|                     |        |                     |
+----------+----------+        +----------+----------+
           |                               |
           |                               |
           v                               v
+----------+----------+        +----------+----------+
|   etcd Snapshots    |        |   Kubernetes Backup |
|   (e.g., snapshot.db)|        |   (e.g., Velero)    |
+---------------------+        +---------------------+
           |
           |
           v
+----------+----------+
|   Disaster Recovery |
|   (e.g., Restore)   |
+---------------------+
```

---

### 5. **Monitoring and Logging**

**Objective**: Continuously monitor the health and performance of the cluster and collect logs for troubleshooting.

**Steps**:
1. **Set Up Monitoring**:
   - Use Prometheus and Grafana for cluster monitoring and visualization.

   **Example Prometheus Configuration**:
   ```yaml
   apiVersion: monitoring.coreos.com/v1
   kind: ServiceMonitor
   metadata:
     name: my-service-monitor
   spec:
     selector:
       matchLabels:
         app: my-app
     endpoints:
     - port: web
   ```

2. **Set Up Logging**:
   - Use a logging stack like ELK (Elasticsearch, Logstash, Kibana) or Fluentd + Elasticsearch + Kibana.

   **Example Fluentd Configuration**:
   ```xml
   <source>
     @type tail
     path /var/log/containers/*.log
     pos_file /var/log/fluentd.pos
     tag kubernetes.*
     <parse>
       @type json
     </parse>
   </source>
   ```

3. **Alerting**:
   - Configure alerts for critical conditions and thresholds.

   **Example Alerting Rule**:
   ```yaml
   groups:
   - name: example
     rules:
     - alert: HighMemoryUsage
       expr: container_memory_usage_bytes / container_spec_memory_limit_bytes > 0.9
       for: 5m
       annotations:
         summary: "High memory usage detected"
   ```

**Diagram: Monitoring and Logging**

```plaintext
+-------------------+        +-------------------+
|   Kubernetes      |        |   Monitoring      |
|   Cluster         |        |   (e.g., Prometheus|
|                   |        |   & Grafana)      |
+--------+----------+        +--------+----------+
         |                           |
         |                           |
         v                           v
+--------+----------+        +--------+----------+
|   Logs & Metrics  |        |   Alerts           |
|   (e.g., Fluentd, |        |   (e.g., Alertmanager|
|   ELK Stack)      |        |   & Grafana)       |
+-------------------+        +-------------------+
```

---

### Conclusion

Effective cluster maintenance is crucial for ensuring the stability, performance, and security of a Kubernetes cluster. By following best practices for upgrades, resource management, security, backup and recovery, and monitoring, you can maintain a robust and reliable Kubernetes environment. Regular maintenance activities and testing will help prevent issues and ensure smooth operation.

**Additional Resources**:
- **Kubernetes Documentation**: [https://kubernetes.io/docs/](https://kubernetes.io/docs/)
- **Prometheus Documentation**: [https://prometheus.io/docs/](https://prometheus.io/docs/)
- **Velero Documentation**: [https://velero.io/docs/](https://velero.io/docs/)

