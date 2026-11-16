# Testing the labs (for the trainer)

These scripts run the whole course on a test server, so that you know every command works before a course starts. They are not for the students.

Use a server like the students' (Ubuntu 24.04 or newer, 4 CPUs, 8 GB RAM at least), with the course files in `~/CKA`. **It deletes the cluster on that server** and builds a new one.

## Test every lab

**📋 Copy and paste into your terminal:**

```bash
~/CKA/scenario-labs/scripts/test/run-all.sh
```

**What this does:** Builds a fresh cluster (`minikube delete`, then `setup.sh`), then runs every lab and workshop in course order with `run-lab.sh --all`. After each lab it runs the other commands of that lab's pages: the tips, the exam tips, the "Read only" boxes and the commands in the "explained" page (`extra-commands.txt`). It takes about 45 minutes.

In a second terminal, follow it:

```bash
tail -f ~/labtest/progress.txt
```

When it says `Lab test finished`, read the result:

```bash
cat ~/labtest/summary.txt
```

**👀 You should see** one block per lab. A good result looks like this:

```text
=== 1.5    blocks 14, ran 14, compared 12, issues 0
== extras 1.5: 9 commands, 9 OK, 0 WARN, 0 FAIL
```

| The line says | Meaning |
| --- | --- |
| `issues 0` | Every command of the lab printed what the page says under 👀. |
| `issues 2` and lines under it | Those commands printed something else. Compare `expected:` with `actual:`. Ages, IP addresses and random names are already ignored. |
| `** DID NOT REACH THE END **` | The lab stopped half way: look at the end of `~/labtest/logs/<lab>.log`. |
| `FAIL` (extras) | A command from a tip or an explained page failed. `~/labtest/extras.log` has its output. |
| `WARN` (extras) | It worked, but printed a warning or an error line: read it in `~/labtest/extras.log`. |
| `shop after 4.3: dev: All 8 checks passed.` | `check-shop.sh` at the milestones of the course. |

`FROM=6.1 ~/CKA/scenario-labs/scripts/test/run-all.sh` starts at Lab 6.1 on the cluster you have (after a run that stopped half way).

## Test the Day 4 workshop as the first group does it

The first group comes to Day 4 without the course labs: a fresh server, `setup.sh`, and Workshop 1 builds the Shop in `dev`. To test exactly that path (about 15 minutes):

```bash
WORKSHOPS_ONLY=1 ~/CKA/scenario-labs/scripts/test/run-all.sh
```

## Test the trainer demos

The upgrade (Lab 2.6) and the three control plane nodes (Lab 2.4) are shown by the trainer only. This script tries both, and then builds a fresh course cluster again:

```bash
~/CKA/scenario-labs/scripts/test/trainer-demos.sh
```

The result is in `~/labtest/demos.txt`: how many Shop requests failed during the upgrade, the versions after it, and the nodes of the HA cluster.

## The files

| File | What it is |
| --- | --- |
| `run-all.sh` | Runs the whole course (above). |
| `compare.py` | Compares what a lab printed with the 👀 boxes of its page. |
| `extra-commands.txt` | Every command of the pages that is not in a 📋 box, with real values, per lab. Add a line here when you add a command to a tip or an explained page. |
| `run-extras.sh` | Runs one section of `extra-commands.txt`: `run-extras.sh 1.5`. |
| `trainer-demos.sh` | The upgrade and HA demos (above). |
| `nodeport-after-rollout.sh` | Shows why Labs 1.5 and 1.8 wait 15 seconds after a rollout: `nodeport-after-rollout.sh 0` and `nodeport-after-rollout.sh 15`. |

`~/CKA/scenario-labs/TEST-REPORT.md` has the results of the last full test.
