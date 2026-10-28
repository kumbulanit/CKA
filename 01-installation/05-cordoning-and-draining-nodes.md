### Cordoning and Draining Nodes in Kubernetes

> This lesson uses the minikube node names: `minikube` is the control plane, `minikube-m02` and `minikube-m03` the workers (`controlplane`, `node01` and `node02` on a kubeadm cluster).


Cordoning and draining nodes are crucial steps in Kubernetes cluster maintenance, especially when performing upgrades or other administrative tasks. These operations ensure that no new pods are scheduled on the node, and existing pods are gracefully removed or rescheduled to other nodes.

---

### **Cordoning Nodes**

**Objective**: Prevent new pods from being scheduled on a specific node.

**Steps**:

1. **Cordoning a Node**:
   - Use the `kubectl cordon` command to mark the node as unschedulable. This means that no new pods will be scheduled on this node, but existing pods will continue to run until they are manually removed or rescheduled.
   - **Command**:
     ```sh
     kubectl cordon <node-name>
     ```

2. **Verify Node Status**:
   - Check the status of the node to ensure that it is marked as unschedulable.
   - **Command**:
     ```sh
     kubectl get nodes
     ```
   - **Output** (after `kubectl cordon minikube-m02`):
     ```plaintext
     NAME           STATUS                     ROLES           AGE   VERSION
     minikube       Ready                      control-plane   30d   v1.36.5
     minikube-m02   Ready,SchedulingDisabled   worker          30d   v1.36.5
     minikube-m03   Ready                      worker          30d   v1.36.5
     ```

**Diagram: Cordoning Nodes**

```plaintext
+---------------------+
|  Cordon Node        |
+---------+-----------+
          |
          |
          v
+---------+-----------+
|  Node Marked as     |
|  Unschedulable      |
+---------------------+
```

---

### **Draining Nodes**

**Objective**: Safely remove all pods from a node, ensuring that workloads are rescheduled and no data is lost.

**Steps**:

1. **Drain the Node**:
   - Use the `kubectl drain` command to evict all pods from the node. This command will also handle DaemonSets and local data, which are not evicted by default.
   - **Command**:
     ```sh
     kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data
     ```
   - **Options**:
     - `--ignore-daemonsets`: Ignores DaemonSets, which run on all nodes. DaemonSets will continue to run on the node.
     - `--delete-emptydir-data`: Allows evicting pods that use `emptyDir` volumes; that data is lost. (This flag replaced `--delete-local-data`, which no longer exists.)

2. **Verify Pods Eviction**:
   - Check the status of the node to ensure that it is successfully drained and that all pods are rescheduled or removed.
   - **Command**:
     ```sh
     kubectl get nodes
     ```
   - **Output**:
     ```plaintext
     NAME           STATUS                     ROLES           AGE   VERSION
     minikube       Ready                      control-plane   30d   v1.36.5
     minikube-m02   Ready,SchedulingDisabled   worker          30d   v1.36.5
     minikube-m03   Ready                      worker          30d   v1.36.5
     ```

3. **Reboot or Maintain Node**:
   - Perform maintenance or reboot the node as required.

4. **Uncordon Node**:
   - After maintenance, use `kubectl uncordon` to make the node schedulable again.
   - **Command**:
     ```sh
     kubectl uncordon <node-name>
     ```

5. **Verify Node Readiness**:
   - Ensure that the node is back in service and ready to schedule new pods.
   - **Command**:
     ```sh
     kubectl get nodes
     ```

**Diagram: Draining Nodes**

```plaintext
+---------------------+
|  Drain Node         |
|  (Evict Pods)       |
+---------+-----------+
          |
          |
          v
+---------+-----------+
|  Pods Evicted       |
|  (or Rescheduled)   |
+---------+-----------+
          |
          |
          v
+---------+-----------+
|  Node Marked as     |
|  Unschedulable      |
+---------------------+
```

---

### **Example Scenario**

**Scenario**: You need to perform a rolling upgrade on a Kubernetes node. Here’s how you would handle it:

1. **Cordoning the Node**:
   ```sh
   kubectl cordon minikube-m02
   ```

2. **Draining the Node**:
   ```sh
   kubectl drain minikube-m02 --ignore-daemonsets --delete-emptydir-data
   ```

3. **Perform Upgrade or Maintenance**:
   - Perform required operations on `minikube-m02`.

4. **Restart the Node** (on minikube, stop and start it; on a kubeadm cluster, `sudo reboot` on the node):
   ```sh
   minikube node stop minikube-m02
   minikube node start minikube-m02
   ```

5. **Uncordon the Node**:
   ```sh
   kubectl uncordon minikube-m02
   ```

6. **Verify Node Readiness**:
   ```sh
   kubectl get nodes
   ```

---

### **Conclusion**

Cordoning and draining nodes are essential practices for managing Kubernetes clusters, particularly when performing maintenance or upgrades. By following these procedures, you ensure that workloads are properly managed, minimize disruptions, and maintain the overall health of the cluster.

**Additional Resources**:
- **Kubernetes Documentation on Draining Nodes**: [https://kubernetes.io/docs/concepts/scheduling-eviction/draining-node/](https://kubernetes.io/docs/concepts/scheduling-eviction/draining-node/)
- **Kubernetes Documentation on Cordoning Nodes**: [https://kubernetes.io/docs/concepts/scheduling-eviction/](https://kubernetes.io/docs/concepts/scheduling-eviction/)
