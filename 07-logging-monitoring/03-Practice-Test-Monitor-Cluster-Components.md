# Practice Test - Monitor Cluster Components
  - Take me to [Practice Test](https://kodekloud.com/topic/practice-test-monitor-cluster-components/)
  
#### Practice setup (your own cluster)

The test starts with a few pods running workloads: `elephant` uses memory, `lion` uses CPU, `rabbit` does almost nothing. Create them first:

```
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: elephant
spec:
  containers:
  - name: elephant
    image: busybox:1.37
    command: ["sh", "-c", "dd if=/dev/zero of=/fill/data bs=1M count=150; sleep 1d"]
    volumeMounts:
    - name: fill
      mountPath: /fill
  volumes:
  - name: fill
    emptyDir:
      medium: Memory
---
apiVersion: v1
kind: Pod
metadata:
  name: lion
spec:
  containers:
  - name: lion
    image: busybox:1.37
    command: ["sh", "-c", "while true; do :; done"]
    resources:
      limits:
        cpu: 200m
---
apiVersion: v1
kind: Pod
metadata:
  name: rabbit
spec:
  containers:
  - name: rabbit
    image: busybox:1.37
    command: ["sleep", "1d"]
EOF
```

This is also the file [`03-practice-test-monitor-cluster-components-elephant.yaml`](./03-practice-test-monitor-cluster-components-elephant.yaml) in this folder: `kubectl apply -f 03-practice-test-monitor-cluster-components-elephant.yaml`

Solutions to practice test - monitor cluster components
1.  <details>
    <summary>We have deployed a few PODs running workloads. Inspect it.</summary>

    ```
    kubectl get pods
    ```
    </details>
  
1.  <details>
    <summary>Let us deploy metrics-server to monitor the PODs and Nodes. Download the deployment files.</summary>

    ```
    mkdir kubernetes-metrics-server
    curl -L -o kubernetes-metrics-server/components.yaml https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
    ```
    </details>
  
1.  <details>
    <summary>Deploy the metrics-server by creating all the components downloaded.</summary>
    
    Run the 'kubectl create -f .' command from within the download folder. On minikube and kubeadm clusters, also add `--kubelet-insecure-tls` (see *how to setup metrics server and use for autoscaling.md*).
  
    ```
    cd kubernetes-metrics-server
    kubectl create -f .
    kubectl -n kube-system patch deployment metrics-server --type=json -p '[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
    ```
    </details>
    
1.  <details>
    <summary>It takes a few minutes for the metrics server to start gathering data.</summary>

    Run the `kubectl top node` command and wait for a valid output.
    
    ```
    kubectl top node
    ```
    </details>
  
1.  <details>
    <summary>Identify the node that consumes the most CPU(cores).</summary>

     Run the `kubectl top node` command

      ```
      kubectl top node
      ```

      Examine the `CPU(cores)` column of the output to get the answer.

      </details>
  
1.  <details>
    <summary>Identify the node that consumes the most Memory(bytes).</summary>
    Run the `kubectl top node` command
  
    ```
    $ kubectl top node
    ```

    Examine the `MEMORY(bytes)` column of the output to get the answer.

    </details>
  
1.  <details>
    <summary>Identify the POD that consumes the most Memory(bytes).</summary>

    Run the `kubectl top pod` command
  
    ```
    kubectl top pod
    ```

    Examine the `MEMORY(bytes)` column of the output to get the answer.

    </details>
  
1.  <details>

    <summary>Identify the POD that consumes the least CPU(cores).</summary>

    Run the `kubectl top pod` command
  
    ```
    kubectl top pod
    ```

    Examine the `CPU(cores)` column of the output to get the answer.

  </details>
  


