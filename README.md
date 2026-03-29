# SDD Harness

Spec-Driven Development harness for Claude Code — portable across projects.

## Install into a new project

```bash
~/.claude/sdd-harness/install.sh [/path/to/project]
# defaults to current directory
```

## Update all registered projects

```bash
~/.claude/sdd-harness/update.sh
```

## Update a specific project

```bash
~/.claude/sdd-harness/update.sh /path/to/project
```

## Add a GitHub remote (optional, for cross-machine sync)

```bash
cd ~/.claude/sdd-harness
git remote add origin git@github.com:<you>/sdd-harness.git
git push -u origin main
```

## Registered projects

Listed in `projects.txt` — one absolute path per line.
