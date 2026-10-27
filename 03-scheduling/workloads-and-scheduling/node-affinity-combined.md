### nodeAffinity-required.yaml
```sh
apiVersion: v1
kind: Pod
metadata:
  name: kplabs-node-affinity
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: disk
            operator: In
            values:
            - ssd2
  containers:
  - name: with-node-affinity
    image: nginx
```

This is also the file [`node-affinity-combined-kplabs-node-affinity.yaml`](./node-affinity-combined-kplabs-node-affinity.yaml) in this folder: `kubectl apply -f node-affinity-combined-kplabs-node-affinity.yaml`

### nodeAffinity-preferred.yaml
```sh
apiVersion: v1
kind: Pod
metadata:
  name: kplabs-node-affinity-preferred
spec:
  affinity:
    nodeAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 1
        preference:
          matchExpressions:
          - key: memory
            operator: In
            values:
            - high
            - medium
  containers:
  - name: kplabs-affinity-prefferd
    image: nginx
```

This is also the file [`node-affinity-combined-kplabs-node-affinity-preferred.yaml`](./node-affinity-combined-kplabs-node-affinity-preferred.yaml) in this folder: `kubectl apply -f node-affinity-combined-kplabs-node-affinity-preferred.yaml`
