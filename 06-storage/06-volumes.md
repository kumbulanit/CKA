# Volumes

  - Take me to [Lecture](https://kodekloud.com/topic/volumes/)

In this section, we will take a look at **Volumes**

- We discussed about Docker storage, If we don't attach the volume in the container runtime, when container destroyed and then all data will be lost. So, We need to persist data into the Docker container so we attach a volume to the containers when they are created.
- The data are processed by the container is now placed in this volume thereby retaining it permanently. Even if the container is deleted the data remains in the volume.

- In the Kubernetes world, the PODs created in Kubernetes are transient in nature. When a POD is created to process data and then deleted, the data processed by it gets deleted as well. 
- For example, We create a simple POD that generated a random between 1 and 100 and writes that to a file at `/opt/number.out`. To persist into the volume.

```
apiVersion: v1
kind: Pod
metadata:
  name: random-number-generator
spec:
  containers:
  - image: alpine
    name: alpine
    command: ["/bin/sh", "-c"]
    args: ["shuf -i 0-100 -n 1 >> /opt/number.out;"]
    volumeMounts:
    - mountPath: /opt
      name: data-volume
  restartPolicy: Never
  volumes:
  - name: data-volume
    hostPath:
      path: /data
      type: DirectoryOrCreate
```

This is also the file [`06-volumes.yaml`](./06-volumes.yaml) in this folder: `kubectl apply -f 06-volumes.yaml`

- We create a volume for that. In this case I specify a path `/data` on the host. Files are stored in the directory data on my node. We use the volumeMounts field in each container to mount the data-volume to the directory `/opt` within the container. The random number will now be written to `/opt` mount inside the container, which happens to be on the data-volume which is in fact `/data` directory on the host. When the pod gets deleted, the file with the random number still lives on the host.




## Volume Storage Options

- In the volumes, hostPath volume type is fine with the single node. It's not recommended for use with the multi node cluster.
- In the Kubernetes, it supports several types of standard storage solutions such as NFS, GlusterFS, CephFS or public cloud solutions like AWS EBS, Azure Disk or Google's Persistent Disk.




- Cloud and network storage is now provided by **CSI drivers**. The old in-tree volume types (`awsElasticBlockStore`, `gcePersistentDisk`, `azureDisk`, ...) were removed from Kubernetes; use a PersistentVolumeClaim with the provider's CSI StorageClass instead (see *Storage Class*).

#### Kubernetes Volumes Reference Docs

- https://kubernetes.io/docs/concepts/storage/volumes/
- https://kubernetes.io/docs/tasks/configure-pod-container/configure-volume-storage/
- https://kubernetes.io/docs/reference/kubernetes-api/config-and-storage-resources/volume/
