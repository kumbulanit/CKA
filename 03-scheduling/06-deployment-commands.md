#### Documentation Referred:

https://kubernetes.io/docs/concepts/workloads/controllers/deployment/

#### Create a new Deployment 
If `kplabs-deployment` from the Deployment lesson is still running, delete it first:
```sh
kubectl delete -f 03-deployment.yaml
```
```sh
kubectl create deployment kplabs-deployment --image=nginx
```
```sh
kubectl get pods
```
#### Set a New Image to Existing Deployment
There is no image called `apache`, so the new pods fail with `ErrImagePull`/`ImagePullBackOff` while the old pods keep running. That is the point: watch the rollout get stuck, then roll it back.
```sh
kubectl set image deployment/kplabs-deployment nginx=apache
kubectl rollout status deployment/kplabs-deployment --timeout=30s
```
```sh
kubectl get pods
```
#### Rolling Back changes
```sh
kubectl rollout history deployment kplabs-deployment
```
```sh
kubectl rollout undo deployment/kplabs-deployment
```
#### Recording a Change Cause
The old `--record` flag is deprecated. Set the `kubernetes.io/change-cause` annotation instead; `rollout history` shows it in the CHANGE-CAUSE column.
```sh
kubectl set image deployment/kplabs-deployment nginx=httpd
kubectl annotate deployment/kplabs-deployment kubernetes.io/change-cause="image updated to httpd"
```
```sh
kubectl rollout history deployment kplabs-deployment
```
#### Scaling Deployment

```sh
kubectl scale deployment/kplabs-deployment --replicas=10
```
```sh
kubectl get deployments
kubectl get pods
```

#### Delete the resources created in this lecture
```sh
kubectl delete deployment kplabs-deployment
```