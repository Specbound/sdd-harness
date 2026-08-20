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

## Path Setup

Resolve paths at runtime — never hardcode a home directory or a project slug.
Claude derives the memory-dir slug from the repo path by replacing `/` with `-`.

```bash
HARNESS="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel)}"
SLUG="$(printf '%s' "$HARNESS" | sed 's|/|-|g')"
MEM_DIR="$HOME/.claude/projects/$SLUG/memory"
MEMORY="$MEM_DIR/MEMORY.md"
```

Portability notes (these have bitten this skill before):
- Use `grep -oE`, not `grep -oP` — BSD/macOS grep has no `-P`.
- Do not use `python3 -c` — inline interpreter execution is blocked by harness
  policy. Use `jq` for JSON.

---

## Workflow

### Phase 1: Memory Index Integrity

**Check: MEMORY.md entries → files exist**

```bash
grep -oE '\]\([^)]+\.md\)' "$MEMORY" | tr -d ']()'
```

For each file reference extracted, check it exists in `$MEM_DIR`. Collect missing entries.

**Check: orphaned memory files → listed in MEMORY.md**

```bash
ls "$MEM_DIR"/*.md | xargs -n1 basename | grep -v '^MEMORY.md$'
```

For each `.md` file in the memory directory, check it appears in MEMORY.md. Collect unlisted files.

**Auto-fixes:**
- **Missing entry file**: Remove the line from MEMORY.md. Log: `MEMORY: removed stale entry → [filename]`
- **Orphaned file**: Add a one-line entry to MEMORY.md: `- [slug](filename.md) ⚠️ auto-indexed, description needed`. Log: `MEMORY: added missing index entry → [filename]`

---

### Phase 2: Hook Script Integrity

**Check: hooks in settings.json → scripts exist on disk**

Read hook commands from all three settings files (project, project-local, global):

```bash
for f in "$HARNESS/.claude/settings.json" \
         "$HARNESS/.claude/settings.local.json" \
         "$HOME/.claude/settings.json"; do
  [ -f "$f" ] || continue
  echo "=== $f"
  jq -r '.hooks // {} | to_entries[] | .value[] | (.hooks // [.])[] | .command' "$f" \
    | grep -oE '[^ "]+\.(sh|js|py)'
done
```

For each command, extract file path references and check they exist on disk.
Expand `${CLAUDE_PROJECT_DIR:-.}` to `$HARNESS` before testing.

**Check: scripts in hooks/ → referenced in settings.json**

```bash
ls "$HARNESS/.claude/hooks"/*.sh | xargs -n1 basename
```

For each script, check it appears in at least one settings.json command.

**Check: source tree vs installed tree in sync**

`hooks/claude/` is the committed source; `.claude/hooks/` is the installed copy.
They should be identical.

```bash
diff -rq "$HARNESS/hooks/claude" "$HARNESS/.claude/hooks"
```

**Auto-fixes:**
- **Hook pointing to a missing script**: Remove the hook entry from settings.json. Log: `HOOKS: removed dead hook → [script path]`

**Flag for human review (do not auto-fix):**
- Scripts on disk not referenced in settings.json — may be intentionally dormant pending registration
- Divergence between `hooks/claude/` and `.claude/hooks/` — direction of sync is a judgment call

---

### Phase 3: Doc Link Path Validity

**Check: markdown links in docs/ → paths resolve**

Resolve each link relative to the directory of the file that contains it, not to `docs/`.

```bash
cd "$HARNESS/docs" && grep -rnoE '\]\([^)#][^)]*\)' --include='*.md' . \
  | sed -E 's/\]\(/\t/; s/\)$//' \
  | grep -vE $'\t(https?|mailto):' \
  | while IFS=$'\t' read -r loc link; do
      src="${loc%%:*}"; d=$(dirname "$src"); t="${link%%#*}"
      case "$t" in "~"*) t="$HOME${t#\~}";; esac
      case "$t" in /*) p="$t";; *) p="$d/$t";; esac
      [ -e "$p" ] && echo "OK   $src -> $link" || echo "BROKEN  $src -> $link"
    done
```

**Auto-fix (only when unambiguous):**
- If a referenced file was renamed and only one candidate matches by filename search, update the link. Log: `DOCS: updated stale link → [old] → [new]`

**Flag for human review:**
- Broken links where no matching file can be found by name search

---

### Phase 4: Summary Report

Write to `$SDD_HARNESS/reports/drift-review-report.md`:

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

If nothing changed and nothing was flagged, write: `All clean — no drift detected.`

---

## Key Principles

- **Auto-fix only what's unambiguous.** Missing files, dead hook paths, and unlisted memory entries have one right answer. Skip anything requiring judgment.
- **Never remove a hook script from disk.** Only remove the settings.json reference to a missing script.
- **Orphaned memory files get indexed, not deleted.** They may contain valuable content — surface for human review via an auto-indexed entry.
- **Never guess at doc links.** If a broken link's target is ambiguous, report it rather than picking the wrong file.
- **Never hardcode absolute paths in this skill.** Derive them (see Path Setup) — hardcoded paths are themselves drift.
