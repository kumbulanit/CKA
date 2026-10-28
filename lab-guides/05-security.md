# Module 5: Security

Each lab below is a practical from this repository, step by step: the command, what it does, and what it printed on the practice cluster. Names with random endings (pod names such as `nginx-7d9c…`), IP addresses and ages will differ on yours. The outputs show Kubernetes v1.36.4 (v1.37.0 after the upgrade lab), the newest version the practice cluster's images have; the cluster `setup.sh` makes runs v1.36.5, so the VERSION columns on yours say v1.36.5. Lab numbers are those of the labs in Desired Labs.

- [Lab 5.1: Authenticating with tokens](#lab-51-authenticating-with-tokens)
- [Lab 5.2: Authorisation with a Role](#lab-52-authorisation-with-a-role)
- [Lab 5.3: ClusterRoles and their bindings](#lab-53-clusterroles-and-their-bindings)
- [Lab 5.4: A user with a client certificate](#lab-54-a-user-with-a-client-certificate)
- [Lab 5.5: Secrets](#lab-55-secrets)
- [Lab 5.6: Secrets inside pods](#lab-56-secrets-inside-pods)
- [Lab 5.7: The API server's certificate](#lab-57-the-api-servers-certificate)
- [Lab 5.8: Security contexts](#lab-58-security-contexts)
- [Lab 5.9: A network policy](#lab-59-a-network-policy)

## Before you start

Start the practice cluster on your Ubuntu server, as in the [README](../README.md#the-practice-cluster):

```bash
git clone https://github.com/kumbulanit/CKA.git && cd CKA
sudo ./setup.sh          # minikube with three nodes, Kubernetes v1.36 (about 10 minutes the first time)
kubectl get nodes         # minikube, minikube-m02, minikube-m03
```

The steps use those node names, and `minikube ssh -n <node>` for commands on a node. Run `kubectl` as your own user on the server; commands on the control plane's files (`/etc/kubernetes/manifests`, the kubelet) go through `minikube ssh` with `sudo`. The outputs were recorded in Desired Labs, whose cluster is set out like minikube's (the API server on port 8443, certificates in `/var/lib/minikube/certs` and `~/.minikube`); its terminal is root on `minikube`, so prompts differ, and addresses and ages on yours will differ too.

## Lab 5.1: Authenticating with tokens

### What you will do

Follow [02-authentication-with-tokens.md](https://github.com/kumbulanit/CKA/blob/main/05-security/02-authentication-with-tokens.md):

1. Create the service account **external**.
2. Save a pod **external-pod** (`nginx`) to **pod-sa.yaml** with `--dry-run=client -o yaml`, add
   `serviceAccountName: external` under `spec`, and apply it. Look at the pod's YAML.
3. Read the token inside the pod (`/var/run/secrets/kubernetes.io/serviceaccount/token`).
4. Call the API server (`kubectl cluster-info` shows its address; save it with
   `APISERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')`) with
   `curl -k`, first without a token, then `/api/v1` with `--header "Authorization: Bearer <TOKEN>"`.
5. Get a token without a pod: `kubectl create token external`. Leave the pod running.

### Step by step

**Step 1.** Creates the service account `external`.

```bash
kubectl create serviceaccount external
```

You should see something like:

```text
serviceaccount/external created
```

**Step 2.** Writes the manifest of the pod `external-pod` without creating it.

```bash
kubectl run external-pod --image=nginx --dry-run=client -o yaml > pod-sa.yaml
```

It prints nothing when it works.

**Step 3.** Edits `pod-sa.yaml`: `spec:` becomes `spec:   serviceAccountName: external`. The edit: add the service account.

```bash
sed -i 's/^spec:$/spec:\n  serviceAccountName: external/' pod-sa.yaml
```

It prints nothing when it works.

**Step 4.** Creates the objects in `pod-sa.yaml`, or updates them if they exist.

```bash
kubectl apply -f pod-sa.yaml
```

You should see something like:

```text
pod/external-pod created
```

**Step 5.** Waits until the pod `external-pod` is Ready.

```bash
kubectl wait --for=condition=Ready pod/external-pod --timeout=120s
```

You should see something like:

```text
I1028 13:17:37.712892    3565 reflector.go:664] "Warning: watch ended with error" reflector="k8s.io/client-go/tools/watch/informerwatcher.go:162" type="*unstructured.Unstructured" err="an error on the server (\"unable to decode an event from the watch stream: context canceled\") has prevented the request from succeeding"
pod/external-pod condition met
```

**Step 6.** Lists the pods.

```bash
kubectl get pods
```

You should see something like:

```text
NAME           READY   STATUS    RESTARTS   AGE
external-pod   1/1     Running   0          22s
```

**Step 7.** Shows the pod `external-pod` as YAML, as the API server stores it.

```bash
kubectl get pod external-pod -o yaml
```

You should see something like:

```text
apiVersion: v1
kind: Pod
metadata:
  annotations:
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"v1","kind":"Pod","metadata":{"annotations":{},"labels":{"run":"external-pod"},"name":"external-pod","namespace":"default"},"spec":{"containers":[{"image":"nginx","name":"external-pod","resources":{}}],"dnsPolicy":"ClusterFirst","restartPolicy":"Always","serviceAccountName":"external"},"status":{}}
  creationTimestamp: "2026-10-28T13:17:15Z"
  generation: 1
  labels:
    run: external-pod
  name: external-pod
  namespace: default
  resourceVersion: "796"
  uid: 772d8a78-cb72-451c-8b53-a5549894597f
spec:
  containers:
  - image: nginx
    imagePullPolicy: Always
… (109 more lines)
```

**Step 8.** Saves `$TOKEN`: inside the pod `external-pod`, not on the server: shows the file `/var/run/secrets/kubernetes.io/serviceaccount/token`.

```bash
TOKEN=$(kubectl exec external-pod -- cat /var/run/secrets/kubernetes.io/serviceaccount/token)
```

It prints nothing when it works.

**Step 9.** Prints a value.

```bash
echo $TOKEN
```

You should see something like:

```text
eyJhbGciOiJSUzI1NiIsImtpZCI6Ikl3SzRTNTJUMHZkUTJlM25SY0QxLVlZM0U3WmRTd2NQS0pDM3pNOWQ3aGsifQ.eyJhdWQiOlsiaHR0cHM6Ly9rdWJlcm5ldGVzLmRlZmF1bHQuc3ZjLmNsdXN0ZXIubG9jYWwiXSwiZXhwIjoxODI0NzI5NDQyLCJpYXQiOjE3OTMxOTM0NDIsImlzcyI6Imh0dHBzOi8va3ViZXJuZXRlcy5kZWZhdWx0LnN2Yy5jbHVzdGVyLmxvY2FsIiwianRpIjoiYjFlMjE2OWEtMWU3OC00OGQ1LTg0NTAtMDYyNGJhYzkxMTJiIiwia3ViZXJuZXRlcy5pbyI6eyJuYW1lc3BhY2UiOiJkZWZhdWx0Iiwibm9kZSI6eyJuYW1lIjoibWluaWt1YmUtbTAyIiwidWlkIjoiZjI4MGZlNzEtNGVjMS00OWYwLWIzYzUtMjQxYjMxY2MzNmY3In0sInBvZCI6eyJuYW1lIjoiZXh0ZXJuYWwtcG9kIiwidWlkIjoiNzcyZDhhNzgtY2I3Mi00NTFjLThiNTMtYTU1NDk4OTQ1OTdmIn0sInNlcnZpY2VhY2NvdW50Ijp7Im5hbWUiOiJleHRlcm5hbCIsInVpZCI6IjE3NTViYzZlLTI0OTgtNDRhNi1hMzY0LWQ2YWUyOTZlZWZlOSJ9LCJ3YXJuYWZ0ZXIiOjE3OTMxOTcwNDl9LCJuYmYiOjE3OTMxOTM0NDIsInN1YiI6InN5c3RlbTpzZXJ2aWNlYWNjb3VudDpkZWZhdWx0OmV4dGVybmFsIn0.Xh8eSFBrLWyBzB7ajtBNrRN_XfV7DU3kE7rUQRPzZQQcNuWgq57UEJqe7-fz5Vwx4iz2VUqqMdw9eG__Is8GOz9rAxvrgjA4Ud6K3nIJFa2UHcFguDsm1P4uY_glBGNmgeh1etllXTADDS_YNu6pQQLEVNTOmWf7LFZFms0Fl5-oP5RDX_DpqyczkOmsItK-VPUzrilyrlJdlo-3sk0r-4GbDLohILvK8-LEXCVN3H5hJgxBaneFujHkQHJYMPV9dVcowoyA4K5_NnsJxQrA4dXb53xhrPPBLkj-1u5s3MyID0S-T5EJSaIllDaPUCckPFOsIpQdry8Nz6tQj0l0ZA
```

**Step 10.** Shows the addresses of the API server and CoreDNS.

```bash
kubectl cluster-info
```

You should see something like:

```text
Kubernetes control plane is running at https://192.168.147.3:8443
CoreDNS is running at https://192.168.147.3:8443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
```

**Step 11.** Saves `$APISERVER`: shows the kubeconfig.

```bash
APISERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
```

It prints nothing when it works.

**Step 12.** Sends an HTTP request to `the address` and prints the answer.

```bash
curl -k $APISERVER
```

You should see something like:

```text
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   217  100   217    0     0  27935      0 --:--:-- --:--:-- --:--:-- 31000
{
  "kind": "Status",
  "apiVersion": "v1",
  "metadata": {},
  "status": "Failure",
  "message": "forbidden: User \"system:anonymous\" cannot get path \"/\"",
  "reason": "Forbidden",
  "details": {},
  "code": 403
}@@PB-STEP 12@@
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0{
  "kind": "APIResourceList",
  "groupVersion": "v1",
… (570 more lines)
```

**Step 13.** Sends an HTTP request to `the address` and prints the answer.

```bash
curl -k $APISERVER/api/v1 --header "Authorization: Bearer $TOKEN"
```

**Step 14.** Creates a short-lived token for the service account `external`.

```bash
kubectl create token external
```

### If you see something else

- The check says: _There is no service account called external._
- The check says: _/root/pod-sa.yaml is missing, or has no `serviceAccountName: external`._
- The check says: _There is no running pod external-pod using the service account external._
- `serviceAccountName` goes directly under `spec`, next to `containers`.
- Without a token the API server treats you as `system:anonymous`; with the token it knows you as `system:serviceaccount:default:external`.

### Why it works

**Why it works.** Every request to the API server is first authenticated. A service account is an identity for software; the kubelet mounts a short-lived token for it into each pod that uses it. The token is a signed JWT naming `system:serviceaccount:default:external`, so the API server knows who is calling. Without any token you are `system:anonymous`, which may only reach a few discovery paths.

**Note:** since v1.24 service accounts no longer get a permanent token Secret; `kubectl create token` issues a short-lived one (one hour by default).

---

## Lab 5.2: Authorisation with a Role

![RBAC: who (subject) may do what (role), where (binding)](../images/rbac.svg)

*RBAC: who (subject) may do what (role), where (binding)*

### What you will do

Follow [03-authorization.md](https://github.com/kumbulanit/CKA/blob/main/05-security/03-authorization.md),
using a token of the service account **external** (`TOKEN=$(kubectl create token external)`):

1. With curl and the token, list the pods in `default`
   (`$APISERVER/api/v1/namespaces/default/pods`): it is **Forbidden**.
2. Write and apply **role.yaml**: a Role **pod-reader** in `default` that may `list` pods.
3. Write and apply **rolebinding.yaml**: a RoleBinding **read-pods** that gives pod-reader to the
   user `system:serviceaccount:default:external`.
4. Run the same curl again: now it lists the pods.

### Step by step

**Step 1.** Saves `$TOKEN`: creates a short-lived token for the service account `external`.

```bash
TOKEN=$(kubectl create token external)
```

It prints nothing when it works.

**Step 2.** Saves `$APISERVER`: shows the kubeconfig.

```bash
APISERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
```

It prints nothing when it works.

**Step 3.** Sends an HTTP request to `the address` and prints the answer.

```bash
curl -k $APISERVER/api/v1 --header "Authorization: Bearer $TOKEN"
```

You should see something like:

```text
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0{
  "kind": "APIResourceList",
  "groupVersion": "v1",
  "resources": [
    {
      "name": "bindings",
      "singularName": "binding",
      "namespaced": true,
      "kind": "Binding",
      "verbs": [
        "create"
      ]
    },
    {
      "name": "componentstatuses",
      "singularName": "componentstatus",
… (571 more lines)
```

**Step 4.** Sends an HTTP request to `the address` and prints the answer.

```bash
curl -k $APISERVER/api/v1/namespaces/default/pods --header "Authorization: Bearer $TOKEN"
```

**Step 5.** Writes the file `role.yaml`.

```bash
cat > role.yaml <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: default
  name: pod-reader
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["list"]
EOF
```

**Step 6.** Creates the objects in `role.yaml`, or updates them if they exist.

```bash
kubectl apply -f role.yaml
```

You should see something like:

```text
role.rbac.authorization.k8s.io/pod-reader created
```

**Step 7.** Lists the Roles.

```bash
kubectl get role
```

You should see something like:

```text
NAME         CREATED AT
pod-reader   2026-10-28T13:17:39Z
```

**Step 8.** Shows the details of the Role `pod-reader`, with its recent events at the bottom.

```bash
kubectl describe role pod-reader
```

You should see something like:

```text
Name:         pod-reader
Labels:       <none>
Annotations:  <none>
PolicyRule:
  Resources  Non-Resource URLs  Resource Names  Verbs
  ---------  -----------------  --------------  -----
  pods       []                 []              [list]
```

**Step 9.** Writes the file `rolebinding.yaml`.

```bash
cat > rolebinding.yaml <<'EOF'
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
```

It prints nothing when it works.

**Step 10.** Creates the objects in `rolebinding.yaml`, or updates them if they exist.

```bash
kubectl apply -f rolebinding.yaml
```

You should see something like:

```text
rolebinding.rbac.authorization.k8s.io/read-pods created
```

**Step 11.** Lists the RoleBindings.

```bash
kubectl get rolebinding
```

You should see something like:

```text
NAME        ROLE              AGE
read-pods   Role/pod-reader   0s
```

**Step 12.** Shows the details of the RoleBinding `read-pods`, with its recent events at the bottom.

```bash
kubectl describe rolebinding read-pods
```

You should see something like:

```text
Name:         read-pods
Labels:       <none>
Annotations:  <none>
Role:
  Kind:  Role
  Name:  pod-reader
Subjects:
  Kind  Name                                    Namespace
  ----  ----                                    ---------
  User  system:serviceaccount:default:external
```

**Step 13.** Sends an HTTP request to `the address` and prints the answer.

```bash
curl -k $APISERVER/api/v1/namespaces/default/pods --header "Authorization: Bearer $TOKEN"
```

You should see something like:

```text
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0{
  "kind": "PodList",
  "apiVersion": "v1",
  "metadata": {
    "resourceVersion": "801"
  },
  "items": [
    {
      "metadata": {
        "name": "external-pod",
        "namespace": "default",
        "uid": "772d8a78-cb72-451c-8b53-a5549894597f",
        "resourceVersion": "796",
        "generation": 1,
        "creationTimestamp": "2026-10-28T13:17:15Z",
        "labels": {
… (291 more lines)
```

### If you see something else

- The check says: _There is no Role pod-reader in default that may list pods._
- The check says: _There is no RoleBinding read-pods giving the Role pod-reader to system:serviceaccount:default:external._
- The check says: _The service account external still cannot list pods in default._
- A service account's token authenticates as the user `system:serviceaccount:<namespace>:<name>`; that is the subject to bind.
- `kubectl auth can-i list pods --as=system:serviceaccount:default:external` answers yes or no without curl.

### Why it works

**Why it works.** After authentication comes authorisation: on kubeadm clusters, RBAC. A Role lists what may be done (verbs on resources) in one namespace; a RoleBinding gives that Role to subjects (users, groups, service accounts). Nothing is allowed unless a binding allows it, so the first curl is Forbidden and the second, after the binding, lists the pods.

**In the exam:** `kubectl create role` and `kubectl create rolebinding` write the same objects quickly, and `kubectl auth can-i ... --as=...` proves the result.

---

## Lab 5.3: ClusterRoles and their bindings

### What you will do

Follow [04-clusterroles-and-bindings.md](https://github.com/kumbulanit/CKA/blob/main/05-security/04-clusterroles-and-bindings.md),
with the same token:

1. Delete the Role and RoleBinding from the last task (`kubectl delete -f role.yaml`, then
   `rolebinding.yaml`).
2. Write and apply **cluster-role.yaml**: a ClusterRole **pod-reader** that may `list` pods.
3. Write and apply **cluster-role-binding.yaml**: a ClusterRoleBinding **list-pods-global** giving
   it to `system:serviceaccount:default:external`. List pods in `default` with curl.
4. Create the namespace **external** and list its pods with curl: allowed everywhere.
5. Delete list-pods-global; the curl to `external` is Forbidden again.
6. Write and apply **clusterrole-to-rolebinding.yaml**: a **RoleBinding** read-pods in `default`
   that refers to the ClusterRole pod-reader. Curl both namespaces: only `default` works.

### Step by step

**Step 1.** Saves `$TOKEN`: creates a short-lived token for the service account `external`.

```bash
TOKEN=$(kubectl create token external)
```

It prints nothing when it works.

**Step 2.** Saves `$APISERVER`: shows the kubeconfig.

```bash
APISERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
```

It prints nothing when it works.

**Step 3.** Deletes the objects in `role.yaml`.

```bash
kubectl delete -f role.yaml
```

You should see something like:

```text
role.rbac.authorization.k8s.io "pod-reader" deleted from default namespace
```

**Step 4.** Deletes the objects in `rolebinding.yaml`.

```bash
kubectl delete -f rolebinding.yaml
```

You should see something like:

```text
rolebinding.rbac.authorization.k8s.io "read-pods" deleted from default namespace
```

**Step 5.** Writes the file `cluster-role.yaml`.

```bash
cat > cluster-role.yaml <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: pod-reader
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["list"]
EOF
```

It prints nothing when it works.

**Step 6.** Creates the objects in `cluster-role.yaml`, or updates them if they exist.

```bash
kubectl apply -f cluster-role.yaml
```

You should see something like:

```text
clusterrole.rbac.authorization.k8s.io/pod-reader created
```

**Step 7.** Lists the ClusterRoles.

```bash
kubectl get clusterrole
```

You should see something like:

```text
NAME                                                                   CREATED AT
admin                                                                  2026-10-28T13:15:48Z
cluster-admin                                                          2026-10-28T13:15:48Z
edit                                                                   2026-10-28T13:15:48Z
kindnet                                                                2026-10-28T13:15:51Z
kubeadm:get-nodes                                                      2026-10-28T13:15:49Z
local-path-provisioner-role                                            2026-10-28T13:15:52Z
pod-reader                                                             2026-10-28T13:17:40Z
system:aggregate-to-admin                                              2026-10-28T13:15:48Z
system:aggregate-to-edit                                               2026-10-28T13:15:48Z
system:aggregate-to-view                                               2026-10-28T13:15:48Z
system:auth-delegator                                                  2026-10-28T13:15:48Z
system:basic-user                                                      2026-10-28T13:15:48Z
system:certificates.k8s.io:certificatesigningrequests:nodeclient       2026-10-28T13:15:48Z
system:certificates.k8s.io:certificatesigningrequests:selfnodeclient   2026-10-28T13:15:48Z
system:certificates.k8s.io:kube-apiserver-client-approver              2026-10-28T13:15:48Z
system:certificates.k8s.io:kube-apiserver-client-kubelet-approver      2026-10-28T13:15:48Z
system:certificates.k8s.io:kubelet-serving-approver                    2026-10-28T13:15:48Z
… (57 more lines)
```

**Step 8.** Shows the details of the ClusterRole `pod-reader`, with its recent events at the bottom.

```bash
kubectl describe clusterrole pod-reader
```

You should see something like:

```text
Name:         pod-reader
Labels:       <none>
Annotations:  <none>
PolicyRule:
  Resources  Non-Resource URLs  Resource Names  Verbs
  ---------  -----------------  --------------  -----
  pods       []                 []              [list]
```

**Step 9.** Writes the file `cluster-role-binding.yaml`.

```bash
cat > cluster-role-binding.yaml <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: list-pods-global
subjects:
- kind: User
  name: system:serviceaccount:default:external
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
EOF
```

It prints nothing when it works.

**Step 10.** Creates the objects in `cluster-role-binding.yaml`, or updates them if they exist.

```bash
kubectl apply -f cluster-role-binding.yaml
```

You should see something like:

```text
clusterrolebinding.rbac.authorization.k8s.io/list-pods-global created
```

**Step 11.** Lists the ClusterRoleBindings.

```bash
kubectl get clusterrolebinding
```

You should see something like:

```text
NAME                                                            ROLE                                                                               AGE
cluster-admin                                                   ClusterRole/cluster-admin                                                          112s
kindnet                                                         ClusterRole/kindnet                                                                109s
kubeadm:apiserver-kubelet-client                                ClusterRole/system:kubelet-api-admin                                               111s
kubeadm:cluster-admins                                          ClusterRole/cluster-admin                                                          113s
kubeadm:get-nodes                                               ClusterRole/kubeadm:get-nodes                                                      111s
kubeadm:kubelet-bootstrap                                       ClusterRole/system:node-bootstrapper                                               111s
kubeadm:node-autoapprove-bootstrap                              ClusterRole/system:certificates.k8s.io:certificatesigningrequests:nodeclient       111s
kubeadm:node-autoapprove-certificate-rotation                   ClusterRole/system:certificates.k8s.io:certificatesigningrequests:selfnodeclient   111s
kubeadm:node-proxier                                            ClusterRole/system:node-proxier                                                    110s
list-pods-global                                                ClusterRole/pod-reader                                                             0s
local-path-provisioner-bind                                     ClusterRole/local-path-provisioner-role                                            108s
system:basic-user                                               ClusterRole/system:basic-user                                                      112s
system:controller:attachdetach-controller                       ClusterRole/system:controller:attachdetach-controller                              112s
system:controller:certificate-controller                        ClusterRole/system:controller:certificate-controller                               112s
system:controller:clusterrole-aggregation-controller            ClusterRole/system:controller:clusterrole-aggregation-controller                   112s
system:controller:cronjob-controller                            ClusterRole/system:controller:cronjob-controller                                   112s
system:controller:daemon-set-controller                         ClusterRole/system:controller:daemon-set-controller                                112s
… (44 more lines)
```

**Step 12.** Shows the details of the ClusterRoleBinding `list-pods-global`, with its recent events at the bottom.

```bash
kubectl describe clusterrolebinding list-pods-global
```

You should see something like:

```text
Name:         list-pods-global
Labels:       <none>
Annotations:  <none>
Role:
  Kind:  ClusterRole
  Name:  pod-reader
Subjects:
  Kind  Name                                    Namespace
  ----  ----                                    ---------
  User  system:serviceaccount:default:external
```

**Step 13.** Sends an HTTP request to `the address` and prints the answer.

```bash
curl -k $APISERVER/api/v1/namespaces/default/pods --header "Authorization: Bearer $TOKEN"
```

You should see something like:

```text
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0{
  "kind": "PodList",
  "apiVersion": "v1",
  "metadata": {
    "resourceVersion": "806"
  },
  "items": [
    {
      "metadata": {
        "name": "external-pod",
        "namespace": "default",
        "uid": "772d8a78-cb72-451c-8b53-a5549894597f",
        "resourceVersion": "796",
        "generation": 1,
        "creationTimestamp": "2026-10-28T13:17:15Z",
        "labels": {
… (292 more lines)
```

**Step 14.** Creates the namespace `external`.

```bash
kubectl create namespace external
```

**Step 15.** Sends an HTTP request to `the address` and prints the answer.

```bash
curl -k $APISERVER/api/v1/namespaces/external/pods --header "Authorization: Bearer $TOKEN"
```

You should see something like:

```text
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   110  100   110    0     0   2114      0 --:--:-- --:--:-- --:--:--  2115
{
  "kind": "PodList",
  "apiVersion": "v1",
  "metadata": {
    "resourceVersion": "809"
  },
  "items": []
}@@PB-STEP 15@@
clusterrolebinding.rbac.authorization.k8s.io "list-pods-global" deleted
```

**Step 16.** Deletes the ClusterRoleBinding `list-pods-global`.

```bash
kubectl delete clusterrolebinding list-pods-global
```

**Step 17.** Sends an HTTP request to `the address` and prints the answer.

```bash
curl -k $APISERVER/api/v1/namespaces/external/pods --header "Authorization: Bearer $TOKEN"
```

You should see something like:

```text
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   325  100   325    0     0  76362      0 --:--:-- --:--:-- --:--:-- 81250
{
  "kind": "Status",
  "apiVersion": "v1",
  "metadata": {},
  "status": "Failure",
  "message": "pods is forbidden: User \"system:serviceaccount:default:external\" cannot list resource \"pods\" in API group \"\" in the namespace \"external\"",
  "reason": "Forbidden",
  "details": {
    "kind": "pods"
  },
  "code": 403
}@@PB-STEP 17@@
```

**Step 18.** Writes the file `clusterrole-to-rolebinding.yaml`.

```bash
cat > clusterrole-to-rolebinding.yaml <<'EOF'
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
  kind: ClusterRole
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
EOF
```

**Step 19.** Creates the objects in `clusterrole-to-rolebinding.yaml`, or updates them if they exist.

```bash
kubectl apply -f clusterrole-to-rolebinding.yaml
```

You should see something like:

```text
rolebinding.rbac.authorization.k8s.io/read-pods created
```

**Step 20.** Sends an HTTP request to `the address` and prints the answer.

```bash
curl -k $APISERVER/api/v1/namespaces/external/pods --header "Authorization: Bearer $TOKEN"
```

You should see something like:

```text
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   325  100   325    0     0  75005      0 --:--:-- --:--:-- --:--:-- 81250
{
  "kind": "Status",
  "apiVersion": "v1",
  "metadata": {},
  "status": "Failure",
  "message": "pods is forbidden: User \"system:serviceaccount:default:external\" cannot list resource \"pods\" in API group \"\" in the namespace \"external\"",
  "reason": "Forbidden",
  "details": {
    "kind": "pods"
  },
  "code": 403
}@@PB-STEP 20@@
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0{
… (306 more lines)
```

**Step 21.** Sends an HTTP request to `the address` and prints the answer.

```bash
curl -k $APISERVER/api/v1/namespaces/default/pods --header "Authorization: Bearer $TOKEN"
```

### If you see something else

- The check says: _cluster-role-binding.yaml is missing, or the ClusterRoleBinding list-pods-global is still there (step 5 deletes it)._
- The check says: _The Role pod-reader should be deleted and the ClusterRole pod-reader created._
- The check says: _The RoleBinding read-pods in default does not refer to the ClusterRole pod-reader yet (step 6)._
- The check says: _external should be able to list pods in default but not in the namespace external._
- A ClusterRole has no namespace. Bound with a ClusterRoleBinding it applies in every namespace; bound with a RoleBinding, only in that RoleBinding's namespace.
- `kubectl auth can-i list pods -n external --as=system:serviceaccount:default:external` checks each step without curl.

### Why it works

**Why it works.** A ClusterRole is a Role without a namespace. What decides its reach is the binding: a ClusterRoleBinding grants it in every namespace (and for cluster-wide resources), while a RoleBinding that refers to a ClusterRole grants it only in the RoleBinding's own namespace. That lets you define a role once and hand it out namespace by namespace.

**In the exam:** a RoleBinding's `roleRef` cannot be changed after creation; delete and recreate the binding instead.

---

## Lab 5.4: A user with a client certificate

### What you will do

Follow [07-certificates-for-users.md](https://github.com/kumbulanit/CKA/blob/main/05-security/07-certificates-for-users.md)
from step 1 (kubectl is already set up here). First delete the RoleBinding from the last task:
`kubectl delete -f clusterrole-to-rolebinding.yaml`. Then:

1. In **~/certificates**, create the key **zeal.key** and a CSR **zeal.csr** with
   `-subj "/CN=zeal/O=kplabs"`.
2. Write **csr-requests.yaml**: a CertificateSigningRequest **zeal-csr** with the base64 CSR, signer
   `kubernetes.io/kube-apiserver-client` and usage `client auth`. Apply and approve it.
3. Save the issued certificate as **zeal.crt**.
4. Add the user **zeal** to your kubeconfig and a context **zeal-context** (cluster `minikube`).
   `kubectl --context=zeal-context get pods` is Forbidden.
5. Create the Role pod-reader and a RoleBinding read-pods for the user **zeal**, run the same command
   again (now it works), then delete both.

### Step by step

**Step 1.** Deletes the objects in `clusterrole-to-rolebinding.yaml`.

```bash
kubectl delete -f clusterrole-to-rolebinding.yaml
```

You should see something like:

```text
rolebinding.rbac.authorization.k8s.io "read-pods" deleted from default namespace
```

**Step 2.** Creates the folder `~/certificates`.

```bash
mkdir -p ~/certificates
```

It prints nothing when it works.

**Step 3.** Goes into `~/certificates`.

```bash
cd ~/certificates
```

It prints nothing when it works.

**Step 4.** Creates a private key `zeal.key`.

```bash
openssl genrsa -out zeal.key 2048
```

It prints nothing when it works.

**Step 5.** Creates a certificate signing request `zeal.csr` for `zeal`.

```bash
openssl req -new -key zeal.key -out zeal.csr -subj "/CN=zeal/O=kplabs"
```

It prints nothing when it works.

**Step 6.** Shows the file `zeal.csr`.

```bash
cat zeal.csr | base64 | tr -d '\n'
```

You should see something like:

```text
LS0tLS1CRUdJTiBDRVJUSUZJQ0FURSBSRVFVRVNULS0tLS0KTUlJQ1pUQ0NBVTBDQVFBd0lERU5NQXNHQTFVRUF3d0VlbVZoYkRFUE1BMEdBMVVFQ2d3R2EzQnNZV0p6TUlJQgpJakFOQmdrcWhraUc5dzBCQVFFRkFBT0NBUThBTUlJQkNnS0NBUUVBd0kwa29Qb2pxNjVPMWZ0c2RLUnlxTjFFCmtXV0hwd2NDQU0xZHRPQ0lxOFpleUhMdGd0aVNaa0haZ0pDK0ZpdndJVDg3bWlBUEZmMEtuK3RMS1ZNdUVuNG8KbXRDcVdKNU9hMTkwTmF6clJzZHNJNUg0bTVoSFFJNFg2ZkYyVWhkSldGWVB2djhXM1NDTWVzVUJLR1hwT0xxdApLYnVJaXh2WForQ1FSRFNBY0dzVkhjeGNiWllqeTJBVEVFc1ZIcHJ4TlFveUIzR0tidDA4OUdOQ0I2Zm9CeDlQCkhnVXJTL1NRTW0rL01ZNERSSDU0c0ZxQkFZUjVFaDRIRk5ZaTY3UFRPRFBkWCtDckcrSVhQdEo5Kzc4bndpWXkKdW1FVG8xS3pQUDY2aU5jdXA2OUlnZXJNMW56UkNSakhjN3oyajFZd0VLUFpGWEZaQlJzdFBJTFB3dlJONHdJRApBUUFCb0FBd0RRWUpLb1pJaHZjTkFRRUxCUUFEZ2dFQkFLOXNRZ2JXMjEwbUJFaDVrazJYeG5zUmU4dXFZaHJBCmhFYVhjaXdqWU9EQ2t1VVRsZjhvVEN5U3A0QURKd1BmbnR2NkhBSHM3S2UxODZHUE9iNi9sbEZJV2NocXhtck8KVlc4NTJ2V3NURVJHUXk5NjdtVHhGbEtSekFobEhQSm1Vd2JPR0xHeUhLYmU0MmJsbm4vWExrbDZObStqTHdRawpOTEk3b2dacWFYNWIxU3ptNU1OU3RVYnZmbStjakJ1NTRFdXNjVC9QMXJEYXR1NnVoN0svQnpEWWZOUm55cXVCCjRHMGtBU0pnc25MYnFzSi9Udm5qNlFZdXQzL1BOZmQzeGlRMVdyS2U2STN0VFhCSFlhMHdVeEpsb3FMdzZuN1EKTjJsakFBN0Ntb1I4OGphdjhTdG9aRVRBbnVNQjJ4M0svbjBkd2VhSk92d2JXTzVRSXJjSjQ5OD0KLS0tLS1FTkQgQ0VSVElGSUNBVEUgUkVRVUVTVC0tLS0tCg==@@PB-STEP 6@@
```

**Step 7.** Writes the file `csr-requests.yaml`.

```bash
cat > csr-requests.yaml <<EOF
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: zeal-csr
spec:
  groups:
  - system:authenticated
  request: $(cat zeal.csr | base64 | tr -d '\n')
  signerName: kubernetes.io/kube-apiserver-client
  usages:
  - digital signature
  - key encipherment
  - client auth
EOF
```

**Step 8.** Creates the objects in `csr-requests.yaml`, or updates them if they exist.

```bash
kubectl apply -f csr-requests.yaml
```

You should see something like:

```text
certificatesigningrequest.certificates.k8s.io/zeal-csr created
```

**Step 9.** Lists the certificate signing requests.

```bash
kubectl get csr
```

You should see something like:

```text
NAME        AGE    SIGNERNAME                                    REQUESTOR                 REQUESTEDDURATION   CONDITION
csr-swdgz   103s   kubernetes.io/kube-apiserver-client-kubelet   system:bootstrap:abcdef   <none>              Approved,Issued
csr-xx4h4   103s   kubernetes.io/kube-apiserver-client-kubelet   system:bootstrap:abcdef   <none>              Approved,Issued
zeal-csr    0s     kubernetes.io/kube-apiserver-client           kubernetes-admin          <none>              Pending
```

**Step 10.** Approves the certificate signing request `zeal-csr`.

```bash
kubectl certificate approve zeal-csr
```

You should see something like:

```text
certificatesigningrequest.certificates.k8s.io/zeal-csr approved
```

**Step 11.** Repeats until the condition is true (waits for the cluster to catch up). Wait until it is issued.

```bash
until [ -n "$(kubectl get csr zeal-csr -o jsonpath='{.status.certificate}')" ]; do sleep 1; done
```

It prints nothing when it works.

**Step 12.** Prints one field of the certificate signing request `zeal-csr`.

```bash
kubectl get csr zeal-csr -o jsonpath='{.status.certificate}' | base64 -d > zeal.crt
```

It prints nothing when it works.

**Step 13.** Adds a user `zeal`.

```bash
kubectl config set-credentials zeal --client-certificate=zeal.crt --client-key=zeal.key
```

You should see something like:

```text
User "zeal" set.
```

**Step 14.** Lists the clusters.

```bash
kubectl config get-clusters
```

You should see something like:

```text
NAME
minikube
```

**Step 15.** Adds a context `zeal-context`.

```bash
kubectl config set-context zeal-context --cluster minikube --user=zeal
```

You should see something like:

```text
Context "zeal-context" created.
```

**Step 16.** Lists the pods.

```bash
kubectl --context=zeal-context get pods
```

You should see something like:

```text
Error from server (Forbidden): pods is forbidden: User "zeal" cannot list resource "pods" in API group "" in the namespace "default"
```

**Step 17.** Writes the file `role.yaml`.

```bash
cat > role.yaml <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: default
  name: pod-reader
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["list"]
EOF
```

It prints nothing when it works.

**Step 18.** Creates the objects in `role.yaml`, or updates them if they exist.

```bash
kubectl apply -f role.yaml
```

You should see something like:

```text
role.rbac.authorization.k8s.io/pod-reader created
```

**Step 19.** Writes the file `rolebinding.yaml`.

```bash
cat > rolebinding.yaml <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pods
  namespace: default
subjects:
- kind: User
  name: zeal
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
EOF
```

It prints nothing when it works.

**Step 20.** Creates the objects in `rolebinding.yaml`, or updates them if they exist.

```bash
kubectl apply -f rolebinding.yaml
```

You should see something like:

```text
rolebinding.rbac.authorization.k8s.io/read-pods created
```

**Step 21.** Lists the pods.

```bash
kubectl --context=zeal-context get pods
```

You should see something like:

```text
NAME           READY   STATUS    RESTARTS   AGE
external-pod   1/1     Running   0          27s
```

**Step 22.** Deletes the objects in `role.yaml`.

```bash
kubectl delete -f role.yaml
```

You should see something like:

```text
role.rbac.authorization.k8s.io "pod-reader" deleted from default namespace
```

**Step 23.** Deletes the objects in `rolebinding.yaml`.

```bash
kubectl delete -f rolebinding.yaml
```

You should see something like:

```text
rolebinding.rbac.authorization.k8s.io "read-pods" deleted from default namespace
```

### If you see something else

- The check says: _~/certificates/zeal.crt is missing, or is not a certificate for CN=zeal signed by the cluster CA._
- The check says: _Your kubeconfig has no context zeal-context for the cluster minikube and the user zeal._
- The check says: _kubectl --context=zeal-context does not log in as zeal. Check the certificate and key in set-credentials._
- The check says: _The Role pod-reader or the RoleBinding read-pods is still there. The last step deletes them._
- The CSR's `request` field is the CSR file in base64 on one line: `cat zeal.csr | base64 | tr -d '\n'`.
- `kubectl config set-credentials zeal --client-certificate=zeal.crt --client-key=zeal.key`, then `kubectl config set-context zeal-context --cluster minikube --user=zeal`.

### Why it works

**Why it works.** Kubernetes has no user objects. A user is anyone who presents a client certificate signed by the cluster CA: the certificate's CN is the user name and its O fields are the groups. The CertificateSigningRequest API lets an admin get a CSR signed by the cluster CA (`kubernetes.io/kube-apiserver-client` signer) without touching ca.key. The new user can log in straight away but can do nothing until RBAC grants something.

**In practice:** `kubectl config set-credentials` and `set-context` only edit your kubeconfig file; nothing changes in the cluster.

---

## Lab 5.5: Secrets

### What you will do

Follow [08-secrets.md](https://github.com/kumbulanit/CKA/blob/main/05-security/08-secrets.md):

1. Create **firstsecret** from the literal `dbpassword=mypassword123`.
2. Write `dbuser=admin` to **credentials.txt** and create **secondsecret** from that file.
3. Look at firstsecret's YAML and decode its value with `base64 -d`.
4. Write and apply **secret-data.yaml** (Secret **thirdsecret** with base64 `data`) and
   **secret-stringdata.yaml** (Secret **stringdata** with a `config.yaml` in `stringData`).

### Step by step

**Step 1.** Creates the Secret `firstsecret`.

```bash
kubectl create secret generic  firstsecret --from-literal=dbpassword=mypassword123
```

You should see something like:

```text
secret/firstsecret created
```

**Step 2.** Writes `credentials.txt`.

```bash
echo 'dbuser=admin' > credentials.txt
```

It prints nothing when it works.

**Step 3.** Creates the Secret `secondsecret`.

```bash
kubectl create secret generic  secondsecret --from-file=./credentials.txt
```

You should see something like:

```text
secret/secondsecret created
```

**Step 4.** Shows the Secret `firstsecret` as YAML, as the API server stores it.

```bash
kubectl get secret firstsecret -o yaml
```

You should see something like:

```text
apiVersion: v1
data:
  dbpassword: bXlwYXNzd29yZDEyMw==
kind: Secret
metadata:
  creationTimestamp: "2026-10-28T13:17:43Z"
  name: firstsecret
  namespace: default
  resourceVersion: "823"
  uid: 6fa23635-86dd-473d-86fa-77e493bdb8eb
type: Opaque
```

**Step 5.** Prints one field of the Secret `firstsecret`.

```bash
kubectl get secret firstsecret -o jsonpath='{.data.dbpassword}' | base64 -d
```

You should see something like:

```text
mypassword123@@PB-STEP 5@@
```

**Step 6.** Writes the file `secret-data.yaml`.

```bash
cat > secret-data.yaml <<'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: thirdsecret
type: Opaque
data:
  username: ZGJhZG1pbg==
  password: bXlwYXNzd29yZDEyMw==
EOF
```

**Step 7.** Creates the objects in `secret-data.yaml`, or updates them if they exist.

```bash
kubectl apply -f secret-data.yaml
```

You should see something like:

```text
secret/thirdsecret created
```

**Step 8.** Writes the file `secret-stringdata.yaml`.

```bash
cat > secret-stringdata.yaml <<'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: stringdata
type: Opaque
stringData:
 config.yaml: |-
   username: dbadmin
   password: mypassword
EOF
```

It prints nothing when it works.

**Step 9.** Creates the objects in `secret-stringdata.yaml`, or updates them if they exist.

```bash
kubectl apply -f secret-stringdata.yaml
```

You should see something like:

```text
secret/stringdata created
```

### If you see something else

- The check says: _firstsecret is missing, or its dbpassword is not mypassword123._
- The check says: _secondsecret is missing, or has no key credentials.txt containing dbuser=admin._
- The check says: _thirdsecret is missing, or its username and password are not dbadmin and mypassword123._
- The check says: _The Secret stringdata is missing, or its config.yaml does not hold the username dbadmin._
- `--from-file=./credentials.txt` uses the file name as the key; `--from-literal=key=value` sets one key directly.
- `data` values must be base64 (`echo -n dbadmin | base64`); `stringData` takes plain text and the API server encodes it.

### Why it works

**Why it works.** A Secret holds small pieces of sensitive data as key/value pairs. `--from-literal` and `--from-file` build it for you; in YAML, `data` needs base64 values while `stringData` takes plain text and is encoded by the API server. base64 is an encoding, not encryption: anyone who can read the Secret can read the value, so access to Secrets is controlled with RBAC (and etcd encryption at rest, if configured).

---

## Lab 5.6: Secrets inside pods

### What you will do

Follow [09-mounting-secrets.md](https://github.com/kumbulanit/CKA/blob/main/05-security/09-mounting-secrets.md)
(it uses firstsecret from the last task):

1. Write and apply **secretpod.yaml**: a pod **secretmount** (`nginx`) that mounts firstsecret
   read-only at `/etc/foo`. Read `/etc/foo/dbpassword` inside it.
2. Write and apply **secret-env.yaml**: a pod **secret-env** (`nginx`) with the environment variable
   `SECRET_USERNAME` taken from firstsecret's key `dbpassword`. Print it inside the pod.

### Step by step

**Step 1.** Writes the file `secretpod.yaml`.

```bash
cat > secretpod.yaml <<'EOF'
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
EOF
```

It prints nothing when it works.

**Step 2.** Creates the objects in `secretpod.yaml`, or updates them if they exist.

```bash
kubectl apply -f secretpod.yaml
```

You should see something like:

```text
pod/secretmount created
```

**Step 3.** Writes the file `secret-env.yaml`.

```bash
cat > secret-env.yaml <<'EOF'
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
```

It prints nothing when it works.

**Step 4.** Creates the objects in `secret-env.yaml`, or updates them if they exist.

```bash
kubectl apply -f secret-env.yaml
```

You should see something like:

```text
pod/secret-env created
```

**Step 5.** Waits until the pods `secretmount`, `secret-env` are Ready.

```bash
kubectl wait --for=condition=Ready pod/secretmount pod/secret-env --timeout=120s
```

You should see something like:

```text
pod/secretmount condition met
pod/secret-env condition met
```

**Step 6.** Inside the pod `secretmount`, not on the server: shows the file `/etc/foo/dbpassword`.

```bash
kubectl exec secretmount -- cat /etc/foo/dbpassword
```

You should see something like:

```text
mypassword123@@PB-STEP 6@@
mypassword123
```

**Step 7.** Inside the pod `secret-env`, not on the server: runs `printenv`.

```bash
kubectl exec secret-env -- printenv SECRET_USERNAME
```

### If you see something else

- The check says: _The pod secretmount is not running, or /etc/foo/dbpassword inside it is not firstsecret's value._
- The check says: _The pod secret-env is not running, or its SECRET_USERNAME is not firstsecret's dbpassword._
- A secret volume puts each key in a file named after it: firstsecret's dbpassword becomes /etc/foo/dbpassword.
- `env[].valueFrom.secretKeyRef` takes `name` (the Secret) and `key`.

### Why it works

**Why it works.** A pod can use a Secret as files (a `secret` volume, one file per key) or as environment variables (`secretKeyRef`). Mounted files are updated when the Secret changes; environment variables are fixed when the container starts.

**In practice:** files are usually preferred, because environment variables leak more easily (into logs, crash dumps and child processes).

---

## Lab 5.7: The API server's certificate

### What you will do

Follow [10-tls-access-to-api.md](https://github.com/kumbulanit/CKA/blob/main/05-security/10-tls-access-to-api.md)
on minikube:

1. Inspect the API server's certificate, `~/.minikube/profiles/minikube/apiserver.crt`, with
   `openssl x509` (its SANs, subject, issuer and dates), and find the certificate files in the
   kube-apiserver manifest with `minikube ssh`.
2. Add the name `k8s.example.internal` and the address `192.168.49.100` to the certificate with
   `minikube start --apiserver-names=... --apiserver-ips=...`.
3. Check the SANs again, and `curl --cacert ~/.minikube/ca.crt https://$(minikube ip):8443/version`.

### Step by step

**Step 1.** Prints the certificate in readable form.

```bash
openssl x509 -in ~/.minikube/profiles/minikube/apiserver.crt -noout -text | grep -A1 "Subject Alternative Name"
```

You should see something like:

```text
            X509v3 Subject Alternative Name: 
                DNS:kubernetes, DNS:kubernetes.default, DNS:kubernetes.default.svc, DNS:kubernetes.default.svc.cluster.local, DNS:localhost, DNS:minikube, DNS:pb-82d4c232-control-plane, IP Address:10.96.0.1, IP Address:192.168.147.3, IP Address:127.0.0.1
```

**Step 2.** Signs the certificate with the cluster CA.

```bash
openssl x509 -in ~/.minikube/profiles/minikube/apiserver.crt -noout -subject -issuer -dates
```

You should see something like:

```text
subject=CN=kube-apiserver
issuer=CN=kubernetes
notBefore=Oct 28 13:10:41 2026 GMT
notAfter=Oct 28 13:15:41 2027 GMT
```

**Step 3.** On the node `minikube`, not on the server: searches for the text.

```bash
minikube ssh -- "sudo grep -E 'tls-cert-file|tls-private-key-file|client-ca-file' /etc/kubernetes/manifests/kube-apiserver.yaml"
```

You should see something like:

```text
    - --client-ca-file=/var/lib/minikube/certs/ca.crt
    - --requestheader-client-ca-file=/var/lib/minikube/certs/front-proxy-ca.crt
    - --tls-cert-file=/var/lib/minikube/certs/apiserver.crt
    - --tls-private-key-file=/var/lib/minikube/certs/apiserver.key
```

**Step 4.** Runs `minikube`.

```bash
minikube start --apiserver-names=k8s.example.internal --apiserver-ips=192.168.49.100
```

You should see something like:

```text
😄  minikube on the lab's machines
✨  Using the existing cluster (3 nodes: minikube minikube-m02 minikube-m03)
🔐  Signing a new API server certificate for: k8s.example.internal,192.168.49.100
🔄  Restarting the API server with the new certificate
🏄  Done! kubectl is now configured to use "minikube" cluster and "default" namespace by default
```

**Step 5.** Prints the certificate in readable form.

```bash
openssl x509 -in ~/.minikube/profiles/minikube/apiserver.crt -noout -text | grep -A1 "Subject Alternative Name"
```

You should see something like:

```text
            X509v3 Subject Alternative Name: 
                DNS:k8s.example.internal, DNS:kubernetes, DNS:kubernetes.default, DNS:kubernetes.default.svc, DNS:kubernetes.default.svc.cluster.local, DNS:localhost, DNS:minikube, DNS:pb-82d4c232-control-plane, IP Address:10.96.0.1, IP Address:192.168.147.3, IP Address:192.168.49.100, IP Address:127.0.0.1
```

**Step 6.** Sends an HTTP request to `https://…:8443/version` and prints the answer.

```bash
curl --cacert ~/.minikube/ca.crt https://$(minikube ip):8443/version
```

You should see something like:

```text
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   379  100   379    0     0  66189      0 --:--:-- --:--:-- --:--:-- 75800
{
  "major": "1",
  "minor": "36",
  "emulationMajor": "1",
  "emulationMinor": "36",
  "minCompatibilityMajor": "1",
  "minCompatibilityMinor": "35",
  "gitVersion": "v1.36.4",
  "gitCommit": "bb826b1d48562f110659e64e8ec444327433db95",
  "gitTreeState": "clean",
  "buildDate": "2026-08-20T03:06:28Z",
  "goVersion": "go1.26.5",
  "compiler": "gc",
  "platform": "linux/arm64"
}@@PB-STEP end@@
```

### If you see something else

- The check says: _The API server's certificate does not list k8s.example.internal and 192.168.49.100 yet._
- The check says: _curl --cacert ~/.minikube/ca.crt https://$(minikube ip):8443/version does not answer._
- `minikube start` on a running cluster keeps it, and signs a new API server certificate when you give it `--apiserver-names` (names) and `--apiserver-ips` (addresses).
- The SANs are in `openssl x509 -noout -text`, under `X509v3 Subject Alternative Name`.

### Why it works

**Why it works.** Clients check the API server's certificate against the cluster CA and against the name they connected to: the name must be one of the certificate's Subject Alternative Names. To reach the API server under a new name (a load balancer, a DNS alias), the certificate must be signed again with that SAN, by the same CA. On minikube, `minikube start --apiserver-names/--apiserver-ips` does that and restarts the API server with the new certificate; the CA stays the same, so every kubeconfig keeps working.

**In the exam:** the clusters are kubeadm clusters. There the certificates are in `/etc/kubernetes/pki`, you add SANs under `apiServer.certSANs` in the ClusterConfiguration and run `kubeadm init phase certs apiserver --config kubeadm.yaml` (after moving the old certificate away), and `kubeadm certs check-expiration` and `kubeadm certs renew` manage their lifetimes (one year for kubeadm's certificates, ten for the CA). The lesson shows those steps too.

---

## Lab 5.8: Security contexts

### What you will do

Follow the first part of [11-security-context-and-network-policy.md](https://github.com/kumbulanit/CKA/blob/main/05-security/11-security-context-and-network-policy.md):

1. Apply **privileged.yaml**: the pods **privileged** (`securityContext.privileged: true`) and
   **non-privileged**. Compare `ls /dev | wc -l` and `grep CapEff /proc/1/status` in both.
2. Apply **capabilities.yaml**: the pod **privileged1**, which drops the `LINUX_IMMUTABLE`
   capability. Compare its CapEff with non-privileged's.

### Step by step

**Step 1.** Writes the file `privileged.yaml`.

```bash
cat > privileged.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: privileged
spec:
  containers:
  - name: privileged
    image: nginx
    securityContext:
      privileged: true

---
apiVersion: v1
kind: Pod
metadata:
  name: non-privileged
spec:
  containers:
  - name: non-privileged
    image: nginx
EOF
```

It prints nothing when it works.

**Step 2.** Creates the objects in `privileged.yaml`, or updates them if they exist.

```bash
kubectl apply -f privileged.yaml
```

You should see something like:

```text
pod/privileged created
pod/non-privileged created
```

**Step 3.** Lists the pods.

```bash
kubectl get pods
```

You should see something like:

```text
NAME             READY   STATUS    RESTARTS   AGE
external-pod     1/1     Running   0          53s
non-privileged   0/1     Pending   0          0s
privileged       0/1     Pending   0          0s
secret-env       1/1     Running   0          24s
secretmount      1/1     Running   0          24s
```

**Step 4.** Waits until the pods `privileged`, `non-privileged` are Ready.

```bash
kubectl wait --for=condition=Ready pod/privileged pod/non-privileged --timeout=120s
```

You should see something like:

```text
pod/privileged condition met
pod/non-privileged condition met
```

**Step 5.** Inside the pod `privileged`, not on the server: runs `'ls`.

```bash
kubectl exec privileged -- sh -c 'ls /dev | wc -l; grep CapEff /proc/1/status'
```

You should see something like:

```text
59
CapEff:    000001ffffffffff
```

**Step 6.** Inside the pod `non-privileged`, not on the server: runs `'ls`.

```bash
kubectl exec non-privileged -- sh -c 'ls /dev | wc -l; grep CapEff /proc/1/status'
```

You should see something like:

```text
15
CapEff:    00000000a80425fb
```

**Step 7.** Writes the file `capabilities.yaml`.

```bash
cat > capabilities.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: privileged1
spec:
  containers:
  - name: privileged1
    image: nginx
    securityContext:
      capabilities:
        drop:
          - LINUX_IMMUTABLE
EOF
```

It prints nothing when it works.

**Step 8.** Creates the objects in `capabilities.yaml`, or updates them if they exist.

```bash
kubectl apply -f capabilities.yaml
```

You should see something like:

```text
pod/privileged1 created
```

**Step 9.** Waits until the pod `privileged1` is Ready.

```bash
kubectl wait --for=condition=Ready pod/privileged1 --timeout=120s
```

You should see something like:

```text
pod/privileged1 condition met
```

**Step 10.** Inside the pod `privileged1`, not on the server: searches for the text.

```bash
kubectl exec privileged1 -- grep CapEff /proc/1/status
```

You should see something like:

```text
CapEff:    00000000a80425fb
```

### If you see something else

- The check says: _The pods privileged (with privileged true) and non-privileged are not both running._
- The check says: _The pod privileged1, dropping LINUX_IMMUTABLE, is not running._
- `securityContext` can be set for the whole pod (`spec.securityContext`) or per container; privileged and capabilities are per container.
- CapEff is a bit mask of the container's capabilities: a privileged container has them all, a dropped capability clears one bit.

### Why it works

**Why it works.** A security context sets the Linux security options a container runs with. `privileged: true` gives it all capabilities and access to the host's devices, nearly the same power as root on the node; avoid it except for system components. Capabilities split root's power into pieces (for example `NET_ADMIN`, `LINUX_IMMUTABLE`); dropping the ones a container does not need limits what an attacker could do with it.

**In the exam:** `runAsUser`, `runAsNonRoot`, `readOnlyRootFilesystem` and `capabilities` are the fields to know.

---

## Lab 5.9: A network policy

### What you will do

Follow the second part of [11-security-context-and-network-policy.md](https://github.com/kumbulanit/CKA/blob/main/05-security/11-security-context-and-network-policy.md):

1. Create a pod **pod01** from `nginx` and check from a temporary busybox pod that it answers
   (`wget -T 3 -qO- <POD01-IP>`).
2. Apply **nsp-deny-pod.yaml**: the NetworkPolicy **default-deny-pod**, which selects `run: pod01`
   and denies all its ingress and egress. Describe it.
3. Try the same wget again: it times out now.

### Step by step

**Step 1.** Starts the pod `pod01` from the image `nginx`.

```bash
kubectl run pod01 --image=nginx
```

You should see something like:

```text
pod/pod01 created
```

**Step 2.** Waits until the pod `pod01` is Ready.

```bash
kubectl wait --for=condition=Ready pod/pod01 --timeout=120s
```

You should see something like:

```text
pod/pod01 condition met
```

**Step 3.** Lists the pod `pod01`, with IP address and node.

```bash
kubectl get pod pod01 -o wide
```

You should see something like:

```text
NAME    READY   STATUS    RESTARTS   AGE   IP           NODE           NOMINATED NODE   READINESS GATES
pod01   1/1     Running   0          2s    10.244.1.5   minikube-m02   <none>           <none>
```

**Step 4.** Saves `$POD01_IP`: prints one field of the pod `pod01`.

```bash
POD01_IP=$(kubectl get pod pod01 -o jsonpath='{.status.podIP}')
```

It prints nothing when it works.

**Step 5.** Starts a throwaway pod `test` that runs one command and is deleted afterwards.

```bash
kubectl run test --image=busybox:1.37 --rm -i --restart=Never -- wget -T 3 -qO- $POD01_IP
```

You should see something like:

```text
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
html { color-scheme: light dark; }
body { width: 35em; margin: 0 auto;
font-family: Tahoma, Verdana, Arial, sans-serif; }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, nginx is successfully installed and working.
Further configuration is required for the web server, reverse proxy, 
API gateway, load balancer, content cache, or other features.</p>

<p>For online documentation and support please refer to
<a href="https://nginx.org/">nginx.org</a>.<br/>
… (40 more lines)
```

**Step 6.** Writes the file `nsp-deny-pod.yaml`.

```bash
cat > nsp-deny-pod.yaml <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-pod
  namespace: default
spec:
  podSelector:
    matchLabels:
        run: pod01
  policyTypes:
  - Ingress
  - Egress
EOF
```

It prints nothing when it works.

**Step 7.** Creates the objects in `nsp-deny-pod.yaml`, or updates them if they exist.

```bash
kubectl apply -f nsp-deny-pod.yaml
```

You should see something like:

```text
networkpolicy.networking.k8s.io/default-deny-pod created
```

**Step 8.** Lists the NetworkPolicies.

```bash
kubectl get networkpolicy
```

You should see something like:

```text
NAME               POD-SELECTOR   AGE
default-deny-pod   run=pod01      1s
```

**Step 9.** Shows the details of the NetworkPolicy `default-deny-pod`, with its recent events at the bottom.

```bash
kubectl describe networkpolicy default-deny-pod
```

You should see something like:

```text
Name:         default-deny-pod
Namespace:    default
Created on:   2026-10-28 13:18:48 +0000 UTC
Labels:       <none>
Annotations:  <none>
Spec:
  PodSelector:     run=pod01
  Allowing ingress traffic:
    <none> (Selected pods are isolated for ingress connectivity)
  Allowing egress traffic:
    <none> (Selected pods are isolated for egress connectivity)
  Policy Types: Ingress, Egress
```

**Step 10.** Waits 5 seconds.

```bash
sleep 5
```

It prints nothing when it works.

**Step 11.** Starts a throwaway pod `test` that runs one command and is deleted afterwards.

```bash
kubectl run test --image=busybox:1.37 --rm -i --restart=Never -- wget -T 3 -qO- $POD01_IP
```

You should see something like:

```text
All commands and output from this session will be recorded in container logs, including credentials and sensitive information passed through the command prompt.
If you don't see a command prompt, try pressing enter.
wget: download timed out
pod "test" deleted from default namespace
pod default/test terminated (Error)
```

### If you see something else

- The check says: _There is no NetworkPolicy default-deny-pod selecting run=pod01 with both Ingress and Egress._
- The check says: _pod01 still answers. Is the policy selecting it (`run: pod01`)?_
- A policy with `policyTypes: [Ingress, Egress]` and no `ingress`/`egress` rules allows nothing for the pods it selects.
- `kubectl run pod01` labels the pod `run=pod01`, which is what the policy's podSelector matches.

### Why it works

**Why it works.** By default every pod can talk to every pod. A NetworkPolicy selects pods with `podSelector` and, for each policy type it lists, allows only the traffic its rules describe. With `Ingress` and `Egress` listed and no rules, nothing is allowed in or out of pod01. Policies are enforced by the network plugin; one without policy support (such as Flannel) silently ignores them.

**In the exam:** policies only add allowances; to open a path, add an `ingress` or `egress` rule with `from`/`to` selectors and ports.

---
