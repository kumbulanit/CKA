#### Documentation Referred:

https://kubernetes.io/docs/reference/access-authn-authz/authorization/

#### Step 1: Verify Current Permissions Through CURL Command
Use a token of the `external` service account from the authentication lesson (`kubectl create token external`). Kubernetes sees it as the user `system:serviceaccount:default:external`, which is the subject the RoleBinding below grants access to.

```sh
curl -k <K8S-SERVER-URL>/api/v1 --header "Authorization: Bearer <TOKEN-HERE>"
curl -k <K8S-SERVER-URL>/api/v1/namespaces/default/pods --header "Authorization: Bearer <TOKEN-HERE>"
```


##### Step 2: Create a new Role
```sh
nano role.yaml
```
```sh
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: default
  name: pod-reader
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["list"]
```

This is also the file [`role.yaml`](./role.yaml) in this folder: `kubectl apply -f role.yaml`

```sh
kubectl apply -f role.yaml
```
```sh
kubectl get role
kubectl describe role pod-reader
```
#### Step 3: Create a New Role Binding
```sh
nano rolebinding.yaml
```
```sh
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
```

This is also the file [`authorization-rolebinding.yaml`](./authorization-rolebinding.yaml) in this folder: `kubectl apply -f authorization-rolebinding.yaml`

```sh
kubectl apply -f rolebinding.yaml
```
```sh
kubectl get rolebinding
kubectl describe rolebinding read-pods
```
##### Step 4: Verify Permissions
```sh
curl -k <K8S-SERVER-URL>/api/v1/namespaces/default/pods --header "Authorization: Bearer <TOKEN-HERE>"
```
