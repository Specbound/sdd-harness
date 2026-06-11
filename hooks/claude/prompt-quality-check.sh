#!/bin/bash
# Prompt Quality Gate — PreToolUse hook on Agent tool
# Scores every agent prompt against 6 PQ dimensions (heuristic, no LLM required).
# Outputs scored feedback to Claude's context (stdout) + appends to ~/.code-insights/pq-log.jsonl.

set -euo pipefail

EVENT=$(cat)
PROMPT=$(echo "$EVENT" | python3 -c "
import json, sys
try:
    e = json.load(sys.stdin)
    inp = e.get('tool_input', {})
    print(inp.get('prompt', '') or inp.get('description', ''))
except Exception:
    print('')
" 2>/dev/null || echo "")

[[ -z "$PROMPT" ]] && exit 0

python3 - "$PROMPT" << 'PYEOF'
import sys, json, re, os, datetime, hashlib, pathlib

prompt = sys.argv[1]
words = prompt.split()
text_lower = prompt.lower()

def score_context_provision(t, w):
    s = 2
    if re.search(r'(file|path|\.py|\.ts|\.js|\.sh|at line \d+|see \w+\.|context:)', t): s += 1
    if re.search(r'\b(already|previously|tried|broken|failing|current|existing|background|prior|working on)\b', t): s += 1
    if len(w) >= 30: s += 1
    return min(s, 5)

def score_request_specificity(t, w):
    s = 2
    if re.search(r'\b(help me|look at|something|somehow|maybe|probably|sort of|kind of|fix this)\b', t): s -= 1
    if re.search(r'\b(implement|create|refactor|extract|rename|migrate|add|remove|replace|verify|check|update|analyze|generate|write|find|list)\b', t): s += 1
    if re.search(r'\b(the\s+\w+\s+(function|class|file|module|component|endpoint|hook|method|script|tool|agent))\b', t): s += 1
    if len(w) < 10: s -= 1
    return max(1, min(s, 5))

def score_scope_management(t, w):
    s = 2
    if re.search(r"\b(only|don't|do not|must not|limited to|no other|without touching|leave|preserve|just the|exclusively)\b", t): s += 2
    if re.search(r'\b(return|output|report|list|show|summarize|format|as json|as markdown|emit|print)\b', t): s += 1
    if re.search(r'\b(everything|all of|anywhere|any\s+file|comprehensive|whatever you need|whatever makes sense)\b', t): s -= 1
    return max(1, min(s, 5))

def score_information_timing(t, w):
    s = 3
    first_third = ' '.join(w[:max(1, len(w)//3)]).lower()
    if re.search(r'\b(implement|create|refactor|find|check|verify|analyze|review|fix|add|remove|write|list|generate)\b', first_third): s += 1
    if re.match(r'^(given|since|because|as you know|note that|remember that|context:|background:)', t.strip(), re.IGNORECASE): s -= 1
    return max(1, min(s, 5))

def score_correction_quality(t):
    if not re.search(r'\b(wrong|incorrect|actually|instead|not what|should be|the issue|the problem|you missed|missed|that\'s not|that is not)\b', t):
        return None
    s = 2
    if re.search(r'\b(specifically|exactly|the\s+\w+\s+(was|is)\s+wrong|wrong\s+because)\b', t): s += 2
    if re.search(r'\b(should|expect|correct\s+version|instead\s+use|replace\s+with|the\s+right)\b', t): s += 1
    return min(s, 5)

ctx    = score_context_provision(text_lower, words)
spec   = score_request_specificity(text_lower, words)
scope  = score_scope_management(text_lower, words)
timing = score_information_timing(text_lower, words)
corr   = score_correction_quality(text_lower)

applicable = [ctx, spec, scope, timing] + ([corr] if corr is not None else [])
overall = round(sum(applicable) / len(applicable), 1)

ICON = {5: '✅', 4: '✅', 3: '🟡', 2: '⚠ ', 1: '❌'}
TIPS = {
    'context_provision':  'add file paths, prior attempts, or relevant background',
    'request_specificity': 'name the specific target (function/file/class) and use an action verb',
    'scope_management':   "state what NOT to change; specify output format",
    'information_timing': 'lead with the goal — state the ask before the context',
    'correction_quality': 'name the exact error and describe the expected correct behavior',
}

def dim_line(label, val, tip_key):
    if val is None:
        return f"  —  {label}: N/A"
    icon = ICON.get(val, '⚠ ')
    line = f"  {icon} {label}: {val}/5"
    if val <= 3:
        line += f"  →  {TIPS[tip_key]}"
    return line

print(f"⚡ PQ Score: {overall}/5")
print(dim_line('context_provision',  ctx,   'context_provision'))
print(dim_line('request_specificity', spec, 'request_specificity'))
print(dim_line('scope_management',    scope, 'scope_management'))
print(dim_line('information_timing',  timing, 'information_timing'))
print(dim_line('correction_quality',  corr,  'correction_quality'))
if overall < 3.5:
    print("  ⬆  Consider improving flagged dimensions before spawning.")
elif overall < 4.0:
    print("  ✍  Good prompt. Address ⚠ items if time allows.")
else:
    print("  ✅ Strong prompt — proceed.")

# Log entry
log_dir = pathlib.Path.home() / '.code-insights'
log_dir.mkdir(parents=True, exist_ok=True)
entry = {
    'ts': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'overall': overall,
    'dims': {
        'context_provision': ctx,
        'request_specificity': spec,
        'scope_management': scope,
        'information_timing': timing,
        'correction_quality': corr,
    },
    'prompt_hash': hashlib.sha256(prompt.encode()).hexdigest()[:12],
    'word_count': len(words),
}
with open(log_dir / 'pq-log.jsonl', 'a') as f:
    f.write(json.dumps(entry) + '\n')
PYEOF
