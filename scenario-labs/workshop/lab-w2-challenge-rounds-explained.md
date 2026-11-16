# Workshop 2 explained: three challenge rounds

This page goes with [Workshop 2](./lab-w2-challenge-rounds.md). The workshop page has the tasks and the answers; this page explains how the rounds work, what each task practises, and where in the course you learned it. It gives no answers. There is nothing to paste here.

## In short

Fifteen exam-style tasks on the Shop, in three rounds of five, done in pairs. Each task is short and has one clear result, like an exam task. The skill is not knowing the answer by heart, but finding the right command quickly, checking the result, and moving on.

## The ideas behind this workshop

### How to work a task

1. **Read the whole task**, and underline the names, namespace, numbers and labels. Most lost points in the exam come from a wrong name or namespace, not from not knowing Kubernetes.
2. **Choose the fastest way:** an imperative command (`kubectl create`, `scale`, `set`, `expose`, `label`), or a generated YAML (`--dry-run=client -o yaml`) when the command cannot do everything.
3. **Do it.**
4. **Check it** with one command that proves the result: `kubectl get`, `describe`, `auth can-i`, `exec ... env`.

The person who reads the task also checks the result. Swapping roles every round means both practise both.

### When to open the answer

After five minutes stuck. Before that, use what the exam allows: `kubectl explain`, `--help`, and the documentation. Learning **where** to find something is worth as much as the answer.

### Cleaning up

Each round ends with a clean-up, so the next round starts from the same Shop. `check-shop.sh` before each round confirms it.

## Step by step

### Round 1: workloads and scheduling

| Task | What it practises | Learned in |
| --- | --- | --- |
| 1.1 Scale the frontend | Changing replicas | Lab 1.3 |
| 1.2 Add an environment variable | Changing a pod template, and checking inside a pod | Lab 1.5 |
| 1.3 A pod with labels | `kubectl run` with options | Labs 1.2 and 2.3 |
| 1.4 Run it on one node | A node selector on a well-known label; pods cannot be moved, only recreated | Lab 4.1 |
| 1.5 Change a probe | Editing one field of a Deployment | Lab 1.7 |

Tasks 1.2 and 1.5 change the pod template, so each starts a rolling update: wait for it before you check.

### Round 2: networking and security

| Task | What it practises | Learned in |
| --- | --- | --- |
| 2.1 A NodePort Service | Exposing a Deployment, choosing the type | Labs 1.4 and 3.2 |
| 2.2 A DNS lookup | A throwaway pod, and the full name of a Service | Lab 3.3 |
| 2.3 A NetworkPolicy | Allowing one more client, without touching the others | Lab 3.1 |
| 2.4 A ServiceAccount with a Role | Role, RoleBinding, and proving it with `can-i` | Lab 5.1 |
| 2.5 Which identity a pod runs as | Reading a pod's spec, and where its token is mounted | Lab 5.1 |

In Task 2.3, remember that policies only add allowances: a new policy is the way to allow more, not editing the existing ones. In Task 2.4, `can-i` with `--as=system:serviceaccount:NAMESPACE:NAME` is the proof.

### Round 3: storage and operations

| Task | What it practises | Learned in |
| --- | --- | --- |
| 3.1 Find the database's volume | Following claim → volume → node and path | Labs 7.1 and 7.2 |
| 3.2 Data survives a pod | Proving persistence | Lab 7.2 |
| 3.3 Release and roll back | `set image`, `rollout history`, `rollout undo` | Lab 1.8 |
| 3.4 Save logs to a file | `kubectl logs` with a label, a time window, and all pods | Lab 6.1 |
| 3.5 An etcd backup | `etcdctl snapshot save` with its four options, and `snapshot status` | Lab 2.5 |

Task 3.5 is the one most people find hard under time: the certificate paths are in the etcd static pod file, so you never have to remember them.

## When something goes wrong

| What you see | What it means | What to do |
| --- | --- | --- |
| A change does not show in the pods | The rollout is still running, or you changed the wrong object | `kubectl rollout status`; check the name and namespace |
| `check-shop.sh` fails before a round | A clean-up was missed | Run the clean-up of the last round; `deploy-shop.sh dev` if needed |
| The NetworkPolicy blocks the Shop | It selected the wrong pods | `kubectl describe networkpolicy`; check its `podSelector` |
| `can-i` says `no` | The RoleBinding is in another namespace, or names the wrong subject | `kubectl describe rolebinding -n dev` |

## For the exam

- Most tasks take 2 to 6 minutes. If one takes longer, flag it and move on.
- Imperative commands with `--dry-run=client -o yaml` give you correct YAML to edit: faster and safer than writing it.
- Always prove the result with one command before moving on; a task you think is done but is not costs the same as one you skipped.

## Check your understanding

1. Why read the task twice before typing?
2. When is a generated YAML better than an imperative command?
3. Why must a pod be recreated to change the node it runs on?
4. How do you prove a ServiceAccount has the right permissions?

<details><summary>Answers</summary>

1. Most lost points come from a wrong name, namespace or number, not from not knowing the topic.
2. When the command cannot set everything the task asks for (a probe, a volume, a node selector...).
3. A pod's node is fixed once it is scheduled; only a new pod can be placed elsewhere.
4. `kubectl auth can-i VERB RESOURCE -n NAMESPACE --as=system:serviceaccount:NAMESPACE:NAME`.

</details>

**Back to:** [Workshop 2](./lab-w2-challenge-rounds.md) · **Next:** [Workshop 3 explained](./lab-w3-break-and-fix-explained.md)
