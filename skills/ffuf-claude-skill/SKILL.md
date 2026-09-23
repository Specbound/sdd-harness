---
name: ffuf-claude-skill
description: Use during authorized web penetration tests or bug-bounty engagements to fuzz HTTP endpoints, directories, parameters, or headers. Covers FUZZ keyword placement, wordlist selection, false-positive filtering, and safe rate-limiting.
source: "https://github.com/jthack/ffuf_claude_skill"
risk: safe
---

# Ffuf Claude Skill

## When to Use

Trigger when fuzzing is needed for:
- Directory and file discovery on a target web server
- Parameter name or value enumeration
- Virtual-host discovery
- Brute-forcing authentication or API endpoints

**Authorization required**: only run against systems you own or have explicit written permission to test.

## Core Syntax

```bash
# Directory discovery
ffuf -u https://TARGET/FUZZ -w /path/to/wordlist.txt

# GET parameter fuzzing
ffuf -u https://TARGET/page?FUZZ=value -w params.txt

# POST body fuzzing
ffuf -u https://TARGET/login -X POST \
     -d "username=FUZZ&password=test" \
     -H "Content-Type: application/x-www-form-urlencoded" \
     -w usernames.txt
```

## Filtering False Positives

| Flag | Filters by | Example |
|------|-----------|---------|
| `-fc` | HTTP status code | `-fc 404,403` |
| `-fs` | Response size (bytes) | `-fs 1234` |
| `-fw` | Word count | `-fw 50` |
| `-fl` | Line count | `-fl 10` |
| `-fr` | Regex match in body | `-fr "Not Found"` |

## Rate Limiting and Safety

```bash
# Limit to 50 req/s, randomize delay 100–500ms
ffuf -u https://TARGET/FUZZ -w wordlist.txt -rate 50 -p 0.1-0.5

# Use a proxy for traffic review
ffuf -u https://TARGET/FUZZ -w wordlist.txt -x http://127.0.0.1:8080
```

## Common Wordlists

- `/usr/share/wordlists/dirb/common.txt` — general directory enumeration
- `SecLists/Discovery/Web-Content/raft-medium-directories.txt` — broader coverage
- `SecLists/Fuzzing/LFI/LFI-Jhaddix.txt` — local file inclusion

## Anti-Patterns

- Running without filters — floods output with false positives and can crash the target
- Omitting `-rate` on production systems — unlimited concurrency triggers WAF blocks or service disruption
- Using against systems without written authorization
