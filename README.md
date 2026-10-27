# CKA
Certified Kubernetes Administrator

Notes and hands-on practicals for the CKA course. Every practical runs on the same small cluster, so the commands work exactly as written.

## The practice cluster

One Ubuntu server is all you need (a VM is fine: 4 CPUs, 8 GB RAM, 30 GB free disk, Ubuntu 22.04 or 24.04). **One command installs everything and starts the cluster** (about 10 minutes the first time):

```sh
git clone https://github.com/kumbulanit/CKA.git && cd CKA
sudo ./setup.sh
```

[setup.sh](./setup.sh) installs all the tools the course uses: Docker, minikube, kubectl v1.36 and helm, plus git, curl, jq, vim, nano and bash completion (with `k` as a short name for `kubectl`). Then it creates and starts a minikube cluster on Docker: Kubernetes **v1.36.5** with Calico, three nodes. Run it with `sudo` from your own user, not as root. Running it again is safe; it also starts the cluster again after the server restarts.

Log out and in once (or run `newgrp docker`) so `minikube` works without `sudo`. Then, as your own user:

```sh
kubectl get nodes                  # minikube (control plane), minikube-m02 and minikube-m03 (workers)
minikube ssh                       # a shell on the control plane node
minikube ssh -n minikube-m02       # a shell on the first worker
minikube stop                      # stop the cluster; sudo ./setup.sh or minikube start starts it again
```

The lessons were written for a kubeadm cluster whose nodes are called `controlplane`, `node01` and `node02`. On the minikube cluster:

| In the lessons | On the minikube cluster |
| --- | --- |
| `controlplane` | `minikube` (`minikube ssh`) |
| `node01`, `ssh node01` | `minikube-m02` (`minikube ssh -n minikube-m02`) |
| `node02`, `ssh node02` | `minikube-m03` (`minikube ssh -n minikube-m03`) |
| `kubectl` as root on controlplane | `kubectl` as your own user on the server |
| `/etc/kubernetes/pki` | `/var/lib/minikube/certs`, inside `minikube ssh` |

minikube builds its nodes with kubeadm, so the static pod manifests (`/etc/kubernetes/manifests`), the kubelet service and `journalctl -u kubelet` are where the lessons say, inside `minikube ssh`.

### The kubeadm lessons

Installing a cluster with kubeadm, adding a node and the upgrade to v1.37 need machines without Kubernetes. [scripts/one-server.sh](./scripts/one-server.sh) runs three of them on the same server, as containers named `controlplane`, `node01` and `node02`, so those lessons work exactly as written. Stop minikube first on an 8 GB server (`minikube stop`).

```sh
sudo ./scripts/one-server.sh create        # three bare Ubuntu 24.04 machines (172.30.56.10, .11, .12)
sudo ./scripts/one-server.sh shell         # root@controlplane; shell node01 opens node01
sudo ./scripts/one-server.sh delete        # remove them
```

`sudo ./scripts/one-server.sh install` installs the kubeadm cluster on them in one go, with [scripts/install-cluster.sh](./scripts/install-cluster.sh) (the same steps as the [installation guide](./Domain%201%20-Installation,%20Configuration%20&%20Validation%20/Kubernetes%20installation%20using%20kubeadm.md)). On separate machines, run that script as root on each one, controlplane first, with your three IP addresses: `sudo ./scripts/install-cluster.sh controlplane 192.168.56.10 192.168.56.11 192.168.56.12`. It prints the command to run on node01 and node02.

## Scripts

**Catch up when a lab runs out of time.** Each day has a script that creates what that day's labs leave in the cluster, as at the end of each lab. Run it on the server as your own user, where `kubectl` works (on a kubeadm cluster: as root on controlplane), for one lab or for the whole day. The scripts find the node names themselves, so they work on both:

```sh
./scripts/catch-up/day1.sh --list        # the labs of the day
./scripts/catch-up/day1.sh services      # one lab
./scripts/catch-up/day2.sh               # the whole day
```

| Day | Topics | Script |
| --- | --- | --- |
| 1 | Core concepts; installation, configuration and validation (modules 1–2) | [day1.sh](./scripts/catch-up/day1.sh) |
| 2 | Workloads and scheduling; services and networking; security (modules 3–5) | [day2.sh](./scripts/catch-up/day2.sh) |
| 3 | Storage; logging and monitoring; troubleshooting (modules 6–8) | [day3.sh](./scripts/catch-up/day3.sh) |

The scripts can be run again safely. They leave out what changes the machines rather than the cluster (installing, adding node03, the v1.37 upgrade, draining), and the troubleshooting labs, which set themselves up with [00-Practice-Setup.md](./Troubleshooting/00-Practice-Setup.md).

## Course outline

Each module has a step-by-step guide in [lab-guides](./lab-guides): every command, what it does, the output it printed on the practice cluster, what to check when you see something else, and a diagram of the idea. The [images](./images) folder has the diagrams (made by `images/diagrams.py`).

| # | Topic | Folder | Step-by-step guide |
| --- | --- | --- | --- |
| 1 | Core concepts: pods, ReplicaSets, Deployments, Namespaces, Services | [Domain 1 - Core Concepts](./Domain%201%20-%20Core%20Concepts) | [Module 1](./lab-guides/01-core-concepts.md) |
| 2 | Installation, configuration and validation: kubeadm, adding nodes, upgrades, drain, etcd backup | [Domain 1 -Installation, Configuration & Validation](./Domain%201%20-Installation,%20Configuration%20&%20Validation%20) | [Module 2](./lab-guides/02-installation.md) |
| 3 | Workloads and scheduling | [Scheduling](./Scheduling) | [Module 3](./lab-guides/03-scheduling.md) |
| 4 | Services and networking | [Networking](./Networking) | [Module 4](./lab-guides/04-networking.md) |
| 5 | Security | [security](./security) | [Module 5](./lab-guides/05-security.md) |
| 6 | Storage | [storage](./storage/08-Storage) | [Module 6](./lab-guides/06-storage.md) |
| 7 | Logging and monitoring | [logging and monitoring](./logging%20and%20monitoring) | [Module 7](./lab-guides/07-logging-monitoring.md) |
| 8 | Troubleshooting (set up the broken scenarios with [00-Practice-Setup.md](./Troubleshooting/00-Practice-Setup.md)) | [Troubleshooting](./Troubleshooting) | [Module 8](./lab-guides/08-troubleshooting.md) |
| | Practice questions | [practice-tests](./practice-tests) | |

## Conventions

- Commands that start with `$` show the prompt; type them without the `$`.
- `kubectl` commands run on `controlplane` unless a step says `ssh node01` first.
- Files such as `newpod.yaml` are created in your current folder; use `vi` or `nano`.
- Images used here run on both amd64 and arm64 unless a lesson says otherwise.

Last reviewed: October 2026 (Kubernetes v1.36/v1.37).
