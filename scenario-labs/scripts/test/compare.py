#!/usr/bin/env python3
"""Compare a run-lab.sh --all log with the lab page: every command's output against its
"You should see" block. Prints only what differs, and error lines the page does not expect.
usage: compare.py LAB.md LOG [LABEL]"""
import re, sys, difflib

md, log = sys.argv[1], sys.argv[2]
label = sys.argv[3] if len(sys.argv) > 3 else md

# ---- the page: commands in run-lab.sh order, each with its expected output (if any)
L = open(md, encoding='utf-8').read().split('\n')
blocks = []          # dicts: cmd, expected (list or None), prose (str or None)
i = 0
pending = False
while i < len(L):
    line = L[i]
    if '📋' in line and re.search(r'[Cc]opy and paste', line) and not line.startswith('>'):
        pending = True
    elif pending and line.startswith('```bash'):
        j = i + 1
        while not L[j].startswith('```'):
            j += 1
        cmd = L[i + 1:j]
        exp, prose = None, None
        k = j + 1
        # the page's text after the box, up to the next box or heading (notes such as "a warning
        # line ... is fine" live there)
        t = j + 1
        while t < len(L) and not ('📋' in L[t] and re.search(r'[Cc]opy and paste', L[t])) and not L[t].startswith('#'):
            t += 1
        after = '\n'.join(L[j + 1:t])
        while k < len(L) and not ('📋' in L[k] and re.search(r'[Cc]opy and paste', L[k])) and not L[k].startswith('#'):
            if '👀' in L[k] and 'should see' in L[k]:
                prose = L[k]
                m = k + 1
                while m < len(L) and m <= k + 3 and not L[m].startswith('```'):
                    m += 1
                if m < len(L) and L[m].startswith('```') and not L[m].startswith('```bash'):
                    e = m + 1
                    while not L[e].startswith('```'):
                        e += 1
                    exp = L[m + 1:e]
                break
            k += 1
        blocks.append(dict(cmd=cmd, exp=exp, prose=prose, after=after))
        pending = False
        i = j
    i += 1

# ---- the log: output after each "▶ [k/N]" line
G = open(log, encoding='utf-8', errors='replace').read().split('\n')
out = {}
k = None
stop = re.compile(r'^(\$ |docker@\S+\$ |── .* ──$|══ End of|Stopped at command|\(The runner does not open)')
for line in G:
    m = re.match(r'^▶ \[(\d+)/(\d+)\]', line)
    if m:
        k = int(m.group(1)); out[k] = []
        continue
    if k is not None:
        if stop.match(line):
            k = None
            continue
        out[k].append(line)
for v in out.values():
    while v and not v[-1].strip():
        v.pop()

def norm(s):
    s = s.strip()
    s = re.sub(r'\x1b\[[0-9;]*m', '', s)
    s = re.sub(r'\b\d{1,3}(\.\d{1,3}){3}(/\d+)?\b', 'IP', s)
    s = re.sub(r'\b([a-z][a-z0-9-]*?)-[a-z0-9]{8,10}-[a-z0-9]{5}\b', r'\1-H-H', s)
    s = re.sub(r'\b([a-z][a-z0-9-]*?)-(?=[a-z0-9]*\d)[a-z0-9]{5}\b', r'\1-H', s)
    s = re.sub(r'\b([a-z][a-z0-9-]*?)-(?=[a-z0-9]*\d)[a-z0-9]{8,10}\b', r'\1-H', s)
    s = re.sub(r'\bpvc-[0-9a-f-]{36}\b', 'pvc-UID', s)
    s = re.sub(r'\b\d+(\.\d+)?(ms|s|m|h|d)(\d+(s|m))?\b', 'AGE', s)
    s = re.sub(r'\b\d+%', 'N%', s)
    s = re.sub(r'\d{2}/\w{3}/\d{4}:\d{2}:\d{2}:\d{2} [+-]\d{4}', 'TIME', s)
    s = re.sub(r'\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}(\.\d+)?Z?', 'TIME', s)
    s = re.sub(r'\b[0-9a-f]{12,}\b', 'HEX', s)
    s = re.sub(r'\s+', ' ', s)
    return s

def best(line, pool):
    b = 0.0
    for p in pool:
        if line == p:
            return 1.0
        r = difflib.SequenceMatcher(None, line, p).ratio()
        if r > b:
            b = r
    return b

ERR = re.compile(r'(?i)(\berror\b|unable to|forbidden|permission denied|refused|not found|timed out|no such file|command not found|\bfailed\b|invalid|cannot|could not)')
WARN = re.compile(r'(?i)^\s*warning:')
issues, compared, errors = [], 0, 0
cut = lambda s: s if len(s) <= 150 else s[:147] + '...'
for n, b in enumerate(blocks, 1):
    act = out.get(n)
    if act is None:
        continue                                   # an interactive "minikube ssh" line, or skipped
    an = [norm(a) for a in act if a.strip()]
    msgs = []
    if b['exp'] is not None:
        en = [norm(e) for e in b['exp'] if e.strip() and '...' not in e and not e.strip().startswith('#')]
        if en:
            compared += 1
            hit = sum(1 for e in en if best(e, an) >= 0.75)
            score = hit / len(en)
            if score < 0.7:
                msgs.append('score %.2f (%d of %d expected lines found)' % (score, hit, len(en)))
                msgs.append('  expected: ' + cut(' | '.join(x.strip() for x in b['exp'] if x.strip())[:400]))
                msgs.append('  actual:   ' + cut(' | '.join(x.strip() for x in act if x.strip())[:400] or '(no output)'))
    expn = [norm(e) for e in (b['exp'] or [])]
    for a in act:
        if ERR.search(a) and (not expn or best(norm(a), expn) < 0.75) and not (b['prose'] and ERR.search(b['prose'] or '')):
            msgs.append('  ERROR LINE: ' + cut(a.strip()))
            errors += 1
            break
    # kubectl's own warnings ("Warning: ..."): fine only if the page shows or mentions them
    for a in act:
        if WARN.match(a) and (not expn or best(norm(a), expn) < 0.75) and 'warning' not in b['after'].lower():
            msgs.append('  WARNING LINE the page does not mention: ' + cut(a.strip()))
            break
    if msgs:
        issues.append('  [%d] %s' % (n, cut(b['cmd'][0].strip())))
        issues.extend('      ' + m for m in msgs)

ran = len(out)
ended = any(l.startswith('══ End of') for l in G)
print('=== %-6s blocks %d, ran %d, compared %d, issues %d%s' % (
    label, len(blocks), ran, compared, sum(1 for x in issues if x.startswith('  [')), '' if ended else '  ** DID NOT REACH THE END **'))
for x in issues:
    print(x)
