##### clusterrole.yaml

```sh
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  # "namespace" omitted since ClusterRoles are not namespaced
  name: cluster-pod-reader
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "watch", "list"]


```

This is also the file [`cluster-role-binding-cluster-pod-reader.yaml`](./cluster-role-binding-cluster-pod-reader.yaml) in this folder: `kubectl apply -f cluster-role-binding-cluster-pod-reader.yaml`

##### clusterrolebinding.yaml
```sh
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: read-secrets-global
subjects:
- kind: User
  name: zeal
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: cluster-pod-reader
  apiGroup: rbac.authorization.k8s.io

```

This is also the file [`cluster-role-binding-read-secrets-global.yaml`](./cluster-role-binding-read-secrets-global.yaml) in this folder: `kubectl apply -f cluster-role-binding-read-secrets-global.yaml`

##### cluster-to-rolebind.yaml
```sh
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
  kind: ClusterRole
  name: cluster-pod-reader
  apiGroup: rbac.authorization.k8s.io

```

This is also the file [`cluster-to-rolebind.yaml`](./cluster-to-rolebind.yaml) in this folder: `kubectl apply -f cluster-to-rolebind.yaml`
