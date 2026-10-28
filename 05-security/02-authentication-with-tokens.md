### Documentation and Websites Referred:

https://kubernetes.io/docs/reference/access-authn-authz/authentication/

https://token.dev/


#### Step 1: Create a new Service Account:
```sh
kubectl create serviceaccount external
```

#### Step 2: Create a new POD with External Service Account
```sh
kubectl run external-pod --image=nginx --dry-run=client -o yaml > pod-sa.yaml
```
Add following contents under .spec
```sh
serviceAccountName: external
```
Final File will look like this:

```sh
apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: null
  labels:
    run: external-pod
  name: external-pod
spec:
  serviceAccountName: external
  containers:
  - image: nginx
    name: external-pod
    resources: {}
  dnsPolicy: ClusterFirst
  restartPolicy: Always
status: {}
```

This is also the file [`02-authentication-with-tokens.yaml`](./02-authentication-with-tokens.yaml) in this folder: `kubectl apply -f 02-authentication-with-tokens.yaml`

```sh
kubectl apply -f pod-sa.yaml
```
#### Step 3: Verification
```sh
kubectl get pods
kubectl get pod external-pod -o yaml
```
#### Step 4: Fetch the Token of a POD

```sh
kubectl exec -it external-pod -- bash
cat /var/run/secrets/kubernetes.io/serviceaccount/token
```

#### Step 5: Make a Request to Kubernetes using Token
`kubectl cluster-info` shows `<K8S-SERVER-URL>` (on minikube, `https://192.168.49.2:8443`; on a kubeadm cluster, `https://controlplane:6443`).
```sh
curl -k <K8S-SERVER-URL>
curl -k <K8S-SERVER-URL>/api/v1 --header "Authorization: Bearer <TOKEN-HERE>"
```

You can also get a token for the service account without a pod. Tokens are short-lived (1 hour by default); service accounts no longer get a permanent token Secret since v1.24:
```sh
kubectl create token external
```
