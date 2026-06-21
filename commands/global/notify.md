---
description: Send a message to your configured Slack / Discord / Teams channels via the harness channel webhooks
allowed-tools: Bash
argument-hint: <message>  |  --only slack|discord|teams <message>
---

# Notify Channels

Send `$ARGUMENTS` as a notification to the channels configured in `~/.env.channels`.

## Input Parsing

- If `$ARGUMENTS` is empty, show usage and stop:
  ```
  Usage: /notify <message>
         /notify --only slack <message>      # one platform
         /notify --title "Deploy" <message>  # bold title line

  Configure webhooks in ~/.env.channels (see docs/integrations/channels/README.md).
  ```

## Workflow

1. Resolve the notify script. Prefer the repo-local copy, fall back to the harness source:
   - `.claude/scripts/integrations/channels/notify.py` (inside a harness-installed repo)
   - `~/.claude/sdd-harness/scripts/integrations/channels/notify.py` (harness source)

2. Run it, passing the arguments through verbatim:
   ```bash
   python3 <resolved-path> $ARGUMENTS
   ```

3. Report which platforms succeeded (✓) or failed (✗) from the script output.
   - If it prints "No channels configured", tell the user to create `~/.env.channels`
     from the template and re-run — do not treat it as an error.

## Notes

- The script is stdlib-only and reads webhook URLs from `~/.env.channels`.
- Unconfigured platforms are skipped silently; only configured ones receive the message.
- This is outbound only — the harness sends to channels, it does not listen on them.
