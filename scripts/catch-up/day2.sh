#!/usr/bin/env bash
# day2.sh [lab ...]: creates what the Day 2 labs (workloads and scheduling, services and
# networking, security) leave in the cluster, as at the end of each lab, before its clean-up step.
# Use it when the class runs out of time: run it where kubectl works (on the minikube server, or as
# root on controlplane on a kubeadm cluster), for one lab
# (./day2.sh ingress) or for the whole day (./day2.sh). ./day2.sh --list shows the labs.
#
# Left out on purpose: node taints and the default-deny NetworkPolicy, because the lessons remove
# them again and they would stop later pods from running; and throwaway test pods.
# shellcheck source-path=SCRIPTDIR disable=SC2034
source "$(dirname "$0")/lib.sh"

sched="$repo/Scheduling/ Workloads & Scheduling"
sec="$repo/security/Domain 4 - Security"

LABS=(
  "labels|Pods pod-1, pod-2 (env=stage), pod-3 (env=prod) and nginx (env=dev) (labels)"
  "deployments|my-deployment (3 replicas) and kplabs-deployment updated to httpd, 10 replicas (deployment-cli, imp-dep-commands)"
  "workloads|kplabs-daemonset, kplabs-cronjob and kplabs-job (daemonset.yaml, cronjob.yaml, jobs.yaml)"
  "node-labels|Node labels disk=hdd/ssd/hdd and environment=production on node01 (minikube-m02), pods service-pod and kplabs-node-affinity (nodeSelector, node-affinity, node selectors)"
  "services|nginx-deployment behind kplabs-service-selector, namespace teama with an nginx pod (service-selector, namespace)"
  "ingress|Helm, ingress-nginx on NodePort 30080, service-pod-1/2 behind service1/2 and name-virtual-host-ingress (install-helm, ingress, deploy-ingress-controller)"
  "service-accounts|custom-sa with custom-pod, external with external-pod, Role pod-reader bound to external (sa-practical, authentication, authorization)"
  "secrets|Secrets firstsecret, secondsecret, thirdsecret, stringdata and pods secretmount, secret-env (secret-data, mounting-secrets)"
  "certificates|User zeal: key and certificate in ~/certificates, zeal-context, Role pod-reader in teama bound to zeal (certificate-steps, teama-role)"
  "security-context|Pods privileged, non-privileged and privileged1 (security-context-and-network-policy)"
)

lab_labels() {
  run_pod pod-1 --image=nginx
  run_pod pod-2 --image=nginx --labels=run=pod-2,env=stage
  run_pod pod-3 --image=nginx --labels=run=pod-3,env=prod
  run_pod nginx --image=nginx --labels=run=nginx,env=dev
}

lab_deployments() {
  kubectl create deployment my-deployment --image=nginx --replicas 3 --dry-run=client -o yaml | apply
  if ! kubectl get deployment kplabs-deployment >/dev/null 2>&1; then
    kubectl create deployment kplabs-deployment --image=nginx
    kubectl set image deployment/kplabs-deployment nginx=httpd
    kubectl annotate deployment/kplabs-deployment kubernetes.io/change-cause="image updated to httpd"
  fi
  kubectl scale deployment/kplabs-deployment --replicas=10
}

lab_workloads() {
  apply < "$sched/daemonset.yaml"
  apply < "$sched/cronjob.yaml"
  apply < "$sched/jobs.yaml"
}

lab_node_labels() {
  kubectl label node "$CP" disk=hdd --overwrite
  kubectl label node "$NODE1" disk=ssd environment=production --overwrite
  kubectl label node "$NODE2" disk=hdd --overwrite
  apply <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: service-pod
spec:
  containers:
  - name: service-pod
    image: nginx
  nodeSelector:
    disk: ssd
---
apiVersion: v1
kind: Pod
metadata:
  name: kplabs-node-affinity
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: disk
            operator: In
            values:
            - ssd
  containers:
  - name: with-node-affinity
    image: nginx
EOF
}

lab_services() {
  apply <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.27
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
   name: kplabs-service-selector
spec:
   selector:
     app: nginx
   ports:
   - port: 80
     targetPort: 80
EOF
  namespace teama
  run_pod nginx --image=nginx --namespace teama
}

