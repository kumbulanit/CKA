# Setup explained: what `setup.sh` builds, and why

This page goes with [Setup](./00-setup.md). The setup page has the commands; this page explains them: what each step does on your server, why the course cluster looks the way it does, and what to do when something goes wrong. There is nothing to paste here.

## In short

You get one Ubuntu server. One script turns it into a Kubernetes lab: it installs the tools, builds a cluster of three nodes inside Docker, and checks that every node is `Ready`. A second script, `check-ready.sh`, tells you at any time whether the server, the cluster and the Shop are in order.

## The ideas behind this setup

### A whole cluster on one server

A real cluster has several machines: one or more **control plane** nodes (the brain) and **worker** nodes (where applications run). For a course, every participant needs their own cluster, so nobody can break anyone else's work. Several virtual machines per person would be slow and expensive.

**minikube** solves this. With the **Docker driver**, every node of the cluster is a Docker container on your server. Inside each container runs what runs on a real node: a container runtime (containerd), the kubelet, and the parts of Kubernetes. To Kubernetes, these containers are ordinary machines.

| Node | Role | What runs on it |
| --- | --- | --- |
| `minikube` | Control plane | The API server, etcd, the scheduler, the controller manager, plus system pods |
| `minikube-m02` | Worker | Your applications (and one network and one proxy pod) |
| `minikube-m03` | Worker | Your applications (and one network and one proxy pod) |

Inside, minikube uses **kubeadm**, the same tool the exam clusters are built with. So the files and folders you find on a node in Module 2 (static pod files, certificates, the kubelet) are the same as on a kubeadm cluster.

## Step by step

### Step 1: get the course files

`git clone` copies the course repository from GitHub to your server, into the folder `CKA`. Everything the labs need is in it: the lab pages, the YAML files of the Shop, and the scripts. Every lab starts with `cd` into its module's folder, so the short file names in the labs (such as `backend-pod.yaml`) are found.

### Step 2: install everything and start the cluster

`sudo ./setup.sh` needs administrator rights because it installs packages and changes system settings. It does these steps, in this order:

| Step | What it does | Why |
| --- | --- | --- |
| Packages | Installs small tools such as `curl`, `jq` and `nano` | The labs and the scripts use them |
| Docker | Installs Docker, and adds your user to the group `docker` | minikube runs the nodes as Docker containers |
| minikube, kubectl, helm | Downloads the three programs, at fixed versions | minikube builds the cluster, `kubectl` talks to it, `helm` installs Prometheus (Lab 6.4) |
| kubens and kubectx | Installs the two shortcuts | They save typing (setup Step 5) |
| System settings | Raises two Linux limits on file watching (`fs.inotify`) | Three nodes on one server watch many files; the default limits are too low and pods fail with "too many open files" |
| Shell | Adds Tab completion and the alias `k` to your `~/.bashrc` | The same help you get in the exam |
| The cluster | Runs `minikube start --driver=docker --nodes=3 --kubernetes-version=v1.36.5 --cni=calico` | One control plane and two workers, Kubernetes v1.36.5, Calico as the network plugin |
| Wait and check | Waits until all three nodes are `Ready`, uncordons nodes left cordoned, labels the workers | The labs expect three `Ready` nodes |

**Why Calico?** Kubernetes itself does not give pods a network. A **network plugin** (CNI) does. Calico also enforces **NetworkPolicies**, the firewall rules for pods in Lab 3.1. A plugin without that support would accept the rules and silently ignore them.

**Why can you run it again?** The script checks what is already there before it acts. It installs only what is missing, starts a stopped cluster, starts stopped nodes, and adds missing workers. That is why the answer to most problems is "run `setup.sh` again": it repairs, and keeps the Shop and everything else you created.

**Where does `kubectl` find the cluster?** minikube writes the address of the API server and your login (a certificate) into `~/.kube/config`. This file is your **kubeconfig**. `kubectl` reads it for every command. Its **context** called `minikube` names the cluster, the user and the namespace you work in.

### Step 3: use Docker without `sudo`

