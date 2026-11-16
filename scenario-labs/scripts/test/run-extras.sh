#!/usr/bin/env bash
# Runs one section of extra-commands.txt: the commands in the lab pages that run-lab.sh --all does
# not run by itself (tips, exam tips, "Read only" boxes, the explained pages, the mock exam checks).
#
#   run-extras.sh 1.5          runs the section "## 1.5" (right after Lab 1.5, in its state)
#   run-extras.sh list         lists the sections
#
# For every command it prints the command, where it comes from, its output (25 lines at most) and
# OK, WARN (it worked, but printed a warning or an error line) or FAIL. The last lines sum it up.

here=$(cd "$(dirname "$0")" && pwd)
labs=$(cd "$here/../.." && pwd)
file=${EXTRAS:-$here/extra-commands.txt}
sec=${1:?usage: run-extras.sh <section>|list}

if [ "$sec" = list ]; then grep '^## ' "$file" | cut -c4- | paste -sd' ' -; exit 0; fi

case $sec in
  1.*) dir=01-core-concepts ;;   2.*) dir=02-installation ;;  3.*) dir=03-networking ;;
  4.*) dir=04-scheduling ;;      5.*) dir=05-security ;;      6.*) dir=06-logging-monitoring ;;
  7.*) dir=07-storage ;;         8.*) dir=08-troubleshooting ;; w*) dir=workshop ;;  *) dir=. ;;
esac

lines=()
while IFS= read -r l; do lines+=("$l"); done < <(awk -v s="## $sec" '$0 == s {f = 1; next} /^## / {f = 0} f' "$file")
[ ${#lines[@]} -gt 0 ] || { echo "== extras $sec: no such section"; exit 0; }

warnre='[Ww]arning|WARN|[Dd]eprecat|[Ee]rror|not found|[Ff]orbidden|denied|[Uu]nable to|refused|timed out|[Ii]nvalid'
noise='cannot set terminal process group|no job control in this shell'
n=0; ok=0; warn=0; fail=0; src=""; problems=()
for line in "${lines[@]}"; do
  [[ -z ${line//[[:space:]]/} ]] && continue
  if [[ $line == \#* ]]; then src=${line#\# }; continue; fi
  mode=run; cmd=$line
  case $line in
    '!'*) mode=fail; cmd=${line:1} ;;
    '~'*) mode=keep; cmd=${line:1} ;;
  esac
  n=$((n + 1))
  t=240; [ $mode = keep ] && t=8
  echo "▷ [$sec/$n] $cmd"
  echo "  from: $src"
  out=$(cd "$labs/$dir" && timeout "$t" bash -c "$cmd" 2>&1 </dev/null); rc=$?
  out=$(printf '%s\n' "$out" | grep -Ev "$noise")
  printf '%s\n' "$out" | head -25 | sed 's/^/  | /'
  case $mode in
    run)  [ $rc = 0 ] && v=OK || v=FAIL ;;
    fail) [ $rc != 0 ] && v=OK || v="FAIL (should fail)" ;;
    keep) { [ $rc = 0 ] || [ $rc = 124 ]; } && v=OK || v=FAIL ;;
  esac
  if [ "$v" = OK ] && [ $mode != fail ] && printf '%s\n' "$out" | grep -Eq "$warnre"; then v=WARN; fi
  echo "◁ exit $rc: $v"
  case $v in
    OK) ok=$((ok + 1)) ;;
    WARN) warn=$((warn + 1)); problems+=("WARN [$sec/$n] $cmd  ::  $(printf '%s\n' "$out" | grep -Em1 "$warnre" | cut -c1-150)") ;;
    *) fail=$((fail + 1)); problems+=("FAIL [$sec/$n] exit $rc  $cmd  ::  $(printf '%s\n' "$out" | grep -v '^$' | tail -1 | cut -c1-150)") ;;
  esac
done
echo "== extras $sec: $n commands, $ok OK, $warn WARN, $fail FAIL"
for p in "${problems[@]}"; do echo "   $p"; done
