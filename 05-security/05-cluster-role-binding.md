##### 05-cluster-role-binding-cluster-pod-reader.yaml

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

This is also the file [`05-cluster-role-binding-cluster-pod-reader.yaml`](./05-cluster-role-binding-cluster-pod-reader.yaml) in this folder: `kubectl apply -f 05-cluster-role-binding-cluster-pod-reader.yaml`

##### 05-cluster-role-binding-read-secrets-global.yaml
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

This is also the file [`05-cluster-role-binding-read-secrets-global.yaml`](./05-cluster-role-binding-read-secrets-global.yaml) in this folder: `kubectl apply -f 05-cluster-role-binding-read-secrets-global.yaml`

##### 05-cluster-role-binding-cluster-to-rolebind.yaml
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

This is also the file [`05-cluster-role-binding-cluster-to-rolebind.yaml`](./05-cluster-role-binding-cluster-to-rolebind.yaml) in this folder: `kubectl apply -f 05-cluster-role-binding-cluster-to-rolebind.yaml`

#### Also in this folder

- [`05-cluster-role-binding-clusterrole.yaml`](./05-cluster-role-binding-clusterrole.yaml): The ClusterRole `cluster-pod-reader` (list pods), used by the bindings in this lesson. `kubectl apply -f 05-cluster-role-binding-clusterrole.yaml`
- [`05-cluster-role-binding-clusterrolebinding.yaml`](./05-cluster-role-binding-clusterrolebinding.yaml): A ClusterRoleBinding `list-pods-global` that gives the user `zeal` the ClusterRole `cluster-pod-reader` in every namespace. `kubectl apply -f 05-cluster-role-binding-clusterrolebinding.yaml`
- [`05-cluster-role-binding-cluster-binding.yaml`](./05-cluster-role-binding-cluster-binding.yaml): Binds the built-in ClusterRole `cluster-admin` to the service account `admin-user` in `kube-system` (create it first: `kubectl -n kube-system create serviceaccount admin-user`). `kubectl apply -f 05-cluster-role-binding-cluster-binding.yaml`
