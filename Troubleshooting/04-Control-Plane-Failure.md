# Control Plane Failure

  - Take me to [Lecture](https://kodekloud.com/topic/control-plane-failure/)
  
  - In this lecture we will use how to troubleshoot the Control Plane components.

  - To check the status of the nodes if they are healthy

    ```
    kubectl get nodes
    ```

  - To check the status of the pods if the are running

    ```
    kubectl get pods
    ```

  - To check the status of all the pods of the Control Plane components(if they are deployed with kubeadm tool) and make sure they are **`Running`**

    ```
    kubectl get pods -n kube-system
    ```


  - If the API server itself is down, `kubectl` cannot answer. On a kubeadm cluster, look at the containers directly on `controlplane` with `crictl` (containerd's CLI; `docker ps` does not exist on these nodes):

    ```
    sudo crictl ps -a | grep -E "kube-apiserver|etcd|scheduler|controller"
    sudo crictl logs <container-id>
    sudo ls /var/log/pods/
    ```

  - Static pod manifests are in `/etc/kubernetes/manifests/` on controlplane. The kubelet restarts a component whenever its manifest changes.

  - If the Control Plane components are deployed as services (not with kubeadm) then check the status of all the components


  - To check the status of **`kube-apiserver`** 

    ```
    service kube-apiserver status
    ```

  - To check the status of **`kube-controller-manager`** 

    ```
    service kube-controller-manager status
    ```

  - To check the status of **`kube-scheduler`** 

    ```
    service kube-scheduler status
    ```


  - To check the status of **`kubelet`** 

    ```
    service kubelet status
    ```

  - To check the status of **`kube-proxy`** on the worker nodes.

    ```
    service kube-proxy status
    ```

  - To check the logs of the Control Plane components deployed as Pods:

    ```
    kubectl logs kube-apiserver-controlplane -n kube-system
    ```


  - To check the logs of the Control Plane components deployed as SystemD Service

    ```
    sudo journalctl -u kube-apiserver
    ```


