# Lab 5.2 explained: TLS access to the API

This page goes with [Lab 5.2](./lab-5.2-tls-access-to-the-api.md). The lab has the commands; this page explains them: what happens in the cluster, why it matters for the Shop, what usually goes wrong, and what the exam asks. There is nothing to paste here.

## In short

People log in to Kubernetes with a **client certificate** signed by the cluster's **certificate authority** (CA). The name in the certificate (`CN`) is the user name, the organisation (`O`) the group. In this lab you make a key and a request for Thabo, let the cluster sign it through a **CertificateSigningRequest**, and add a **context** to your kubeconfig. Thabo can then use `kubectl`, or plain `curl`, with exactly the rights RBAC gave him in Lab 5.1.

## The ideas behind this lab

### TLS in both directions

All traffic to the API server is encrypted with TLS, and both sides prove who they are:

| Direction | Proved with | How the other side checks it |
| --- | --- | --- |
| The API server to you | Its server certificate | Your kubeconfig (or `--cacert`) holds the cluster's CA certificate |
| You to the API server | Your client certificate | The API server trusts certificates signed by the cluster's CA |

The **CA** is the root of trust. On kubeadm clusters its key is `/etc/kubernetes/pki/ca.key`, on minikube in `~/.minikube`. Anyone who holds the CA key can make a certificate for any user, so it is the most precious file of the cluster.

### What a certificate says

| Field | Kubernetes reads it as | Your own certificate | Thabo's |
| --- | --- | --- | --- |
| `CN` (common name) | The user name | `minikube-user` | `thabo` |
| `O` (organisation) | A group (there can be several) | `system:masters` | none |
| Issuer | Must be the cluster's CA | `minikubeCA` | `minikubeCA`, after signing |
| Validity | Until it expires | Years | 24 hours (`expirationSeconds: 86400`) |

A certificate cannot be cancelled before it expires (Kubernetes does not check revocation lists). That is one reason to keep user certificates short-lived, and to give rights through RBAC, which you **can** take away.

### Key, request, certificate

1. The **private key** is made by the user and never leaves them.
2. The **certificate signing request** (CSR) contains the public half of the key and the name (`CN=thabo`). It is safe to send.
3. The cluster's CA **signs** it, which produces the **certificate**: the public key plus the name, vouched for by the CA.

The Kubernetes object **CertificateSigningRequest** carries step 3 through the API: an administrator approves it, and the controller manager signs it with the cluster's CA. Nobody needs to touch the CA key by hand.

### kubeconfig: clusters, users, contexts

| Section | Holds |
| --- | --- |
| `clusters` | The API server's address and the CA certificate to check it |
| `users` | Credentials: a client certificate and key, or a token |
| `contexts` | A cluster plus a user (plus a default namespace) under one name |
| `current-context` | The context `kubectl` uses when you do not say `--context` |

`kubectx` switches the current context; `kubectl --context=NAME` uses another one for a single command.

## Step by step

### Step 1: look at your own login

`kubectl config view --minify` shows only the parts of your kubeconfig the current context uses. `openssl x509 -noout -subject -issuer` prints the name and issuer inside your certificate: `CN = minikube-user`, `O = system:masters`. That group is why you can do everything (Lab 5.1).

### Step 2: make a key and a certificate request

`openssl genrsa` makes a 2048-bit RSA private key. `openssl req -new -subj "/CN=thabo"` makes the request with Thabo's name. To put Thabo in a group, the subject would get an `O=` part, for example `/CN=thabo/O=developers`, and RBAC could then bind the group instead of the person.

### Step 3: send the request to the cluster

The YAML has a placeholder `REQUEST`; `sed` replaces it with the request file, base64-encoded on one line (`-w0`), and `kubectl apply -f -` reads the result from the pipe. Three fields matter:

| Field | Meaning |
| --- | --- |
| `signerName: kubernetes.io/kube-apiserver-client` | "A certificate for logging in to the API server" |
| `usages: [client auth]` | It may only be used by a client |
| `expirationSeconds: 86400` | Valid for 24 hours |

The request is `Pending` until somebody with the right to approve it acts.

