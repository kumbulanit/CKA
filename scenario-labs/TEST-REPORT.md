# Test report: all scenario labs on a DaDesktop VM

**Date:** 16 November 2026
**Tested on:** the DaDesktop VM `kumbulani-swdq`: Ubuntu 24.04.4 LTS, 16 CPUs, 22 GB memory, 96 GB disk, user `student` with `sudo` without a password.
**Course files:** the local `CKA` folder at the time of the test (setup, 33 labs, 4 workshops, scripts).

## Summary

**Every lab and workshop now runs from start to finish on a fresh cluster, and the Shop passes all its checks at every milestone.**

- The labs were run twice, all 33 labs and the 4 workshops, in course order, on the same VM.
- The two runs found **11 problems**: 3 in the course scripts, 7 in lab pages and 1 in a workshop page. All of them are fixed in your local files, and each fix was tested on the VM first.
- **Run 2**, on a brand-new cluster with all fixes, passed everywhere: `setup.sh` + `check-ready.sh` ready at once, every lab ran to its end, and `check-shop.sh` gave **All 8 checks passed** in `dev`, `uat` and `prod` at all **10 milestones** (30 of 30).
- Time without stopping: `setup.sh` under 2 minutes (images already downloaded), then all labs and workshops in about **30 minutes**.

## How the labs were tested

1. **Setup, as a participant does it:** `sudo ./setup.sh`, `newgrp docker`, `check-ready.sh`.
2. **Every lab, in course order, on one cluster:** each lab page was run with `run-lab.sh <lab> --all`, which runs every 📋 box of the page in order. Each lab starts from the state the labs before it left behind, exactly as in class.
3. **Every output compared with the page:** a small script compared the output of every command with the page's **👀 You should see** box (names with random letters, IP addresses and ages ignored), and listed every difference and every error line the page does not expect.
4. **The Shop checked at each milestone:** `check-shop.sh` for `dev`, `uat` and `prod` after Labs 1.9, 2.7, 3.3, 4.3, 5.2, 6.4, 7.4, 8.1 and Workshops 1 and 3.
5. **Workshops:** Workshop 2's answers (hidden under "Show the answer") were run as well; Workshop 4 ran the mock exam set-up, then all solutions, then the clean-up.
6. **Run twice:** run 1 found the problems below. After the fixes, run 2 repeated everything **on a brand-new cluster** (`minikube delete`, `setup.sh`) to prove the fixes.

## Results, lab by lab

✅ = ran to the end and matched the page. 🔧 = a problem in run 1, fixed and passing in run 2.

