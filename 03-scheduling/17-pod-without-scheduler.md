> This lesson uses the minikube node names: `minikube` is the control plane, `minikube-m02` and `minikube-m03` the workers (`controlplane`, `node01` and `node02` on a kubeadm cluster).

There are two ways to run a pod without the scheduler: set `nodeName` yourself, or create a static pod that the kubelet runs on its own node.

#### Option 1: Set nodeName
If `kplabs-pod` from the Resource Limits lesson is still running, delete it first: `kubectl delete pod kplabs-pod`.


##### 17-pod-without-scheduler-kplabs-pod.yaml
```sh
apiVersion: v1
kind: Pod
metadata:
  name: kplabs-pod
spec:
  nodeName: minikube-m02
  containers:
  - name: kplabs-container
    image: nginx
```

This is also the file [`17-pod-without-scheduler-kplabs-pod.yaml`](./17-pod-without-scheduler-kplabs-pod.yaml) in this folder: `kubectl apply -f 17-pod-without-scheduler-kplabs-pod.yaml`

```sh
kubectl apply -f 17-pod-without-scheduler-kplabs-pod.yaml
kubectl get pods -o wide
kubectl delete -f 17-pod-without-scheduler-kplabs-pod.yaml
```

#### Option 2: Static pods
The kubelet runs every manifest it finds in its static pod folder. Find the folder in the kubelet configuration of the worker `minikube-m02`. The kubelet and its files are on the node, not on the server, so each command runs on the node: `minikube ssh -n minikube-m02 -- "<command>"` runs the command in quotes there and comes back to the server.
```sh
minikube ssh -n minikube-m02 -- "systemctl status kubelet --no-pager"
minikube ssh -n minikube-m02 -- "cat /etc/systemd/system/kubelet.service.d/10-kubeadm.conf"
minikube ssh -n minikube-m02 -- "sudo grep staticPodPath /var/lib/kubelet/config.yaml"
```
Output of the last one:
```
staticPodPath: /etc/kubernetes/manifests
```
If you run `sudo grep staticPodPath /var/lib/kubelet/config.yaml` on the server itself, it fails with *No such file or directory*: that file is only on the nodes.

It is `/etc/kubernetes/manifests`, as on any kubeadm node (minikube builds its nodes with kubeadm). Write a manifest there; the kubelet starts the pod straight away. Open a shell on the worker:
```sh
minikube ssh -n minikube-m02
```
These commands run on the worker `minikube-m02`, not on the server: write the file, then leave the worker with `exit`:
```sh
cat <<EOF | sudo tee /etc/kubernetes/manifests/static-web.yaml
apiVersion: v1
kind: Pod
metadata:
  name: static-web
spec:
  containers:
  - name: web
    image: nginx
EOF
exit
```

This is also the file [`17-pod-without-scheduler-static-web.yaml`](./17-pod-without-scheduler-static-web.yaml) in this folder. A static pod is not applied with kubectl: instead of writing it on the node, you can copy the file into the node's static pod folder, from this folder on the server: `minikube cp 17-pod-without-scheduler-static-web.yaml minikube-m02:/etc/kubernetes/manifests/static-web.yaml`

Back on the server, the pod runs on `minikube-m02`:
```sh
kubectl get pods -o wide
```

The pod is called `static-web-minikube-m02`: static pods get the node name as a suffix. `kubectl delete` does not remove it (the kubelet recreates it); delete the file instead:
```sh
minikube ssh -n minikube-m02 -- sudo rm /etc/kubernetes/manifests/static-web.yaml
```
