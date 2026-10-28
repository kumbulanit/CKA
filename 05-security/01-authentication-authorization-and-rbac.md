### Authentication, Authorization, and RBAC in Kubernetes

Kubernetes provides mechanisms for securing access to the API server, controlling what users and services can do within a cluster, and ensuring that only authorized actions are permitted. The primary components involved in securing Kubernetes clusters are **Authentication**, **Authorization**, and **Role-Based Access Control (RBAC)**.

---

### **1. Authentication**

**Authentication** is the process of verifying the identity of a user or service. In Kubernetes, authentication determines who you are and provides you with an identity that the system can use to apply appropriate authorization policies.

#### **1.1. Authentication Methods**

Kubernetes supports several authentication methods:

1. **X.509 Certificates**: Clients can use client certificates signed by a trusted Certificate Authority (CA) to authenticate to the Kubernetes API server.

2. **Bearer Tokens**: Tokens are typically used for service accounts. They are issued by the API server and can be used to authenticate API requests.

3. **OpenID Connect (OIDC)**: Kubernetes can integrate with external identity providers (such as Google or Microsoft) using OIDC for user authentication.

4. **Static passwords (Basic Authentication)**: Removed in Kubernetes v1.19 (`--basic-auth-file` no longer exists). Kubernetes has no built-in username/password login.

5. **Webhook Authentication**: Kubernetes can use external services (webhooks) to authenticate users. The external service validates the credentials and returns an authentication result.

#### **1.2. Configuring Authentication**

**Client Certificate Authentication Example**:

Generate a client key and certificate signing request. The certificate's CN is the user name and O is the group:

```sh
openssl genrsa -out client.key 2048
openssl req -new -key client.key -out client.csr -subj "/CN=client/O=dev"
```

The certificate must be signed by the cluster's CA, otherwise the API server rejects it. minikube keeps the cluster CA on the server, in `~/.minikube` (on a kubeadm cluster it is in `/etc/kubernetes/pki` on `controlplane`). Sign it with the CA (or use the CertificateSigningRequest API, see [07-certificates-for-users.md](./07-certificates-for-users.md)):

```sh
openssl x509 -req -in client.csr -CA ~/.minikube/ca.crt -CAkey ~/.minikube/ca.key -CAcreateserial -out client.crt -days 30
```

Add the user to your kubeconfig:

```sh
kubectl config set-credentials client --client-certificate=client.crt --client-key=client.key
kubectl config set-context my-context --cluster=minikube --user=client
kubectl config use-context my-context
```

The user can log in but can do nothing until RBAC gives them permissions (section 3). Switch back with `kubectl config use-context kubernetes-admin@kubernetes`.

---

### **2. Authorization**

**Authorization** determines what a user or service can do once authenticated. Kubernetes uses several mechanisms to control access to resources:

1. **Role-Based Access Control (RBAC)**: This is the primary authorization mechanism used in Kubernetes. RBAC allows you to define roles and bind them to users or groups.

2. **Attribute-Based Access Control (ABAC)**: Uses policies defined in JSON or YAML to control access based on attributes of the request and resource.

3. **Node Authorization**: A special-purpose mode that lets each kubelet read and update only the objects it needs for the pods scheduled on its own node.

4. **Webhook Authorization**: Similar to authentication webhooks, Kubernetes can use external services to make authorization decisions.

---

### **3. Role-Based Access Control (RBAC)**

**RBAC** is a method of regulating access to resources based on the roles assigned to users or service accounts. RBAC is the default authorization mechanism in Kubernetes and allows for fine-grained control over access permissions.

#### **3.1. Key Components**

1. **Role**: Defines a set of permissions within a namespace. Roles specify what actions are allowed on which resources.

2. **ClusterRole**: Defines a set of permissions across the entire cluster. It is similar to a Role but not restricted to a namespace.

3. **RoleBinding**: Associates a Role with users or service accounts within a namespace.

