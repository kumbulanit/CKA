# Persistent Volumes

  - Take me to [Lecture](https://kodekloud.com/topic/persistent-volumes-4/)

In this section, we will take a look at **Persistent Volumes**

- In the large evnironment, with a lot of users deploying a lot of pods, the users would have to configure storage every time for each Pod.
- Whatever storage solution is used, the users who deploys the pods would have to configure that on all pod definition files in his environment. Every time a change is to be made, the user would have to make them on all of his pods.



- A Persistent Volume is a cluster-wide pool of storage volumes configured by an administrator to be used by users deploying application on the cluster. The users can now select storage from this pool using Persistent Volume Claims.

  `pv-definition.yaml`:

  ```yaml
  kind: PersistentVolume
  apiVersion: v1
  metadata:
    name: pv-vol1
  spec:
    accessModes: [ "ReadWriteOnce" ]
    capacity:
     storage: 1Gi
    hostPath:
     path: /tmp/data
  ```

  This is also the file [`07-persistent-volumes-pv-definition.yaml`](./07-persistent-volumes-pv-definition.yaml) in this folder: `kubectl apply -f 07-persistent-volumes-pv-definition.yaml`

  ```
  $ kubectl create -f pv-definition.yaml
  persistentvolume/pv-vol1 created

  $ kubectl get pv
  NAME      CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM   STORAGECLASS   REASON   AGE
  pv-vol1   1Gi        RWO            Retain           Available                                   3min
  
  $ kubectl delete pv pv-vol1
  persistentvolume "pv-vol1" deleted
  ```

#### Kubernetes Persistent Volumes

- https://kubernetes.io/docs/concepts/storage/persistent-volumes/
- https://portworx.com/tutorial-kubernetes-persistent-volumes/

