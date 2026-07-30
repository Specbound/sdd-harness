#!/usr/bin/env python3
"""Validates review.json against the schema documented in
skills/gitnexus-pr-review/SKILL.md's "Structured Output Contract" section.

Usage: validate_review_json.py <path-to-review.json>
Exit 0 and silent on success. Exit 1 with one error per line on failure —
never partial-fixes the file, only reports what's wrong so the caller (a
skill invocation) can correct it and re-run.
"""
import json
import sys

SEVERITY_PREFIXES = ("CRITICAL:", "IMPORTANT:", "SUGGESTION:", "NIT:")
VERDICTS = ("APPROVE", "REJECT")
RECOMMENDATIONS = ("APPROVE", "REQUEST CHANGES", "NEEDS DISCUSSION")
SIDES = ("LEFT", "RIGHT")


def validate(data):
    errors = []

    if data.get("verdict") not in VERDICTS:
        errors.append(f"verdict must be one of {VERDICTS}, got {data.get('verdict')!r}")

    body = data.get("body")
    if not isinstance(body, dict):
        errors.append("body must be an object")
    else:
        if not isinstance(body.get("overview"), str) or not body.get("overview"):
            errors.append("body.overview must be a non-empty string")
        if not isinstance(body.get("concerns"), list):
            errors.append("body.concerns must be an array")
        if not isinstance(body.get("issue_count"), int):
            errors.append("body.issue_count must be an integer")
        if body.get("recommendation") not in RECOMMENDATIONS:
            errors.append(
                f"body.recommendation must be one of {RECOMMENDATIONS}, "
                f"got {body.get('recommendation')!r}"
            )

    comments = data.get("comments")
    if not isinstance(comments, list):
        errors.append("comments must be an array")
    else:
        for i, c in enumerate(comments):
            if not isinstance(c, dict):
                errors.append(f"comments[{i}] must be an object")
                continue
            if not isinstance(c.get("path"), str) or not c.get("path"):
                errors.append(f"comments[{i}].path must be a non-empty string")
            if not isinstance(c.get("line"), int):
                errors.append(f"comments[{i}].line must be an integer")
            if c.get("side") not in SIDES:
                errors.append(f"comments[{i}].side must be one of {SIDES}")
            if not isinstance(c.get("start_line"), int):
                errors.append(f"comments[{i}].start_line must be an integer")
            if c.get("start_side") not in SIDES:
                errors.append(f"comments[{i}].start_side must be one of {SIDES}")
            body_text = c.get("body")
            if not isinstance(body_text, str) or not body_text.startswith(SEVERITY_PREFIXES):
                errors.append(
                    f"comments[{i}].body must start with one of {SEVERITY_PREFIXES}"
                )

    return errors


def main():
    if len(sys.argv) != 2:
        print("Usage: validate_review_json.py <path-to-review.json>", file=sys.stderr)
        sys.exit(1)

    path = sys.argv[1]
    try:
        with open(path) as f:
            data = json.load(f)
    except (OSError, json.JSONDecodeError) as e:
        print(f"error: could not read/parse {path}: {e}", file=sys.stderr)
        sys.exit(1)

    errors = validate(data)
    if errors:
        for e in errors:
            print(f"error: {e}", file=sys.stderr)
        sys.exit(1)

    sys.exit(0)


if __name__ == "__main__":
    main()