4. **ClusterRoleBinding**: Associates a ClusterRole with users or service accounts across the entire cluster.

#### **3.2. Examples**

**Role Example**:

Create a Role that allows read access to Pods in a namespace:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: default
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch"]
```

This is also the file [`01-authentication-authorization-and-rbac-pod-reader.yaml`](./01-authentication-authorization-and-rbac-pod-reader.yaml) in this folder: `kubectl apply -f 01-authentication-authorization-and-rbac-pod-reader.yaml`

**RoleBinding Example**:

Bind the `pod-reader` Role to a user:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pods
  namespace: default
subjects:
  - kind: User
    name: alice
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

This is also the file [`01-authentication-authorization-and-rbac-read-pods.yaml`](./01-authentication-authorization-and-rbac-read-pods.yaml) in this folder: `kubectl apply -f 01-authentication-authorization-and-rbac-read-pods.yaml`

**ClusterRole Example**:

Create a ClusterRole that allows read access to all Pods in the cluster:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cluster-pod-reader
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch"]
```

This is also the file [`01-authentication-authorization-and-rbac-cluster-pod-reader.yaml`](./01-authentication-authorization-and-rbac-cluster-pod-reader.yaml) in this folder: `kubectl apply -f 01-authentication-authorization-and-rbac-cluster-pod-reader.yaml`

**ClusterRoleBinding Example**:

Bind the `cluster-pod-reader` ClusterRole to a user across the entire cluster:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: read-cluster-pods
subjects:
  - kind: User
    name: bob
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: cluster-pod-reader
  apiGroup: rbac.authorization.k8s.io
```

This is also the file [`01-authentication-authorization-and-rbac-read-cluster-pods.yaml`](./01-authentication-authorization-and-rbac-read-cluster-pods.yaml) in this folder: `kubectl apply -f 01-authentication-authorization-and-rbac-read-cluster-pods.yaml`

#### **3.3. Diagram: RBAC Components**

```plaintext
+----------------+              +-------------------+
|    User/Group  |              |   Service Account |
+--------+-------+              +---------+---------+
         |                              |
         v                              v
+--------+---------+            +---------+---------+
|   RoleBinding    |            | ClusterRoleBinding|
|   (Namespace)    |            |    (Cluster-wide) |
+--------+---------+            +---------+---------+
         |                              |
         v                              v
+--------+---------+            +---------+---------+
|       Role       |            |    ClusterRole    |
| (Namespace-level) |            |  (Cluster-wide)   |
+------------------+            +-------------------+
         |                              |
         v                              v
+--------+---------+            +---------+---------+
|   Pod/Resource   |            |   Pod/Resource    |
+------------------+            +-------------------+
```

---

### **4. Common Use Cases**

#### **4.1. Limiting Access to Sensitive Resources**

To ensure that only specific users or service accounts can access sensitive resources, such as secrets or deployment configurations, you can create Roles or ClusterRoles with restrictive permissions and bind them to the relevant users or service accounts.

#### **4.2. Granting Broad Permissions**

For administrators who need broad access across the cluster, you can use ClusterRoles and ClusterRoleBindings to grant permissions across all namespaces or resources.

#### **4.3. Implementing Least Privilege**

By using fine-grained Roles and RoleBindings, you can enforce the principle of least privilege, ensuring that users and services only have the permissions necessary to perform their tasks.

---

### **Conclusion**

Authentication, Authorization, and RBAC are critical components of Kubernetes security. By configuring these mechanisms, you can ensure that only authenticated users and services have access to the appropriate resources, and that their actions are controlled according to your organization's policies.

**Additional Resources**:
- **Kubernetes RBAC Documentation**: [https://kubernetes.io/docs/reference/access-authn-authz/rbac/](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- **Kubernetes Authentication Documentation**: [https://kubernetes.io/docs/reference/access-authn-authz/authentication/](https://kubernetes.io/docs/reference/access-authn-authz/authentication/)

