#!/usr/bin/env bash
# Tests the whole course on a fresh cluster: every lab with run-lab.sh --all, in course order, and
# after each lab the other commands of its pages (extra-commands.txt). Takes about 45 minutes.
# Run it on the course server, as the course user, with Docker usable without sudo:
#
#   ~/CKA/scenario-labs/scripts/test/run-all.sh
#
# Watch:   tail -f ~/labtest/progress.txt
# Results: ~/labtest/summary.txt          one block per lab: what differs from the page, and
#                                         every extra command that failed or warned
#          ~/labtest/logs/<lab>.log       everything the lab printed
#          ~/labtest/extras.log           every extra command with its output
#          ~/labtest/shop.txt             check-shop.sh at the milestones
#
# FRESH=0 keeps the cluster (no minikube delete + setup.sh). FROM=2.4 starts at that lab.
# WORKSHOPS_ONLY=1 tests the Day 4 workshop as the first group does it: a fresh cluster, no labs,
# then Workshops 1 to 4 (Workshop 1 builds the Shop in dev with deploy-shop.sh).
# WARNING: without FRESH=0 it deletes the cluster first.

here=$(cd "$(dirname "$0")" && pwd)
L=$(cd "$here/../.." && pwd)
R=$L/scripts/run-lab.sh
T=${LABTEST_DIR:-$HOME/labtest}
mkdir -p "$T/logs"
p() { echo "$*" | tee -a "$T/progress.txt"; }

healthy() {   # the API server answers and every node is Ready, within 3 minutes
  for _ in $(seq 1 36); do
    if kubectl get --raw=/readyz >/dev/null 2>&1 && ! kubectl get nodes --no-headers 2>/dev/null | grep -qv ' Ready '; then
      return 0
    fi
    sleep 5
  done
  return 1
}

extras() {    # the other commands of the lab's pages
  "$here/run-extras.sh" "$1" > "$T/extras-$1.log" 2>&1
  cat "$T/extras-$1.log" >> "$T/extras.log"
  sed -n '/^== extras /,$p' "$T/extras-$1.log" >> "$T/summary.txt"
  rm -f "$T/extras-$1.log"
}

run() {   # id, page
  local id=$1 page=$2 start rc
  [ -n "$FROM" ] && [ "$id" != "$FROM" ] && [ -z "$STARTED" ] && return 0
  STARTED=1
  start=$(date +%s)
  p ">>> $id  $(date +%T)"
  timeout 1800 "$R" "$page" --all > "$T/logs/$id.log" 2>&1 < /dev/null
  rc=$?
  p "    exit $rc, $(( $(date +%s) - start ))s"
  python3 "$here/compare.py" "$page" "$T/logs/$id.log" "$id" >> "$T/summary.txt" 2>&1
  if ! healthy; then
    p "!!! the cluster is not healthy after $id: stopping"
    kubectl get nodes 2>&1 | tee -a "$T/progress.txt"
    exit 1
  fi
  milestone "$id"
  extras "$id"
}

milestone() {   # checks the --all run cannot do by itself
  case $1 in
    1.3)  # the step that needs a value from you: delete one backend pod, and see it replaced
      { echo "--- 1.3 Step 3 (needs a pod name):"
        pod=$(kubectl get pods -n dev -l app=backend -o name | head -1)
        kubectl delete "$pod" -n dev; sleep 8; kubectl get pods -n dev -l app=backend; } >> "$T/shop.txt" 2>&1 ;;
    1.9|2.7|3.3|4.3|5.2|6.4|7.4|8.1|w1|w3)
      { echo "--- check-shop after $1:"
        for ns in $envs; do kubectl rollout status deployment/db deployment/backend deployment/frontend -n "$ns" --timeout=180s >/dev/null 2>&1; done
        for ns in $envs; do echo "$ns: $("$L/scripts/check-shop.sh" "$ns" 2>&1 | tail -1)"; done; } >> "$T/shop.txt" 2>&1
      tail -n "$(wc -w <<<"$envs")" "$T/shop.txt" | sed "s/^/    shop after $1: /" >> "$T/summary.txt" ;;
  esac
}

