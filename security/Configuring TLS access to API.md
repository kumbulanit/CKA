### Configuring TLS Access to Kubernetes API

**TLS (Transport Layer Security)** is a cryptographic protocol designed to provide secure communication over a network. In Kubernetes, TLS is used to secure access to the Kubernetes API server. This ensures that the communication between clients and the API server is encrypted and authenticated.

Here's a detailed guide on configuring TLS access to the Kubernetes API server:

---

### **1. Understanding TLS in Kubernetes**

The Kubernetes API server communicates with clients (e.g., `kubectl`, the kubelets, the controller manager) only over HTTPS. On a kubeadm cluster, `kubeadm init` creates a cluster **certificate authority (CA)** in `/etc/kubernetes/pki/` and uses it to sign every certificate the cluster needs:

| File in `/etc/kubernetes/pki/` | Used for |
| --- | --- |
| `ca.crt`, `ca.key` | The cluster CA. Clients trust the API server because its certificate is signed by this CA. |
| `apiserver.crt`, `apiserver.key` | The API server's serving certificate. |
| `apiserver-kubelet-client.crt` | The API server's client certificate when it talks to kubelets. |
| `etcd/ca.crt`, `etcd/server.crt` | etcd's own CA and server certificate. |
| `front-proxy-ca.crt` | The CA for the aggregation layer (e.g. metrics server). |

### **2. Inspecting the API Server Certificate**

The certificate's **Subject Alternative Names (SANs)** list every name and IP address clients may use to reach the API server. A client that connects with a name not in the list gets a TLS error.

```sh
sudo openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -text | grep -A1 "Subject Alternative Name"
sudo openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -subject -issuer -dates
```

The manifest shows which files the API server uses:

```sh
sudo grep -E "tls-cert-file|tls-private-key-file|client-ca-file" /etc/kubernetes/manifests/kube-apiserver.yaml
```

```yaml
    - --client-ca-file=/etc/kubernetes/pki/ca.crt
    - --tls-cert-file=/etc/kubernetes/pki/apiserver.crt
    - --tls-private-key-file=/etc/kubernetes/pki/apiserver.key
```

### **3. Checking and Renewing Certificates**

kubeadm certificates are valid for one year (the CA for ten). Check them:

```sh
sudo kubeadm certs check-expiration
```

Renew all of them (a `kubeadm upgrade` also renews them):

```sh
sudo kubeadm certs renew all
```

Then restart the control plane static pods so they load the new certificates: move the manifests out of `/etc/kubernetes/manifests/` and back after about 20 seconds, or restart the kubelet. Copy the renewed `/etc/kubernetes/admin.conf` to `~/.kube/config`.

### **4. Adding a Name or IP to the API Server Certificate**

Do not replace `apiserver.crt` with a certificate you made yourself: if it is not signed by the cluster CA or misses a SAN, kubectl, the kubelets and the controllers can no longer connect. To add a name (for example a load balancer's DNS name), let kubeadm regenerate the certificate:

```sh
kubectl -n kube-system get configmap kubeadm-config -o jsonpath='{.data.ClusterConfiguration}' > kubeadm.yaml
```

Add the names under `apiServer.certSANs` in `kubeadm.yaml`:

```yaml
apiServer:
  certSANs:
  - controlplane
  - k8s.example.internal
  - 192.168.56.100
```

Move the old certificate away and generate a new one:

```sh
sudo mv /etc/kubernetes/pki/apiserver.{crt,key} ~/
sudo kubeadm init phase certs apiserver --config kubeadm.yaml
```

The kubelet restarts the API server with the new certificate. Verify the SANs again with the `openssl` command from section 2.

**Verify the API server connection** with the cluster CA (no `-k` needed):

```sh
curl --cacert /etc/kubernetes/pki/ca.crt https://controlplane:6443/version
```

### **5. Configuring Client Access**

Clients (such as `kubectl`) need to be configured to trust the CA certificate and use the correct client certificate.

#### **5.1. Update kubeconfig File**

Update the `kubeconfig` file to use the CA certificate and client certificates:

**Example `kubeconfig` Entries** (`kubectl config view --raw` shows yours; kubeadm embeds the files as `certificate-authority-data` and `client-certificate-data`):

```yaml
apiVersion: v1
clusters:
- cluster:
    certificate-authority: /path/to/ca.crt
    server: https://<api-server-ip>:6443
  name: my-cluster
contexts:
- context:
    cluster: my-cluster
    user: my-user
  name: my-context
current-context: my-context
kind: Config
preferences: {}
users:
- name: my-user
  user:
    client-certificate: /path/to/client.crt
    client-key: /path/to/client.key
```

### **6. Using Kubernetes Secrets for TLS**

You can also manage TLS certificates using Kubernetes Secrets.

#### **6.1. Create a Secret**

**Example Command**:

```sh
kubectl create secret tls my-tls-secret --cert=server.crt --key=server.key
```

#### **6.2. Mount the Secret in Pods**

**Example Pod Specification**:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
spec:
  containers:
    - name: my-container
      image: nginx
      volumeMounts:
        - name: tls-secret
          mountPath: /etc/tls
  volumes:
    - name: tls-secret
      secret:
        secretName: my-tls-secret
```

### **7. Conclusion**

Configuring TLS access to the Kubernetes API ensures secure communication between clients and the API server. On a kubeadm cluster, kubeadm manages the CA and certificates: inspect them with `openssl`, renew them with `kubeadm certs renew`, and add names through `certSANs` rather than replacing certificates by hand.

**Additional Resources**:
- **PKI certificates and requirements**: [https://kubernetes.io/docs/setup/best-practices/certificates/](https://kubernetes.io/docs/setup/best-practices/certificates/)
- **Certificate management with kubeadm**: [https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-certs/](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-certs/)
- **Kubernetes API Server Configuration**: [https://kubernetes.io/docs/reference/command-line-tools-reference/kube-apiserver/](https://kubernetes.io/docs/reference/command-line-tools-reference/kube-apiserver/)
