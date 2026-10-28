# Worker Node Failure

  - Take me to the [Lecture](https://kodekloud.com/topic/worker-node-failure/)

  - Lets check the status of the Nodes in the cluster, are they **`Ready`** or **`NotReady`**

    ```
    kubectl get nodes
    ```

  - If they are **`NotReady`** then check the **`LastHeartbeatTime`** of the node to find out the time when node might have crashed

    ```
    kubectl describe node minikube-m02
    ```



  - Log in to the node (`minikube ssh -n minikube-m02`; `ssh node01` on a kubeadm cluster) and check the possible **`CPU`**, **`MEMORY`** and disk usage using **`top`**, **`free -m`** and **`df -h`** 

 


  - Check the status and the logs of the **`kubelet`** for the possible issues.

    ```
    service kubelet status
    ```

    ```
    sudo journalctl -u kubelet
    ```
  
    
  - Check the **`kubelet`** Certificates, they are not expired, and in the right group and issued by the right CA.

    ```
    sudo openssl x509 -in /var/lib/kubelet/pki/kubelet-client-current.pem -noout -subject -issuer -dates
    sudo openssl x509 -in /var/lib/kubelet/pki/kubelet.crt -noout -subject -issuer -dates
    ```



