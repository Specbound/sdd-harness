---
name: proof-collaborative-review
description: Use during SDD approval-gate phases to publish a markdown artifact to a live collaborative Proof document, wait for human review/adjustment, retrieve the final version, then tear down the server.
---

# Proof Collaborative Review

Use this skill when an SDD phase gate requires human review of a markdown artifact (spec, design doc, PRD, task list) and stakeholders need to comment, suggest, or adjust it before Claude proceeds.

## When to Use

- SDD phase transitions requiring stakeholder sign-off
- Any artifact that benefits from inline comments rather than terminal approval
- Multi-stakeholder reviews where more than one person needs to weigh in
- Long documents where "approve / reject" is insufficient — reviewers need to edit inline

## Workflow

### Step 1: Ensure Proof is Installed (Once)

Check if Proof SDK is already set up:

```bash
if [ -d "$HOME/.claude/tools/proof-sdk/node_modules" ]; then
  echo "Proof already installed, skipping setup"
else
  mkdir -p "$HOME/.claude/tools"
  cd "$HOME/.claude/tools"
  git clone https://github.com/EveryInc/proof-sdk
  cd proof-sdk
  npm install
fi
```

`node_modules` presence is the install signal — never run `npm install` again after first setup.

### Step 2: Start the Server (If Not Running)

```bash
PROOF_URL="${PROOF_SERVER_URL:-http://localhost:4000}"

# Check if server is already up
if curl -sf "$PROOF_URL/health" > /dev/null 2>&1; then
  echo "Server already running"
else
  cd "$HOME/.claude/tools/proof-sdk"
  npm run serve &
  echo $! > /tmp/proof-server.pid

  # Wait for readiness (up to 15s)
  for i in $(seq 1 15); do
    sleep 1
    if curl -sf "$PROOF_URL/health" > /dev/null 2>&1; then
      echo "Server ready"
      break
    fi
  done
fi
```

### Step 3: Create the Document

```bash
RESPONSE=$(curl -sf -X POST "$PROOF_URL/documents" \
  -H "Content-Type: application/json" \
  -d "{\"content\": $(jq -Rs . < artifact.md), \"title\": \"Review: [artifact name]\"}")

SLUG=$(echo "$RESPONSE" | jq -r '.slug')
OWNER_SECRET=$(echo "$RESPONSE" | jq -r '.ownerSecret')
SHARE_URL="$PROOF_URL/doc/$SLUG"

echo "Review URL: $SHARE_URL"
```

Store `OWNER_SECRET` securely in memory — never log it. Use it for privileged operations (accepting suggestions, etc.).

### Step 4: Present the URL and Wait

Tell the user:

> **Review ready:** Open `[SHARE_URL]` in your browser. Edit, comment, or accept/reject suggestions directly in the document. When you're done, come back here and say "done" (or just reply).

Then wait for the user's signal before polling.

### Step 5: Poll for Events (Optional — for agent-driven workflows)

If running autonomously (no human in the loop to signal "done"):

```bash
LAST_EVENT_ID=0
while true; do
  EVENTS=$(curl -sf "$PROOF_URL/documents/$SLUG/events/pending?after=$LAST_EVENT_ID" \
    -H "Authorization: Bearer $OWNER_SECRET")

  COUNT=$(echo "$EVENTS" | jq '.events | length')
  if [ "$COUNT" -gt 0 ]; then
    LAST_EVENT_ID=$(echo "$EVENTS" | jq '.events[-1].id')
    # Process events: comment.add, suggestion.accept, rewrite
    echo "$EVENTS" | jq '.events[] | {type: .type, content: .content}'
  fi

  sleep 3
done
```

Use `Idempotency-Key` header on any mutation requests to make retries safe.

### Step 6: Retrieve Final State

```bash
FINAL=$(curl -sf "$PROOF_URL/documents/$SLUG/state" \
  -H "Authorization: Bearer $OWNER_SECRET")

FINAL_MARKDOWN=$(echo "$FINAL" | jq -r '.content')
echo "$FINAL_MARKDOWN" > final_artifact.md
```

This is the human-adjusted version. Use it as the approved artifact for the next SDD phase.

### Step 7: Tear Down the Server

```bash
if [ -f /tmp/proof-server.pid ]; then
  kill $(cat /tmp/proof-server.pid) 2>/dev/null
  rm /tmp/proof-server.pid
  echo "Proof server stopped"
fi
```

Only kill if Claude started it (PID file exists). If the server was already running before this session, leave it alone.

## Key API Reference

| Method | Endpoint | Purpose |
|--------|----------|---------|
| `POST /documents` | Create document | Body: `{content, title}` |
| `GET /documents/:slug/state` | Get current content | Returns `{content}` |
| `POST /documents/:slug/ops` | Submit operation | Body: `{type, ...}` |
| `GET /documents/:slug/events/pending?after=<id>` | Poll events | Returns `{events[]}` |
| `POST /documents/:slug/events/ack` | Acknowledge events | Body: `{eventIds[]}` |

## Operation Types

- `"comment.add"` — Human added a comment
- `"suggestion.accept"` — Human accepted a Claude suggestion
- `"rewrite"` — Human applied a content rewrite

## Configuration

Set `PROOF_SERVER_URL` env var to point at a remote Proof instance (default: `http://localhost:4000`).

## Principles

- Install once, run many times — always check `node_modules` before running `npm install`
- Only tear down what you started — check for `/tmp/proof-server.pid` before killing
- Never log `ownerSecret` — store in a variable, use inline, discard after the session
- The final state from Step 6 is the source of truth — not the original artifact
