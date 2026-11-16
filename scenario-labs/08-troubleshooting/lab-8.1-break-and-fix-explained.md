# Lab 8.1 explained: troubleshooting, six faults to find and fix

This page goes with [Lab 8.1](./lab-8.1-break-and-fix.md). The lab has the commands; this page explains the method behind them, and what each fault teaches. It gives nothing away before you try: the explanation of each fault is folded, to read **after** you fixed it. There is nothing to paste here.

## In short

Troubleshooting is not guessing. You walk the path a request takes through the Shop, and at each stop ask one question, with one command. The first thing that is wrong is your lead. Fix one thing, check again, and say the cause in one sentence. Each of the six faults comes from a module you did, so each one is something you have already seen working.

## The ideas behind this lab

### Why a fixed method

Under pressure, people jump to the part they know best, or change three things at once and never learn which one helped. A fixed order avoids both. It also works in the exam, where every minute counts: the first two commands find most faults.

### The seven questions, and why in this order

| Step | Question | Why it comes here |
| --- | --- | --- |
| 1 | Are all pods `Running` and `1/1`? | The cheapest look, and it catches most faults at once |
| 2 | A pod is not: why? | The **events** of a pod say what Kubernetes tried and what failed |
| 3 | It runs but does not work: what does it say? | The program's **log** explains problems Kubernetes cannot see |
| 4 | Does the Service have pods behind it? | All pods fine, yet no answer: the link between Service and pods |
| 5 | Pods missing, not even listed? | A pod that was never created leaves no pod to describe, only **namespace events** |
| 6 | Is the network allowed? | Pods and Services fine, but traffic times out: NetworkPolicies |
| 7 | Are the nodes healthy? | Everything on one node fails: the node itself |

The order goes from the application outwards to the cluster: most faults are in the application's own objects, and the node is the rarest.

### The tools you have

| Tool | What it adds |
| --- | --- |
| `check-shop.sh dev` | Tells you **that** something is wrong, and roughly where: each part, each Service, the whole path |
| `kubectl get` | The current state |
| `kubectl describe` | The details, and the events at the bottom |
| `kubectl logs` | What the program says |
| `kubectl get events` | What happened in the namespace, including refusals |
| `minikube ssh -n NODE` | A shell on a node, for the kubelet (`systemctl`, `journalctl`) |

`check-shop.sh` is a course tool. In the exam you have only `kubectl` and a shell on the nodes, so the method is what you take with you.

## Step by step

### The method: walk the path of a request

A request to the Shop passes: the frontend Service, a frontend pod, the backend Service, a backend pod, the database Service, the database pod, all on nodes, all subject to network rules. Each step of the method checks one link of that chain.

### Before you start

You switch to `dev` and run `check-shop.sh` while everything works. A known good result is your baseline: you know what "healthy" looks like before anything breaks. If a check already fails, the lab tells you to rebuild with `deploy-shop.sh dev`, so that only the planned fault is in the Shop.

### How every round works

`break.sh N` puts one fault into the Shop in `dev`. You then follow six moves: see it (`check-shop.sh`), find it (the method), fix it, check it, and say it. The ten minutes before the hint are on purpose: finding the fault yourself is the exercise. After a fix, the backend may need up to 30 seconds to reconnect to the database, so the last check can fail once more right after a correct fix.

### Fault 1

The hint sends you to step 1 and the events: one pod is not `Running`.

<details><summary>Read after you fixed it: why this happens</summary>

A Deployment was given an image name with a typing mistake. The kubelet asks the registry for that image, gets "not found", and retries with growing pauses: first `ErrImagePull`, then `ImagePullBackOff`. The Shop kept running on the old pods, exactly as in Lab 1.8: the new pod never became ready, so no old pod was stopped. Fixing the image starts a normal rolling update. In the exam, `kubectl describe pod` shows the wrong image name and the registry's answer in the events.

</details>

### Fault 2

The hint says all pods are fine, so look at step 4: the Service.

<details><summary>Read after you fixed it: why this happens</summary>

A Service only sends traffic to pods whose labels match its selector (Lab 1.4). The selector was changed to a label no pod has, so the Service's EndpointSlice was empty: the name resolves, the Service exists, but there is nobody behind it. That is why `kubectl get endpointslices` is the first command when "the Service gives no answer". Patching the selector back fills the EndpointSlice within seconds.

</details>

### Fault 3

The hint points to a new backend pod with an unusual status, and to the last event.

<details><summary>Read after you fixed it: why this happens</summary>

