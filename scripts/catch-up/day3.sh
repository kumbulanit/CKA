#!/usr/bin/env bash
# day3.sh [lab ...]: creates what the Day 3 labs (storage, logging and monitoring, cluster
# maintenance) leave in the cluster, as at the end of each lab, before its clean-up step.
# Use it when the class runs out of time: run it where kubectl works (on the minikube server, or as
# root on controlplane on a kubeadm cluster), for one lab
# (./day3.sh pv-pvc) or for the whole day (./day3.sh). ./day3.sh --list shows the labs.
#
# The troubleshooting labs set up their own broken scenarios: see 08-troubleshooting/00-practice-setup.md.
# Not done here, because they change the machines rather than the cluster: cordon/drain and the
# upgrade to v1.37.
# shellcheck source-path=SCRIPTDIR disable=SC2034
source "$(dirname "$0")/lib.sh"

LABS=(
  "pv-pvc|PersistentVolume pv-log, claim claim-log-1 and pod webapp using it (06-storage/10-practice-test-persistent-volume-claims)"
  "storage-class|local-path provisioner with myclaim and mypod (06-storage/11-storage-classes)"
  "local-storage|StorageClasses local-storage and delayed-volume-sc, local-pv on node01 (minikube-m02), local-pvc and pod nginx (06-storage/12-practice-test-storage-classes)"
  "metrics-server|metrics-server (--kubelet-insecure-tls), Deployment nginx with an HPA (07-logging-monitoring/03-metrics-server-and-autoscaling)"
  "monitor-pods|Pods elephant, lion and rabbit for kubectl top (07-logging-monitoring/04-practice-test-monitor-cluster-components)"
  "app-logs|Pods webapp-1 and webapp-2 that write logs (07-logging-monitoring/06-practice-test-managing-application-logs)"
  "prometheus|Prometheus and Grafana with Helm; heavy, so only when named (07-logging-monitoring/07-prometheus-and-grafana)"
  "etcd-backup|etcd snapshot in etcd's data folder (/opt/etcd-backup.db on kubeadm) (09-cluster-maintenance/02-cluster-maintenance)"
)
OPTIONAL=(prometheus)

lab_metrics_server() {
  kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
  kubectl -n kube-system get deployment metrics-server -o jsonpath='{.spec.template.spec.containers[0].args}' | grep -q kubelet-insecure-tls \
    || kubectl -n kube-system patch deployment metrics-server --type=json \
         -p '[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
  kubectl create deployment nginx --image=nginx --dry-run=client -o yaml | apply
  kubectl set resources deployment nginx --requests=cpu=50m
  kubectl expose deployment nginx --port=80 --target-port=80 --dry-run=client -o yaml | apply
  kubectl autoscale deployment nginx --cpu-percent=50 --min=1 --max=10 --dry-run=client -o yaml | apply
  echo "kubectl top nodes works once metrics-server is running (about a minute)."
}

lab_monitor_pods() {
  apply <<'EOF'
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
}

lab_app_logs() {
  run_pod webapp-1 --image=busybox:1.37 -- sh -c 'i=0; while true; do i=$((i+1)); echo "$(date) INFO USER$((i % 4 + 1)) logged in"; [ $((i % 5)) -eq 0 ] && echo "$(date) WARNING USER5 Failed to Login as the account is locked due to MANY FAILED ATTEMPTS."; sleep 2; done'
  apply <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: webapp-2
spec:
  containers:
  - name: simple-webapp
    image: busybox:1.37
    command: ["sh", "-c", "i=0; while true; do i=$((i+1)); echo \"$(date) INFO USER$((i % 4 + 1)) is viewing page2\"; [ $((i % 5)) -eq 0 ] && echo \"$(date) WARNING USER30 Order failed as the item is OUT OF STOCK.\"; sleep 2; done"]
  - name: db
    image: busybox:1.37
    command: ["sh", "-c", "while true; do echo \"$(date) INFO db ready\"; sleep 5; done"]
EOF
}

lab_prometheus() {
  command -v helm >/dev/null || die "helm is not installed: run ./day2.sh ingress, or install-cluster.sh, first"
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
  helm repo add grafana https://grafana.github.io/helm-charts
  helm repo update
  helm upgrade --install --timeout 15m prometheus prometheus-community/prometheus \
    --set server.persistentVolume.enabled=false --set alertmanager.persistence.enabled=false
  kubectl expose deployment prometheus-server --type=NodePort --name=prometheus-service --port=9090 --dry-run=client -o yaml | apply
  helm upgrade --install --timeout 15m grafana grafana/grafana
}

