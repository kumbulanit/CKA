# Practice Test - Storage Class
  
  - Take me to [Practice Test](https://kodekloud.com/topic/practice-test-storage-class-2/)

#### Practice setup (your own cluster)

The test starts with two storage classes and a local PersistentVolume on the worker `minikube-m02` (`node01` on a kubeadm cluster). Create them first:

```
minikube ssh -n minikube-m02 -- sudo mkdir -p /opt/vol1
cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-storage
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-io-priority-high
provisioner: kubernetes.io/portworx-volume
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: local-pv
spec:
  capacity:
    storage: 500Mi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage
  local:
    path: /opt/vol1
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - minikube-m02
EOF
```

This is also the file [`13-practice-test-storage-class-local-storage.yaml`](./13-practice-test-storage-class-local-storage.yaml) in this folder: `kubectl apply -f 13-practice-test-storage-class-local-storage.yaml`

Then: (7) create the PVC `local-pvc`; (8–10) see why it stays Pending; (11) create the pod `nginx` that uses it; (12) create the storage class `delayed-volume-sc`.

#### Solution

  1. Check the Solution

     <details>

      ```
      0
      ```
    
     </details>

  2. Check the Solution

     <details>

      ```
      2
      ```
     </details>
 
  3. Check the Solution

     <details>

      ```
      local-storage
      ```
     </details>

  4. Check the Solution
    
     <details>

      ```
      WaitForFirstConsumer
      ```
      </details>

  5. Check the Solution

     <details>

      ```
      portworx-volume
      ```

     </details>

  6. Check the Solution

     <details>

      ```
      NO
      ```
     </details>

  7. Check the Solution

     <details>

      ```
      apiVersion: v1
      kind: PersistentVolumeClaim
      metadata:
        name: local-pvc
      spec:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 500Mi
        storageClassName: local-storage
      ```

      This is also the file [`13-practice-test-storage-class-local-pvc.yaml`](./13-practice-test-storage-class-local-pvc.yaml) in this folder: `kubectl apply -f 13-practice-test-storage-class-local-pvc.yaml`

     </details>

  8. Check the Solution

     <details>

      ```
      Pending
      ```
     </details>

  9. Check the Solution

     <details>

      ```
      A Pod consuming the volume in not scheduled
      ```
     </details>

  10. Check the Solution

      <details>
 
       ```
       The Storage Class called local-storage makes use of VolumeBindingMode set to WaitForFirstConsumer. This will delay the binding and provisioning of a PersistentVolume until a Pod using the PersistentVolumeClaim is created.
       ```
      </details>

  11. Check the Solution

      <details>
 
       ```
       apiVersion: v1
       kind: Pod
       metadata:
         name: nginx
         labels:
           name: nginx
       spec:
           containers:
           - name: nginx
             image: nginx:alpine
             volumeMounts:
             - name: local-persistent-storage
               mountPath: /var/www/html
           volumes:
           - name: local-persistent-storage
             persistentVolumeClaim:
               claimName: local-pvc
       ```

       This is also the file [`13-practice-test-storage-class-nginx.yaml`](./13-practice-test-storage-class-nginx.yaml) in this folder: `kubectl apply -f 13-practice-test-storage-class-nginx.yaml`

      </details>

  12. Check the Solution

      <details>
 
       ```
       apiVersion: storage.k8s.io/v1
       kind: StorageClass
       metadata:
         name: delayed-volume-sc
       provisioner: kubernetes.io/no-provisioner
       volumeBindingMode: WaitForFirstConsumer
       ```

       This is also the file [`13-practice-test-storage-class-delayed-volume-sc.yaml`](./13-practice-test-storage-class-delayed-volume-sc.yaml) in this folder: `kubectl apply -f 13-practice-test-storage-class-delayed-volume-sc.yaml`

      </details>