`CreateContainerConfigError` means the kubelet could not build the container's settings: here, the Deployment referred to a Secret by a wrong name (Lab 1.5). The pod exists and is scheduled, but the container is never started, so there is no log to read: only the events name the missing Secret. Because the old pods kept running, the Shop stayed up (Lab 1.8 again).

</details>

### Fault 4

The hint: too few frontend pods, none in error, and the namespace events (step 5).

<details><summary>Read after you fixed it: why this happens</summary>

A ResourceQuota limited the namespace to fewer pods than the Shop needs (Lab 7.4). The ReplicaSet's requests to create pods were refused by the API server, so those pods never existed: nothing to describe, nothing in `kubectl get pods`. Only the namespace events (`FailedCreate ... exceeded quota`) and `kubectl describe resourcequota` show it. After the quota is raised, the ReplicaSet tries again; a `rollout restart` makes it happen at once.

</details>

### Fault 5

The hint: backend pods `Running` but `0/1`, the database fine, so look between them (step 6).

<details><summary>Read after you fixed it: why this happens</summary>

A NetworkPolicy allowed the backend to reach the database on the wrong port (Lab 3.1). The database listened on 5432, the policy opened another port, so the backend's connections were dropped and timed out. The readiness probe (Lab 1.7) noticed that the backend could not reach its database, and took the pods out of the Service. Two lessons at once: a timeout points to a policy, and `0/1 Running` points to readiness. Applying the correct policies again restores the path.

</details>

### Fault 6

The hint: one node is not `Ready` (step 7), so look at the service that runs pods there.

<details><summary>Read after you fixed it: why this happens</summary>

The kubelet on one worker was stopped. Nothing told the control plane; it only noticed that the node stopped reporting, and after a grace period marked it `NotReady` (Lab 1.1). The kubelet is a systemd service, not a pod (Lab 2.1), so you find and fix it on the node, with `systemctl` and `journalctl`. Pods on a node that stays `NotReady` are evicted after about five minutes and recreated elsewhere (Lab 4.3, the `unreachable` taint).

</details>

### After the last fault

`check-shop.sh dev` must pass all its checks. If one still fails, a fix is incomplete, or two faults overlapped.

### What to take to the exam

The table at the end of the lab maps **what you see** to **where to look** and **the usual cause**. It is the summary of the whole module, and worth learning by heart.

## When something goes wrong

| What you see | What it means | What to do |
| --- | --- | --- |
| `check-shop.sh` still fails right after a correct fix | The backend has not reconnected yet | Wait 30 seconds and run it again |
| A fault from an earlier round is still there | That round's fix was not complete | Run the method from step 1 again |
| Several things look broken at once | One fault can cause symptoms in several places | Follow the path in order; fix the first broken link |
| You changed several things and it works now | You do not know what fixed it | Undo all but one, or say which change mattered |
| The Shop is in a state you cannot recover | Too many changes | `./deploy-shop.sh dev` rebuilds it |

## For the exam

- Troubleshooting is the largest part of the exam (30%). Use the same order every time: pods, describe, logs, Services, events, network, nodes.
- Read events first: `kubectl describe` for one object, `kubectl get events --sort-by=.lastTimestamp` for a namespace.
- For node and control plane faults: `ssh` to the node, `systemctl status kubelet`, `journalctl -u kubelet`, the static pod files in `/etc/kubernetes/manifests`, and `crictl` when the API server is down.
- Fix with the smallest change that works (`kubectl set image`, `kubectl patch`, `kubectl edit`), then check, then move on.

## Check your understanding

1. Why does the method start with `kubectl get pods`?
2. All pods are `Running` and `1/1`, but the Shop gives no answer. Where do you look next?
3. A Deployment shows `3/5` and no pod has an error. Where is the reason?
4. A connection between two pods times out. What is the likely cause?
5. Why does a pod in `CreateContainerConfigError` have no logs?

<details><summary>Answers</summary>

1. It is the cheapest look, and it catches most faults: any pod not `Running` and ready is a lead.
2. At the Services: do they have pods behind them (`kubectl get endpointslices`)?
3. In the namespace events: often a quota refused the missing pods.
4. A NetworkPolicy dropping the traffic (a refusal would mean nothing listens on the port).
5. The container was never started, because its settings (a ConfigMap or Secret) could not be found.

</details>

**Back to:** [Lab 8.1](./lab-8.1-break-and-fix.md) · **Next:** [Workshop 1 explained](../workshop/lab-w1-start-explained.md)
