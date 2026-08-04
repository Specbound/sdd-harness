---
name: repo-drift-review
description: "Weekly harness integrity sweep: checks MEMORY.md index vs files on disk, settings.json hooks vs scripts on disk, and doc links vs real paths. Auto-fixes mechanical drift, flags structural issues."
risk: safe
source: local
---

# Repo Drift Review

Weekly sweep of the SDD harness for mechanical drift: MEMORY.md entries pointing to missing files, hook scripts in settings.json that no longer exist, unregistered scripts in hooks/, and broken doc link paths. Auto-fixes what's unambiguous; flags the rest.

## When to Use This Skill

- Run automatically each week (CCR scheduled routine, Wednesdays)
- User says "check harness drift", "audit harness integrity", "are my hooks still valid", "is MEMORY.md stale"

## Do Not Use This Skill When

- Auditing skill quality or redundancy — use `skill-curator`
- Reviewing code correctness — use `comprehensive-review-full-review`

---

## Workflow

### Phase 1: Memory Index Integrity

**Check: MEMORY.md entries → files exist**

```bash
MEMORY=/home/dalesser/.claude/projects/-home-dalesser--claude-sdd-harness/memory/MEMORY.md
MEM_DIR=/home/dalesser/.claude/projects/-home-dalesser--claude-sdd-harness/memory
grep -oP '\]\(\K[^)]+\.md' "$MEMORY"
```

For each file reference extracted, check it exists in `$MEM_DIR`. Collect missing entries.

**Check: orphaned memory files → listed in MEMORY.md**

```bash
ls $MEM_DIR/*.md | grep -v MEMORY.md
```

For each `.md` file in the memory directory, check it appears in MEMORY.md. Collect unlisted files.

**Auto-fixes:**
- **Missing entry file**: Remove the line from MEMORY.md. Log: `MEMORY: removed stale entry → [filename]`
- **Orphaned file**: Add a one-line entry to MEMORY.md: `- [slug](filename.md) — ⚠️ auto-indexed, description needed`. Log: `MEMORY: added missing index entry → [filename]`

---

### Phase 2: Hook Script Integrity

**Check: hooks in settings.json → scripts exist on disk**

Read hook commands from both settings files:
```bash
cat /home/dalesser/.claude/sdd-harness/.claude/settings.json | python3 -c "
import json,sys
d=json.load(sys.stdin)
hooks=d.get('hooks',{})
for event,entries in hooks.items():
    for e in (entries if isinstance(entries,list) else [entries]):
        cmd=e.get('command','') if isinstance(e,dict) else e
        print(cmd)
"
cat /home/dalesser/.claude/settings.json | python3 -c "
import json,sys
d=json.load(sys.stdin)
hooks=d.get('hooks',{})
for event,entries in hooks.items():
    for e in (entries if isinstance(entries,list) else [entries]):
        cmd=e.get('command','') if isinstance(e,dict) else e
        print(cmd)
" 2>/dev/null
```

For each command, extract any file path references (`.sh` files). Check they exist on disk.

**Check: scripts in hooks/ → referenced in settings.json**

```bash
ls /home/dalesser/.claude/sdd-harness/.claude/hooks/*.sh
```

For each script, check it appears in at least one settings.json command.

**Auto-fixes:**
- **Hook pointing to missing script**: Remove the hook entry from settings.json. Log: `HOOKS: removed dead hook → [script path]`

**Flag for human review (do not auto-fix):**
- Scripts on disk not referenced in settings.json — may be intentionally dormant or pending registration

---

### Phase 3: Doc Link Path Validity

**Check: markdown links in docs/ → paths resolve**

```bash
grep -roh '\[.*\](\./[^)]*\|/[^)]*\|[^)]*\.md)' /home/dalesser/.claude/sdd-harness/docs/ --include="*.md" | grep -oP '\(\K[^)]+' | sort -u
```

For each extracted path: resolve relative to the file's directory and check existence. Also check any absolute paths.

**Auto-fix (only when unambiguous):**
- If a referenced file was renamed and only one candidate matches by filename search, update the link. Log: `DOCS: updated stale link → [old] → [new]`

**Flag for human review:**
- Broken links where no matching file can be found by name search

---

### Phase 4: Summary Report

Write to `/home/dalesser/.claude/sdd-harness/docs/drift-review-report.md`:

```markdown
## Harness Drift Review — [YYYY-MM-DD]

### Auto-Fixed
- MEMORY: [list of changes]
- HOOKS: [list of changes]
- DOCS: [list of changes]

### Flagged for Human Review
- [item]: [why it needs a human decision]

### Clean (no drift found)
- [areas that passed with no issues]
```

If nothing was changed and nothing flagged, write: `All clean — no drift detected.`

---

## Key Principles

- **Auto-fix only what's unambiguous.** Missing files, dead hook paths, and unlisted memory entries have one right answer. Skip anything requiring judgment.
- **Never remove a hook script from disk.** Only remove the settings.json reference to a missing script.
- **Orphaned memory files get indexed, not deleted.** They may contain valuable content — surface them for human review via the auto-indexed entry.
- **Flag > guess for doc links.** If a broken link's target is ambiguous, report it rather than picking the wrong file.
