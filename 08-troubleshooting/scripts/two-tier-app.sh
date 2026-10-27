#!/usr/bin/env bash
# two-tier-app <namespace> [fault ...]
# Creates the course's two-tier application (webapp-mysql + mysql) in <namespace>, with the faults
# from 08-troubleshooting/03-Solution-Application-Failure.md. All app namespaces (including this one)
# are deleted first, so the app starts fresh and web-service can use node port 30081.
# Faults: svc-name target-port selector db-user db-password node-port
set -euo pipefail
ns=$1; shift
faults=" $* "
has() { [[ $faults == *" $1 "* ]]; }

# mysql:5.6 is only built for amd64; MariaDB is a drop-in replacement on arm64 machines.
db_image=mysql:5.6
[ "$(kubectl get nodes -o jsonpath='{.items[0].status.nodeInfo.architecture}')" = arm64 ] && db_image=mariadb:10.11

for old in alpha beta gamma delta epsilon zeta triton; do
  kubectl delete namespace "$old" --ignore-not-found --timeout=180s >/dev/null
done
# Deleting a namespace finishes in the background; wait until the old one is gone.
for i in $(seq 1 90); do kubectl get namespace "$ns" >/dev/null 2>&1 || break; sleep 2; done
kubectl create namespace "$ns" >/dev/null
# A new namespace gets its default service account a moment later; pods need it.
until kubectl -n "$ns" get serviceaccount default >/dev/null 2>&1; do sleep 1; done

svc=mysql-service;   has svc-name    && svc=mysql
target=3306;         has target-port && target=8080
selector=mysql;      has selector    && selector=sql00001
user=root;           has db-user     && user=sql-user
password=paswrd;     has db-password && password=passwooooorrddd
nodeport=30081;      has node-port   && nodeport=30088

kubectl -n "$ns" apply -f - >/dev/null <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: mysql
  labels:
    name: mysql
spec:
  containers:
  - name: mysql
    image: $db_image
    env:
    - name: MYSQL_ROOT_PASSWORD
      value: $password
    ports:
    - containerPort: 3306
---
apiVersion: v1
kind: Service
metadata:
  name: $svc
spec:
  selector:
    name: $selector
  ports:
  - port: 3306
    targetPort: $target
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-mysql
  labels:
    name: webapp-mysql
spec:
  replicas: 1
  selector:
    matchLabels:
      name: webapp-mysql
  template:
    metadata:
      name: webapp-mysql
      labels:
        name: webapp-mysql
    spec:
      containers:
      - name: webapp-mysql
        image: mmumshad/simple-webapp-mysql
        env:
        - name: DB_Host
          value: mysql-service
        - name: DB_User
          value: $user
        - name: DB_Password
          value: paswrd
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: web-service
spec:
  type: NodePort
  selector:
    name: webapp-mysql
  ports:
  - port: 8080
    targetPort: 8080
    nodePort: $nodeport
EOF
echo "two-tier app created in namespace $ns"
