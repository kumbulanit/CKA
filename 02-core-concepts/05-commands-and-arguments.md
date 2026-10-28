#### Documentation Referenced in Video

https://kubernetes.io/docs/tasks/inject-data-application/define-command-argument-container/

#### Create POD without any commands or arguments.

##### 05-commands-and-arguments-commands.yaml

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

This is also the file [`05-commands-and-arguments-commands.yaml`](./05-commands-and-arguments-commands.yaml) in this folder: `kubectl apply -f 05-commands-and-arguments-commands.yaml`

```sh
kubectl apply -f 05-commands-and-arguments-commands.yaml
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

This is also the file [`05-commands-and-arguments-commands-2.yaml`](./05-commands-and-arguments-commands-2.yaml) in this folder: `kubectl apply -f 05-commands-and-arguments-commands-2.yaml`

```sh
kubectl apply -f 05-commands-and-arguments-commands-2.yaml
```
```sh
kubectl get pods
kubectl exec -it command2 -- sh
```
This opens a shell inside the pod `command2`: what you type then runs in its container, not on the server. Leave it with `exit`.

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

This is also the file [`05-commands-and-arguments-commands-3.yaml`](./05-commands-and-arguments-commands-3.yaml) in this folder: `kubectl apply -f 05-commands-and-arguments-commands-3.yaml`

```sh
kubectl apply -f 05-commands-and-arguments-commands-3.yaml
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

This is also the file [`05-commands-and-arguments-commands-4.yaml`](./05-commands-and-arguments-commands-4.yaml) in this folder: `kubectl apply -f 05-commands-and-arguments-commands-4.yaml`

```sh
kubectl apply -f 05-commands-and-arguments-commands-4.yaml
```
```sh
kubectl get pods
kubectl exec -it command4 -- sh
```
This opens a shell inside the pod `command4`: what you type then runs in its container, not on the server. Leave it with `exit`.