### Step 4: approve it (you are the administrator)

`kubectl certificate approve thabo` marks it approved; the signer in the controller manager then signs it, and the condition becomes `Approved,Issued`. In real life, this is the moment to check that the name in the request is the person who asked.

### Step 5: fetch the certificate and make the login

The signed certificate is in the CSR's `status.certificate`, base64-encoded; `base64 -d` writes it to `thabo.crt`. `kubectl config set-credentials thabo ... --embed-certs=true` adds a user `thabo` to your kubeconfig, with the certificate and key copied **into** the file, so it keeps working if the files move. `set-context thabo` combines the cluster `minikube` with that user. Thabo would normally get a kubeconfig of his own; here both live in yours, for the demo.

### Step 6: work as Thabo

`--context=thabo` makes `kubectl` present Thabo's certificate. The API server authenticates him as `thabo`, and RBAC applies his bindings from Lab 5.1: he lists DEV pods, gets `Forbidden` for deleting PROD pods, and for listing nodes. `Forbidden` (403) means "I know who you are, and you may not"; `Unauthorized` (401) would mean "I do not know who you are".

### Step 7: talk to the API without kubectl

`curl` does what `kubectl` does underneath: an HTTPS request to the API server's REST path (`/api/v1/namespaces/dev/pods`), with `--cacert` to check the server, and `--cert`/`--key` to prove the user. The answer is JSON; `jq` picks out the names. Without a certificate, the API server treats you as `system:anonymous`, and RBAC gives that user nothing: `403`.

## When something goes wrong

| What you see | What it means | What to do |
| --- | --- | --- |
| The CSR stays `Pending` | Nobody approved it | `kubectl certificate approve NAME` |
| `Approved` but no `Issued` | The signer name or usages are wrong | Check `signerName: kubernetes.io/kube-apiserver-client` and `usages: [client auth]` |
| `error: You must be logged in to the server (Unauthorized)` | The certificate is not trusted, expired, or the key does not match | Check the dates (`openssl x509 -noout -dates`) and redo the CSR |
| `Forbidden` | Authenticated, but RBAC does not allow it | Add a Role and a RoleBinding (Lab 5.1) |
| Everything says `Forbidden` after `kubectx thabo` | You are still Thabo | `kubectx minikube` |
| The context stops working after a day | The certificate expired after 24 hours | Make a new CSR |

## For the exam

- The task "create a user from this `.csr` file": a CertificateSigningRequest with the base64 request, `signerName: kubernetes.io/kube-apiserver-client`, `usages: [client auth]`; then `kubectl certificate approve`; then a Role and RoleBinding for the user. The documentation page "Certificates and Certificate Signing Requests" has the YAML.
- `kubectl config set-credentials`, `set-context`, `use-context`, and `view --minify` are the kubeconfig commands to know.
- Know where the CA and the API server certificates are on a kubeadm node: `/etc/kubernetes/pki/`. `kubeadm certs check-expiration` shows their dates.
- 401 Unauthorized is an authentication problem; 403 Forbidden is an authorization problem.

## Check your understanding

1. Where does Kubernetes get the user name from a client certificate?
2. Why is the private key never sent to the cluster?
3. Who signs Thabo's certificate, and with what?
4. What is the difference between `Unauthorized` and `Forbidden`?
5. Thabo leaves the company tomorrow. His certificate is valid for another 20 hours. What do you do?

<details><summary>Answers</summary>

1. From the `CN` field; groups come from `O`.
2. Only the user needs it, to prove they own the certificate. The request carries only the public half.
3. The controller manager's signer, with the cluster's CA key, after an administrator approves the CSR.
4. `Unauthorized` (401): the cluster does not know who you are. `Forbidden` (403): it knows, and RBAC does not allow the request.
5. Delete his RoleBindings. The certificate cannot be cancelled, but without bindings it is worth nothing.

</details>

**Back to:** [Lab 5.2](./lab-5.2-tls-access-to-the-api.md) · **Next:** [Lab 6.1 explained](../06-logging-monitoring/lab-6.1-application-and-system-logs-explained.md)