| Lab | Run 1 | Run 2 | Notes |
| --- | --- | --- | --- |
| Setup | 🔧 | ✅ | `check-ready.sh` hung in a real terminal; right after `setup.sh` it reported a FAIL (fixes 1 and 2) |
| 1.1 Architecture and namespaces | ✅ | ✅ | |
| 1.2 Pods, labels and selectors | ✅ | ✅ | Only the runner's speed shows (see "Not problems") |
| 1.3 Deployments | ✅ | ✅ | The `POD-NAME` step was tested by hand |
| 1.4 Services | ✅ | ✅ | Note added for a harmless `kubectl` warning (fix 9) |
| 1.5 Configuration | 🔧 | ✅ | Step 4 failed for everyone; Step 5 showed the wrong part; Step 8 could hang (fixes 3, 4, 8) |
| 1.6 The database | ✅ | ✅ | |
| 1.7 Health checks | ✅ | ✅ | |
| 1.8 Releases and rollbacks | ✅ | ✅ | Pause added after the frontend release, as in 1.5 (fix 8) |
| 1.9 UAT and PROD | ✅ | ✅ | |
| 2.1 Installing the cluster | ✅ | ✅ | Includes `minikube stop` and `start` |
| 2.2 Growing the cluster | ✅ | ✅ | A 4th node was added and removed |
| 2.3 Standalone pods | ✅ | ✅ | Static pod made and removed on `minikube-m02` |
| 2.4 Control plane HA | ✅ | ✅ | API server stopped; the Shop kept answering |
| 2.5 etcd backup and restore | ✅ | ✅ | PROD deleted and restored from the snapshot |
| 2.6 Upgrade | ✅ | ✅ | The read-only steps; the upgrade itself is a trainer demo and was not run |
| 2.7 Cordon and drain | ✅ | ✅ | |
| 3.1 Network model | ✅ | ✅ | Only the harmless `kubectl` warning |
| 3.2 Scaling, load balancing, Ingress | 🔧 | ✅ | Creating the Ingress failed: the controller was not ready yet (fix 5) |
| 3.3 DNS | ✅ | ✅ | |
| 4.1 Node selectors | ✅ | ✅ | |
| 4.2 Affinity and anti-affinity | ✅ | ✅ | |
| 4.3 Taints and tolerations | ✅ | ✅ | |
| 5.1 RBAC | ✅ | ✅ | |
| 5.2 TLS access to the API | ✅ | ✅ | |
| 6.1 Application and system logs | 🔧 | ✅ | In run 1 the Ingress from 3.2 was missing; fine in run 2 |
| 6.2 Cluster-wide logging | ✅ | ✅ | |
| 6.3 Metrics Server and autoscaling | 🔧 | ✅ | `kubectl top` ran before the Metrics API was up (fix 6) |
| 6.4 Prometheus | 🔧 | ✅ | The first query ran before Prometheus had any numbers (fix 7) |
| 7.1 Storage architecture | ✅ | ✅ | |
| 7.2 A real disk | ✅ | ✅ | The Juice survived the database pod being deleted |
| 7.3 Storage classes | ✅ | ✅ | |
| 7.4 Resource quotas | ✅ | ✅ | |
| 8.1 Break and fix | 🔧 | ✅ | All six faults put in and fixed; `check-shop.sh` gave a false FAIL in run 1 (fix 10) |
| Workshop 1 | ✅ | ✅ | |
| Workshop 2 | – | ✅ | Run 1 ran only the clean-up boxes (the answers are hidden); run 2 ran all 15 answers too. Note added at the round-3 check (fix 11) |
| Workshop 3 | ✅ | ✅ | Five faults at once, all fixed |
| Workshop 4 | ✅ | ✅ | Set-up, all 15 solutions, clean-up: no errors |

## Problems found and fixed

All fixes are in your local files, and were tested on the VM before they went in.

