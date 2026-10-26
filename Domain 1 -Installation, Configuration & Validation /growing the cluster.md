### Growing the Kubernetes Cluster

Growing a Kubernetes cluster involves adding new nodes to increase its capacity, scalability, and reliability. This process is relatively straightforward using `kubeadm`.

### Prerequisites

1. **Existing Kubernetes Cluster**: Ensure you have an existing Kubernetes cluster set up using `kubeadm`.
2. **New Nodes**: Prepare new nodes with the same prerequisites as the initial cluster setup: steps 1–3 of [Kubernetes installation using kubeadm](./Kubernetes%20installation%20using%20kubeadm.md) (system preparation, containerd, and the Kubernetes packages).

### Steps to Add New Nodes

#### 1. Prepare the New Node

1. **Give the node its name** (this example adds `node03`):
   ```sh
   sudo hostnamectl set-hostname node03
   ```

2. **Add it to `/etc/hosts` on every node** (use the new node's IP address), and add the existing nodes to `/etc/hosts` on node03:
   ```sh
   echo "192.168.56.13 node03" | sudo tee -a /etc/hosts
   ```

3. **Run steps 1–3 of the installation guide on node03**: update the system, disable swap, load the kernel modules and sysctl settings, install and configure containerd, and install `kubeadm`, `kubelet` and `kubectl` from `pkgs.k8s.io` **with the same minor version as the cluster** (check it with `kubectl get nodes`).

#### 2. Retrieve Join Command from the Control Plane Node

On the control plane node (`controlplane`), run the following command to get the `kubeadm join` command, which includes the necessary token and discovery-token-ca-cert-hash:

```sh
kubeadm token create --print-join-command
```

**Example Output**:
```sh
kubeadm join controlplane:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>
```

#### 3. Join the New Node to the Cluster

Run the `kubeadm join` command on the new node:

```sh
sudo kubeadm join controlplane:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>
```

### Verifying the New Node

1. **Check the status of nodes**:
   ```sh
   kubectl get nodes
   ```

   **Example Output**:
   ```sh
   NAME           STATUS   ROLES           AGE   VERSION
   controlplane   Ready    control-plane   30m   v1.36.5
   node01         Ready    <none>          20m   v1.36.5
   node02         Ready    <none>          10m   v1.36.5
   node03         Ready    <none>          1m    v1.36.5
   ```

2. **Check the status of pods**:
   ```sh
   kubectl get pods --all-namespaces
   ```

### Diagram: Growing the Kubernetes Cluster

```plaintext
+-------------------------------------+
|            controlplane             |
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
|               node01                |
|                                     |
| +---------------------------------+ |
| |            kubelet              | |
| |            kube-proxy           | |
| |                                 | |
| |  - Container Runtime (containerd)| |
| |  - Pods                         | |
| +---------------------------------+ |
|                                     |
+-------------------------------------+
                 |
                 |
                 v
+-------------------------------------+
|               node02                |
|                                     |
| +---------------------------------+ |
| |            kubelet              | |
| |            kube-proxy           | |
| |                                 | |
| |  - Container Runtime (containerd)| |
| |  - Pods                         | |
| +---------------------------------+ |
|                                     |
+-------------------------------------+
                 |
                 |
                 v
+-------------------------------------+
|               node03                |
|                                     |
| +---------------------------------+ |
| |            kubelet              | |
| |            kube-proxy           | |
| |                                 | |
| |  - Container Runtime (containerd)| |
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

- **Kubernetes Official Documentation**: [https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/high-availability/](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/high-availability/)
- **kubeadm Documentation**: [https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/)
- **Books**: "Kubernetes Up & Running" by Kelsey Hightower, Brendan Burns, and Joe Beda

