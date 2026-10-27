#### Documentation Referenced in Video

https://kubernetes.io/docs/tasks/inject-data-application/define-command-argument-container/

#### Create POD without any commands or arguments.

##### commands.yaml

```sh
apiVersion: v1
kind: Pod
metadata:
  name: command
spec:
  containers:
  -  image: busybox
     name: count
```

This is also the file [`cmd-args-commands.yaml`](./cmd-args-commands.yaml) in this folder: `kubectl apply -f cmd-args-commands.yaml`

```sh
kubectl apply -f commands.yaml
```
```sh
kubectl get pods
kubectl describe pod command
```
busybox's default command (`sh`) exits straight away when it has no terminal, so this pod keeps restarting (`CrashLoopBackOff`) and you cannot `exec` into it. That is why the next examples give the container a command that keeps running.

#### Create POD with Command

Modify the POD contents to the following one.

```sh
apiVersion: v1
kind: Pod
metadata:
  name: command2
spec:
  containers:
  -  image: busybox
     name: count
     command: ["sleep","3600"]
```

This is also the file [`cmd-args-commands-2.yaml`](./cmd-args-commands-2.yaml) in this folder: `kubectl apply -f cmd-args-commands-2.yaml`

```sh
kubectl apply -f commands.yaml
```
```sh
kubectl get pods
kubectl exec -it command2 -- sh
```

#### Create POD with Command and Arguments

Modify the YAML file contents to the following one.

```sh
apiVersion: v1
kind: Pod
metadata:
  name: command3
spec:
  containers:
  -  image: busybox
     name: count
     command: ["sleep"]
     args: ["3600"]
```

This is also the file [`cmd-args-commands-3.yaml`](./cmd-args-commands-3.yaml) in this folder: `kubectl apply -f cmd-args-commands-3.yaml`

```sh
kubectl apply -f commands.yaml
```
```sh
kubectl get pods
```

#### Create POD with Arguments

Modify the YAML file contents to the following one.

```sh
apiVersion: v1
kind: Pod
metadata:
  name: command4
spec:
  containers:
  -  image: busybox
     name: count
     args: ["sleep","3600"]
```

This is also the file [`cmd-args-commands-4.yaml`](./cmd-args-commands-4.yaml) in this folder: `kubectl apply -f cmd-args-commands-4.yaml`

```sh
kubectl apply -f commands.yaml
```
```sh
kubectl get pods
kubectl exec -it command4 -- sh
```
