# Managing Application Logs
  - Take me to [Video Tutorial](https://kodekloud.com/topic/managing-application-logs/)

In this section, we will take a look at managing application logs

#### Let us start with logging in docker

 
 
#### Logs - Kubernetes
```
apiVersion: v1
kind: Pod
metadata:
  name: event-simulator-pod
spec:
  containers:
  - name: event-simulator
    image: kodekloud/event-simulator
```

This is also the file [`04-managing-application-logs-event-simulator-pod.yaml`](./04-managing-application-logs-event-simulator-pod.yaml) in this folder: `kubectl apply -f 04-managing-application-logs-event-simulator-pod.yaml`
 
- To view the logs
  ```
  $ kubectl logs -f event-simulator-pod
  ```
- Logs of the previous (crashed) container, and of every container in the pod
  ```
  $ kubectl logs event-simulator-pod --previous
  $ kubectl logs event-simulator-pod --all-containers
  ```
- The `kodekloud/event-simulator` image is built for amd64 only. On an arm64 machine (e.g. Apple Silicon), use busybox to simulate events:
  ```
  $ kubectl run event-simulator-pod --image=busybox:1.37 -- sh -c 'while true; do echo "$(date) INFO USER1 logged in"; sleep 2; done'
  ```
- If there are multiple containers in a pod then you must specify the name of the container explicitly in the command.
  ```
  $ kubectl logs -f <pod-name> -c <container-name>
  $ kubectl logs -f event-simulator-pod -c event-simulator
  ```

  
#### K8s Reference Docs
- https://kubernetes.io/docs/concepts/cluster-administration/logging/
 
