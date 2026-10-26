There are two ways to run a pod without the scheduler: set `nodeName` yourself, or create a static pod that the kubelet runs on its own node.

#### Option 1: Set nodeName
If `kplabs-pod` from the Resource Limits lesson is still running, delete it first: `kubectl delete pod kplabs-pod`.


##### kplabs-pod.yaml
```sh
apiVersion: v1
kind: Pod
metadata:
  name: kplabs-pod
spec:
  nodeName: node01
  containers:
  - name: kplabs-container
    image: nginx
```
```sh
kubectl apply -f kplabs-pod.yaml
kubectl get pods -o wide
kubectl delete -f kplabs-pod.yaml
```

#### Option 2: Static pods
The kubelet runs every manifest it finds in its static pod folder. Find the folder in the kubelet configuration:
```sh
systemctl status kubelet
cat /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
grep staticPodPath /var/lib/kubelet/config.yaml
```
On a kubeadm node it is `/etc/kubernetes/manifests`. Log in to node01 and write a manifest there; the kubelet starts the pod straight away:
```sh
ssh node01
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
kubectl get pods -o wide
```
The pod is called `static-web-node01`: static pods get the node name as a suffix. `kubectl delete` does not remove it (the kubelet recreates it); delete the file instead:
```sh
ssh node01 sudo rm /etc/kubernetes/manifests/static-web.yaml
```