lab_pv_pvc() {
  # Every node: the pod can land on any of them (minikube's control plane runs pods too).
  for n in $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do on_node "$n" 'mkdir -p /var/log/webapp /pv/log'; done
  apply <<'EOF'
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-log
spec:
  accessModes:
    - ReadWriteMany
  capacity:
    storage: 100Mi
  hostPath:
    path: /pv/log
---
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: claim-log-1
spec:
  storageClassName: ""   # a volume you create yourself, not the default StorageClass
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 50Mi
---
apiVersion: v1
kind: Pod
metadata:
  name: webapp
spec:
  containers:
  - name: event-simulator
    image: kodekloud/event-simulator
    env:
    - name: LOG_HANDLERS
      value: file
    volumeMounts:
    - mountPath: /log
      name: log-volume
  volumes:
  - name: log-volume
    persistentVolumeClaim:
      claimName: claim-log-1
EOF
}

lab_storage_class() {
  kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.37/deploy/local-path-storage.yaml
  # A claim's storage class cannot be changed: an older myclaim (google-storage) goes first.
  if [ "$(kubectl get pvc myclaim -o jsonpath='{.spec.storageClassName}' 2>/dev/null)" != local-path ]; then
    kubectl delete pod mypod --ignore-not-found --wait
    kubectl delete pvc myclaim --ignore-not-found --wait
  fi
  apply <<'EOF'
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: myclaim
spec:
  accessModes: [ "ReadWriteOnce" ]
  storageClassName: local-path
  resources:
   requests:
     storage: 500Mi
---
apiVersion: v1
kind: Pod
metadata:
  name: mypod
spec:
  containers:
    - name: frontend
      image: nginx
      volumeMounts:
      - mountPath: "/var/www/html"
        name: web
  volumes:
    - name: web
      persistentVolumeClaim:
        claimName: myclaim
EOF
}

lab_local_storage() {
  on_node "$NODE1" 'mkdir -p /opt/vol1'
  apply <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-storage
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-io-priority-high
provisioner: kubernetes.io/portworx-volume
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: delayed-volume-sc
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: local-pv
spec:
  capacity:
    storage: 500Mi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage
  local:
    path: /opt/vol1
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - $NODE1
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: local-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 500Mi
  storageClassName: local-storage
---
apiVersion: v1
kind: Pod
metadata:
  name: nginx
  labels:
    name: nginx
spec:
    containers:
    - name: nginx
      image: nginx:alpine
      volumeMounts:
        - name: local-persistent-storage
          mountPath: /var/www/html
    volumes:
      - name: local-persistent-storage
        persistentVolumeClaim:
          claimName: local-pvc
EOF
}

lab_etcd_backup() {
  if [ -f /etc/kubernetes/pki/etcd/ca.crt ]; then
    # On controlplane of a kubeadm cluster, as in the lesson.
    need_root
    command -v etcdctl >/dev/null || apt-get install -y -q etcd-client
    ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 \
      --cacert=/etc/kubernetes/pki/etcd/ca.crt \
      --cert=/etc/kubernetes/pki/etcd/server.crt \
      --key=/etc/kubernetes/pki/etcd/server.key \
      snapshot save /opt/etcd-backup.db
    return
  fi
  # Elsewhere (minikube): etcdctl inside the etcd pod, with the certificate files etcd itself uses
  # (/var/lib/minikube/certs/etcd on minikube). The snapshot is saved in etcd's data folder on the
  # control plane node.
  local pod cmd dir
  pod=$(kubectl -n kube-system get pod -l component=etcd -o jsonpath='{.items[0].metadata.name}')
  cmd=$(kubectl -n kube-system get pod "$pod" -o jsonpath='{.spec.containers[0].command}')
  flag() { grep -o "\"--$1=[^\"]*\"" <<<"$cmd" | cut -d= -f2 | tr -d '"'; }
  dir=$(flag data-dir)
  kubectl -n kube-system exec "$pod" -- etcdctl --endpoints=https://127.0.0.1:2379 \
    --cacert="$(flag trusted-ca-file)" --cert="$(flag cert-file)" --key="$(flag key-file)" \
    snapshot save "$dir/etcd-backup.db"
  echo "Saved on node $CP in $dir/etcd-backup.db (minikube ssh, then: sudo ls -l $dir)"
}

run_labs "$@"
