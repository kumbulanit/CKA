# Monitor Cluster Components
  - Take me to [Video Tutuorials](https://kodekloud.com/topic/monitor-cluster-components/)
  
In this section, we will take a look at monitoring kubernetes cluster

#### How do you monitor resource consumption in kubernetes? or more importantly, what would you like to monitor?
 
## Heapster vs Metrics Server
- Heapster is now deprecated and a slimmed down version was formed known as the **`metrics server`**.

  
## Metrics Server


#### How are the metrics generated for the PODs on these nodes?

  
## Metrics Server - Getting Started

  
- Deploy the metrics server from its latest release (the old `kubernetes-incubator/metrics-server` repository and its `deploy/1.8+` folder no longer exist)
  ```
  $ kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
  ```
- On a kubeadm cluster, let it accept the kubelets' self-signed certificates (see *how to setup metrics server and use for autoscaling.md*)
  ```
  $ kubectl -n kube-system patch deployment metrics-server --type=json -p '[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
  ```
  
- View the cluster performance
  ```
  $ kubectl top node
  ```
- View performance metrics of pod
  ```
  $ kubectl top pod
  ```
  
  
  