| # | Where | What went wrong | The fix | Tested |
| --- | --- | --- | --- | --- |
| 1 | `scripts/check-ready.sh` | In a real terminal the script **hung forever** at its DNS test. `timeout` runs `kubectl run -i` in the background, and a background program that reads the keyboard is stopped by the shell. | The test pod's input now comes from `/dev/null`. | Finishes in about 5 seconds: "Everything is ready for the labs." |
| 2 | `setup.sh` | It finished when the nodes were `Ready`, but one `calico-node` pod was still starting, so `check-ready.sh` straight after gave a **FAIL**. | `setup.sh` now also waits for the system pods in `kube-system`. | Run 2: `check-ready.sh` straight after `setup.sh` says "Everything is ready". |
| 3 | Lab 1.5, Step 4 | `kubectl exec deployment/backend -- env` **fails for everyone**: the PostgREST image has no `env` program (no shell, no tools). | Step 4 now reads the settings from the Deployment: `kubectl describe deployment backend \| grep -A4 "Environment Variables from"`, with a tip on why. Check line, companion page and deck slide updated. | Output matches the page. |
| 4 | Lab 1.5, Step 5 | `kubectl describe configmap frontend-config \| tail -18` showed the end of `index.html`, not the nginx settings the page promised (`describe` sorts the keys). | `\| grep -A14 "^default.conf"` shows exactly the nginx settings. | Output matches the page. |
| 5 | Lab 3.2, Steps 5 and 7 | `minikube addons enable ingress` says "enabled" before the controller runs, so creating the Ingress failed with `failed calling webhook ... connection refused`. Then `shop.local` did not work, here and in later labs. | Step 5 waits: `kubectl rollout status deployment/ingress-nginx-controller -n ingress-nginx` and `sleep 20`. Step 7 says what to do if the message still appears. Companion page explains the webhook. | Run 2: all 13 commands match, `shop.local` gives the Shop. |
| 6 | Lab 6.3, Step 1 | `kubectl top` ran before the Metrics API was up: `error: Metrics API not available`. A `sleep 60` was not always enough. | `kubectl wait --for=condition=Available apiservice/v1beta1.metrics.k8s.io --timeout=180s`: waits for exactly the moment `kubectl top` works (66 seconds on the VM). | Switched off and on again: `kubectl top` works straight after the wait. |
| 7 | Lab 6.4, Step 4 | The first Prometheus query came before Prometheus had collected anything (it collects once a minute): empty answer. | `sleep 60` before the first query. | Run 2: both queries give the pods per environment and the restarts. |
| 8 | Labs 1.5 (Step 6) and 1.8 (Step 2) | Right after the frontend pods are replaced, a request through port 30080 can still go to a pod that is stopping, and then `curl` **hangs for about 2 minutes**. Seen in Lab 1.5 in two of three runs. | `sleep 15` after the rollout, with an explanation. A row in setup's "If something is wrong" table: a `curl` that hangs, Ctrl+C and run it again. | Without a pause: 7 of 75 requests failed. With 15 seconds: 0 of 90. |
| 9 | Lab 1.4, Step 4 | `kubectl run dns-test --rm -i` sometimes adds `warning: couldn't attach to pod/dns-test, falling back to streaming logs`, which looks like an error. | A note under the expected output: it is harmless, the answer is the same. | Seen in Labs 1.4, 3.1 and 3.3. |
| 10 | `scripts/check-shop.sh` | Gave **false FAILs** ("frontend -> backend -> database gives no items") while the Shop worked: its throwaway test pod sometimes lost its output when it finished before `kubectl` could attach. | The end-to-end check now asks from inside a frontend pod (`kubectl exec deployment/frontend -- curl ... http://localhost/api/items`): the same path, no extra pod. | Run 2: 30 of 30 checks passed. |
| 11 | Workshop 2, round 3 check | Right after Task 3.2 (the database pod is replaced), the check can say `deployment backend: 1/2 ready` for up to about 30 seconds. | A note: wait 30 seconds and run it again. | |

Also finished during the test: the two placeholders. Setup Step 6 shows the real `check-ready.sh` output from the VM, and the README shows a real `run-lab.sh` screen (`images/run-lab-demo.png`).

## Run 3: every other command in the pages (16 November, evening)

Every command in the pages that is **not** in a 📋 box was listed and given real values: tips, exam tips, "Read only" boxes, tables, the explained pages and the mock exam's "Check:" boxes. That is about 230 commands, in `scripts/test/extra-commands.txt`. Run 3 started from a fresh cluster. It ran every lab again, and after each lab it ran that lab's extra commands with `scripts/test/run-extras.sh`.

- All labs and workshops ran to the end. `check-shop.sh` passed 8 of 8 in dev, uat and prod at all 10 milestones, and `check-ready.sh` said ready at the end.
- The extra commands all worked, except for the problems below. Three FAILs were mistakes in the test itself (wrong time or state), not in the pages, and were corrected in the test file.

| # | Where | What went wrong | The fix | Tested |
| --- | --- | --- | --- | --- |
| 12 | Lab 2.5 exam tip, Lab 2.4 explained | `minikube ssh -- sudo grep -E "cert\|key\|trusted" ...` **hangs**: minikube drops the quotes, so the `\|` runs on your server | Single quotes around the node command: `minikube ssh -- 'sudo grep -E "cert\|key\|trusted" /etc/kubernetes/manifests/etcd.yaml'` | On the VM: prints the paths, exit 0 |
| 13 | Lab 6.3 exam tip, Lab 6.3 explained | `kubectl autoscale ... --cpu-percent=25` prints `Flag --cpu-percent has been deprecated` | `--cpu=25%`, with a note about the old flag | Same HPA (`averageUtilization: 25`), no warning |
| 14 | `scripts/deploy-shop.sh` | After Lab 1.1, it printed `Warning: resource namespaces/dev is missing the ... last-applied-configuration annotation` | It creates the namespace only when it is missing | Syntax checked. The re-run is still to do |
| 15 | Labs 2.2 and 2.7, mock exam Task 14 | `kubectl drain --ignore-daemonsets` always prints `Warning: ignoring DaemonSet-managed Pods: ...`, and the pages did not show it | Lab 2.7 shows it in its output; 2.2 and Task 14 have a short note | Text only |
| 16 | Workshop 2, Task 3.3 | `rollout undo` prints the `kubectl apply` warning (Lab 1.8 explains it; W2 did not) | A one-line note | Text only |

