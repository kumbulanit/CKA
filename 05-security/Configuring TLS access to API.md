### Configuring TLS Access to Kubernetes API

**TLS (Transport Layer Security)** is a cryptographic protocol designed to provide secure communication over a network. In Kubernetes, TLS is used to secure access to the Kubernetes API server. This ensures that the communication between clients and the API server is encrypted and authenticated.

Here's a detailed guide on configuring TLS access to the Kubernetes API server:

---

### **1. Understanding TLS in Kubernetes**

The Kubernetes API server communicates with clients (e.g., `kubectl`, the kubelets, the controller manager) only over HTTPS. The cluster has its own **certificate authority (CA)**, which signs every certificate the cluster needs. On the course's minikube cluster they are in `/var/lib/minikube/certs/` on the control plane node, and minikube keeps copies on the server in `~/.minikube/` (the CA as `~/.minikube/ca.crt`, the API server's certificate as `~/.minikube/profiles/minikube/apiserver.crt`). On a kubeadm cluster, `kubeadm init` creates them in `/etc/kubernetes/pki/` on `controlplane`.

| File in `/var/lib/minikube/certs/` (kubeadm: `/etc/kubernetes/pki/`) | Used for |
| --- | --- |
| `ca.crt`, `ca.key` | The cluster CA. Clients trust the API server because its certificate is signed by this CA. |
| `apiserver.crt`, `apiserver.key` | The API server's serving certificate. |
| `apiserver-kubelet-client.crt` | The API server's client certificate when it talks to kubelets. |
| `etcd/ca.crt`, `etcd/server.crt` | etcd's own CA and server certificate. |
| `front-proxy-ca.crt` | The CA for the aggregation layer (e.g. metrics server). |

### **2. Inspecting the API Server Certificate**

The certificate's **Subject Alternative Names (SANs)** list every name and IP address clients may use to reach the API server. A client that connects with a name not in the list gets a TLS error. On the server:

```sh
openssl x509 -in ~/.minikube/profiles/minikube/apiserver.crt -noout -text | grep -A1 "Subject Alternative Name"
openssl x509 -in ~/.minikube/profiles/minikube/apiserver.crt -noout -subject -issuer -dates
```

(On a kubeadm cluster: `sudo openssl x509 -in /etc/kubernetes/pki/apiserver.crt …` on `controlplane`.)

The API server's static pod manifest shows which files it uses:

```sh
minikube ssh -- "sudo grep -E 'tls-cert-file|tls-private-key-file|client-ca-file' /etc/kubernetes/manifests/kube-apiserver.yaml"
```

```yaml
    - --client-ca-file=/var/lib/minikube/certs/ca.crt
    - --tls-cert-file=/var/lib/minikube/certs/apiserver.crt
    - --tls-private-key-file=/var/lib/minikube/certs/apiserver.key
```

### **3. Checking and Renewing Certificates**

Check the dates with the second `openssl` command above. minikube's certificates last three years (`minikube start --cert-expiration` changes that), and `minikube start` renews any that are about to expire.

On a kubeadm cluster (the exam), certificates are valid for one year (the CA for ten). On `controlplane`, check them, then renew all of them (a `kubeadm upgrade` also renews them):

```sh
sudo kubeadm certs check-expiration
sudo kubeadm certs renew all
```

Then restart the control plane static pods so they load the new certificates: move the manifests out of `/etc/kubernetes/manifests/` and back after about 20 seconds, or restart the kubelet. Copy the renewed `/etc/kubernetes/admin.conf` to `~/.kube/config`.

### **4. Adding a Name or IP to the API Server Certificate**

Do not replace `apiserver.crt` with a certificate you made yourself: if it is not signed by the cluster CA or misses a SAN, kubectl, the kubelets and the controllers can no longer connect. To add a name (for example a load balancer's DNS name), let the cluster's tools regenerate the certificate.

On minikube, give the extra names and addresses to `minikube start`; it signs a new API server certificate with the cluster CA:

```sh
minikube start --apiserver-names=k8s.example.internal --apiserver-ips=192.168.49.100
```

Verify the SANs again with the first `openssl` command from section 2.

On a kubeadm cluster (the exam), on `controlplane`, export the cluster configuration:

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

Move the old certificate away and generate a new one; the kubelet restarts the API server with it:

```sh
sudo mv /etc/kubernetes/pki/apiserver.{crt,key} ~/
sudo kubeadm init phase certs apiserver --config kubeadm.yaml
```

**Verify the API server connection** with the cluster CA (no `-k` needed). On minikube, the API server listens on port `8443`:

```sh
curl --cacert ~/.minikube/ca.crt https://$(minikube ip):8443/version
```

(On a kubeadm cluster: `curl --cacert /etc/kubernetes/pki/ca.crt https://controlplane:6443/version`.)

### **5. Configuring Client Access**

Clients (such as `kubectl`) need to be configured to trust the CA certificate and use the correct client certificate.

#### **5.1. Update kubeconfig File**

Update the `kubeconfig` file to use the CA certificate and client certificates:

**Example `kubeconfig` Entries** (`kubectl config view --raw` shows yours; minikube points at files in `~/.minikube`, kubeadm embeds them as `certificate-authority-data` and `client-certificate-data`):

```yaml
apiVersion: v1
clusters:
- cluster:
    certificate-authority: /path/to/ca.crt
    server: https://<api-server-ip>:8443
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

This is also the file [`configuring-tls-access-to-api-my-pod.yaml`](./configuring-tls-access-to-api-my-pod.yaml) in this folder: `kubectl apply -f configuring-tls-access-to-api-my-pod.yaml`

### **7. Conclusion**

Configuring TLS access to the Kubernetes API ensures secure communication between clients and the API server. minikube and kubeadm manage the CA and certificates for you: inspect them with `openssl`, and add names through `minikube start --apiserver-names` (kubeadm: `certSANs`) rather than replacing certificates by hand. Renewing is `minikube start` (kubeadm: `kubeadm certs renew`).

**Additional Resources**:
- **PKI certificates and requirements**: [https://kubernetes.io/docs/setup/best-practices/certificates/](https://kubernetes.io/docs/setup/best-practices/certificates/)
- **Certificate management with kubeadm**: [https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-certs/](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-certs/)
- **Kubernetes API Server Configuration**: [https://kubernetes.io/docs/reference/command-line-tools-reference/kube-apiserver/](https://kubernetes.io/docs/reference/command-line-tools-reference/kube-apiserver/)
