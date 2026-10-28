Both pods use the secret `firstsecret` from [08-secrets.md](./08-secrets.md) (`kubectl create secret generic firstsecret --from-literal=dbpassword=mypassword123`).

##### 09-mounting-secrets-secretmount.yaml

```sh
apiVersion: v1
kind: Pod
metadata:
  name: secretmount
spec:
  containers:
  - name: secretmount
    image: nginx
    volumeMounts:
    - name: foo
      mountPath: "/etc/foo"
      readOnly: true
  volumes:
  - name: foo
    secret:
      secretName: firstsecret
```

This is also the file [`09-mounting-secrets-secretmount.yaml`](./09-mounting-secrets-secretmount.yaml) in this folder: `kubectl apply -f 09-mounting-secrets-secretmount.yaml`

##### Mounting Secrets as Environment Variables

File Name: secret-env.yaml

```sh
apiVersion: v1
kind: Pod
metadata:
  name: secret-env
spec:
  containers:
  - name: secret-env
    image: nginx
    env:
      - name: SECRET_USERNAME
        valueFrom:
          secretKeyRef:
            name: firstsecret
            key: dbpassword
  restartPolicy: Never
```

This is also the file [`09-mounting-secrets-secret-env.yaml`](./09-mounting-secrets-secret-env.yaml) in this folder: `kubectl apply -f 09-mounting-secrets-secret-env.yaml`
