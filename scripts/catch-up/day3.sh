#!/usr/bin/env bash
# day3.sh [lab ...]: creates what the Day 3 labs (logging and monitoring, storage) leave in the
# cluster, as at the end of each lab, before its clean-up step.
# Use it when the class runs out of time: run it where kubectl works (on the minikube server, or as
# root on controlplane on a kubeadm cluster), for one lab
# (./day3.sh pv-pvc) or for the whole day (./day3.sh). ./day3.sh --list shows the labs.
#
# The troubleshooting labs set up their own broken scenarios: see 08-troubleshooting/00-Practice-Setup.md.
# shellcheck source-path=SCRIPTDIR disable=SC2034
source "$(dirname "$0")/lib.sh"

LABS=(
  "metrics-server|metrics-server (--kubelet-insecure-tls), Deployment nginx with an HPA (how to setup metrics server)"
  "monitor-pods|Pods elephant, lion and rabbit for kubectl top (03-Practice-Test-Monitor-Cluster-Components)"
  "app-logs|Pods webapp-1 and webapp-2 that write logs (06-Practice-Test-Managing-Application-Logs)"
  "prometheus|Prometheus and Grafana with Helm; heavy, so only when named (setting up promtheus)"
  "pv-pvc|PersistentVolume pv-log, claim claim-log-1 and pod webapp using it (10-Practice-Test-Persistent-Volume-Claims)"
  "storage-class|local-path provisioner with myclaim and mypod (12-Storage-Class)"
  "local-storage|StorageClasses local-storage and delayed-volume-sc, local-pv on node01 (minikube-m02), local-pvc and pod nginx (13-Practice-Test-Storage-Class)"
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
  for n in "$NODE1" "$NODE2"; do on_node "$n" 'mkdir -p /var/log/webapp /pv/log'; done
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

run_labs "$@"
