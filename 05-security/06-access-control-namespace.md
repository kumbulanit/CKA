##### 06-access-control-namespace-teama-role.yaml

```sh
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: teama
  name: pod-reader
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "watch", "list", "create"]

```

This is also the file [`06-access-control-namespace-teama-role.yaml`](./06-access-control-namespace-teama-role.yaml) in this folder: `kubectl apply -f 06-access-control-namespace-teama-role.yaml`

##### 06-access-control-namespace-teama-rolebinding.yaml
```sh
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pods
  namespace: teama
subjects:
- kind: User
  name: zeal
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

This is also the file [`06-access-control-namespace-teama-rolebinding.yaml`](./06-access-control-namespace-teama-rolebinding.yaml) in this folder: `kubectl apply -f 06-access-control-namespace-teama-rolebinding.yaml`