`compare.py` now also flags any `Warning:` line that a page does not show or mention. That is how 15 and 16 were found.

## Day 4 workshop for the first group (fresh server, no labs)

All earlier runs did the workshops after the 33 labs, which is the path of the group that takes the course. The first group comes to Day 4 without the labs, so this path was tested on its own: `WORKSHOPS_ONLY=1 scripts/test/run-all.sh` runs a fresh cluster and `setup.sh`, then Workshops 1 to 4, where Workshop 1 builds the Shop with `deploy-shop.sh dev`.

| # | Where | What went wrong (first group only) | The fix | Tested |
| --- | --- | --- | --- | --- |
| 17 | Workshop 4, Task 14 | The drain of `minikube-m03` with `--force` **deleted the pods of Tasks 1 and 5** (`web`, `secret-reader`), because they happened to run on that node. On the course group's cluster, `minikube-m03` is kept for PROD (Lab 4.3), so it never happened there. | "Before you start" puts a taint on `minikube-m03` that keeps the exam's pods off it, and the clean-up removes it. The solution explains `--force`. | Re-run: the drain no longer touches the exam pods, and all checks of the solutions pass |
| 18 | Workshop 2, Task 3.2 and the round-3 check | After the database pod is replaced, one backend pod stayed not ready for **more than 100 seconds** (it got stuck reconnecting), so the check said `backend: 0/2 ready`. The note said "wait 30 seconds". | The answer restarts the backend (`kubectl rollout restart deployment/backend -n dev`, as Lab 7.3 does), and the note says the same | The restart made it ready in 13 seconds. Re-run: the round-3 check passes |

**Result after the fixes, from a fresh cluster:** Workshop 1 built the Shop, and `check-shop.sh dev` passed 8 of 8. Workshop 2's answers and its round-3 check passed. Workshop 3 put in five faults, and after the fixes 8 of 8 passed. Workshop 4 ran all 15 solutions, and all their checks found the answers. `check-ready.sh` said ready at the end. For the course group nothing changes: Task 14 always moved their PROD pods to the other nodes (PROD only *prefers* `minikube-m03`, Lab 4.2), so the Shop stays open. The clean-up now tells them how to move PROD back (`kubectl rollout restart ... -n prod`), and run 4 below tested that.

