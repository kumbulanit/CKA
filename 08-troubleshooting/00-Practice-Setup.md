# Practice Setup: Breaking the Cluster on Purpose

The solutions in this folder come from practice labs where the cluster was already broken for you. On the course's minikube cluster (`sudo ./setup.sh`; nodes `minikube`, `minikube-m02`, `minikube-m03`), run the command for a scenario first, then troubleshoot it with the matching solution.

Run the commands on the server as your own user, in this folder (`cd ~/CKA/08-troubleshooting`). Commands for a node go through `minikube ssh` (`-n minikube-m02` for the first worker). Do one scenario at a time and fix it before the next.

> On a kubeadm cluster (nodes `controlplane`, `node01`, `node02`), run the same `sed` commands as root on the node itself. Its paths differ: certificates are in `/etc/kubernetes/pki` (not `/var/lib/minikube/certs`), and the API server listens on port `6443` (not `8443`).

## Application Failure (03-Solution-Application-Failure.md)

The script [scripts/two-tier-app.sh](./scripts/two-tier-app.sh) deploys the 2 tier application with the faults you name:

```sh
./scripts/two-tier-app.sh alpha svc-name                          # 1. alpha
./scripts/two-tier-app.sh beta target-port                        # 2. beta
./scripts/two-tier-app.sh gamma selector                          # 3. gamma
./scripts/two-tier-app.sh delta db-user                           # 4. delta
./scripts/two-tier-app.sh epsilon db-user db-password             # 5. epsilon
./scripts/two-tier-app.sh zeta node-port db-user db-password      # 6. zeta
```

Each run deletes the previous scenario's namespace. The application is healthy when `curl http://$(minikube ip):30081` shows **DATABASE CONNECTION SUCCESSFUL**.

The architecture:

| Object | Details |
| --- | --- |
| pod **mysql** (label `name=mysql`) | database, port 3306, `MYSQL_ROOT_PASSWORD=paswrd` |
| service **mysql-service** | ClusterIP, port 3306 → pod port 3306, selects `name=mysql` |
| deployment **webapp-mysql** | web app, port 8080, env `DB_Host=mysql-service`, `DB_User=root`, `DB_Password=paswrd` |
| service **web-service** | NodePort, port 8080, nodePort **30081**, selects `name=webapp-mysql` |

## Control Plane Failure (06-Solution-Control-Plane-Failure.md)

**1. The scheduler** (a pod of the deployment `app` stays `Pending`):
```sh
minikube ssh -- "sudo sed -i 's/^\(\s*- \)kube-scheduler\$/\1kube-schedulerrrr/' /etc/kubernetes/manifests/kube-scheduler.yaml"
sleep 30
kubectl create deployment app --image=nginx
```

**2 and 3. Scaling does not happen** (then scale `app` to 2):
```sh
minikube ssh -- "sudo sed -i 's#--kubeconfig=/etc/kubernetes/controller-manager.conf#--kubeconfig=/etc/kubernetes/controller-manager-XXXX.conf#' /etc/kubernetes/manifests/kube-controller-manager.yaml"
```

**4. Scaling stops again** (then scale `app` to 3):
```sh
minikube ssh -- "sudo sed -i 's#path: /var/lib/minikube/certs\$#path: /var/lib/minikube/WRONG-CERTS-DIRECTORY#' /etc/kubernetes/manifests/kube-controller-manager.yaml"
```

## Worker Node Failure (09-Solution-Worker-Node-Failure.md)

**1. The kubelet is stopped:**
```sh
minikube ssh -n minikube-m02 -- sudo systemctl stop kubelet
```

**2. The kubelet cannot load its CA file:**
```sh
minikube ssh -n minikube-m02 -- "sudo sed -i 's#clientCAFile: /var/lib/minikube/certs/ca.crt#clientCAFile: /var/lib/minikube/certs/WRONG-CA-FILE.crt#' /var/lib/kubelet/config.yaml && sudo systemctl restart kubelet"
```

**3. The kubelet uses the wrong API server port:**
```sh
minikube ssh -n minikube-m02 -- "sudo sed -i 's#:8443#:8553#' /etc/kubernetes/kubelet.conf && sudo systemctl restart kubelet"
```

Each takes up to a minute before `kubectl get nodes` shows minikube-m02 `NotReady`.

## Network (10-Practice-Test-Troubleshoot-Network.md)

**Test 1, no network plugin:** delete any earlier scenario first (pods cannot be removed once the network plugin is gone), remove Calico, then deploy the application in `triton`. Its pods stay in `ContainerCreating`.
```sh
for ns in alpha beta gamma delta epsilon zeta triton; do kubectl delete namespace $ns --ignore-not-found; done
kubectl delete -f https://raw.githubusercontent.com/projectcalico/calico/v3.33.0/manifests/calico.yaml
./scripts/two-tier-app.sh triton
```

**Test 2, kube-proxy cannot find its configuration:**
```sh
kubectl -n kube-system get ds kube-proxy -o yaml \
  | sed 's#--config=/var/lib/kube-proxy/config.conf#--config=/var/lib/kube-proxy/configuration.conf#' \
  | kubectl replace -f -
./scripts/two-tier-app.sh triton
```

## Cleaning Up

```sh
for ns in alpha beta gamma delta epsilon zeta triton; do kubectl delete namespace $ns --ignore-not-found; done
kubectl delete deployment app --ignore-not-found
```
