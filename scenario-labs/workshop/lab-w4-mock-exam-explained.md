# Workshop 4 explained: the mock exam

This page goes with [Workshop 4](./lab-w4-mock-exam.md). The mock exam has the tasks, and the [solutions page](./lab-w4-mock-exam-solutions.md) has the answers; this page explains how to approach each kind of task, and how to use your time. It gives no answers. Read it before the exam starts. There is nothing to paste here.

## In short

Fifteen tasks, 100 points, 90 minutes, alone, with the documentation open: like the real exam, only shorter. The tasks cover every module of the course. Passing (66 points) is less about knowing everything than about working calmly: easy tasks first, every task checked, and no task allowed to eat ten minutes.

## The ideas behind this workshop

### Time

90 minutes for 100 points is about 54 seconds a point. A 6-point task should take about 5 minutes. The workshop's rule, skip anything that takes more than 6 minutes, keeps one hard task from costing three easy ones. Note skipped tasks and come back at the end.

### Points

Tasks have different weights (4 to 10 points). Partial results can earn partial points in the real exam, so a half-done task is better than an empty one. But a task done in the wrong namespace, or with a wrong name, earns nothing: read every name twice.

### The tools you may use

| Tool | Best for |
| --- | --- |
| `kubectl create ... --dry-run=client -o yaml` (the variable `$do` in the lab) | Correct YAML to start from |
| `kubectl explain KIND.FIELD` | The exact field names and where they go |
| `kubectl COMMAND --help` | The options and examples of a command |
| kubernetes.io/docs | Full examples to copy: NetworkPolicy, PV and PVC, probes, CSR |

The alias `k` and Tab completion save seconds on every command; over 15 tasks that adds up to minutes.

## Step by step

### Before you start

The exam works in its own namespace, `exam`, so nothing touches the Shop's environments. The Secret is created for you because Task 5 needs it. The taint on `minikube-m03` keeps the exam's pods off the node that Task 14 drains (a drain with `--force` deletes pods that no controller brings back). `~/exam` holds the answer files some tasks ask for.

### The tasks

How to approach each, and where you practised it:

| Task | Points | Kind | Approach | Course lab |
| --- | --- | --- | --- | --- |
| 1 | 4 | A pod | One imperative command, with a label option | 1.2 |
| 2 | 6 | A Deployment | Create, then scale: two commands | 1.3 |
| 3 | 6 | A Service | Check whether the command can set every value the task asks for; if not, generate YAML and edit | 1.4 |
| 4 | 6 | A ConfigMap as environment variables | Create the ConfigMap imperatively; the pod needs YAML (all keys at once) | 1.5 |
| 5 | 6 | A Secret as files | A pod YAML with a Secret volume and a mount | 1.5 |
| 6 | 8 | Storage | PV and PVC from the documentation example; check that they bind | 7.2 |
| 7 | 6 | A health check | Generate a pod, add a probe from `kubectl explain` or the docs | 1.7 |
| 8 | 6 | Resources | One command can set requests and limits on a Deployment | 6.3, 7.4 |
| 9 | 6 | Scheduling | Label the node, then a pod with a node selector | 4.1 |
| 10 | 8 | A NetworkPolicy | Copy the docs example; check `podSelector` versus `from` | 3.1 |
| 11 | 8 | Access control | ServiceAccount, Role, RoleBinding, then write the `can-i` answer to the file | 5.1 |
| 12 | 6 | Release and rollback | `set image`, wait, `rollout undo`, then read the running image | 1.8 |
| 13 | 6 | Logs | One `kubectl logs` with a line limit, redirected to the file | 6.1 |
| 14 | 8 | A node | Drain with the options it asks for, then make it schedulable again | 2.7 |
| 15 | 10 | Troubleshooting | The method: pods, describe, events; fix the Deployment, not the pods | 8.1 |

A sensible order: the quick ones first (1, 2, 8, 9, 13, 14, 12), then the YAML ones (3, 4, 5, 7), then the ones that need the documentation (6, 10, 11), and Task 15 whenever you have ten calm minutes. It is worth the most.

Task 14 drains `minikube-m03`. Thanks to the taint from "Before you start", none of your exam pods run there, so you can do it at any time. In the real exam the tasks are usually spread over separate clusters or hosts, so one task's drain does not touch another task's answer there.

### When the time is up

Mark your own work with the solutions page, task by task, and be strict: a wrong name is zero. The score table tells you what to do next. The tasks you lost points on are your study plan: go back to the course lab in the table above.

## When something goes wrong

| What you see | What it means | What to do |
| --- | --- | --- |
| An object is in the wrong namespace | `-n exam` was forgotten | Delete it and create it again in `exam` |
| A YAML is refused | Indentation, or a field at the wrong level | `kubectl explain` the field; compare with a generated YAML |
| A claim stays `Pending` | Class name, size or access mode do not match the PV | `kubectl describe pvc` |
| The drain stops with an error | It names the option it needs | Read the error; add only that option |
| You are stuck at minute 6 | The task is taking too long | Note it and move on |

## For the exam

- The real exam is 2 hours, with more tasks and several clusters. Every task starts with a context command: run it first.
- Keep a list of skipped tasks with their numbers, so the last minutes go where the points are.
- Never leave a task empty if you can do part of it.
- After the mock: repeat it until you pass well within the time, then book the real exam.

## Check your understanding

1. About how long may a 6-point task take?
2. Why do the quick tasks first?
3. A task is done perfectly, but in `default` instead of `exam`. How many points?
4. Where do you find a complete NetworkPolicy example during the exam?

<details><summary>Answers</summary>

1. About 5 minutes (about 54 seconds a point).
2. They secure points early, and leave the remaining time for the long tasks without pressure.
3. None: the task asked for `exam`.
4. In the Kubernetes documentation (kubernetes.io/docs), page "Network Policies".

</details>

**Back to:** [Workshop 4](./lab-w4-mock-exam.md) · **Back to the start:** [Setup explained](../00-setup-explained.md)