Docker only accepts commands from `root` and from members of the group `docker`. The script added your user to that group, but a running shell keeps the groups it started with. `newgrp docker` starts a new shell that has the new group. Logging out and in again does the same. Without it, `docker ps` says `permission denied ... docker.sock`.

### Step 4: check the cluster

`kubectl get nodes` asks the API server for the list of nodes. `Ready` means the kubelet on that node reports in regularly and the node has a working network. A node stays `NotReady` until its network plugin pod runs, so a node can be `NotReady` for a minute right after the start.

The `ROLES` column comes from labels. minikube gives the control plane the label `node-role.kubernetes.io/control-plane`; `setup.sh` gives the workers `node-role.kubernetes.io/worker`, so the column does not say `<none>`.

### Step 5: the shortcuts

| Shortcut | What it really does |
| --- | --- |
| `kubens dev` | Changes the namespace stored in your current context, in `~/.kube/config` |
| `kubectx thabo` | Switches to another context: another cluster or another user (Lab 5.2) |
| `k` | An alias: the shell replaces `k` with `kubectl` |
| Tab | Bash completion: `kubectl` itself suggests the possible words |

In the exam, `k` and Tab completion are ready, but `kubens` and `kubectx` are not. That is why the labs always show the full command, and point out the shortcut in a tip.

### Step 6: check that everything is ready

`check-ready.sh` only looks; it changes nothing. It checks four things, in order, because each needs the one before:

1. **The server:** Ubuntu version, CPUs, memory, free disk, internet access.
2. **The tools:** Docker (and that you may use it without `sudo`), minikube, kubectl, helm, jq, kubens and kubectx.
3. **The cluster:** all nodes running and `Ready`, `kubectl` pointed at minikube, the API server healthy, every system part running, DNS working (it starts a small test pod), a default storage class.
4. **The Shop:** for `dev`, `uat` and `prod`, whether the Shop is there and ready. Before Lab 1.1 there is no Shop yet, so this part says `INFO`.

`FAIL` always comes with a `fix:` line. Run the script at the start of every course day: it catches a stopped cluster or a full disk before the first lab, not in the middle of it.

## When something goes wrong

| What you see | What it means | What to do |
| --- | --- | --- |
| `The connection to the server ... was refused` | The cluster (or the server) was stopped | `cd ~/CKA && sudo ./setup.sh` |
| A node is `NotReady` for more than a few minutes | Its kubelet or its network pod has a problem | Run `setup.sh` again: it restarts a worker that is not `Ready` |
| `permission denied ... docker.sock` | Your shell does not have the group `docker` yet | `newgrp docker`, or log out and in again |
| `setup.sh` stops at a download | The internet connection failed for a moment | Run it again; it carries on |
| `minikube could not create the cluster` twice | Something is broken inside the cluster | `minikube delete`, then `sudo ./setup.sh` again (this deletes the Shop) |
| Pods hang or nodes fall over during the day | The server is short of memory | `check-ready.sh` shows the memory; 8 GB is the minimum, 16 GB is comfortable |

## For the exam

- The exam clusters are built with **kubeadm**, not minikube. Module 2 shows what kubeadm does and where its files are.
- Every exam task starts with a `kubectl config use-context` command. Run it first: you work on several clusters during the exam.
- `k` and Tab completion are ready to use. Practise with them now.

## Check your understanding

1. Why does every participant get their own cluster?
2. What is a node in the course cluster, physically?
3. What does Calico do that Kubernetes itself does not?
4. You open a new terminal and `docker ps` says `permission denied`. Why?
5. Your server was restarted overnight. What do you run first?

<details><summary>Answers</summary>

1. So that nobody can break anyone else's work, and everybody can do every lab, including the ones that stop parts of the cluster.
2. A Docker container on your server, with containerd and a kubelet inside.
3. It gives every pod an address and a network, and it enforces NetworkPolicies.
4. The shell was started before your user joined the group `docker`. Run `newgrp docker`, or log out and in.
5. `cd ~/CKA && sudo ./setup.sh`, then `check-ready.sh`. The cluster starts again with all your work in it.

</details>

**Back to:** [Setup](./00-setup.md) · **Next:** [Lab 1.1 explained](./01-core-concepts/lab-1.1-architecture-and-namespaces-explained.md)
