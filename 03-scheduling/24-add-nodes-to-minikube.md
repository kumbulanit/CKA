
> The course's minikube cluster already has 3 nodes (`sudo ./setup.sh` starts it with `--nodes=3`); this page shows how to add or remove more. On a kubeadm cluster, adding a node is the *growing the cluster* lesson.

Adding new nodes to a Minikube cluster involves configuring Minikube to use multiple nodes, which effectively creates a multi-node Kubernetes cluster on your local machine. Here’s how you can do it:

### 1. **Start Minikube with Multiple Nodes:**
   You can start Minikube with a specified number of nodes by using the `--nodes` flag when starting the cluster.

   ```bash
   minikube start --nodes=3
   ```

   This command starts Minikube with 3 nodes (1 control plane and 2 worker nodes). You can increase the number based on your requirement.

### 2. **Add Nodes to an Existing Minikube Cluster:**
   If you already have a running Minikube cluster and want to add more nodes:

   ```bash
   minikube node add
   ```

   This will add one more node to your existing Minikube cluster: a worker, named `minikube-m04` for the fourth node. Give it the worker role name, as `setup.sh` does for the other two:

   ```bash
   kubectl label node minikube-m04 node-role.kubernetes.io/worker=
   ```

### 3. **View the Nodes:**
   After adding the nodes, you can check the nodes in your cluster using the `kubectl` command:

   ```bash
   kubectl get nodes
   ```

   This will list all the nodes, including the newly added ones, along with their status.

### 4. **Remove a Node:**
   If you want to remove a node from the cluster, you can do so with:

   ```bash
   minikube node delete <node-name>
   ```

   Replace `<node-name>` with the name of the node you want to remove. You can get the node names using `kubectl get nodes`.

### 5. **Stop Minikube:**
   To stop the entire Minikube cluster:

   ```bash
   minikube stop
   ```

### 6. **Delete the Minikube Cluster:**
   To delete the Minikube cluster and all nodes:

   ```bash
   minikube delete
   ```

