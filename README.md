# CKA
Certified Kubernetes Administrator

Notes and hands-on practicals for the CKA course. Every practical runs on the same small cluster, so the commands work exactly as written.

## The practice cluster

One Ubuntu server is all you need (a VM is fine: 4 CPUs, 8 GB RAM, 30 GB free disk, Ubuntu 22.04 or 24.04). **One command installs everything and starts the cluster** (about 10 minutes the first time):

```sh
git clone https://github.com/kumbulanit/CKA.git && cd CKA
sudo ./setup.sh
```

[setup.sh](./setup.sh) installs all the tools the course uses: Docker, minikube, kubectl v1.36 and helm, plus git, curl, jq, vim, nano and bash completion (with `k` as a short name for `kubectl`). Then it creates and starts a minikube cluster on Docker: Kubernetes **v1.36.5** with Calico, one control plane node (`minikube`) and two worker nodes (`minikube-m02`, `minikube-m03`). If a minikube cluster with fewer nodes already exists, it adds the missing workers. Run it with `sudo` from your own user, not as root. Running it again is safe; it also starts the cluster again after the server restarts.

Clone the repository as your own user (without `sudo`), in your home folder: the lessons are done as that user, inside the lesson folders (`cd ~/CKA/02-core-concepts`), and some steps create files there. If the folder was cloned with `sudo`, `setup.sh` gives it back to your user.

Log out and in once (or run `newgrp docker`) so `minikube` works without `sudo`. Then, as your own user:

```sh
kubectl get nodes                  # minikube (control plane), minikube-m02 and minikube-m03 (workers)
minikube ssh                       # a shell on the control plane node
minikube ssh -n minikube-m02       # a shell on the first worker
minikube stop                      # stop the cluster; sudo ./setup.sh or minikube start starts it again
```

The lessons use these minikube names and commands. On a kubeadm cluster (the optional route below, and the CKA exam) the same things are:

| On the minikube cluster | On a kubeadm cluster |
| --- | --- |
| `minikube` (`minikube ssh`) | `controlplane` |
| `minikube-m02` (`minikube ssh -n minikube-m02`) | `node01` (`ssh node01`) |
| `minikube-m03` (`minikube ssh -n minikube-m03`) | `node02` (`ssh node02`) |
| `kubectl` as your own user on the server | `kubectl` as root on controlplane |
| `/var/lib/minikube/certs`, API server port `8443` | `/etc/kubernetes/pki`, API server port `6443` |

minikube builds its nodes with kubeadm, so the static pod manifests (`/etc/kubernetes/manifests`), the kubelet service and `journalctl -u kubelet` are in the same places, inside `minikube ssh`.

### Optional: kubeadm, the exam's tool

The CKA exam uses kubeadm clusters. Installing a cluster with kubeadm, adding a node and the kubeadm upgrade (in [01-installation](./01-installation)) need machines without Kubernetes. [scripts/one-server.sh](./scripts/one-server.sh) runs three of them on the same server, as containers named `controlplane`, `node01` and `node02`, so those lessons work exactly as written. Stop minikube first on an 8 GB server (`minikube stop`).

```sh
sudo ./scripts/one-server.sh create        # three bare Ubuntu 24.04 machines (172.30.56.10, .11, .12)
sudo ./scripts/one-server.sh shell         # root@controlplane; shell node01 opens node01
sudo ./scripts/one-server.sh delete        # remove them
```

`sudo ./scripts/one-server.sh install` installs the kubeadm cluster on them in one go, with [scripts/install-cluster.sh](./scripts/install-cluster.sh) (the same steps as the [installation guide](./01-installation/kubeadm-lesson-install-kubeadm.md)). On separate machines, run that script as root on each one, controlplane first, with your three IP addresses: `sudo ./scripts/install-cluster.sh controlplane 192.168.56.10 192.168.56.11 192.168.56.12`. It prints the command to run on node01 and node02.

## Scripts

