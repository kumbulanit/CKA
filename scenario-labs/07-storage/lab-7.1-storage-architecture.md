# Lab 7.1: Storage architecture: why the Shop keeps losing its Juice

**The situation:** three times now the Shop lost the items that were added: when the database stopped (Lab 1.7), when the cluster restarted (Lab 2.1) and when a node was drained (Lab 2.7). For a real shop that means lost orders.

**Goal:** see the problem one more time, on purpose, and understand the parts Kubernetes offers to solve it.

**Outline topic:** Storage: *Storage architecture*.

**What you learn:** container files, volumes, `emptyDir`, and the three storage objects: PersistentVolume, PersistentVolumeClaim, StorageClass.

📘 **More detail:** [Lab 7.1 explained](./lab-7.1-storage-architecture-explained.md): what happens in the cluster at each step, common mistakes and exam notes.

> **How to use this lab**
>
> - **📋 Copy and paste into your terminal:** copy the whole grey box (the copy button is in its top right corner), paste it into the terminal of your server, and press Enter.
> - **👀 You should see** *(do not paste)*: what the command prints. Names that end in random letters, IP addresses and ages are different on your server. That is normal.
> - **📖 Read only:** something to look at. Do not paste it.
> - **💡 Tip:** a shortcut or an extra. You do not need it to finish the lab.

## Where can a pod keep files?

| Place | Lives as long as | Good for |
| --- | --- | --- |
| Inside the container | The container. A restart wipes it. | Nothing you want to keep |
| A volume of type `emptyDir` | The **pod**. A new pod gets a new, empty one. | Temporary files, caches |
| A **PersistentVolume** | You decide. It outlives pods. | Databases, uploads: data you must keep |

The Shop's database uses an `emptyDir` (Lab 1.6). That is the problem.

## Before you start

Go to the folder of this module, and make `dev` your working namespace:

**📋 Copy and paste into your terminal:**

```bash
cd ~/CKA/scenario-labs/07-storage
kubectl config set-context --current --namespace=dev
```

**What this does:**

- `cd ~/CKA/scenario-labs/07-storage`: Goes to the folder `~/CKA/scenario-labs/07-storage`.
- `kubectl config set-context --current --namespace=dev`: Makes `dev` your working namespace: commands without `-n` now work in `dev`.

**👀 You should see** *(do not paste)*:

```text
Context "minikube" modified.
```

💡 **Tip:** `kubens dev` does the same as the second line (see the shortcuts in [setup, Step 5](../00-setup.md)).

## Step 1: see the volume the database uses now

**📋 Copy and paste into your terminal:**

```bash
kubectl get deployment db -o jsonpath='{.spec.template.spec.volumes[0]}{"\n"}'
```

**What this does:** Reads the Deployment `db`, and prints only one value from it.

**👀 You should see** *(do not paste)*:

```text
{"emptyDir":{},"name":"data"}
```

## Step 2: add an item

**📋 Copy and paste into your terminal:**

```bash
curl -s -X POST http://$(minikube ip):30080/api/items \
  -H 'Content-Type: application/json' \
  -d '{"name":"Juice","price":20}' -w '%{http_code}\n'
curl -s http://$(minikube ip):30080/api/items; echo
```

**What this does:**

- `curl -s -X POST ...`: Adds a new item, Juice, to the Shop, as a customer filling in a form would (a POST request). `-w` prints only the answer code: `201` means it was created.
- `curl -s http://$(minikube ip):30080/api/items; echo`: Asks the Shop for its items, as a web browser would.

**👀 You should see** `201`, and then four items *(do not paste)*:

```text
201
[{"id":1,"name":"Coffee","price":35},
 {"id":2,"name":"Tea","price":25},
 {"id":3,"name":"Muffin","price":30},
 {"id":4,"name":"Juice","price":20}]
```

## Step 3: delete the database pod

A pod can be replaced at any time: a node is drained, a pod is evicted, someone deletes it. Do it yourself:

**📋 Copy and paste into your terminal:**

```bash
kubectl delete pod -l app=db
kubectl rollout status deployment/db
sleep 40
curl -s http://$(minikube ip):30080/api/items; echo
```

**What this does:**

- `kubectl delete pod -l app=db`: Deletes the pod with the label `app=db`.
- `kubectl rollout status deployment/db`: Waits until the new pods of the Deployment `db` are all ready, and says when it is done.
- `sleep 40`: Waits 40 seconds, to give the backend time to connect to the new database pod.
- `curl -s http://$(minikube ip):30080/api/items; echo`: Asks the Shop for its items, as a web browser would.

**👀 You should see** only three items *(do not paste)*:

```text
pod "db-5568b9454f-tqm8d" deleted from dev namespace
deployment "db" successfully rolled out
[{"id":1,"name":"Coffee","price":35},
 {"id":2,"name":"Tea","price":25},
 {"id":3,"name":"Muffin","price":30}]
```

