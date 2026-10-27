# CKA
Certified Kubernetes Administrator

Notes and hands-on practicals for the CKA course. Every practical runs on the same small cluster, so the commands work exactly as written.

## The practice cluster

- 3 Ubuntu 24.04 machines named **`controlplane`**, **`node01`** and **`node02`**
- Kubernetes **v1.36**, installed with kubeadm, containerd and Calico (the maintenance lesson upgrades it to v1.37)
- You work as root on `controlplane` (`sudo -i`) and log in to the workers with `ssh node01`

Use the same host names: lessons such as troubleshooting refer to the nodes by name.

### Everything on one Ubuntu server

You only need **one Ubuntu server** (a VM is fine: 4 CPUs, 8 GB RAM, 40 GB disk, Ubuntu 22.04 or 24.04). [scripts/one-server.sh](./scripts/one-server.sh) runs the three machines on it as containers. Each one is a full Ubuntu 24.04 machine with systemd and SSH, so every command in the lessons works unchanged, including the kubeadm installation, `ssh node01` and draining nodes.

```sh
git clone https://github.com/kumbulanit/CKA.git && cd CKA
sudo ./scripts/one-server.sh install     # the three machines with Kubernetes installed (5 to 10 minutes)
sudo ./scripts/one-server.sh shell       # you are now root@controlplane; the repository is in /root/CKA
```

- To do the installation lesson yourself, use `sudo ./scripts/one-server.sh create` instead: it starts the three machines with nothing installed. Their IP addresses are `172.30.56.10`, `.11` and `.12` (`sudo ./scripts/one-server.sh status` shows them).
- `sudo ./scripts/one-server.sh shell node01` opens node01. Type `exit` to go back to the server.
- The machines start again when the server restarts. `sudo ./scripts/one-server.sh delete` removes them, so you can start again from scratch.

## Scripts

**Install the whole cluster** with [scripts/install-cluster.sh](./scripts/install-cluster.sh). It runs the same steps as the [installation guide](./Domain%201%20-Installation,%20Configuration%20&%20Validation%20/Kubernetes%20installation%20using%20kubeadm.md) (containerd, kubeadm v1.36, Calico) and also installs `helm` and `etcd-client` on controlplane. `one-server.sh install` runs it for you. On separate machines, run it as root on each one, controlplane first, with your three IP addresses:

```sh
sudo ./scripts/install-cluster.sh controlplane 192.168.56.10 192.168.56.11 192.168.56.12
```

At the end it prints the command to run on node01 and node02, with the join command included.

**Catch up when a lab runs out of time.** Each day has a script that creates what that day's labs leave in the cluster, as at the end of each lab. Run it on controlplane as root (`sudo ./scripts/one-server.sh shell`, then `cd /root/CKA`), for one lab or for the whole day:

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