envs="dev uat prod"                                  # the first group only has dev
[ "${WORKSHOPS_ONLY:-0}" = 1 ] && envs=dev
: > "$T/progress.txt"; : > "$T/summary.txt"; : > "$T/shop.txt"; : > "$T/extras.log"
p "Lab test started $(date)$([ "${WORKSHOPS_ONLY:-0}" = 1 ] && echo ': Day 4 workshop only, as the first group')"

if [ "${FRESH:-1}" = 1 ] && [ -z "$FROM" ]; then
  p ">>> fresh cluster (Lab 2.1: minikube delete, then setup.sh)"
  minikube delete > "$T/logs/delete.log" 2>&1
  sudo sed -i '/shop\.local/d' /etc/hosts
  rm -rf ~/thabo ~/exam ~/lerato ~/mallory ~/ci-bot
  for u in thabo lerato; do kubectl config delete-context $u >/dev/null 2>&1; kubectl config delete-user $u >/dev/null 2>&1; done
  start=$(date +%s)
  (cd "$L/.." && sudo ./setup.sh) > "$T/logs/setup.log" 2>&1 || { p "!!! setup.sh failed"; tail -5 "$T/logs/setup.log" | tee -a "$T/progress.txt"; exit 1; }
  p "    setup.sh $(( $(date +%s) - start ))s: $(grep '==> OK' "$T/logs/setup.log")"
  "$L/scripts/check-ready.sh" > "$T/logs/check-ready.log" 2>&1
  p "    check-ready: $(tail -1 "$T/logs/check-ready.log")"
  echo "=== setup: check-ready says: $(tail -1 "$T/logs/check-ready.log")" >> "$T/summary.txt"
  extras setup
fi

if [ "${WORKSHOPS_ONLY:-0}" != 1 ]; then
  for page in $(ls -1 "$L"/0[1-8]-*/lab-*.md | grep -v -- '-explained' | sort); do
    id=$(basename "$page" .md); id=${id#lab-}; id=${id%%-*}
    run "$id" "$page"
  done
fi
run w1 "$(ls "$L"/workshop/lab-w1-*.md | grep -v -- '-explained' | head -1)"
# Workshop 2: the answers sit in "Show the answer" blocks without a 📋 mark, so run-lab.sh would
# skip them. Mark them, so the answers run in order, with the clean-up boxes of each round.
awk '{print} /^<details><summary>Show the answer/{print ""; print "**📋 Copy and paste into your terminal:**"}' \
  "$(ls "$L"/workshop/lab-w2-*.md | grep -v -- '-explained' | head -1)" > "$T/w2-with-answers.md"
run w2 "$T/w2-with-answers.md"
run w3 "$(ls "$L"/workshop/lab-w3-*.md | grep -v -- '-explained' | head -1)"

# The mock exam: its last box deletes the exam namespace. Run the tasks page without it, then the
# solutions, then the solutions' "Check:" commands (extras), then the clean-up box.
w4=$L/workshop/lab-w4-mock-exam.md
awk '/^## When the time is up/{exit} {print}' "$w4" > "$T/w4-tasks.md"
{ echo "# Workshop 4: clean-up"; echo; awk '/^## When the time is up/{f=1} f' "$w4"; } > "$T/w4-cleanup.md"
run w4 "$T/w4-tasks.md"
run w4-solutions "$L/workshop/lab-w4-mock-exam-solutions.md"
run w4-cleanup "$T/w4-cleanup.md"

extras end
{ echo "--- check-ready at the end:"; "$L/scripts/check-ready.sh" 2>&1 | tail -12; } >> "$T/shop.txt"
echo "=== end: check-ready says: $(tail -1 "$T/shop.txt")" >> "$T/summary.txt"
p "Lab test finished $(date)"
