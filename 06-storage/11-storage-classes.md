# Storage Class

  - Take me to [Lecture](https://kodekloud.com/topic/storage-class/)

In this section, we will take a look at **Storage Class**

- We discussed about how to create Persistent Volume and Persistent Volume Claim and We also saw that how to use into the Pod's volume to claim that volume space.
- We created Persistent Volume but before this if we are taking a volume from Cloud providers like GCP, AWS, Azure. We need to first create disk in the Google Cloud as an example. 
- We need to create manually each time when we define in the Pod definition file. that's called **Static Provisioning**. 

#### Static Provisioning



#### Dynamic Provisioning


- Now we have a Storage Class, So we no longer to define Persistent Volume. It will create automatically when a Storage Class is created. It's called **Dynamic Provisioning**. 

`11-storage-classes-sc-definition.yaml`:

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
   name: google-storage
provisioner: pd.csi.storage.gke.io
```

This is also the file [`11-storage-classes-sc-definition.yaml`](./11-storage-classes-sc-definition.yaml) in this folder: `kubectl apply -f 11-storage-classes-sc-definition.yaml`

The provisioner is the cloud's CSI driver (`pd.csi.storage.gke.io` on Google Cloud, `ebs.csi.aws.com` on AWS, `disk.csi.azure.com` on Azure). The old in-tree names such as `kubernetes.io/gce-pd` no longer exist.

**On minikube, or a kubeadm cluster on your own machines**, there is no cloud disk. minikube already has a default StorageClass (`standard`); to practise with the local-path provisioner this lesson uses, install it (it creates volumes in a folder on the node):

```
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.37/deploy/local-path-storage.yaml
kubectl get storageclass
```

Then use `storageClassName: local-path` in the claim below.

#### Create a Storage Class

```
kubectl create -f 11-storage-classes-sc-definition.yaml
```
Output:
```
storageclass.storage.k8s.io/google-storage created
```

#### List the Storage Class

```
kubectl get sc
```
Output:
```
NAME             PROVISIONER            RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
google-storage   pd.csi.storage.gke.io  Delete          Immediate           false                  20s
```

#### Create a Persistent Volume Claim

If `mypod` and `myclaim` from *Using PVC in PODs* are still there, delete them first (`kubectl delete pod mypod`, then `kubectl delete pvc myclaim`): a claim's storage class cannot be changed.

`11-storage-classes-pvc-definition.yaml`:

```yaml
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: myclaim
spec:
  accessModes: [ "ReadWriteOnce" ]
  storageClassName: google-storage       
  resources:
   requests:
     storage: 500Mi
```

This is also the file [`11-storage-classes-pvc-definition.yaml`](./11-storage-classes-pvc-definition.yaml) in this folder: `kubectl apply -f 11-storage-classes-pvc-definition.yaml`

```
kubectl create -f 11-storage-classes-pvc-definition.yaml

```
#### Create a Pod

`11-storage-classes-pod-definition.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: mypod
spec:
  containers:
    - name: frontend
      image: nginx
      volumeMounts:
      - mountPath: "/var/www/html"
        name: web
  volumes:
    - name: web
      persistentVolumeClaim:
        claimName: myclaim
```

This is also the file [`11-storage-classes-pod-definition.yaml`](./11-storage-classes-pod-definition.yaml) in this folder: `kubectl apply -f 11-storage-classes-pod-definition.yaml`

```
kubectl create -f 11-storage-classes-pod-definition.yaml
```
#### Provisioner


#### Kubernetes Storage Class Reference Docs

- https://kubernetes.io/docs/concepts/storage/storage-classes/
- https://cloud.google.com/kubernetes-engine/docs/concepts/persistent-volumes#storageclasses
- https://docs.aws.amazon.com/eks/latest/userguide/storage-classes.html
