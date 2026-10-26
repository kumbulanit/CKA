# CKA
Certified Kubernetes Administrator

Notes and hands-on practicals for the CKA course. Every practical runs on the same small cluster, so the commands work exactly as written.

## The practice cluster

- 3 Ubuntu 24.04 machines named **`controlplane`**, **`node01`** and **`node02`**
- Kubernetes **v1.36**, installed with kubeadm, containerd and Calico (the maintenance lesson upgrades it to v1.37)
- You work as root on `controlplane` (`sudo -i`) and log in to the workers with `ssh node01`

Build it with [Kubernetes installation using kubeadm](./Domain%201%20-Installation,%20Configuration%20&%20Validation%20/Kubernetes%20installation%20using%20kubeadm.md). Use the same host names: lessons such as troubleshooting refer to the nodes by name.

## Course outline

| # | Topic | Folder |
| --- | --- | --- |
| 1 | Core concepts: pods, ReplicaSets, Deployments, Namespaces, Services | [Domain 1 - Core Concepts](./Domain%201%20-%20Core%20Concepts) |
| 2 | Installation, configuration and validation: kubeadm, adding nodes, upgrades, drain, etcd backup | [Domain 1 -Installation, Configuration & Validation](./Domain%201%20-Installation,%20Configuration%20&%20Validation%20) |
| 3 | Workloads and scheduling | [Scheduling](./Scheduling) |
| 4 | Services and networking | [Networking](./Networking) |
| 5 | Security | [security](./security) |
| 6 | Storage | [storage](./storage/08-Storage) |
| 7 | Logging and monitoring | [logging and monitoring](./logging%20and%20monitoring) |
| 8 | Troubleshooting (set up the broken scenarios with [00-Practice-Setup.md](./Troubleshooting/00-Practice-Setup.md)) | [Troubleshooting](./Troubleshooting) |
| | Practice questions | [practice-tests](./practice-tests) |

## Conventions

- Commands that start with `$` show the prompt; type them without the `$`.
- `kubectl` commands run on `controlplane` unless a step says `ssh node01` first.
- Files such as `newpod.yaml` are created in your current folder; use `vi` or `nano`.
- Images used here run on both amd64 and arm64 unless a lesson says otherwise.

Last reviewed: October 2026 (Kubernetes v1.36/v1.37).