**Catch up when a lab runs out of time.** Each day has a script that creates what that day's labs leave in the cluster, as at the end of each lab. Run it on the server as your own user, where `kubectl` works (on a kubeadm cluster: as root on controlplane), for one lab or for the whole day. The scripts find the node names themselves, so they work on both:

```sh
./scripts/catch-up/day1.sh --list        # the labs of the day
./scripts/catch-up/day1.sh services      # one lab
./scripts/catch-up/day2.sh               # the whole day
```

| Day | Topics | Script |
| --- | --- | --- |
| 1 | Installation, configuration and validation; core concepts (modules 1–2) | [day1.sh](./scripts/catch-up/day1.sh) |
| 2 | Workloads and scheduling; services and networking; security (modules 3–5) | [day2.sh](./scripts/catch-up/day2.sh) |
| 3 | Storage; logging and monitoring; troubleshooting (modules 6–8) | [day3.sh](./scripts/catch-up/day3.sh) |

The scripts can be run again safely. They leave out what changes the machines rather than the cluster (installing, adding node03, the v1.37 upgrade, draining), and the troubleshooting labs, which set themselves up with [00-practice-setup.md](./08-troubleshooting/00-practice-setup.md).

## Course outline

Each module has a step-by-step guide in [lab-guides](./lab-guides): every command, what it does, the output it printed on the practice cluster, what to check when you see something else, and a diagram of the idea. The [images](./images) folder has the diagrams (made by `images/diagrams.py`).

| # | Topic | Folder | Step-by-step guide |
| --- | --- | --- | --- |
| 1 | Installation, configuration and validation: the minikube cluster first, then drain and etcd backup; the `kubeadm-lesson-*` files (kubeadm install, adding nodes, HA) are the optional kubeadm route | [01-installation](./01-installation) | [Installation guide](./lab-guides/02-installation.md) |
| 2 | Core concepts: pods, Namespaces, Deployments, ReplicaSets, Services | [02-core-concepts](./02-core-concepts) | [Core concepts guide](./lab-guides/01-core-concepts.md) |
| 3 | Workloads and scheduling | [03-scheduling](./03-scheduling) | [Scheduling guide](./lab-guides/03-scheduling.md) |
| 4 | Services and networking | [04-networking](./04-networking) | [Networking guide](./lab-guides/04-networking.md) |
| 5 | Security | [05-security](./05-security) | [Security guide](./lab-guides/05-security.md) |
| 6 | Storage | [06-storage](./06-storage) | [Storage guide](./lab-guides/06-storage.md) |
| 7 | Logging and monitoring | [07-logging-monitoring](./07-logging-monitoring) | [Logging guide](./lab-guides/07-logging-monitoring.md) |
| 8 | Troubleshooting (set up the broken scenarios with [00-practice-setup.md](./08-troubleshooting/00-practice-setup.md)) | [08-troubleshooting](./08-troubleshooting) | [Troubleshooting guide](./lab-guides/08-troubleshooting.md) |
| | Practice questions | [practice-tests](./practice-tests) | |

## Conventions

- Commands are written without a prompt, so you can copy them as they are. Where a lesson shows what a command prints, that is in its own block after "Output:".
- `kubectl` commands run on the server as your own user. Commands for a node start with `minikube ssh` (`minikube ssh -n minikube-m02` for the first worker).
- Lessons are numbered in the order the course teaches them. In `01-installation`, the lessons named `kubeadm-lesson-<name>.md` have no number: they are the optional kubeadm route (the exam's tool), not the minikube practicals.
- Every YAML example is also saved as a file in the same folder as its lesson, named after the lesson (`<lesson>.yaml`, or `<lesson>-<name>.yaml` when a lesson has several), and the line under each example names it. Go to that folder and apply it instead of typing it, for example `cd ~/CKA/02-core-concepts`, then `kubectl apply -f 03-first-pod-yaml.yaml`.
- Files a lesson asks you to write yourself (with `vi` or `nano`, such as `role.yaml`) go in your current folder; the lesson folders belong to your user, so you can create files there.
- Images used here run on both amd64 and arm64 unless a lesson says otherwise.

Last reviewed: October 2026 (Kubernetes v1.36/v1.37).
