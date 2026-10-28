#### Step 1: Create a new deployment:

03-deployment.yaml

```sh
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kplabs-deployment
spec:
  replicas: 5
  selector:
    matchLabels:
      tier: frontend
  template:
    metadata:
      labels:
        tier: frontend
    spec:
      containers:
      - name: php-redis
        image: nginx
```

This is also the file [`03-deployment.yaml`](./03-deployment.yaml) in this folder: `kubectl apply -f 03-deployment.yaml`

```sh
kubectl apply -f 03-deployment.yaml
```
```sh
kubectl get replicasets
```

#### Step 2: Update the Image in Deployments

Modify image from nginx to nginx:1.17.3

Final code will look as follows:

```sh
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kplabs-deployment
spec:
  replicas: 5
  selector:
    matchLabels:
      tier: frontend
  template:
    metadata:
      labels:
        tier: frontend
    spec:
      containers:
      - name: php-redis
        image: nginx:1.17.3
```

This is also the file [`03-deployment-2.yaml`](./03-deployment-2.yaml) in this folder: `kubectl apply -f 03-deployment-2.yaml`

```sh
kubectl apply -f 03-deployment-2.yaml
```

#### Step 3: Check for Deployment Events
```sh
kubectl describe deployment kplabs-deployment
```

#### Step 4: Check for Rollout History
```sh
kubectl rollout history deployment/kplabs-deployment

kubectl rollout history deployment/kplabs-deployment --revision 1
kubectl rollout history deployment/kplabs-deployment --revision 2
```