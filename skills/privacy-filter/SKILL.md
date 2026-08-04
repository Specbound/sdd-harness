---
name: privacy-filter
description: Use OPF (OpenAI Privacy Filter) to detect and redact PII from text, files, or codebases. Covers 8 categories including secrets/API keys, emails, phone numbers, account numbers, names, addresses, and dates. Use before commits, before sharing data, or during security reviews.
---

# Privacy Filter — PII Detection & Redaction

Use this skill when:
- Scanning files or outputs before committing or sharing externally
- Running a security review on logs, memory files, or generated data
- Preparing data for logging, AI ingestion, or third-party services
- `/kiro:ship` review — confirm no PII leaks into production artifacts

## Step 1: Verify OPF is installed

```bash
opf --help 2>/dev/null && echo "installed" || echo "not found"
```

If missing:
```bash
pip install opf
# or via uv (preferred in harness projects):
uv pip install opf
```

Model weights (~600MB) auto-download on first run to `~/.opf/privacy_filter`.

---

## Step 2: Scan

**A file:**
```bash
opf -f path/to/file.txt --format json
```

**A string:**
```bash
opf "Contact dan@example.com or call 555-1234" --format json
```

**Multiple files / a directory:**
```bash
find . -name "*.log" -o -name "*.md" | xargs opf -f --format json
```

**Staged git files (before commit):**
```bash
bash .claude/hooks/scan-pii.sh --staged
```

---

## Step 3: Interpret results

OPF detects 8 categories:

| Category | Examples | Severity |
|---|---|---|
| `secret` | API keys, tokens, passwords | 🔴 Block commit |
| `account_number` | Credit cards, bank accounts | 🔴 Block commit |
| `private_email` | Email addresses | 🟡 Review |
| `private_phone_number` | Phone numbers | 🟡 Review |
| `private_person` | Personal names | 🟡 Review |
| `private_address` | Street addresses | 🟡 Review |
| `private_date` | Dates of birth, event dates | 🟢 Low risk |
| `private_url` | URLs with personal paths | 🟢 Low risk |

**JSON output structure:**
```json
{
  "summary": { "num_detected_spans": 2, "labels": { "secret": 1, "private_email": 1 } },
  "redacted_text": "Contact <private_email> or use token <secret>",
  "detected_spans": [
    { "label": "private_email", "start": 8, "end": 24, "text": "dan@example.com" }
  ]
}
```

---

## Step 4: Redact

**Plain redacted text:**
```bash
opf -f input.txt --output-mode redacted > input_clean.txt
```

**Typed redaction (preserve category labels):**
```bash
opf -f input.txt --output-mode typed
# → Contact <private_email> or call <private_phone_number>
```

---

## Integration checkpoints

| Harness touchpoint | Action |
|---|---|
| Before `git commit` | `bash .claude/hooks/scan-pii.sh --staged` |
| After writing logs/memory | `opf -f .claude/memory/ --format json` |
| During `/kiro:ship` | Run scan-pii.sh on all changed files |
| Before pasting data into prompts | `opf "your text here"` |
| Before exporting to external service | `opf -f data.json --output-mode redacted > data_safe.json` |

---

## Python API (for scripts or agents)

```python
from opf import redact, OPF

# One-liner
clean = redact("dan@example.com called from 555-1234")

# Full control with span details
model = OPF(output_mode="typed", decode_mode="viterbi")
result = model.redact("text here")
print(result.redacted_text)
print(result.detected_spans)   # list of spans with label, start, end, text
print(result.summary)          # category counts
```

---

## Limitations

OPF is a **detection aid, not an anonymization guarantee**:
- Accuracy degrades on non-English text
- May miss uncommon naming patterns or out-of-distribution formats
- Placeholder `<REDACTED>` is not format-preserving (a redacted email is not a valid email)
- High-sensitivity use cases (medical, legal, financial, government) need additional human review

See [docs/privacy-filter/README.md](~/.claude/sdd-harness/docs/privacy-filter/README.md) for full setup and troubleshooting.
