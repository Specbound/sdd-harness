#!/usr/bin/env python3
"""
Re-explanation detector for the SDD harness.

Scans user turns for phrases indicating the user had to re-explain context
the agent should already have remembered. Emits memory-gap candidates as
JSON for consumption by session-judge and /kiro:reflect.

Rationale: every re-explained preference is a memory the agent should have
saved but didn't. Catching these automatically turns drift into a signal.

Inputs (one of):
    --file PATH            Scan a plain-text file
    --stdin                Scan stdin
    --auto-transcript      Find most recent Claude Code session transcript
                           for the current working directory and scan its
                           user messages.

Outputs: JSON array on stdout. Each hit:
    {
      "phrase": "I already told you",
      "context": "... 100-char window around the hit ...",
      "suggested_memory_topic": "short topic guess"
    }

Pass --emit observation to instead write a single [memory-gap] line
suitable for direct appending to observations.md.

Exit codes: 0 = ran (regardless of hits); 2 = usage error; 3 = no input found.
"""

import argparse
import json
import os
import re
import sys
from datetime import date
from pathlib import Path


RE_EXPLANATION_PATTERNS = [
    r"\bI (?:already|just) (?:told|said|mentioned)\b",
    r"\bas I (?:said|mentioned|told you)\b",
    r"\bwe (?:already )?(?:discussed|covered) this\b",
    r"\bremember(?: that)? I (?:said|told you)\b",
    r"\bstop (?:asking|doing)\b",
    r"\blike I (?:said|told you)\b",
    r"\bhow many times\b",
    r"\bI(?:'ve| have) (?:told|said) (?:you|this)\b",
    r"\b(?:again|repeatedly)[,:]? (?:I|we) (?:told|said|explained)\b",
]

COMPILED = [re.compile(p, re.IGNORECASE) for p in RE_EXPLANATION_PATTERNS]

CONTEXT_CHARS = 120
TOPIC_STOPWORDS = {
    "the", "a", "an", "to", "of", "in", "on", "for", "with", "that", "this",
    "is", "was", "it", "and", "or", "but", "as", "at", "by", "be", "been",
    "i", "you", "we", "they", "he", "she", "your", "my", "our", "their",
    "already", "told", "said", "mentioned", "discussed", "covered",
    "remember", "stop", "asking", "doing", "like", "how", "many", "times",
    "again", "repeatedly", "explained", "have",
}


def extract_topic(context: str) -> str:
    """Extract a short noun-phrase-ish topic hint from the hit context."""
    tokens = re.findall(r"[A-Za-z][A-Za-z0-9_\-]{2,}", context)
    candidates = [
        t for t in tokens
        if t.lower() not in TOPIC_STOPWORDS and not t.isupper()
    ]
    # Prefer tokens with uppercase (likely proper nouns / identifiers) or
    # tokens >= 5 chars that aren't stopwords.
    scored = []
    for t in candidates:
        score = 0
        if any(c.isupper() for c in t[1:]):
            score += 2
        if len(t) >= 5:
            score += 1
        if "_" in t or "-" in t:
            score += 1
        scored.append((score, t))
    scored.sort(reverse=True)
    top = [t for _, t in scored[:3]]
    return " ".join(top) if top else "(unclear)"


def scan(text: str) -> list[dict]:
    hits: list[dict] = []
    seen_spans: list[tuple[int, int]] = []
    for pattern in COMPILED:
        for m in pattern.finditer(text):
            start, end = m.span()
            # Dedupe only *overlapping* spans from other patterns matching the
            # same phrase; distinct phrases near each other are separate hits.
            if any(not (end <= s or start >= e) for s, e in seen_spans):
                continue
            seen_spans.append((start, end))
            ctx_start = max(0, start - CONTEXT_CHARS)
            ctx_end = min(len(text), end + CONTEXT_CHARS)
            context = text[ctx_start:ctx_end].replace("\n", " ").strip()
            hits.append({
                "phrase": m.group(0),
                "context": context,
                "suggested_memory_topic": extract_topic(context),
            })
    return hits


def find_latest_transcript() -> Path | None:
    """Find the most recent Claude Code session transcript for cwd."""
    base = Path.home() / ".claude" / "projects"
    if not base.is_dir():
        return None
    cwd = Path.cwd().resolve()
    # Claude Code encodes the cwd as path with slashes → dashes, leading dash.
    encoded = "-" + str(cwd).replace("/", "-")
    project_dir = base / encoded
    if not project_dir.is_dir():
        # Fall back: pick the most recent project dir overall.
        candidates = [p for p in base.iterdir() if p.is_dir()]
        if not candidates:
            return None
        project_dir = max(candidates, key=lambda p: p.stat().st_mtime)
    transcripts = list(project_dir.glob("*.jsonl"))
    if not transcripts:
        return None
    return max(transcripts, key=lambda p: p.stat().st_mtime)


def read_user_turns_from_jsonl(path: Path) -> str:
    """Extract user message text from a Claude Code JSONL transcript."""
    chunks: list[str] = []
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if not line.strip():
            continue
        try:
            rec = json.loads(line)
        except json.JSONDecodeError:
            continue
        # Only scan user turns — we're looking for what the human typed.
        role = rec.get("role") or rec.get("type")
        if role != "user":
            continue
        content = rec.get("content") or rec.get("message", {}).get("content")
        if isinstance(content, str):
            chunks.append(content)
        elif isinstance(content, list):
            for block in content:
                if isinstance(block, dict) and block.get("type") == "text":
                    chunks.append(block.get("text", ""))
    return "\n".join(chunks)


def _load_text(args) -> tuple[str | None, int]:
    """Resolve input source to text. Returns (text, exit_code). text=None means
    no input was available (caller should emit [] and exit 0)."""
    if args.stdin:
        return sys.stdin.read(), 0
    if args.file:
        if not args.file.is_file():
            print(f"ERROR: file not found: {args.file}", file=sys.stderr)
            return None, 3
        return args.file.read_text(encoding="utf-8", errors="replace"), 0
    path = find_latest_transcript()
    if path is None:
        return None, 0
    return read_user_turns_from_jsonl(path), 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    src = ap.add_mutually_exclusive_group(required=True)
    src.add_argument("--file", type=Path, help="Scan a plain-text file")
    src.add_argument("--stdin", action="store_true", help="Scan stdin")
    src.add_argument(
        "--auto-transcript",
        action="store_true",
        help="Scan most recent Claude Code transcript for cwd",
    )
    ap.add_argument(
        "--emit",
        choices=["json", "observation"],
        default="json",
        help="Output format. 'observation' writes a single [memory-gap] line to stdout suitable for appending to observations.md.",
    )
    args = ap.parse_args()

    text, code = _load_text(args)
    if text is None:
        if args.emit == "observation":
            return code
        print("[]")
        return code
    hits = scan(text)

    if args.emit == "observation":
        if not hits:
            return 0
        topics = ", ".join(
            dict.fromkeys(h["suggested_memory_topic"] for h in hits)
        )
        # Cap at ~80 chars to keep observations.md readable
        if len(topics) > 80:
            topics = topics[:77] + "..."
        print(
            f"- {date.today().isoformat()} [memory-gap]: "
            f"{len(hits)} re-explanation hit(s) — topics: {topics}"
        )
    else:
        print(json.dumps(hits, indent=2))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(130)
