# Namespaces
  - Take me to [Video Tutorial](https://kodekloud.com/topic/namespaces/)
  
In this section, we will take a look at **`Namespaces`**

So far in this course we have created **`Objects`** such as **`PODs`**, **`Deployments`** and **`Services`** in our cluster. Whatever we have been doing we have been doing in a **`NAMESPACE`**.
- This namespace is the **`default`** namespace in kubernetes. It is automatically created when kubernetes is setup initially.

 
- You can create your own namespaces as well.

  
- To list the pods in default namespace
  ```
  $ kubectl get pods
  ```
- To list the pods in another namespace. Use **`kubectl get pods`** command along with the **`--namespace`** flag or argument.
  ```
  $ kubectl get pods --namespace=kube-system
  ```
  
- Here we have a pod definition file, when we create a pod with pod-definition file, the pod is created in the default namespace.

```
apiVersion: v1
kind: Pod
metadata:
  name: myapp-pod
  labels:
     app: myapp
     type: front-end
spec:
  containers:
  - name: nginx-container
    image: nginx
 ```

This is also the file [`pod-definition.yaml`](./pod-definition.yaml) in this folder: `kubectl apply -f pod-definition.yaml`

  ```
  $ kubectl create -f pod-definition.yaml
  ```
- To create the pod with the pod-definition file in another namespace, use the **`--namespace`** option.
  ```
  $ kubectl create -f pod-definition.yaml --namespace=dev
  ```

- If you want to make sure that this pod gets you created in the **`dev`** env all the time, even if you don't specify in the command line, you can move the **`--namespace`** definition into the pod-definition file.
```
apiVersion: v1
kind: Pod
metadata:
  name: myapp-pod
  namespace: dev
  labels:
     app: myapp
     type: front-end
spec:
  containers:
  - name: nginx-container
    image: nginx
 ```

This is also the file [`18-namespaces-myapp-pod.yaml`](./18-namespaces-myapp-pod.yaml) in this folder: `kubectl apply -f 18-namespaces-myapp-pod.yaml`
  
  
- To create a new namespace, create a namespace definition as shown below and then run **`kubectl create`**
```
apiVersion: v1
kind: Namespace
metadata:
  name: dev
```

This is also the file [`namespace-dev.yaml`](./namespace-dev.yaml) in this folder: `kubectl apply -f namespace-dev.yaml`

  ```
  $ kubectl create -f namespace-dev.yaml
  ```
  Another way to create a namespace
  ```
  $ kubectl create namespace dev
  ```
  
- By default, we will be in a **`default`** namespace. To switch to a particular namespace permenently run the below command.
  ```
  $ kubectl config set-context $(kubectl config current-context) --namespace=dev
  ```
  The shorter form does the same: `kubectl config set-context --current --namespace=dev`. Switch back with `--namespace=default`.
- To view pods in all namespaces
  ```
  $ kubectl get pods --all-namespaces
  ```
  
- To limit resources in a namespace, create a resource quota. To create one start with **`ResourceQuota`** definition file.
```
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-quota
  namespace: dev
spec:
  hard:
    pods: "10"
    requests.cpu: "4"
    requests.memory: 5Gi
    limits.cpu: "10"
    limits.memory: 10Gi
```

This is also the file [`compute-quota.yaml`](./compute-quota.yaml) in this folder: `kubectl apply -f compute-quota.yaml`

  ```
  $ kubectl create -f compute-quota.yaml
  ```
  
K8s Reference Docs:
- https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/
- https://kubernetes.io/docs/tasks/administer-cluster/namespaces-walkthrough/
- https://kubernetes.io/docs/tasks/administer-cluster/namespaces/
- https://kubernetes.io/docs/tasks/administer-cluster/manage-resources/quota-memory-cpu-namespace/
- https://kubernetes.io/docs/tasks/access-application-cluster/list-all-running-container-images/
  
  
