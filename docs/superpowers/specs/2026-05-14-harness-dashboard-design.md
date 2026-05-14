# Harness Local Dashboard

**Date:** 2026-05-14  
**Status:** Implemented  
**Output:** `scripts/dashboard.py` → `.dashboard/index.html`

---

## Context

The SDD harness accumulates rich per-repo telemetry — trust scores, session quality signals, hook activity, CCR routine history, memory changes — but all of it is buried in append-only files and markdown documents with no visual surface. This spec defines a local browser-based dashboard that gives a glanceable, per-repo view of harness health.

**Outcome:** A single Python generator script (`scripts/dashboard.py`) that reads all harness data files, renders them into a fully self-contained HTML file, and opens it in the default browser. No server, no dependencies, no pip install.

---

## Design Decisions

| Decision | Choice |
|---|---|
| Layout | Fixed left sidebar (200px), content panel flex-1 |
| Theme | Catppuccin Mocha (deep purple/teal dark theme) |
| Trust battery | Arc gauge — semicircular arc with nubs at both ends |
| GitNexus panel | Hybrid — stats strip + iframe embed of localhost:4567 |
| CCR panel | Cards with alert banners — one card per routine |
| Launch | Static generator — `python3 scripts/dashboard.py` |

**Sections (8, in sidebar order):**
1. ⚡ Trust Battery
2. 🕸 GitNexus
3. 🪝 Hooks History
4. 📅 CCR Routines
5. 🧠 Memory Changes
6. 🎯 Skill Changes
7. 📊 Session Quality
8. 🔧 Maintenance Status

---

## Architecture

### Generator Script: `scripts/dashboard.py`

Single Python 3 file, stdlib only. Run with:
```bash
python3 ~/.claude/sdd-harness/scripts/dashboard.py [--repo /path/to/repo] [--no-open]
```

**Steps:**
1. Discover repos from `projects.txt` at harness root
2. Read + parse all data sources per repo into a single JSON blob
3. Pre-render all sections for all repos into HTML strings
4. Assemble HTML template + JSON data blob → `.dashboard/index.html`
5. Open in browser (WSL-aware: `wslview` / `explorer.exe` / `xdg-open`)

Output file `.dashboard/` is gitignored.

### Multi-repo Architecture

All sections are pre-rendered server-side for all repos. A `const SD` JSON blob embeds the pre-rendered HTML strings, keyed by `repo_name → section_key → html`. JavaScript only shows/hides — no re-rendering on repo switch.

---

## Visual Design

**Catppuccin Mocha palette (inlined as CSS vars):**
```css
--base:    #1e1e2e   /* sidebar bg */
--mantle:  #181825   /* content bg */
--surface: #313244   /* cards, borders */
--text:    #cdd6f4
--subtext: #a6adc8
--overlay: #6c7086
--green:   #a6e3a1   /* healthy */
--red:     #f38ba8   /* error/missed */
--yellow:  #f9e2af   /* warning */
--mauve:   #cba6f7   /* accent/links */
--blue:    #89b4fa   /* info */
--teal:    #94e2d5   /* secondary */
```

**Layout:**
```
[sidebar 200px fixed] | [content panel flex-1]
```

**Sidebar contents:**
- App header "⬡ SDD Harness"
- `<select>` repo dropdown populated from `projects.txt`
- Section nav list (8 items with emoji icons)
- Active section: left border + background tint

**Charts:** Pure inline SVG — no external libraries.

---

## Section Specs

### 1. ⚡ Trust Battery

**Data:** `<repo>/.claude/memory/trust-score.jsonl`, `observations.md`

Each line of trust-score.jsonl: `{"ts": "...", "delta_raw": N, "delta_applied": N, "score": N, "summary": "..."}`

**Layout:**
- Arc gauge SVG (180° sweep, stroke-dasharray fill). Green ≥ 70%, Yellow 40–69%, Red < 40%.
- Score number centered inside arc; today's delta pill (▲/▼) below
- 30-day bar chart (SVG), one bar per day, coloured by delta sign
- Today's charges/drains from latest `[judge]` observation

---

### 2. 🕸 GitNexus

**Data:** `gitnexus status` CLI (optional), `.gitnexus/` mtime, iframe to `localhost:4567`

