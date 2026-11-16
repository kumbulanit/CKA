#!/usr/bin/env bash
# Runs a lab step by step: for the trainer's demo, or to catch up. It reads the lab's own page and
# runs the same commands, in the same order. For every command it shows the command and what it
# does, waits for you, runs it, and shows the result.
#
#   ./run-lab.sh              lists the labs
#   ./run-lab.sh 1.3          runs Lab 1.3. Before every command: Enter runs it, s skips it, q stops
#   ./run-lab.sh 1.3 --all    runs all of Lab 1.3 without stopping (to catch up)
#
# Ctrl+C stops the command that is running (and only that command).
# Variables are prefixed RL_ so that the lab's own commands (which run in this shell) cannot clash.

RL_labs=$(cd "$(dirname "$0")/.." && pwd)

rl_list() {
  echo "The labs. Run one with: $0 <number>   (add --all to run it without stopping)"
  local f n t
  for f in "$RL_labs"/0[1-8]-*/lab-*.md "$RL_labs"/workshop/lab-*.md; do
    n=$(basename "$f" .md); n=${n#lab-}
    case $n in *solutions) n="${n%%-*}-solutions" ;; *) n=${n%%-*} ;; esac
    t=$(head -1 "$f" | sed -E 's/^# //')
    printf '  %-14s %s\n' "$n" "$t"
  done
}

rl_find() {
  local a=${1#lab-}
  [ -f "$1" ] && { echo "$1"; return; }
  case $a in
    *-solutions) ls "$RL_labs"/*/lab-"${a%-solutions}"-*solutions.md 2>/dev/null | head -1 ;;
    *) ls "$RL_labs"/*/lab-"$a"-*.md 2>/dev/null | grep -v solutions | head -1 ;;
  esac
}

