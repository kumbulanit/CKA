##### teama-role.yaml

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

This is also the file [`teama-role.yaml`](./teama-role.yaml) in this folder: `kubectl apply -f teama-role.yaml`

##### teama-rolebinding.yaml
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

This is also the file [`teama-rolebinding.yaml`](./teama-rolebinding.yaml) in this folder: `kubectl apply -f teama-rolebinding.yaml`
