# Practice Setup: Breaking the Cluster on Purpose

The solutions in this folder come from practice labs where the cluster was already broken for you. On your own cluster (built with [Kubernetes installation using kubeadm](../Domain%201%20-Installation,%20Configuration%20&%20Validation%20/Kubernetes%20installation%20using%20kubeadm.md), nodes `controlplane`, `node01`, `node02`), run the command for a scenario first, then troubleshoot it with the matching solution.

Run everything as root on `controlplane` (`sudo -i`). Root SSH to the workers (step 8 of the installation guide) is needed for the worker node scenarios. Do one scenario at a time and fix it before the next.

## Application Failure (03-Solution-Application-Failure.md)

The script [scripts/two-tier-app.sh](./scripts/two-tier-app.sh) deploys the 2 tier application with the faults you name. Copy it to controlplane, then:

```sh
chmod +x two-tier-app.sh
./two-tier-app.sh alpha svc-name                          # 1. alpha
./two-tier-app.sh beta target-port                        # 2. beta
./two-tier-app.sh gamma selector                          # 3. gamma
./two-tier-app.sh delta db-user                           # 4. delta
./two-tier-app.sh epsilon db-user db-password             # 5. epsilon
./two-tier-app.sh zeta node-port db-user db-password      # 6. zeta
```

Each run deletes the previous scenario's namespace. The application is healthy when `curl http://node01:30081` shows **DATABASE CONNECTION SUCCESSFUL**.

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
sed -i 's/^\(\s*- \)kube-scheduler$/\1kube-schedulerrrr/' /etc/kubernetes/manifests/kube-scheduler.yaml
sleep 30
kubectl create deployment app --image=nginx
```

**2 and 3. Scaling does not happen** (then scale `app` to 2):
```sh
sed -i 's#--kubeconfig=/etc/kubernetes/controller-manager.conf#--kubeconfig=/etc/kubernetes/controller-manager-XXXX.conf#' /etc/kubernetes/manifests/kube-controller-manager.yaml
```

**4. Scaling stops again** (then scale `app` to 3):
```sh
sed -i 's#path: /etc/kubernetes/pki$#path: /etc/kubernetes/WRONG-PKI-DIRECTORY#' /etc/kubernetes/manifests/kube-controller-manager.yaml
```

## Worker Node Failure (09-Solution-Worker-Node-Failure.md)

**1. The kubelet is stopped:**
```sh
ssh node01 systemctl stop kubelet
```

**2. The kubelet cannot load its CA file:**
```sh
ssh node01 "sed -i 's#clientCAFile: /etc/kubernetes/pki/ca.crt#clientCAFile: /etc/kubernetes/pki/WRONG-CA-FILE.crt#' /var/lib/kubelet/config.yaml && systemctl restart kubelet"
```

**3. The kubelet uses the wrong API server port:**
```sh
ssh node01 "sed -i 's#:6443#:6553#' /etc/kubernetes/kubelet.conf && systemctl restart kubelet"
```

Each takes up to a minute before `kubectl get nodes` shows node01 `NotReady`.

## Network (10-Practice-Test-Troubleshoot-Network.md)

**Test 1, no network plugin:** delete any earlier scenario first (pods cannot be removed once the network plugin is gone), remove Calico, then deploy the application in `triton`. Its pods stay in `ContainerCreating`.
```sh
for ns in alpha beta gamma delta epsilon zeta triton; do kubectl delete namespace $ns --ignore-not-found; done
kubectl delete -f https://raw.githubusercontent.com/projectcalico/calico/v3.33.0/manifests/calico.yaml
./two-tier-app.sh triton
```

**Test 2, kube-proxy cannot find its configuration:**
```sh
kubectl -n kube-system get ds kube-proxy -o yaml \
  | sed 's#--config=/var/lib/kube-proxy/config.conf#--config=/var/lib/kube-proxy/configuration.conf#' \
  | kubectl replace -f -
./two-tier-app.sh triton
```

## Cleaning Up

```sh
for ns in alpha beta gamma delta epsilon zeta triton; do kubectl delete namespace $ns --ignore-not-found; done
kubectl delete deployment app --ignore-not-found
```
