Both pods use the secret `firstsecret` from *secret-data.md* (`kubectl create secret generic firstsecret --from-literal=dbpassword=mypassword123`).

##### secretpod.yaml

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

This is also the file [`mounting-secrets-secretmount.yaml`](./mounting-secrets-secretmount.yaml) in this folder: `kubectl apply -f mounting-secrets-secretmount.yaml`

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

This is also the file [`mounting-secrets-secret-env.yaml`](./mounting-secrets-secret-env.yaml) in this folder: `kubectl apply -f mounting-secrets-secret-env.yaml`
