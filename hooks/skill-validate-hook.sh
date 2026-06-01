#!/bin/bash
# Skill quality gate: validates frontmatter before writing skill files.
# Hard-blocks (exit 2) on missing/mismatched name or description.
# Warns (exit 0) on vague description phrasing.

set -euo pipefail

EVENT=$(cat)

TMPFILE=$(mktemp /tmp/skill-validate-XXXXXX.py)
trap 'rm -f "$TMPFILE"' EXIT

cat > "$TMPFILE" << 'PYTHON_END'
import json, sys, re, pathlib

try:
    e = json.loads(sys.stdin.read())
except Exception:
    sys.exit(0)

# Only validate Write operations
if e.get('tool_name', '') != 'Write':
    sys.exit(0)

inp = e.get('tool_input', {})
file_path = inp.get('file_path', inp.get('path', ''))
content = inp.get('content', '')

if not file_path or not content:
    sys.exit(0)

skills_dir = pathlib.Path.home() / '.claude' / 'skills'
p = pathlib.Path(file_path)

try:
    rel = p.relative_to(skills_dir)
    parts = rel.parts
except ValueError:
    sys.exit(0)  # Not in skills dir

# Match: ~/.claude/skills/<name>/SKILL.md  or  ~/.claude/skills/<name> (flat)
if len(parts) == 2 and parts[1] == 'SKILL.md':
    expected_slug = parts[0]
elif len(parts) == 1:
    expected_slug = parts[0]
else:
    sys.exit(0)

errors = []
warnings = []

if not content.strip().startswith('---'):
    errors.append('Missing YAML frontmatter — file must start with ---')
else:
    fm_parts = content.split('---', 2)
    if len(fm_parts) < 3:
        errors.append('Malformed frontmatter — missing closing ---')
    else:
        fm = fm_parts[1]

        # Validate name
        name_m = re.search(r'^name:\s*(.+)$', fm, re.MULTILINE)
        if not name_m:
            errors.append("Missing 'name:' field in frontmatter")
        else:
            name_val = name_m.group(1).strip().strip('"\'')
            if not re.match(r'^[a-z][a-z0-9-]*$', name_val):
                errors.append(f"name '{name_val}' must be kebab-case (lowercase letters and hyphens only)")
            elif name_val != expected_slug:
                errors.append(f"name '{name_val}' does not match file path slug '{expected_slug}'")

        # Validate description (single-line or block scalar >)
        desc_val = None
        inline_m = re.search(r'^description:\s*(.+)$', fm, re.MULTILINE)
        block_m = re.search(r'^description:\s*>\n((?:[ \t]+.+\n?)+)', fm, re.MULTILINE)

        if inline_m:
            desc_val = inline_m.group(1).strip().strip('"\'')
        elif block_m:
            desc_val = ' '.join(block_m.group(1).split()).strip()

        if desc_val is None:
            errors.append("Missing 'description:' field in frontmatter")
        elif len(desc_val) < 25:
            errors.append(
                f"description too short ({len(desc_val)} chars) — "
                "include trigger phrases so Claude knows when to activate this skill"
            )
        else:
            vague_starters = ['a skill that', 'this skill', 'skill for', 'use this skill', 'provides']
            for v in vague_starters:
                if desc_val.lower().startswith(v):
                    warnings.append(
                        f'description starts with "{v}" — '
                        'lead with trigger phrases or concrete use cases instead'
                    )
                    break

if not errors and not warnings:
    sys.exit(0)

if errors:
    print('╔══ Skill Quality Gate — BLOCKED ══════════════════════════════════╗')
    print('║  Fix these errors before writing the skill file.                ║')
    print('╚══════════════════════════════════════════════════════════════════╝')
    print()
    print('  Errors (must fix):')
    for err in errors:
        print(f'    ✗  {err}')
    if warnings:
        print()
        print('  Warnings (should also fix):')
        for w in warnings:
            print(f'    △  {w}')
    print()
    print('  Required frontmatter format:')
    print('    ---')
    print(f'    name: {expected_slug}')
    print('    description: <30+ chars — start with WHEN to use, not WHAT it is>')
    print('    ---')
    print()
    print('  Do NOT proceed with this write. Fix the content and retry.')
    sys.exit(2)
else:
    print('╔══ Skill Quality Gate — WARNING ══════════════════════════════════╗')
    print('╚══════════════════════════════════════════════════════════════════╝')
    for w in warnings:
        print(f'  △  {w}')
    print()
    print('  Proceed is allowed, but vague descriptions reduce trigger accuracy.')
    sys.exit(0)
PYTHON_END

echo "$EVENT" | python3 "$TMPFILE"
