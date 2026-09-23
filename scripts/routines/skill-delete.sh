#!/bin/bash
# Single source of truth for deleting a skill — pairs with skill-write.sh.
#
# Why this exists: deleting only the installed copy (~/.claude/skills/<name>/)
# of a harness-shipped skill doesn't stick — update.sh's scheduled sync
# re-creates it from skills/<name>/ (harness source) on its next tick. Must
# remove both, or the delete silently reverts.
#
# Usage: skill-delete.sh <skill-name>
# Run from the harness repo root (same cwd harness-health-runner.sh uses).

set -u

SKILL_NAME="${1:-}"

if [ -z "$SKILL_NAME" ]; then
  echo "usage: skill-delete.sh <skill-name>" >&2
  exit 1
fi

SRC_DIR="skills/$SKILL_NAME"
INSTALLED_DIR="$HOME/.claude/skills/$SKILL_NAME"
BACKUP_DIR=".claude/memory/skill-repair-backups/$SKILL_NAME"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"

if [ ! -d "$SRC_DIR" ] && [ ! -d "$INSTALLED_DIR" ]; then
  echo "error: no skill directory found at $SRC_DIR or $INSTALLED_DIR" >&2
  exit 1
fi

mkdir -p "$BACKUP_DIR/$TIMESTAMP-deleted"

[ -d "$SRC_DIR" ] && cp -r "$SRC_DIR" "$BACKUP_DIR/$TIMESTAMP-deleted/source"
[ -d "$INSTALLED_DIR" ] && cp -r "$INSTALLED_DIR" "$BACKUP_DIR/$TIMESTAMP-deleted/installed"

rm -rf "$SRC_DIR" "$INSTALLED_DIR"

echo "deleted: $SRC_DIR + $INSTALLED_DIR"
echo "backup: $BACKUP_DIR/$TIMESTAMP-deleted/"
