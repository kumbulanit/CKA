# Lab 1.2 explained: pods, labels and selectors

This page goes with [Lab 1.2](./lab-1.2-pods-labels-selectors.md). The lab has the commands; this page explains them: what happens in the cluster, why it matters for the Shop, what usually goes wrong, and what the exam asks. There is nothing to paste here.

## In short

A **pod** is the smallest thing Kubernetes runs. You describe it in a YAML file, hand the file to the API server, and the scheduler and a kubelet make it run. **Labels** are name tags on objects; **selectors** find objects by their tags. Almost everything in Kubernetes connects through labels and selectors.

## The ideas behind this lab

### What a pod is

A pod wraps one container (sometimes a few that belong together). Everything in a pod shares one network address and can share files. A pod is **mortal**: when it dies or is deleted, it is gone. A new pod is a new pod, with a new name and a new IP address.

That is fine for a test, but not for the Shop. This lab shows the problem on purpose: you delete the backend, and nothing brings it back.

### What happens when you `kubectl apply` a pod

1. `kubectl` sends the YAML to the **API server**.
2. The API server checks it and stores the pod in **etcd**. The pod has no node yet: its status is `Pending`.
3. The **scheduler** sees a pod without a node, picks one, and writes the node's name into the pod.
4. The **kubelet** on that node sees a pod for its node. It asks the container runtime to download the image and start the container (`ContainerCreating`).
5. The network plugin gives the pod an IP address.
6. The container starts; the kubelet reports `Running`.

Every step is a different part of the cluster, and each part only talks to the API server. That is the pattern of all of Kubernetes.

### The parts of a YAML file

Every Kubernetes object has the same four parts:

| Part | Meaning |
| --- | --- |
| `apiVersion` | Which version of the API describes this kind (`v1` for pods) |
| `kind` | What it is: `Pod`, `Deployment`, `Service`... |
| `metadata` | Its name, namespace and labels |
| `spec` | What you want: for a pod, the containers |

Kubernetes adds a fifth part, `status`, which says what really is. `spec` is your wish, `status` is the truth.

### Labels and selectors

A label is a `key=value` pair, such as `app=backend`. It means nothing to Kubernetes on its own. It becomes powerful when something **selects** by it:

- `kubectl get pods -l app=backend` lists only matching pods.
- A Deployment (Lab 1.3) finds its pods by label.
- A Service (Lab 1.4) sends traffic to the pods with a label.
- A NetworkPolicy (Lab 3.1) allows traffic between labels.

The label `app=backend` you see here is the thread that ties the whole Shop together.

## Step by step

### Step 1: look at the file

The image `postgrest/postgrest:v12.2.3` is the backend program: PostgREST turns a PostgreSQL database into a web API. `containerPort: 3000` is information for people and tools; the program listens on 3000 whether the line is there or not.

### Step 2: create the pod

`kubectl apply -f` creates the object if it is new, or updates it if it exists. It is the command you use for files all through the course.

### Step 3: watch it start

The first time, the node must download the image, which takes a few seconds: `ContainerCreating`. `-o wide` adds the pod's IP address and its node. The IP comes from the pod network (`10.244.x.x`), which only exists inside the cluster.

### Step 4: read the logs

`kubectl logs` shows what the program wrote to its screen (stdout and stderr). The kubelet keeps it in a file on the node (Lab 6.2). The backend says it cannot reach a database: correct, there is none yet. Reading logs to tell "broken" from "waiting for something" is a skill you use all week.

### Step 5: look at the labels

`--show-labels` adds a column with all labels. `-l app=backend` is a selector. You can combine labels (`-l app=backend,tier=api`) or use sets (`-l 'app in (backend,frontend)'`).

### Step 6: look at all the details

`kubectl describe` collects everything about one object in readable form: its labels, node, IP, image, the state of each container, and at the bottom the **events**: `Scheduled`, `Pulling`, `Pulled`, `Created`, `Started`. When a pod does not start, the events almost always say why (Lab 8.1).

### Step 7: delete the pod

The kubelet stops the container (it asks politely first, then forces it after 30 seconds), and the pod disappears. No controller is watching this pod, so nothing replaces it. That is the weakness the next lab fixes with a Deployment.

## When something goes wrong

| What you see | What it means | What to do |
| --- | --- | --- |
| `ContainerCreating` for a long time | The image is still downloading | Wait; `kubectl describe pod backend` shows `Pulling` |
| `ErrImagePull` or `ImagePullBackOff` | The image name is wrong, or there is no internet | Check the image name in the file |
| `Pending` | No node was chosen yet | `kubectl describe pod backend`: the events say why |
| `pods "backend" already exists` with `kubectl create` | It is there already | Use `kubectl apply`, which updates instead |
| The logs complain about a database | Expected until Lab 1.6 | Nothing to do |

## For the exam

- Never start YAML from an empty file. `kubectl run NAME --image=IMAGE --dry-run=client -o yaml > pod.yaml` writes a correct pod for you to edit.
- `kubectl explain pod.spec.containers` lists the fields without leaving the terminal.
- Labels can be added or changed on a running pod: `kubectl label pod backend tier=api`.
- When a task says "the pod is not running", go straight to `kubectl describe pod` and read the events.

## Check your understanding

1. Which part of the cluster chooses the node for the pod?
2. What is the difference between `spec` and `status`?
3. Why did the deleted pod not come back?
4. What do a Deployment, a Service and a NetworkPolicy have in common?
5. The pod shows `ImagePullBackOff`. Where do you look first?

<details><summary>Answers</summary>

1. The scheduler.
2. `spec` is what you asked for; `status` is what Kubernetes reports is really there.
3. Nothing was watching it: a pod on its own has no controller to replace it.
4. They all find pods by their labels, with a selector.
5. `kubectl describe pod`, at the events: they show the image name and the error from the registry.

</details>

**Back to:** [Lab 1.2](./lab-1.2-pods-labels-selectors.md) · **Next:** [Lab 1.3 explained](./lab-1.3-deployments-explained.md)
