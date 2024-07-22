### Growing the Kubernetes Cluster

Growing a Kubernetes cluster involves adding new nodes to increase its capacity, scalability, and reliability. This process is relatively straightforward using `kubeadm`.

### Prerequisites

1. **Existing Kubernetes Cluster**: Ensure you have an existing Kubernetes cluster set up using `kubeadm`.
2. **New Nodes**: Prepare new nodes with the same prerequisites as the initial cluster setup (system preparation, Docker installation, and Kubernetes package installation).

### Steps to Add New Nodes

#### 1. Prepare the New Node

1. **Update the system**:
   ```sh
   sudo apt update && sudo apt upgrade -y
   ```

2. **Install necessary packages**:
   ```sh
   sudo apt install -y apt-transport-https ca-certificates curl
   ```

3. **Disable swap**:
   ```sh
   sudo swapoff -a
   sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
   ```

4. **Install Docker**:
   ```sh
   curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
   sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
   sudo apt update
   sudo apt install -y docker-ce docker-ce-cli containerd.io
   sudo systemctl start docker
   sudo systemctl enable docker
   ```

5. **Install kubeadm, kubelet, and kubectl**:
   ```sh
   curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
   sudo apt-add-repository "deb http://apt.kubernetes.io/ kubernetes-xenial main"
   sudo apt update
   sudo apt install -y kubeadm kubelet kubectl
   sudo apt-mark hold kubeadm kubelet kubectl
   ```

#### 2. Retrieve Join Command from the Master Node

On the master node, run the following command to get the `kubeadm join` command, which includes the necessary token and discovery-token-ca-cert-hash:

```sh
kubeadm token create --print-join-command
```

**Example Output**:
```sh
kubeadm join <master-ip>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>
```

#### 3. Join the New Node to the Cluster

Run the `kubeadm join` command on the new node:

```sh
sudo kubeadm join <master-ip>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>
```

### Verifying the New Node

1. **Check the status of nodes**:
   ```sh
   kubectl get nodes
   ```

   **Example Output**:
   ```sh
   NAME           STATUS   ROLES    AGE     VERSION
   master-node    Ready    master   30m     v1.20.1
   worker-node1   Ready    <none>   20m     v1.20.1
   worker-node2   Ready    <none>   10m     v1.20.1
   worker-node3   Ready    <none>   1m      v1.20.1
   ```

2. **Check the status of pods**:
   ```sh
   kubectl get pods --all-namespaces
   ```

### Diagram: Growing the Kubernetes Cluster

```plaintext
+-------------------------------------+
|             Master Node             |
|                                     |
| +---------------------------------+ |
| |        Control Plane            | |
| |                                 | |
| |  - kube-apiserver               | |
| |  - kube-controller-manager      | |
| |  - kube-scheduler               | |
| |  - etcd                         | |
| +---------------------------------+ |
|                                     |
+-------------------------------------+
                 |
                 |
                 v
+-------------------------------------+
|            Worker Node 1            |
|                                     |
| +---------------------------------+ |
| |            kubelet              | |
| |            kube-proxy           | |
| |                                 | |
| |  - Container Runtime (Docker)   | |
| |  - Pods                         | |
| +---------------------------------+ |
|                                     |
+-------------------------------------+
                 |
                 |
                 v
+-------------------------------------+
|            Worker Node 2            |
|                                     |
| +---------------------------------+ |
| |            kubelet              | |
| |            kube-proxy           | |
| |                                 | |
| |  - Container Runtime (Docker)   | |
| |  - Pods                         | |
| +---------------------------------+ |
|                                     |
+-------------------------------------+
                 |
                 |
                 v
+-------------------------------------+
|            Worker Node 3            |
|                                     |
| +---------------------------------+ |
| |            kubelet              | |
| |            kube-proxy           | |
| |                                 | |
| |  - Container Runtime (Docker)   | |
| |  - Pods                         | |
| +---------------------------------+ |
|                                     |
+-------------------------------------+
```

### Scaling Out Applications

After adding new nodes, you may want to scale out your applications to utilize the new capacity.

1. **Scale a deployment**:
   ```sh
   kubectl scale deployment <deployment-name> --replicas=<number-of-replicas>
   ```

   **Example**:
   ```sh
   kubectl scale deployment webapp-deployment --replicas=6
   ```

2. **Verify the scaled deployment**:
   ```sh
   kubectl get pods -l app=webapp
   ```

   **Example Output**:
   ```sh
   NAME                               READY   STATUS    RESTARTS   AGE
   webapp-deployment-5f7d9b7dd-2k8sx  1/1     Running   0          2m
   webapp-deployment-5f7d9b7dd-4j9tz  1/1     Running   0          2m
   webapp-deployment-5f7d9b7dd-8f4xk  1/1     Running   0          2m
   webapp-deployment-5f7d9b7dd-c8lk9  1/1     Running   0          2m
   webapp-deployment-5f7d9b7dd-mk7jx  1/1     Running   0          2m
   webapp-deployment-5f7d9b7dd-w7k9z  1/1     Running   0          2m
   ```

### Conclusion

Growing a Kubernetes cluster by adding new nodes is essential for scaling applications and maintaining high availability. By following the steps outlined above, you can seamlessly integrate new nodes into your existing cluster and verify their status. This ensures that your cluster can handle increased workloads and maintain performance.

### Additional Resources

- **Kubernetes Official Documentation**: [https://kubernetes.io/docs/setup/independent/high-availability/](https://kubernetes.io/docs/setup/independent/high-availability/)
- **kubeadm Documentation**: [https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/)
- **Books**: "Kubernetes Up & Running" by Kelsey Hightower, Brendan Burns, and Joe Beda