# Reads a lab page and writes, for every 📋 box, its commands (NNN.cmd), the heading it is under
# (NNN.head), its "What this does" note (NNN.what) and flags (NNN.flags): "change" (the box has a
# value to change), "node" (it is typed on a node, after minikube ssh), "answer" (it is hidden under
# <details>). Also the title, "The situation" and the "✅ Check" lines.
IFS= read -r -d '' RL_awk <<'AWK'
function out(name) { return dir "/" sprintf("%03d", n) "." name }
function endwhat(  f) { if (wcap) { f = out("what"); close(f) } wcap = 0; want = 0 }
{
  line = $0
  if (fence) {
    if (line ~ /^```/) {
      fence = 0
      if (cap) { cap = 0; f = out("cmd"); close(f); want = 1 }
      next
    }
    if (cap) { f = out("cmd"); print line > f }
    next
  }
  if (line ~ /^```/) {
    endwhat(); fence = 1
    if (pend != "" && line ~ /^```(bash|sh|shell)?[ \t]*$/) {
      n++; cap = 1
      flags = ""
      if (pend ~ /then change/) flags = flags " change"
      if (pend ~ /node.s terminal/) flags = flags " node"
      if (det) flags = flags " answer"
      f = out("head"); print head > f; close(f)
      f = out("flags"); print flags > f; close(f)
    }
    pend = ""
    next
  }
  if (line ~ /^# / && title == "") { title = substr(line, 3); f = dir "/title"; print title > f; close(f); next }
  if (line ~ /^#+ /) { endwhat(); head = line; sub(/^#+ /, "", head); pend = ""; next }
  if (line ~ /<details/) det = 1
  if (line ~ /<\/details>/) det = 0
  if (line ~ /^\*\*The situation:\*\*/) { s = line; gsub(/\*\*/, "", s); f = dir "/situation"; print s > f; close(f) }
  if (index(line, "✅") == 1) { s = line; gsub(/\*\*/, "", s); f = dir "/check"; print s > f }
  if (index(line, "📋") && line ~ /[Cc]opy and paste/ && line !~ /^>/) { endwhat(); pend = line; next }
  if (want) {
    if (line ~ /^\*\*What this does:\*\*/) {
      want = 0; wcap = 1; s = line; gsub(/\*\*/, "", s); f = out("what"); print s > f; next
    }
    if (line ~ /^[ \t]*$/) next
    want = 0
  }
  if (wcap) {
    if (line ~ /^[ \t]*$/) next
    if (line ~ /^- / || line ~ /^  /) { s = line; gsub(/\*\*/, "", s); f = out("what"); print s > f; next }
    endwhat()
  }
}
END { endwhat(); close(dir "/check") }
AWK

case ${1:-} in
  ""|-h|--help|list) rl_list; exit 0 ;;
esac
RL_file=$(rl_find "$1")
[ -n "$RL_file" ] || { echo "There is no lab \"$1\"."; echo; rl_list; exit 1; }
RL_all=0
[ "${2:-}" = --all ] && RL_all=1

RL_tmp=$(mktemp -d)
trap 'rm -rf "$RL_tmp"' EXIT
awk -v dir="$RL_tmp" "$RL_awk" "$RL_file"

if [ -t 1 ]; then
  RL_B=$'\e[1m'; RL_C=$'\e[1;36m'; RL_D=$'\e[2m'; RL_Y=$'\e[1;33m'; RL_G=$'\e[1;32m'; RL_R=$'\e[0m'
else
  RL_B=; RL_C=; RL_D=; RL_Y=; RL_G=; RL_R=
fi

RL_cmds=("$RL_tmp"/*.cmd)
[ -e "${RL_cmds[0]}" ] || { echo "$(cat "$RL_tmp/title"): this page has no commands to run."; exit 0; }
RL_total=${#RL_cmds[@]}

echo "${RL_B}══ $(cat "$RL_tmp/title") ══${RL_R}"
[ -f "$RL_tmp/situation" ] && cat "$RL_tmp/situation"
echo "${RL_D}Page: ${RL_file#"$RL_labs"/}   Commands: $RL_total${RL_R}"
if [ "$RL_all" = 1 ]; then
  echo "${RL_D}Runs every command without stopping. Ctrl+C stops the command that is running.${RL_R}"
else
  echo "${RL_D}Before every command: Enter runs it, s skips it, q stops. Ctrl+C stops a running command.${RL_R}"
fi

cd "$RL_labs" || exit 1
RL_node=""; RL_last=""; RL_k=0; RL_int=0; RL_stopped=0
trap 'RL_int=1' INT

for RL_f in "${RL_cmds[@]}"; do
  RL_k=$((RL_k + 1))
  RL_i=${RL_f%.cmd}
  RL_cmd=$(cat "$RL_f")
  RL_head=$(cat "$RL_i.head" 2>/dev/null)
  RL_flags=$(cat "$RL_i.flags" 2>/dev/null)

  if [ "$RL_head" != "$RL_last" ]; then
    printf '\n%s── %s ──%s\n' "$RL_Y" "$RL_head" "$RL_R"
    RL_last=$RL_head
  fi

  # "minikube ssh" alone opens a shell on a node. The runner does not open it: it sends the
  # commands for the node's terminal to that node for you.
  if [[ $RL_cmd =~ ^minikube\ ssh(\ -n\ ([^[:space:]]+))?[[:space:]]*$ ]]; then
    RL_node=${BASH_REMATCH[2]:-minikube}
    printf '\n%s$ %s%s\n' "$RL_C" "$RL_cmd" "$RL_R"
    echo "${RL_D}(The runner does not open this shell. It sends the next commands to the node $RL_node for you.)${RL_R}"
    continue
  fi

  RL_onnode=0
  [[ $RL_flags == *node* && -n $RL_node ]] && RL_onnode=1
  RL_ps='$'
  [ "$RL_onnode" = 1 ] && RL_ps="docker@$RL_node\$"
  echo
  RL_first=1
  while IFS= read -r RL_l; do
    if [ "$RL_first" = 1 ]; then printf '%s%s %s%s\n' "$RL_C" "$RL_ps" "$RL_l" "$RL_R"; RL_first=0
    else printf '%s  %s%s\n' "$RL_C" "$RL_l" "$RL_R"; fi
  done <<<"$RL_cmd"
  [ -f "$RL_i.what" ] && printf '%s%s%s\n' "$RL_D" "$(cat "$RL_i.what")" "$RL_R"
  [[ $RL_flags == *answer* ]] && echo "${RL_Y}This is an answer: in the lab it is hidden under \"Answer\".${RL_R}"

  if [ "$RL_all" = 0 ]; then
    RL_int=0
    if ! read -r -p "${RL_G}▶ [$RL_k/$RL_total] Enter: run   s: skip   q: stop ${RL_R}" RL_key; then
      echo; RL_stopped=1; break
    fi
    case $RL_key in
      s|S) echo "${RL_D}(skipped)${RL_R}"; continue ;;
      q|Q) RL_stopped=1; break ;;
    esac
  else
    echo "${RL_G}▶ [$RL_k/$RL_total]${RL_R}"
  fi

  if [[ $RL_flags == *change* ]]; then
    if [ "$RL_all" = 1 ]; then
      echo "${RL_D}(skipped: this command needs a value from you)${RL_R}"; continue
    fi
    read -r -e -i "$RL_cmd" -p "Put in your value, then press Enter: " RL_cmd || { RL_stopped=1; break; }
  fi

  RL_int=0
  if [ "$RL_onnode" = 1 ]; then
    # The box ends with "exit" (back to your server): that line is not sent to the node.
    RL_body=$(sed '${/^[[:space:]]*exit[[:space:]]*$/d;}' <<<"$RL_cmd")
    minikube ssh -n "$RL_node" -- "echo $(printf '%s\n' "$RL_body" | base64 -w0) | base64 -d | bash"
    [[ $(tail -n 1 <<<"$RL_cmd") =~ ^[[:space:]]*exit[[:space:]]*$ ]] && RL_node=""
  else
    eval "$RL_cmd"
  fi
  [ "$RL_int" = 1 ] && echo "${RL_D}(stopped with Ctrl+C)${RL_R}"
done

echo
if [ "$RL_stopped" = 0 ]; then
  echo "${RL_B}══ End of $(cut -d: -f1 "$RL_tmp/title") ══${RL_R}"
  [ -f "$RL_tmp/check" ] && cat "$RL_tmp/check"
else
  echo "${RL_D}Stopped at command $RL_k of $RL_total.${RL_R}"
fi