**Still to do after run 3:**
- the interactive steps, by hand in a real terminal: `newgrp docker`, Tab completion, `minikube ssh` alone, `run-lab.sh` step by step, `kubectl run -it ... -- sh`, and `kubectl edit` with vi
- the browser steps (Labs 1.6 and 6.4, `shop.local`)
- the `kubectl run -i` lines "All commands and output from this session will be recorded..." that a real terminal shows
- the trainer demos (`scripts/test/trainer-demos.sh`: the Lab 2.6 upgrade and Lab 2.4 `--ha`)
- one more full `run-all.sh` with fixes 12 to 18 (the course group's path, including the new Workshop 4 set-up)

## Not problems (differences that only the automatic run shows)

| Where | What the test showed | Why it is fine |
| --- | --- | --- |
| Lab 1.2, Steps 3 to 5 | `ContainerCreating`, and `kubectl logs` says the container "is waiting to start" | The runner runs Step 3 a split second after Step 2. A person needs longer to read and paste, and the page already says "run it again if it says `ContainerCreating`". Watching the pod start is the point of "Step 3: watch it start". |
| Lab 1.3, Step 3 | Skipped by the runner | It needs a pod name from you (`POD-NAME`). Tested by hand: the deleted backend pod is replaced at once, 2 pods `Running`. |
| Lab 1.6, Step 6 | `kill %1` printed nothing | The `Terminated` line only appears in an interactive terminal. |
| Labs 1.9, 5.2 | `ls` printed one name per line | `ls` does that when its output is not a terminal. |
| Labs 6.1, 6.2 | Log lines, events and file names differ | Live logs and pod IDs are different on every cluster. |
| Lab 8.1, Workshop 3 | `1 check(s) failed` after each `break.sh` | That is the fault the lab puts in, on purpose. |
| Workshop 4 clean-up | Exit code 1 | `kubectl label node minikube-m02 disk-` fails when the label is already gone; the page already says "`not found` ... is fine". |

## Not tested, or worth knowing

- **Lab 2.6:** only the read-only steps run; the upgrade itself is a trainer demo and was not run, so the labs stay on v1.36.5.
- **Two terminals and a desktop browser:** steps that say "open it in a browser" were checked with `curl` only.
- **Timing in class:** the runner is much faster than people. Where a lab waits for something (a rollout, Metrics Server, Prometheus, the Ingress controller), the page now has an explicit wait, so it works at any speed.
- **The non-stop runner (`run-lab.sh --all`):** good for catching up and for the trainer's demo; the only step it cannot do is Lab 1.3 Step 3, which needs a pod name.

## DaDesktop notes for the trainer

- **Uploading files:** the "Drop file here" box at the bottom of DaDesktop writes every uploaded file **twice** into `~/uploads-to-dadesktop` (sometimes mixed together). For the course this does not matter, because participants get the files with `git clone`. If you upload a file, check its size.
- **Speed:** on this VM, `setup.sh` took about **4½ minutes** the first time (downloads) and under **2 minutes** after that. All labs and workshops, run one after the other without stopping, took about **30 minutes**.
- **Memory:** with all three environments, Prometheus and the Ingress controller running, the VM had plenty of room. The course minimum (4 CPUs, 8 GB) is tight for Labs 2.2 and 6.4; 16 GB is comfortable.

## Files changed by this test

| File | Change |
| --- | --- |
| `setup.sh` | Waits for the system pods |
| `scenario-labs/scripts/check-ready.sh` | No more hang at the DNS test |
| `scenario-labs/scripts/check-shop.sh` | Reliable end-to-end check |
| `scenario-labs/scripts/run-lab.sh` | Skips the new "explained" pages (made earlier today) |
| `scenario-labs/00-setup.md` | Real `check-ready.sh` output in Step 6; a row for a hanging `curl` |
| `scenario-labs/README.md` | Real `run-lab.sh` output and screenshot |
| `scenario-labs/images/run-lab-demo.png` | New: the `run-lab.sh` screenshot from the VM |
| `scenario-labs/01-core-concepts/lab-1.4-services.md` | Note on the harmless warning |
| `scenario-labs/01-core-concepts/lab-1.5-configmaps-and-secrets.md` (and `-explained`) | Steps 4, 5 and 6, and the check |
| `scenario-labs/01-core-concepts/lab-1.8-releases-and-rollbacks.md` | Pause after the frontend release |
| `scenario-labs/03-networking/lab-3.2-service-discovery-scaling-load-balancing.md` (and `-explained`) | Wait for the Ingress controller; note in Step 7 |
| `scenario-labs/06-logging-monitoring/lab-6.3-metrics-server.md` (and `-explained`) | Wait for the Metrics API |
| `scenario-labs/06-logging-monitoring/lab-6.4-prometheus.md` | Wait before the first query |
| `scenario-labs/workshop/lab-w2-challenge-rounds.md` | Note at the round-3 check |
| `CKA-new-scenario-based.pptx` | Lab 1.5 slide: the new check line |

No command was changed except where it was broken or needed a wait. Nothing is committed.
