# Lab 1.8 explained: releases and rollbacks

This page goes with [Lab 1.8](./lab-1.8-releases-and-rollbacks.md). The lab has the commands; this page explains them: what happens in the cluster, why it matters for the Shop, what usually goes wrong, and what the exam asks. There is nothing to paste here.

## In short

A new version of a part of the Shop is a change to its Deployment, usually a new image. The Deployment replaces the pods a few at a time, and only removes an old pod when a new one is ready. A bad version therefore gets stuck halfway, while the old pods keep serving. `kubectl rollout undo` puts the previous version back.

## The ideas behind this lab

### A new version is a new ReplicaSet

Lab 1.3 showed that a Deployment owns ReplicaSets, and each ReplicaSet owns pods of **one** version. When you change the pod template (image, settings, probes), the Deployment:

1. creates a **new ReplicaSet** for the new template;
2. scales the new one **up** and the old one **down**, step by step;
3. keeps the old ReplicaSet at 0 pods when it is done.

The old ReplicaSet at 0 is the **history**. A rollback simply scales an old ReplicaSet up again. Each ReplicaSet is a **revision**; by default a Deployment keeps the last 10 (`revisionHistoryLimit`).

### How fast it goes: maxSurge and maxUnavailable

| Setting | Default | Meaning |
| --- | --- | --- |
| `maxSurge` | 25% | How many pods *above* `replicas` may exist during the update |
| `maxUnavailable` | 25% | How many pods *below* `replicas` may be unready during the update |

With 2 replicas, 25% is rounded **up** for surge (1 extra pod) and **down** for unavailable (0). So the update runs: start 1 new pod, wait until it is ready, stop 1 old pod, and again. At no moment are there fewer than 2 ready pods. That is why users notice nothing, and why a broken new version never replaces the working ones.

### Readiness is what makes it safe

"Ready" means the readiness probe from Lab 1.7 passes. Without a readiness probe, "ready" only means "started", and a new backend that starts but cannot work would replace the good ones. The Shop's probes turn a bad release from an outage into a stuck rollout.

### The other strategy: Recreate

`strategy: Recreate` stops all old pods first, then starts the new ones: a short outage. The database uses it (Lab 1.6), because two database pods must never run at once.

## Step by step

### Step 1: look at the history

`kubectl rollout history` lists the revisions of the frontend. There are already two: the Deployment from Lab 1.3, and the one with the ConfigMap from Lab 1.5. `CHANGE-CAUSE` is empty, because nobody wrote a note.

### Step 2: release a new nginx version

`kubectl set image deployment/frontend frontend=nginx:1.28-alpine` changes the image of the container **named** `frontend` (the name before `=`) in the template. That change starts the rolling update. `kubectl annotate ... kubernetes.io/change-cause=...` writes a note that `rollout history` shows next to the new revision. `rollout status` waits until the update is complete.

### Step 3: check

The `IMAGES` column shows `nginx:1.28-alpine`, and the Shop page still answers: the page and the nginx settings come from the ConfigMap, not from the image, so they survive the new image.

### Step 4: release a backend version that does not exist

`postgrest/postgrest:v99` does not exist. The Deployment makes a new ReplicaSet and starts one new pod (the one allowed by `maxSurge`). That pod can never pull its image, so it never becomes ready, so no old pod is ever stopped. `rollout status --timeout=40s` gives up waiting and says so. The update is not cancelled: it simply cannot go on.

A Deployment also has a `progressDeadlineSeconds` (600 by default). After that, its status says the rollout failed. It still does not roll back by itself: that is your decision.

### Step 5: look at the pods

Three backend pods: two old ones, `Running` and ready, from the old ReplicaSet, and one new one in `ErrImagePull`, which turns into `ImagePullBackOff`: the kubelet keeps trying, waiting longer between tries.

### Step 6: find the reason

The events give the exact error: the image `postgrest/postgrest:v99` was not found in the registry. In practice this is a typing mistake or a missing tag, as in Lab 8.1.

### Step 7: is the Shop still open?

Yes. The Service `backend` sends traffic only to ready pods, and the two old pods are still ready. The stuck new pod gets no traffic at all.

### Step 8: roll back

`rollout history` shows the revisions, the last one with your note `backend v99`. `kubectl rollout undo` makes the previous revision's template current again: the old ReplicaSet scales back up (it already has its 2 pods), and the broken one scales to 0. Because the old pods never stopped, the pods in the list are the same ones as before, with their old age. `--to-revision=N` goes back to a chosen revision instead of the previous one.

A rollback is itself a new revision: the old revision number moves to the end of the list.

## When something goes wrong

| What you see | What it means | What to do |
| --- | --- | --- |
| `ErrImagePull`, `ImagePullBackOff` | The image or tag does not exist, or the registry cannot be reached | `kubectl describe pod`; fix the name, or `rollout undo` |
| `rollout status` hangs | New pods do not become ready | Look at the new pods (`kubectl get pods`), not the old ones |
| `unable to find container named "backend"` | `set image` needs the **container** name, not the Deployment name | `kubectl get deployment backend -o wide` shows the container names |
| The history shows `<none>` everywhere | No change-cause annotations were written | Add them with `kubectl annotate` when you release |

## For the exam

- The four commands: `rollout status`, `rollout history`, `rollout undo` (with `--to-revision`), `rollout restart`. They work for Deployments, DaemonSets and StatefulSets.
- `kubectl set image deployment/NAME CONTAINER=IMAGE` is the fastest release. `kubectl rollout history deployment/NAME --revision=N` shows what one revision contained.
- Know what `maxSurge` and `maxUnavailable` do, and that `Recreate` causes a short outage.
- A task like "the new version is broken, restore the previous one" is solved with `rollout undo`, not by editing the image back by hand (both work; undo is faster and safer).

## Check your understanding

1. What does Kubernetes create when you change a Deployment's image?
2. With 2 replicas and the defaults, how many ready pods are there during an update, at least?
3. Why did the broken release not close the Shop?
4. What does `kubectl rollout undo` actually do?
5. The `v99` pod would stay forever. Does Kubernetes roll back by itself?

<details><summary>Answers</summary>

1. A new ReplicaSet for the new pod template. The old one is kept at 0 pods as history.
2. Two: `maxUnavailable` of 25% rounds down to 0, so no old pod stops before a new one is ready.
3. The new pod never became ready, so no old pod was stopped, and the Service only sends traffic to ready pods.
4. It makes an earlier revision's pod template current again, which scales that revision's ReplicaSet back up.
5. No. After `progressDeadlineSeconds` the status says the rollout failed, but rolling back is your decision.

</details>

**Back to:** [Lab 1.8](./lab-1.8-releases-and-rollbacks.md) · **Next:** [Lab 1.9 explained](./lab-1.9-uat-and-prod-explained.md)