![The Juice is gone after the database pod was deleted](../images/data-lost.png)

The **Juice is gone**. The new pod got a new, empty `emptyDir`, and the database started from its first three items.

If you get an error instead of the list, the backend is still connecting to the new database. Wait 15 seconds and run `shop items` again.

## The solution: three objects

| Object | What it is | Who makes it | Like |
| --- | --- | --- | --- |
| **PersistentVolume (PV)** | A real piece of disk | The administrator | A parking space |
| **PersistentVolumeClaim (PVC)** | A request: "I need 1Gi of disk" | The application | A parking ticket |
| **StorageClass** | The **kind** of disk, and who makes it | The administrator | The type of car park |

A pod never names a disk. It names a **claim**. Kubernetes joins the claim to a volume that fits. That is called **binding**. When the pod is replaced, the new pod uses the same claim, and gets the same disk with the same data.

**📖 Read only (do not paste):**

```text
Pod  →  PersistentVolumeClaim  →  PersistentVolume  →  the real disk
        "I need 1Gi"               "here is 1Gi"        (a folder, NFS, a cloud disk)
```

## Step 4: see what storage the cluster has now

**📋 Copy and paste into your terminal:**

```bash
kubectl get storageclass
kubectl get pv
kubectl get pvc -A
```

**What this does:**

- `kubectl get storageclass`: Lists the storage classes.
- `kubectl get pv`: Lists the PersistentVolumes (disks).
- `kubectl get pvc -A`: Lists the PersistentVolumeClaims (requests for a disk) in all namespaces.

**👀 You should see** one storage class, and no volumes and no claims yet *(do not paste)*:

```text
NAME                 PROVISIONER                RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
standard (default)   k8s.io/minikube-hostpath   Delete          Immediate           false                  4m14s
No resources found
No resources found
```

In the next lab you make the first disk, and give it to the database.

💡 **Exam tip:** a PersistentVolume belongs to the **cluster** (no namespace). A PersistentVolumeClaim belongs to a **namespace**. That is why `kubectl get pv` needs no `-n`, and `kubectl get pvc` does.

✅ **Check:** you saw the Juice disappear, and you can name the three storage objects.

## More practice

The Shop part of the lab is done. These exercises use test pods in `dev`, and the clean-up at the end removes them and their files.

### 🟡 Practice 1: `emptyDir` survives a container crash, not a pod delete

**⌨️ Command line option:** none. `kubectl run` cannot add a volume, so the YAML is the only way.

**📋 Copy and paste into your terminal:**

```bash
cat > scratch.yaml <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: scratch
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "while [ ! -f /tmp/stop ]; do sleep 1; done"]   # runs until the file /tmp/stop exists
    volumeMounts:
    - name: work
      mountPath: /work
  volumes:
  - name: work
    emptyDir: {}
YAML
kubectl apply -n dev -f scratch.yaml
kubectl wait pod/scratch -n dev --for=condition=Ready --timeout=60s
kubectl exec scratch -n dev -- sh -c 'echo "saved at $(date +%T)" > /work/note.txt'
kubectl exec scratch -n dev -- touch /tmp/stop
sleep 10
kubectl get pod scratch -n dev
kubectl exec scratch -n dev -- cat /work/note.txt
```

**What this does:**

- `cat > scratch.yaml <<'YAML' ...`: Writes the YAML between the two `YAML` lines into the file `scratch.yaml`: a pod with an `emptyDir` folder at `/work`. Its program runs until the file `/tmp/stop` exists.
- `kubectl apply -n dev -f scratch.yaml`: Creates the pod `scratch`.
- `kubectl wait pod/scratch ...`: Waits until the pod is ready.
- `kubectl exec scratch ... > /work/note.txt'`: Writes a file into `/work`.
- `kubectl exec scratch -n dev -- touch /tmp/stop`: Makes the file `/tmp/stop`, so the program ends, as if it crashed. The kubelet starts the container again, in the same pod. (`/tmp` is inside the container, so the new container does not have that file.)
- `sleep 10`: Waits 10 seconds.
- `kubectl get pod scratch -n dev`: Shows the pod: `RESTARTS` is now 1.
- `kubectl exec scratch -n dev -- cat /work/note.txt`: Reads the note in the new container.

**👀 You should see** `RESTARTS 1`, and the note is still there: an `emptyDir` belongs to the **pod**, not to the container. Now delete the pod and make it again from the same file:

**📋 Copy and paste into your terminal:**

```bash
kubectl delete pod scratch -n dev --now
kubectl apply -n dev -f scratch.yaml
kubectl wait pod/scratch -n dev --for=condition=Ready --timeout=60s
kubectl exec scratch -n dev -- cat /work/note.txt
```

