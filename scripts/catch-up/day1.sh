#!/usr/bin/env bash
# day1.sh [lab ...]: creates what the Day 1 labs (installation, configuration and validation;
# core concepts) leave in the cluster, as at the end of each lab, before its clean-up step.
# Use it when the class runs out of time: run it where kubectl works (on the minikube server, or as
# root on controlplane on a kubeadm cluster), for one lab
# (./day1.sh services) or for the whole day (./day1.sh). ./day1.sh --list shows the labs.
#
# Not done here, because they change the machines rather than the cluster: installing the
# cluster (use ../install-cluster.sh), adding node03, the upgrade to v1.37, and cordon/drain.
# shellcheck source-path=SCRIPTDIR disable=SC2034
source "$(dirname "$0")/lib.sh"

LABS=(
  "pod-yaml|Pods from YAML: nginxwebserver, nginx-pod, command to command4 (01-installation/02-first-pod-yaml, 03-standalone-pods; 02-core-concepts/03-first-pod-yaml, 05-commands-and-arguments, 06-expose-pods)"
  "standalone|Pods standalone-pod and test-pod (01-installation/04-standalone-pods-2)"
  "etcd-backup|etcd snapshot in /opt/etcd-backup.db (01-installation/06-cluster-maintenance)"
  "pods|Pods nginx, nginx-port and mywebserver (02-core-concepts/01-pods, 02-basic-pods, 04-pod-manifest-cli)"
  "namespaces|Namespace dev with myapp-pod and the compute-quota ResourceQuota (02-core-concepts/07-namespaces)"
  "deployments|Deployment myapp-deployment (02-core-concepts/08-deployments, 09-replicasets)"
  "services|Services myapp-service (NodePort 30008) and back-end (02-core-concepts/10-services-nodeport, 11-services-clusterip)"
  "webapp|webapp-deployment with 6 replicas and webapp-service (02-core-concepts/12-deployments-and-services, 01-installation/kubeadm-lesson-growing-the-cluster)"
)

lab_pods() {
  run_pod nginx --image nginx
  run_pod nginx-port --image=nginx --port=80
  run_pod mywebserver --image=nginx
}

lab_pod_yaml() {
  apply <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: nginxwebserver
spec:
  containers:
  -  image: nginx
     name: democontainer
---
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod
spec:
  containers:
  -  image: nginx
     name: democontainer
     ports:
       - containerPort: 8080
EOF
  # command has no command of its own: busybox exits at once and the pod restarts (the lesson's point).
  apply <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: command
spec:
  containers:
  -  image: busybox
     name: count
---
apiVersion: v1
kind: Pod
metadata:
  name: command2
spec:
  containers:
  -  image: busybox
     name: count
     command: ["sleep","3600"]
---
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
---
apiVersion: v1
kind: Pod
metadata:
  name: command4
spec:
  containers:
  -  image: busybox
     name: count
     args: ["sleep","3600"]
EOF
}

lab_namespaces() {
  # The pod first: once the quota exists, dev only accepts pods that set requests and limits.
  namespace dev
  apply <<'EOF'
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
EOF
  apply <<'EOF'
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
EOF
}

lab_deployments() {
  # The ReplicaSet lesson's myapp-replicaset selects the same pods (type: front-end), so it is
  # replaced by the Deployment, as in the lessons.
  kubectl delete replicationcontroller myapp-rc --ignore-not-found
  kubectl delete replicaset myapp-replicaset --ignore-not-found
  apply <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-deployment
  labels:
    app: myapp
    type: front-end
spec:
 template:
    metadata:
      name: myapp-pod
      labels:
        app: myapp
        type: front-end
    spec:
     containers:
     - name: nginx-container
       image: nginx
 replicas: 3
 selector:
   matchLabels:
    type: front-end
EOF
}

lab_services() {
  apply <<'EOF'
apiVersion: v1
kind: Service
metadata:
 name: myapp-service
spec:
 type: NodePort
 ports:
 - targetPort: 80
   port: 80
   nodePort: 30008
 selector:
   app: myapp
   type: front-end
---
apiVersion: v1
kind: Service
metadata:
 name: back-end
spec:
 type: ClusterIP
 ports:
 - targetPort: 80
   port: 80
 selector:
   app: myapp
   type: back-end
EOF
}

lab_webapp() {
  apply <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-deployment
spec:
  replicas: 6
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
    spec:
      containers:
      - name: webapp
        image: nginx:1.27
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: webapp-service
spec:
  selector:
    app: webapp
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
  type: ClusterIP
EOF
}

lab_standalone() {
  apply <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: standalone-pod
  labels:
    app: standalone-app
spec:
  containers:
  - name: standalone-container
    image: nginx
    ports:
    - containerPort: 80
---
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
spec:
  containers:
  - name: test-container
    image: busybox
    command: ['sh', '-c', 'echo Hello Kubernetes! && sleep 3600']
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
