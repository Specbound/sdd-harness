---
name: varlock-claude-skill
description: Use whenever a Claude session needs to read, check, or debug environment variables / secrets (.env files, API keys, DB URLs) — wraps the Varlock CLI so secret values are validated and injected without ever appearing in terminal output, Claude's context, logs, or git history.
source: "https://github.com/wrsmith108/varlock-claude-skill"
risk: safe
---

# Varlock Claude Skill

## Why This Skill

Secrets leak into Claude sessions through ordinary-looking commands: `cat .env`, `echo $SECRET`, `printenv | grep API`. Each of those puts the raw value in terminal output, which becomes part of Claude's context, session transcripts, and sometimes logs or pasted diffs. [Varlock](https://varlock.dev) (by [DMNO](https://dmno.dev)) validates and injects secrets without ever printing them.

## Installation

Install the Varlock CLI (one-time, per machine):

```bash
curl -sSfL https://varlock.dev/install.sh | sh -s -- --force-no-brew
export PATH="$HOME/.varlock/bin:$PATH"
```

## Core Rule

**Never let a secret value enter the conversation.** Use the safe alternative on the right, never the command on the left:

| Never Do | Safe Alternative |
|----------|------------------|
| `cat .env` | `cat .env.schema` |
| `echo $SECRET` | `varlock load` |
| `printenv \| grep API` | `varlock load \| grep API` |

`varlock load` prints variable names with values masked — enough to confirm a secret is set and well-formed, without exposing it.

## Quick Reference

```bash
varlock load                 # validate all secrets, masked output
varlock load --quiet         # validate with no output on success
varlock run -- npm start     # run a command with secrets injected into its env only
cat .env.schema              # inspect expected variables and types — always safe, no values
```

## Schema File

A project defines its expected variables in `.env.schema` (committed; unlike `.env` it holds no values):

```bash
# Global defaults
# @defaultSensitive=true @defaultRequired=infer

# Public config — shown in output since it isn't a secret
# @type=enum(development,staging,production) @sensitive=false
NODE_ENV=development

# Sensitive secret — masked in all output, must start with sk_
# @type=string(startsWith=sk_) @required @sensitive
STRIPE_SECRET_KEY=

# Sensitive secret — must be a well-formed URL
# @type=url @required @sensitive
DATABASE_URL=
```

| Annotation | Effect |
|------------|--------|
| `@sensitive` | Value masked in all output (default) |
| `@sensitive=false` | Value shown — use only for genuinely public config |
| `@required` | Validation fails if missing |
| `@type=string(startsWith=X)` / `@type=url` / `@type=enum(...)` | Format/prefix validation |

## Handling User Requests

| User asks | Do this |
|-----------|---------|
| "Check if API key is set" | `varlock load \| grep API_KEY` — confirms presence/shape without revealing the value |
| "Debug authentication" | `varlock load` — validates everything at once |
| "Show me .env" | Show `.env.schema` instead; explain why the raw file isn't shown |
| "Update a secret" | Decline to read or write the value yourself; ask the user to set it directly (their shell, secrets manager, or `.env` file) |

## Install (for a new project)

```bash
mkdir -p ~/.claude/skills/varlock && curl -sSL https://raw.githubusercontent.com/wrsmith108/varlock-claude-skill/main/skills/varlock/SKILL.md -o ~/.claude/skills/varlock/SKILL.md
```