**What this does:**

- `kubectl delete pod scratch -n dev --now`: Deletes the pod.
- `kubectl apply -n dev -f scratch.yaml`: Makes the same pod again.
- `kubectl wait pod/scratch ...`: Waits until it is ready.
- `kubectl exec scratch -n dev -- cat /work/note.txt`: Tries to read the note.

**👀 You should see** `No such file or directory`. A new pod gets a new, empty folder. This is exactly what happened to the Juice.

### 🟡 Practice 2: `hostPath`: the files stay, but on one node only

**⌨️ Command line option:** none. `kubectl run` cannot add a volume.

**📋 Copy and paste into your terminal:**

```bash
for n in minikube minikube-m02; do
kubectl apply -n dev -f - <<YAML
apiVersion: v1
kind: Pod
metadata:
  name: host-$n
spec:
  nodeSelector:
    kubernetes.io/hostname: $n
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    hostPath:
      path: /data/practice        # a folder on the node itself
      type: DirectoryOrCreate
YAML
done
kubectl wait pod/host-minikube pod/host-minikube-m02 -n dev --for=condition=Ready --timeout=60s
kubectl exec host-minikube-m02 -n dev -- sh -c 'echo "written on m02" > /data/note.txt'
kubectl exec host-minikube -n dev -- ls /data
minikube ssh -n minikube-m02 -- cat /data/practice/note.txt
```

**What this does:**

- `for n in minikube minikube-m02; do ... done`: Creates two pods, `host-minikube` and `host-minikube-m02`, one on each node. Both mount the node's folder `/data/practice` at `/data`. (This time the `YAML` word has no quotes, so the shell fills in `$n`.)
- `kubectl wait ...`: Waits until both pods are ready.
- `kubectl exec host-minikube-m02 ...`: Writes a file from the pod on `minikube-m02`.
- `kubectl exec host-minikube -n dev -- ls /data`: Lists the folder from the pod on `minikube`.
- `minikube ssh -n minikube-m02 -- cat /data/practice/note.txt`: Reads the file straight from the node `minikube-m02`.

**👀 You should see** nothing from `ls` (the folder on `minikube` is empty), and `written on m02` from the node. The file is on the **node**: it survives any pod, but only pods on that node see it. That is why the disk in Lab 7.2 says which node it is on.

### 🔵 Optional 3: all the kinds of volumes

**📋 Copy and paste into your terminal:**

```bash
kubectl explain pod.spec.volumes | awk '/^FIELDS/{f=1;next} f && /^  [a-zA-Z]/{print $1}' | tr '\n' ' '; echo
```

**What this does:** Asks the API for the description of a pod's volumes, and keeps only the names of the kinds of volume (the lines under `FIELDS`), on one line.

**👀 You should see** a list with `configMap`, `emptyDir`, `hostPath`, `nfs`, `persistentVolumeClaim`, `projected`, `secret` and more. You already used `configMap` (Lab 1.5) and `emptyDir`; Lab 7.2 adds `persistentVolumeClaim`.

### 🔵 Optional 4: challenge

Without looking at the answer: make a pod `fast-cache` in `dev` with an `emptyDir` **in memory** (not on disk), at most 16Mi, mounted at `/cache`. Prove that it is memory.

<details><summary>Show the answer</summary>

**📋 Copy and paste into your terminal:**

```bash
kubectl apply -n dev -f - <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: fast-cache
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
    volumeMounts:
    - name: cache
      mountPath: /cache
  volumes:
  - name: cache
    emptyDir:
      medium: Memory              # RAM instead of the node's disk
      sizeLimit: 16Mi
YAML
kubectl wait pod/fast-cache -n dev --for=condition=Ready --timeout=60s
kubectl exec fast-cache -n dev -- df -h /cache
```

**What this does:** Creates the pod, waits until it is ready, and shows the size and kind of the folder `/cache`.

**👀 You should see** the filesystem `tmpfs`: memory. It is very fast, and it counts against the pod's memory limit.

</details>

🧹 **Clean up the practice:**

**📋 Copy and paste into your terminal:**

```bash
kubectl delete pod scratch host-minikube host-minikube-m02 fast-cache -n dev --now --ignore-not-found
minikube ssh -n minikube-m02 -- sudo rm -rf /data/practice
minikube ssh -- sudo rm -rf /data/practice
rm -f scratch.yaml
```

**What this does:**

- `kubectl delete pod ...`: Deletes the test pods, at once.
- `minikube ssh ... sudo rm -rf /data/practice`: Deletes the practice folder on the nodes `minikube-m02` and `minikube`.
- `rm -f scratch.yaml`: Deletes the saved YAML file.

**Next:** [Lab 7.2: Storage backends](./lab-7.2-storage-backends.md)
