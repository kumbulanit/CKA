##### Generating Secret Based on Generic - Literal Value
```sh
kubectl create secret generic  firstsecret --from-literal=dbpassword=mypassword123
```
##### Generating Secret Based on Generic - File
```sh
echo 'dbuser=admin' > credentials.txt
kubectl create secret generic  secondsecret --from-file=./credentials.txt
```
##### To View Secret from CLI
```sh
kubectl get secret firstsecret -o yaml
kubectl get secret firstsecret -o jsonpath='{.data.dbpassword}' | base64 -d
```
Secret values are only base64-encoded, not encrypted: anyone who can read the Secret can read the value.

##### secret-data.yaml

```sh
apiVersion: v1
kind: Secret
metadata:
  name: thirdsecret
type: Opaque
data:
  username: ZGJhZG1pbg==
  password: bXlwYXNzd29yZDEyMw==
```

This is also the file [`secret-data-thirdsecret.yaml`](./secret-data-thirdsecret.yaml) in this folder: `kubectl apply -f secret-data-thirdsecret.yaml`

##### secret-stringdata.yaml

```sh
apiVersion: v1
kind: Secret
metadata:
  name: stringdata
type: Opaque
stringData:
 config.yaml: |-
   username: dbadmin
   password: mypassword

```

This is also the file [`secret-data-stringdata.yaml`](./secret-data-stringdata.yaml) in this folder: `kubectl apply -f secret-data-stringdata.yaml`