lab_ingress() {
  if ! command -v helm >/dev/null; then
    need_root
    curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey | gpg --dearmor --yes -o /usr/share/keyrings/helm.gpg
    echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" > /etc/apt/sources.list.d/helm-stable-debian.list
    apt-get update -q && apt-get install -y -q helm
  fi
  helm upgrade --install --timeout 15m ingress-nginx ingress-nginx --repo https://kubernetes.github.io/ingress-nginx --namespace ingress-nginx --create-namespace \
    --set controller.service.type=NodePort --set controller.service.nodePorts.http=30080
  run_pod service-pod-1 --image=nginx
  run_pod service-pod-2 --image=nginx
  kubectl expose pod service-pod-1 --name service1 --port=80 --target-port=80 --dry-run=client -o yaml | apply
  kubectl expose pod service-pod-2 --name service2 --port=80 --target-port=80 --dry-run=client -o yaml | apply
  kubectl wait --for=condition=Ready pod/service-pod-1 pod/service-pod-2 --timeout=300s
  kubectl exec service-pod-1 -- sh -c 'echo "This is Website 1" > /usr/share/nginx/html/index.html'
  kubectl exec service-pod-2 -- sh -c 'echo "This is Website 2" > /usr/share/nginx/html/index.html'
  kubectl -n ingress-nginx rollout status deployment/ingress-nginx-controller --timeout=300s
  apply <<'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: name-virtual-host-ingress
spec:
  ingressClassName: nginx
  rules:
  - host: website01.example.internal
    http:
      paths:
      - pathType: Prefix
        path: "/"
        backend:
          service:
            name: service1
            port:
              number: 80
  - host: website02.example.internal
    http:
      paths:
      - pathType: Prefix
        path: "/"
        backend:
          service:
            name: service2
            port:
              number: 80
EOF
  local ip
  ip=$(kubectl get node "$NODE1" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
  echo "Try it: curl -H \"Host: website01.example.internal\" http://$ip:30080"

}

lab_service_accounts() {
  kubectl create serviceaccount custom-sa --dry-run=client -o yaml | apply
  kubectl create serviceaccount external --dry-run=client -o yaml | apply
  apply <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: custom-pod
spec:
  serviceAccountName: custom-sa
  containers:
  - image: nginx
    name: custom-pod
---
apiVersion: v1
kind: Pod
metadata:
  labels:
    run: external-pod
  name: external-pod
spec:
  serviceAccountName: external
  containers:
  - image: nginx
    name: external-pod
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: default
  name: pod-reader
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pods
  namespace: default
subjects:
- kind: User
  name: system:serviceaccount:default:external
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
EOF
  echo "A token for the external service account: kubectl create token external"
}

lab_secrets() {
  kubectl create secret generic firstsecret --from-literal=dbpassword=mypassword123 --dry-run=client -o yaml | apply
  local dir
  dir=$(mktemp -d)
  echo 'dbuser=admin' > "$dir/credentials.txt"
  kubectl create secret generic secondsecret --from-file="$dir/credentials.txt" --dry-run=client -o yaml | apply
  rm -r "$dir"
  apply <<'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: thirdsecret
type: Opaque
data:
  username: ZGJhZG1pbg==
  password: bXlwYXNzd29yZDEyMw==
---
apiVersion: v1
kind: Secret
metadata:
  name: stringdata
type: Opaque
stringData:
 config.yaml: |-
   username: dbadmin
   password: mypassword
---
apiVersion: v1
kind: Pod
metadata:
  name: secretmount
spec:
  containers:
  - name: secretmount
    image: nginx
    volumeMounts:
    - name: foo
      mountPath: "/etc/foo"
      readOnly: true
  volumes:
  - name: foo
    secret:
      secretName: firstsecret
---
apiVersion: v1
kind: Pod
metadata:
  name: secret-env
spec:
  containers:
  - name: secret-env
    image: nginx
    env:
      - name: SECRET_USERNAME
        valueFrom:
          secretKeyRef:
            name: firstsecret
            key: dbpassword
  restartPolicy: Never
EOF
}

lab_certificates() {
  local dir=$HOME/certificates   # /root/certificates as root on controlplane, as in the lesson
  mkdir -p "$dir"
  cd "$dir" || return
  if [ ! -s zeal.crt ]; then
    [ -f zeal.key ] || openssl genrsa -out zeal.key 2048
    openssl req -new -key zeal.key -out zeal.csr -subj "/CN=zeal/O=kplabs"
    kubectl delete csr zeal-csr --ignore-not-found
    kubectl apply -f - <<EOF
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: zeal-csr
spec:
  groups:
  - system:authenticated
  request: $(base64 < zeal.csr | tr -d '\n')
  signerName: kubernetes.io/kube-apiserver-client
  usages:
  - digital signature
  - key encipherment
  - client auth
EOF
    kubectl certificate approve zeal-csr
    for _ in $(seq 1 30); do
      kubectl get csr zeal-csr -o jsonpath='{.status.certificate}' | base64 -d > zeal.crt
      [ -s zeal.crt ] && break
      sleep 1
    done
  fi
  kubectl config set-credentials zeal --client-certificate="$dir/zeal.crt" --client-key="$dir/zeal.key"
  kubectl config set-context zeal-context --cluster "$CLUSTER" --user=zeal
  cd - >/dev/null || return
  namespace teama
  apply < "$sec/teama-role.yaml"
  apply < "$sec/teama-rolebinding.yaml"
  echo "Try it: kubectl --context=zeal-context get pods -n teama"
}

lab_security_context() {
  apply < "$sec/privileged.yaml"
  apply < "$sec/capabilities.yaml"
}

run_labs "$@"