**Layout:**
- Stats strip (4 cells): symbols | clusters | HIGH risks | indexed N ago
  - Yellow if `.gitnexus/` mtime > 24h; red if > 72h
- Iframe (height 420px) → `http://localhost:4567`
  - On load failure (3.5s timeout + onerror): fallback card with "gitnexus serve" copy button

---

### 3. 🪝 Hooks History

**Data:** `<repo>/.claude/hooks/*.sh`, `observations.md`

**Layout:**
- Table: Hook name | Event type | Last activity | Status badge (Active/Inactive)
- Last activity = most recent `observations.md` line mentioning the hook stem
- "no recorded activity" if no observations match

---

### 4. 📅 CCR Routines

**Data:** `docs/ccr-routines/README.md`, `git log` on output files

**Missed-run detection:**
```python
overdue = (now - last_run).total_seconds() - interval_seconds
if overdue > interval_seconds * 0.25:  # MISSED
```
- Last run: `git log -1 --format=%cI -- <output_file>`
- CCR README parsed via regex for routine name, trigger ID, cron, output file

**Each card shows:** name, trigger ID, schedule (human-readable), last ran, next expected, output link, status badge.

**MISSED extras:** red border, "N days overdue", inline debug checklist:
- GitHub App permissions revoked
- Repo renamed/moved (trigger IDs are path-bound)
- Trigger deleted (re-run `/schedule`)
- Output file path changed

**Cron parser (stdlib):** handles `0 H * * *` (daily) and `0 H * * D` (weekly) patterns only.

---

### 5. 🧠 Memory Changes

**Data:** `git log` on `~/.claude/projects/*/memory/` and `<repo>/.claude/memory/`

**Layout:**
- Filter chips: All | hot-memory | observations | meta/patterns | project-memory
- Chronological feed, newest first, max 50 entries
- Each entry: filename, relative timestamp, commit summary
- Click to expand `git show --stat`

---

### 6. 🎯 Skill Changes

**Data:** `docs/skill-curation-report.md`, git log on that file

**Layout:**
- "Last audit: N days ago" header
- Rendered markdown content (inline converter: headings, bold, lists, code, tables)
- "Next audit expected in N days" footer
- Fallback if file missing: instruction to run weekly CCR routine

---

### 7. 📊 Session Quality

**Data:** `observations.md` filtered for `[session-quality]`, `[keep-rate]`, `[memory-gap]` tags

**Layout:**
- 3 summary stats: avg session score | avg keep-rate % | total memory gaps (last 30d)
- 30-day chart (SVG): session score line + keep-rate line + memory-gap bars
- Last 5 `[memory-gap]` entries with suggested topics

**Regex patterns:**
```python
score_re = re.compile(r'\[session-quality\].*Score=(\d+)/5')
keep_re  = re.compile(r'\[keep-rate\].*?(\d+)%')
gap_re   = re.compile(r'\[memory-gap\].*?(\d+) .* topics?: (.+)')
```

---

### 8. 🔧 Maintenance Status

**Data:** `logs/orchestrator.log`, `<repo>/.claude/memory/.last-routine-run`

**Layout:**
- Per-repo status table: Repo | Last run | Duration | Exit code | Status
  - Green "OK" for exit 0; red "FAILED" for non-zero
  - Yellow "OVERDUE" if `.last-routine-run` > 25 hours old
- Global log tail: last 10 lines from `orchestrator.log` (monospace scrollable)
- "Next scheduled: 18:00 today / tomorrow"

**Log format:** `2026-05-13T13:18:53+03:00 /path/to/repo exit=0 duration=338s`

---

## File Changes

| File | Action |
|---|---|
| `scripts/dashboard.py` | New — stdlib-only generator, ~580 LOC |
| `.gitignore` | Added `.dashboard/` |
| `docs/superpowers/specs/2026-05-14-harness-dashboard-design.md` | This file |

---

## Running the Dashboard

```bash
# Generate and open in browser
python3 ~/.claude/sdd-harness/scripts/dashboard.py

# Generate only, no browser
python3 ~/.claude/sdd-harness/scripts/dashboard.py --no-open

# Pre-select a repo
python3 ~/.claude/sdd-harness/scripts/dashboard.py --repo /mnt/c/dev/aiq-zora-ai-engine
```
