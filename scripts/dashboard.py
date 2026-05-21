#!/usr/bin/env python3
"""SDD Harness Dashboard — starts a local server and opens the dashboard in the browser.

Usage:
    python3 ~/.claude/sdd-harness/scripts/dashboard.py [--repo /path/to/repo] [--no-open]
    python3 ~/.claude/sdd-harness/scripts/dashboard.py --static   # write file only, no server
"""

import argparse
import html
import json
import math
import os
import re
import subprocess
import sys
import threading
from datetime import datetime, timezone, timedelta
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlencode, urlparse
from urllib.request import urlopen, Request as UrlRequest
from urllib.error import URLError

# ── Constants ─────────────────────────────────────────────────────────────────

HARNESS_DIR    = Path(__file__).resolve().parent.parent
PROJECTS_FILE  = HARNESS_DIR / "projects.txt"
DASHBOARD_DIR  = HARNESS_DIR / ".dashboard"
OUTPUT_FILE    = DASHBOARD_DIR / "index.html"
ORCH_LOG       = HARNESS_DIR / "logs" / "orchestrator.log"
COMPANION_PORT = 4569
WORKSHOP_PORT  = 5899

SECTION_DEFS = [
    ("trust_battery",      "⚡", "Trust Battery"),
    ("gitnexus",           "🕸", "GitNexus"),
    ("workshop",           "🔬", "Workshop"),
    ("hooks_history",      "🪝", "Hooks History"),
    ("ccr_routines",       "📅", "CCR Routines"),
    ("memory_changes",     "🧠", "Memory Changes"),
    ("skill_changes",      "🎯", "Skill Changes"),
    ("session_quality",    "📊", "Session Quality"),
    ("maintenance_status", "🔧", "Maintenance Status"),
    ("automation_audit",   "🤖", "Automation Audit"),
]

NOW = datetime.now(timezone.utc)

HOOK_DESCRIPTIONS = {
    "impeccable-detect":      "Scores in-session behavior (0–5) after each tool use; writes session-quality observations",
    "revert-detect":          "Detects git reverts; logs them as trust-drain events in observations",
    "session-start":          "Runs on session start: checks for missed maintenance, loads context",
    "stop":                   "Post-session wrap-up: keep-rate check, memory housekeeping",
    "pre-tool-use-gitnexus":  "Ensures GitNexus graph is indexed before code-analysis tool calls",
    "memory-discipline":      "Gates memory writes: enforces quality/length rules before saving",
    "hook-added-notify":      "Notifies when a new hook file is added to the repo",
    "ccr-routine-added":      "Notifies when a new CCR schedule trigger is created",
    "gbrain-agent-spawn":     "Intercepts agent spawns to inject memory-first lookup pattern",
    "gbrain-memory-write":    "Validates memory writes against GBrain quality patterns",
    "gbrain-external":        "Routes external fetches through GBrain compiled-truth check",
    "compaction-discipline":  "Injects boundary-timing principles before context compaction",
    "scan-pii":               "Scans outgoing data for PII before tool calls",
}

# ── Utilities ─────────────────────────────────────────────────────────────────

def rel_time(ts_str):
    if not ts_str:
        return "unknown"
    try:
        ts = datetime.fromisoformat(str(ts_str).replace("Z", "+00:00"))
        if ts.tzinfo is None:
            ts = ts.replace(tzinfo=timezone.utc)
        secs = int((NOW - ts).total_seconds())
        if secs < 0:
            return "just now"
        if secs < 60:
            return f"{secs}s ago"
        if secs < 3600:
            return f"{secs // 60}m ago"
        if secs < 86400:
            return f"{secs // 3600}h ago"
        days = secs // 86400
        return f"{days}d ago"
    except Exception:
        return str(ts_str)

def run_cmd(cmd, cwd=None, timeout=5):
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, cwd=cwd)
        return r.stdout.strip()
    except Exception:
        return ""

def h(text):
    return html.escape(str(text))

def badge(text, style="default"):
    colours = {
        "ok":      ("#a6e3a1", "rgba(166,227,161,0.15)"),
        "warn":    ("#f9e2af", "rgba(249,226,175,0.15)"),
        "missed":  ("#f38ba8", "rgba(243,139,168,0.15)"),
        "info":    ("#89b4fa", "rgba(137,180,250,0.15)"),
        "active":  ("#a6e3a1", "rgba(166,227,161,0.15)"),
        "inactive":("#6c7086", "rgba(108,112,134,0.15)"),
        "default": ("#a6adc8", "rgba(166,173,200,0.1)"),
    }
    color, bg = colours.get(style, colours["default"])
    return (f'<span style="display:inline-block;padding:2px 8px;border-radius:20px;'
            f'font-size:9px;font-weight:600;text-transform:uppercase;letter-spacing:0.6px;'
            f'color:{color};background:{bg};border:1px solid {color}55">{h(text)}</span>')

def empty_state(msg):
    return (f'<div style="padding:48px;text-align:center;color:var(--overlay0);'
            f'font-size:13px">{h(msg)}</div>')

def section_desc(text, *, icon="ℹ", color="var(--blue)"):
    return (f'<div style="background:rgba(49,50,68,0.5);border-left:3px solid {color}44;'
            f'border-radius:0 6px 6px 0;padding:8px 12px;margin-bottom:16px;'
            f'font-size:11px;color:var(--subtext0);line-height:1.6">'
            f'<span style="color:{color};margin-right:6px">{icon}</span>{text}</div>')

# ── Minimal Markdown → HTML ────────────────────────────────────────────────────

def inline_md(text):
    text = re.sub(r'`([^`]+)`',
        lambda m: (f'<code style="background:var(--surface0);padding:1px 5px;'
                   f'border-radius:3px;font-family:monospace;font-size:11px">'
                   f'{h(m.group(1))}</code>'),
        text)
    text = re.sub(r'\*\*([^*]+)\*\*', r'<strong style="color:var(--text)">\1</strong>', text)
    text = re.sub(r'\*([^*]+)\*', r'<em>\1</em>', text)
    text = re.sub(r'\[([^\]]+)\]\(([^)]+)\)',
        r'<a href="\2" style="color:var(--mauve)">\1</a>', text)
    return text

def mini_md(text):
    lines = text.split("\n")
    out = []
    in_ul = False
    in_table = False
    table_header_done = False

    def flush_ul():
        nonlocal in_ul
        if in_ul:
            out.append("</ul>")
            in_ul = False

    def flush_table():
        nonlocal in_table, table_header_done
        if in_table:
            out.append("</tbody></table>")
            in_table = False
            table_header_done = False

    td_s = "padding:5px 10px;border:1px solid var(--surface0);font-size:12px"
    th_s = td_s + ";font-weight:600;color:var(--mauve);background:var(--surface0)"

    for line in lines:
        stripped = line.strip()
        if stripped.startswith("#### "):
            flush_ul(); flush_table()
            out.append(f'<h4 style="color:var(--text);margin:12px 0 4px">{inline_md(stripped[5:])}</h4>')
        elif stripped.startswith("### "):
            flush_ul(); flush_table()
            out.append(f'<h3 style="color:var(--mauve);margin:16px 0 6px;font-size:14px">{inline_md(stripped[4:])}</h3>')
        elif stripped.startswith("## "):
            flush_ul(); flush_table()
            out.append(f'<h2 style="color:var(--text);margin:20px 0 8px;font-size:16px;'
                       f'border-bottom:1px solid var(--surface0);padding-bottom:6px">'
                       f'{inline_md(stripped[3:])}</h2>')
        elif stripped.startswith("# "):
            flush_ul(); flush_table()
            out.append(f'<h1 style="color:var(--text);margin:0 0 12px;font-size:18px">'
                       f'{inline_md(stripped[2:])}</h1>')
        elif re.match(r'^\|[-| :]+\|$', stripped):
            # Table separator row — mark header as done
            table_header_done = True
        elif stripped.startswith("|") and stripped.endswith("|"):
            flush_ul()
            cells = [c.strip() for c in stripped[1:-1].split("|")]
            if not in_table:
                out.append('<table style="width:100%;border-collapse:collapse;margin:8px 0">'
                           '<tbody>')
                in_table = True
                out.append("<tr>" + "".join(
                    f"<th style='{th_s}'>{inline_md(c)}</th>" for c in cells
                ) + "</tr>")
            else:
                out.append("<tr>" + "".join(
                    f"<td style='{td_s}'>{inline_md(c)}</td>" for c in cells
                ) + "</tr>")
        elif stripped.startswith("- ") or stripped.startswith("* "):
            flush_table()
            if not in_ul:
                out.append('<ul style="margin:4px 0;padding-left:20px;color:var(--subtext1)">')
                in_ul = True
            out.append(f'<li style="margin:2px 0;font-size:12px">{inline_md(stripped[2:])}</li>')
        elif stripped in ("---", "***", "___"):
            flush_ul(); flush_table()
            out.append('<hr style="border:none;border-top:1px solid var(--surface0);margin:12px 0">')
        elif stripped == "":
            flush_ul(); flush_table()
            out.append('<div style="height:6px"></div>')
        else:
            flush_ul(); flush_table()
            out.append(f'<p style="margin:3px 0;color:var(--subtext1);font-size:12px">'
                       f'{inline_md(stripped)}</p>')

    flush_ul()
    flush_table()
    return "\n".join(out)

# ── Data Parsers ──────────────────────────────────────────────────────────────

def discover_repos():
    if not PROJECTS_FILE.exists():
        return []
    repos = []
    for line in PROJECTS_FILE.read_text().splitlines():
        p = Path(line.strip())
        if line.strip() and p.exists():
            repos.append(p)
    return repos

def parse_trust_scores(repo):
    f = repo / ".claude" / "memory" / "trust-score.jsonl"
    if not f.exists():
        return []
    records = []
    for line in f.read_text().splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            records.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    records.sort(key=lambda r: r.get("ts", ""))
    return records[-30:]

def parse_observations(repo):
    f = repo / ".claude" / "memory" / "observations.md"
    if not f.exists():
        return {}
    pattern = re.compile(r'^- (\d{4}-\d{2}-\d{2}) \[([^\]]+)\]: (.+)$')
    result = {}
    for line in f.read_text().splitlines():
        m = pattern.match(line.strip())
        if not m:
            continue
        date_str, tags_raw, text = m.group(1), m.group(2), m.group(3)
        for tag in [t.strip() for t in tags_raw.split(",")]:
            result.setdefault(tag, []).append((date_str, text))
    return result

def list_hooks(repo):
    hooks_dir = repo / ".claude" / "hooks"
    if not hooks_dir.exists():
        return []
    return sorted(f.name for f in hooks_dir.glob("*.sh"))

def read_last_routine_run(repo):
    f = repo / ".claude" / "memory" / ".last-routine-run"
    if not f.exists():
        return None
    try:
        ts_str = f.read_text().strip()
        dt = datetime.fromisoformat(ts_str.replace("Z", "+00:00"))
        return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)
    except Exception:
        return None

def gitnexus_stats(repo):
    gn_dir  = repo / ".gitnexus"
    meta_f  = gn_dir / "meta.json"
    result  = {"available": gn_dir.exists()}
    if not gn_dir.exists():
        return result
    try:
        mtime = gn_dir.stat().st_mtime
        age   = NOW.timestamp() - mtime
        dt    = datetime.fromtimestamp(mtime, tz=timezone.utc)
        result["indexed_ago"] = rel_time(dt.isoformat())
        result["stale"]       = age > 86400
        result["very_stale"]  = age > 259200
    except Exception:
        pass
    if meta_f.exists():
        try:
            meta = json.loads(meta_f.read_text())
            s = meta.get("stats", {})
            result["symbols"]   = s.get("nodes", 0)
            result["clusters"]  = s.get("communities", 0)
            result["processes"] = s.get("processes", 0)
            result["files"]     = s.get("files", 0)
            # Use indexedAt from meta for accuracy
            if "indexedAt" in meta:
                result["indexed_ago"] = rel_time(meta["indexedAt"])
                age2 = (NOW - datetime.fromisoformat(
                    meta["indexedAt"].replace("Z", "+00:00"))).total_seconds()
                result["stale"]      = age2 > 86400
                result["very_stale"] = age2 > 259200
        except Exception:
            pass
    return result

def workshop_stats(repo):
    import shutil, subprocess
    installed = shutil.which("raindrop") is not None
    try:
        result = subprocess.run(
            ["grep", "-rq", "raindrop.begin", str(repo),
             "--include=*.py", "--include=*.ts"],
            capture_output=True, timeout=5
        )
        instrumented = result.returncode == 0
    except Exception:
        instrumented = False
    return {"installed": installed, "instrumented": instrumented}

def parse_orchestrator_log():
    if not ORCH_LOG.exists():
        return []
    pattern = re.compile(r'(\S+)\s+(\S+)\s+exit=(\d+)\s+duration=(\d+)s')
    runs = []
    for line in ORCH_LOG.read_text().splitlines():
        m = pattern.match(line.strip())
        if m:
            runs.append({
                "ts": m.group(1), "path": m.group(2),
                "exit": int(m.group(3)), "duration": int(m.group(4)),
            })
    return runs

def parse_cron(cron_str):
    parts = cron_str.strip().split()
    if len(parts) != 5:
        return None
    minute, hour, _dom, _month, dow = parts
    try:
        if dow != '*':
            dow_names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
            return {
                "type": "weekly", "dow": int(dow),
                "hour": int(hour), "minute": int(minute),
                "interval_seconds": 7 * 86400,
                "human": f"Every {dow_names[int(dow)]} at {int(hour):02d}:{int(minute):02d} UTC",
            }
        else:
            return {
                "type": "daily",
                "hour": int(hour), "minute": int(minute),
                "interval_seconds": 86400,
                "human": f"Daily at {int(hour):02d}:{int(minute):02d} UTC",
            }
    except (ValueError, IndexError):
        return None

def _next_schedule_occurrence(sched, from_dt):
    """Return the next datetime when a parsed cron schedule fires after from_dt."""
    if not sched:
        return None
    try:
        h, m = sched["hour"], sched["minute"]
        if sched["type"] == "daily":
            candidate = from_dt.replace(hour=h, minute=m, second=0, microsecond=0,
                                        tzinfo=from_dt.tzinfo or timezone.utc)
            if candidate <= from_dt:
                candidate += timedelta(days=1)
            return candidate
        if sched["type"] == "weekly":
            target_dow = sched["dow"]  # 0=Sun … 6=Sat (cron convention)
            # Python weekday(): Mon=0 … Sun=6; cron: Sun=0 … Sat=6
            py_dow = (target_dow - 1) % 7  # convert cron→python
            days_ahead = (py_dow - from_dt.weekday()) % 7
            candidate = (from_dt + timedelta(days=days_ahead)).replace(
                hour=h, minute=m, second=0, microsecond=0,
                tzinfo=from_dt.tzinfo or timezone.utc)
            if candidate <= from_dt:
                candidate += timedelta(weeks=1)
            return candidate
    except Exception:
        return None


def parse_ccr_routines():
    readme = HARNESS_DIR / "docs" / "ccr-routines" / "README.md"
    if not readme.exists():
        return []
    text = readme.read_text()
    routines = []
    for section in re.split(r'^(?=### )', text, flags=re.MULTILINE):
        if not section.startswith("### "):
            continue
        name    = section.splitlines()[0][4:].strip()
        id_m    = re.search(r'\*\*ID:\*\*\s*`(trig_\w+)`', section)
        cron_m  = re.search(r'cron\s+`([^`]+)`', section)
        out_m   = re.search(r'\*\*Output:\*\*.*?`([^`]*\.md)`', section)
        stat_m  = re.search(r'\*\*Status:\*\*\s*(\w+)', section)
        if not id_m:
            continue
        sched      = parse_cron(cron_m.group(1)) if cron_m else None
        out_file   = out_m.group(1) if out_m else None
        last_run_ts = None
        if out_file:
            git_ts = run_cmd(
                ["git", "log", "-1", "--format=%cI", "--", out_file],
                cwd=str(HARNESS_DIR)
            )
            if git_ts:
                try:
                    dt = datetime.fromisoformat(git_ts.replace("Z", "+00:00"))
                    last_run_ts = dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)
                except Exception:
                    pass
        miss_status = "ok"
        overdue_secs = 0
        next_run_str = "unknown"
        if sched:
            interval = sched["interval_seconds"]
            if last_run_ts:
                elapsed      = (NOW - last_run_ts).total_seconds()
                overdue_secs = max(0.0, elapsed - interval)
                if overdue_secs > interval * 0.25:
                    miss_status = "missed"
                elif overdue_secs > 0:
                    miss_status = "warn"
                nxt = last_run_ts + timedelta(seconds=interval)
            else:
                # Never run — compute next occurrence from schedule
                nxt = _next_schedule_occurrence(sched, NOW)
            if nxt:
                d = (nxt - NOW).total_seconds()
                if d > 0:
                    next_run_str = f"in {int(d/3600)}h" if d < 86400 else f"in {int(d/86400)}d"
                else:
                    next_run_str = (f"{int(-d/3600)}h overdue" if -d < 86400
                                    else f"{int(-d/86400)}d overdue")
        routines.append({
            "name":           name,
            "id":             id_m.group(1),
            "schedule_human": sched["human"] if sched else (cron_m.group(1) if cron_m else "—"),
            "status":         stat_m.group(1) if stat_m else "Unknown",
            "output_file":    out_file,
            "last_run_rel":   rel_time(last_run_ts.isoformat()) if last_run_ts else "never (not yet run)",
            "last_run_ts_iso": last_run_ts.isoformat() if last_run_ts else None,
            "miss_status":    miss_status,
            "overdue_secs":   overdue_secs,
            "next_run":       next_run_str,
        })
    return sorted(routines, key=lambda r: (r["miss_status"] not in ("missed","warn"), r["miss_status"] != "missed"))

def read_skill_report():
    report = HARNESS_DIR / "docs" / "skill-curation-report.md"
    if not report.exists():
        return None, None
    git_ts = run_cmd(
        ["git", "log", "-1", "--format=%cI", "--", "docs/skill-curation-report.md"],
        cwd=str(HARNESS_DIR)
    )
    return report.read_text(), (rel_time(git_ts) if git_ts else "unknown")

def git_log_memory(repo):
    out = run_cmd(
        ["git", "log", "--format=%H|%cr|%s", "-30", "--", ".claude/memory/"],
        cwd=str(repo)
    )
    entries = []
    for line in out.splitlines():
        parts = line.split("|", 2)
        if len(parts) == 3:
            entries.append({"hash": parts[0], "rel": parts[1], "subject": parts[2]})
    return entries or scan_memory_files(repo)

def git_log_harness_memory():
    claude_dir = Path.home() / ".claude"
    if not (claude_dir / ".git").exists():
        return []
    out = run_cmd(
        ["git", "log", "--format=%H|%cr|%s", "-30"],
        cwd=str(claude_dir)
    )
    entries = []
    for line in out.splitlines():
        parts = line.split("|", 2)
        if len(parts) == 3:
            entries.append({"hash": parts[0], "rel": parts[1], "subject": parts[2]})
    return entries

def scan_memory_files(repo):
    """Fallback when .claude/memory is gitignored: return files sorted by mtime."""
    mem_dir = repo / ".claude" / "memory"
    if not mem_dir.exists():
        return []
    cutoff = NOW.timestamp() - 45 * 86400
    tmp = []
    for f in mem_dir.iterdir():
        if f.is_file() and not f.name.startswith("."):
            mtime = f.stat().st_mtime
            if mtime > cutoff:
                dt = datetime.fromtimestamp(mtime, tz=timezone.utc)
                tmp.append((mtime, {
                    "hash": "", "rel": rel_time(dt.isoformat()),
                    "subject": f"[updated] {f.name}",
                }))
    tmp.sort(reverse=True)
    return [e for _, e in tmp[:30]]

def read_memory_file_cards(repo):
    """Read .claude/memory/*.md with snapshot-based diffs stored in .dashboard/."""
    import difflib
    mem_dir  = repo / ".claude" / "memory"
    snap_dir = DASHBOARD_DIR / "memory-snapshots" / repo.name
    if not mem_dir.exists():
        return []
    snap_dir.mkdir(parents=True, exist_ok=True)

    priority  = ["hot-memory.md", "observations.md", "entities.md", "patterns.md"]
    all_files = sorted(mem_dir.glob("*.md"), key=lambda f: (
        priority.index(f.name) if f.name in priority else len(priority), f.name
    ))
    cards = []
    for f in all_files:
        try:
            content = f.read_text(encoding="utf-8", errors="replace")
            mtime   = f.stat().st_mtime
            dt      = datetime.fromtimestamp(mtime, tz=timezone.utc)

            snap_f       = snap_dir / f"{f.name}.prev"
            diff_lines   = None
            diff_summary = None

            if snap_f.exists():
                old = snap_f.read_text(encoding="utf-8", errors="replace")
                if old != content:
                    raw = list(difflib.unified_diff(
                        old.splitlines(), content.splitlines(),
                        fromfile="previous", tofile="current", lineterm=""
                    ))
                    added   = sum(1 for l in raw if l.startswith("+") and not l.startswith("+++"))
                    removed = sum(1 for l in raw if l.startswith("-") and not l.startswith("---"))
                    diff_lines   = raw
                    diff_summary = f"+{added} added / −{removed} removed since last snapshot"
                    snap_f.write_text(content, encoding="utf-8")
                else:
                    diff_summary = "unchanged since last snapshot"
            else:
                snap_f.write_text(content, encoding="utf-8")
                diff_summary = "snapshot created — diff will appear after next change"

            cards.append({
                "name":         f.name,
                "rel":          rel_time(dt.isoformat()),
                "lines":        len(content.splitlines()),
                "content":      content[:6000],
                "truncated":    len(content) > 6000,
                "diff_lines":   diff_lines,
                "diff_summary": diff_summary,
            })
        except Exception:
            pass
    return cards

# ── SVG Helpers ───────────────────────────────────────────────────────────────

def arc_gauge_svg(score, color):
    arc_len = math.pi * 100
    pct     = max(0.0, min(100.0, float(score))) / 100.0
    offset  = arc_len * (1.0 - pct)
    return f"""<svg viewBox="0 0 300 170" width="260" height="148" style="display:block;margin:0 auto">
  <defs>
    <filter id="arc-glow" x="-20%" y="-20%" width="140%" height="140%">
      <feGaussianBlur stdDeviation="3" result="blur"/>
      <feMerge><feMergeNode in="blur"/><feMergeNode in="SourceGraphic"/></feMerge>
    </filter>
  </defs>
  <path d="M 50 150 A 100 100 0 0 1 250 150"
        fill="none" stroke="var(--surface0)" stroke-width="14" stroke-linecap="round"/>
  <path d="M 50 150 A 100 100 0 0 1 250 150"
        fill="none" stroke="{color}" stroke-width="14" stroke-linecap="round"
        stroke-dasharray="{arc_len:.2f}" stroke-dashoffset="{offset:.2f}"
        filter="url(#arc-glow)"/>
  <circle cx="50"  cy="150" r="7" fill="{color}" opacity="0.5"/>
  <circle cx="250" cy="150" r="7" fill="{color}" opacity="0.5"/>
  <text x="150" y="128" text-anchor="middle" fill="{color}"
        font-size="40" font-weight="800"
        font-family="ui-monospace,Consolas,'Courier New',monospace">{score:.0f}%</text>
  <text x="150" y="148" text-anchor="middle" fill="var(--overlay0)"
        font-size="10" font-family="system-ui,sans-serif" letter-spacing="2">TRUST SCORE</text>
</svg>"""

def bar_chart_svg(records, width=420, height=64):
    if not records:
        return f'<svg width="{width}" height="{height}"></svg>'
    n     = len(records)
    gap   = 2
    bar_w = max(4, (width - gap * (n - 1)) // n)
    bars  = []
    for i, r in enumerate(records):
        delta = r.get("delta_applied", 0)
        color = "var(--green)" if delta >= 0 else "var(--red)"
        bh    = max(3, min(height - 4, int(abs(delta) * 8)))
        x     = i * (bar_w + gap)
        y     = height - bh - 2
        bars.append(f'<rect x="{x}" y="{y}" width="{bar_w}" height="{bh}" '
                    f'rx="2" fill="{color}" opacity="0.8"/>')
    return (f'<svg viewBox="0 0 {n*(bar_w+gap)} {height}" width="{width}" '
            f'height="{height}" preserveAspectRatio="none">'
            + "".join(bars) + "</svg>")

# ── Section Renderers ─────────────────────────────────────────────────────────

def render_trust_battery(rd):
    scores = rd["trust_scores"]
    obs    = rd["observations"]
    if not scores:
        return empty_state("No trust score data yet. Run daily-maintenance to start tracking.")

    cur    = scores[-1]
    score  = cur.get("score", 0)
    delta  = cur.get("delta_applied", 0)
    ts     = cur.get("ts", "")
    color  = ("#a6e3a1" if score >= 70 else
              "#f9e2af" if score >= 40 else "#f38ba8")
    if delta > 0:
        delta_str   = f"▲ +{delta:.1f}"
        delta_color = "#a6e3a1"
    elif delta < 0:
        delta_str   = f"▼ {delta:.1f}"
        delta_color = "#f38ba8"
    else:
        delta_str   = "▬ 0.0"
        delta_color = "var(--overlay0)"

    judge_entries = obs.get("judge", [])
    judge_html    = ""
    if judge_entries:
        last_judge = judge_entries[-1][1]
        truncated  = h(last_judge[:300]) + ("…" if len(last_judge) > 300 else "")
        judge_html = (f'<div style="margin-top:14px"><div class="label">Latest judge verdict</div>'
                      f'<div style="background:var(--surface0);border-radius:6px;padding:10px 12px;'
                      f'margin-top:6px;font-size:12px;color:var(--subtext1);line-height:1.6">'
                      f'{truncated}</div></div>')

    seven_day = sum(r.get("delta_applied", 0) for r in scores[-7:])
    gauge      = arc_gauge_svg(score, color)
    chart      = bar_chart_svg(scores)

    desc = section_desc(
        "Cumulative score adjusted daily by the <strong style='color:var(--text)'>session-judge</strong> "
        "agent (runs inside daily-maintenance). Starts at 20% and moves by <strong>±4.5% max/day</strong>. "
        "<strong style='color:var(--yellow)'>Score only moves on specific evidence</strong> — "
        "it does NOT react to general chat. Charges: spec gate passes, self-caught bugs "
        "<code>[debug]</code>, reuse cited in <code>[impl]</code>, rule cited in <code>[decision]</code>. "
        "Drains: <code>[memory-gap]</code> re-explanations (−2 each), silent failures, gate bypasses, churn. "
        "Delta=0 means the judge found no scorable evidence in the last 24h observations window — "
        "normal for maintenance-only days or when sessions don't produce these specific tags."
    )
    return f"""<div class="section-inner">
  <h2 class="section-title">Trust Battery</h2>
  {desc}
  <div style="display:flex;gap:32px;align-items:flex-start;flex-wrap:wrap">
    <div style="min-width:260px">
      {gauge}
      <div style="text-align:center;margin-top:6px">
        <span style="display:inline-block;background:rgba(166,227,161,0.08);
                     border:1px solid {color}44;border-radius:20px;
                     padding:4px 14px;font-size:13px;font-weight:600;
                     color:{delta_color}">{h(delta_str)} today</span>
      </div>
      <div style="text-align:center;margin-top:5px;color:var(--overlay0);font-size:11px">
        {h(rel_time(ts))}
      </div>
    </div>
    <div style="flex:1;min-width:240px">
      <div class="label" style="margin-bottom:6px">30-day delta trend</div>
      {chart}
      <div style="display:flex;gap:10px;margin-top:12px">
        <div class="stat-card">
          <div class="stat-val" style="color:{color}">{score:.0f}%</div>
          <div class="stat-lbl">current</div>
        </div>
        <div class="stat-card">
          <div class="stat-val" style="color:var(--mauve)">{seven_day:+.1f}</div>
          <div class="stat-lbl">7-day delta</div>
        </div>
        <div class="stat-card">
          <div class="stat-val" style="color:var(--blue)">{len(scores)}</div>
          <div class="stat-lbl">days tracked</div>
        </div>
      </div>
      {judge_html}
    </div>
  </div>
</div>"""

def render_gitnexus(rd, companion=False):
    gn        = rd["gitnexus"]
    repo_path = rd["path"]
    repo_name = h(Path(repo_path).name)

    if not gn.get("available"):
        return f"""<div class="section-inner">
  <h2 class="section-title">GitNexus — {repo_name}</h2>
  <div style="padding:40px;text-align:center">
    <div style="font-size:32px;margin-bottom:10px">🕸</div>
    <div style="color:var(--subtext0);margin-bottom:12px">GitNexus not indexed for <strong>{repo_name}</strong></div>
    <div style="display:inline-block;background:var(--surface0);border-radius:6px;
                padding:8px 14px;font-family:monospace;font-size:12px;color:var(--text)">
      /kiro:gitnexus-setup
    </div>
    <div style="color:var(--overlay0);font-size:11px;margin-top:8px">
      Run this command to index the repo and enable graph intelligence
    </div>
  </div>
</div>"""

    stale_color = ("#f38ba8" if gn.get("very_stale") else
                   "#f9e2af" if gn.get("stale")      else "#a6e3a1")

    def _fmt(val):
        if val is None:
            return "—"
        if val >= 1000:
            return f"{val/1000:.1f}k"
        return str(val)

    stats_html = f"""<div style="display:grid;grid-template-columns:repeat(4,1fr);
                          gap:1px;background:var(--surface0);border-radius:0;
                          overflow:hidden;flex-shrink:0;border-bottom:1px solid var(--surface0)">
    <div style="background:var(--base);padding:8px 10px;text-align:center">
      <div style="color:var(--mauve);font-size:16px;font-weight:700;line-height:1.2">{_fmt(gn.get("symbols"))}</div>
      <div class="label">symbols</div></div>
    <div style="background:var(--base);padding:8px 10px;text-align:center">
      <div style="color:var(--teal);font-size:16px;font-weight:700;line-height:1.2">{_fmt(gn.get("clusters"))}</div>
      <div class="label">clusters</div></div>
    <div style="background:var(--base);padding:8px 10px;text-align:center">
      <div style="color:var(--blue);font-size:16px;font-weight:700;line-height:1.2">{_fmt(gn.get("processes"))}</div>
      <div class="label">flows</div></div>
    <div style="background:var(--base);padding:8px 10px;text-align:center">
      <div style="color:{stale_color};font-size:12px;font-weight:600;line-height:1.2">
        {h(gn.get("indexed_ago","unknown"))}</div>
      <div class="label">indexed</div></div>
  </div>"""

    # In companion mode use the proxy so we can inject auto-select script
    iframe_src = ""
    if companion:
        from urllib.parse import quote as _quote
        rp_js  = html.escape(json.dumps(repo_path))  # &quot; inside onclick attr
        iframe_src = f"http://localhost:4569/gn/?autoRepo={_quote(Path(repo_path).name)}"

    serve_btn = ""
    if companion:
        serve_btn = f"""<button id="gn-start-btn"
           style="display:none;background:var(--mauve);color:var(--crust);border:none;
                  border-radius:6px;padding:9px 18px;font-size:12px;font-weight:600;
                  cursor:pointer;letter-spacing:.3px"
           onclick="startGitnexus({rp_js})">
        ▶ Start gitnexus serve
      </button>"""

    iframe_height = "calc(100vh - 110px)"

    iframe_html = f"""<div style="position:relative;overflow:hidden;background:var(--crust);
                          flex:1;min-height:0">
    <iframe id="gn-frame" data-src="{html.escape(iframe_src)}"
            style="width:100%;height:{iframe_height};border:none;display:none">
    </iframe>
    <div id="gn-fallback" style="display:flex;height:{iframe_height};
              background:var(--mantle);flex-direction:column;
              align-items:center;justify-content:center;gap:12px">
      <div style="font-size:32px">🕸</div>
      <div id="gn-status" style="color:var(--subtext0);font-size:13px">Checking gitnexus…</div>
      {serve_btn}
      <div id="gn-copy-btn"
           style="display:none;background:var(--surface0);border-radius:6px;padding:8px 16px;
                  font-family:monospace;font-size:12px;color:var(--text);cursor:pointer"
           onclick="navigator.clipboard.writeText('gitnexus serve');
                    this.textContent='✓ Copied!'">
        gitnexus serve  📋
      </div>
      <div id="gn-copy-hint" style="display:none;color:var(--overlay0);font-size:11px">
        Click to copy, then run in your terminal
      </div>
      <button id="gn-retry-btn"
           style="display:none;background:transparent;color:var(--subtext0);border:1px solid var(--surface0);
                  border-radius:6px;padding:6px 14px;font-size:11px;cursor:pointer;margin-top:4px"
           onclick="_gnProbing=false;probeGitnexus();this.style.display='none';
                    document.getElementById('gn-status').textContent='Checking gitnexus…'">
        ↺ Retry
      </button>
    </div>
  </div>
"""

    # Full-bleed layout: thin stats header + iframe fills the rest of the viewport
    return f"""<div style="display:flex;flex-direction:column;height:100vh;overflow:hidden">
  {stats_html.replace('margin-bottom:14px', 'margin-bottom:0;border-radius:0;flex-shrink:0')}
  {iframe_html}
</div>"""

def render_workshop(rd, companion=False):
    ws        = rd.get("workshop", {})
    repo_path = rd["path"]
    repo_name = h(Path(repo_path).name)

    if not ws.get("installed"):
        return f"""<div class="section-inner">
  <h2 class="section-title">Workshop — {repo_name}</h2>
  <div style="padding:40px;text-align:center">
    <div style="font-size:32px;margin-bottom:10px">🔬</div>
    <div style="color:var(--subtext0);margin-bottom:12px">Raindrop Workshop not installed</div>
    <div style="display:inline-block;background:var(--surface0);border-radius:6px;
                padding:8px 14px;font-family:monospace;font-size:12px;color:var(--text)">
      curl -fsSL https://raindrop.sh/install | bash
    </div>
    <div style="color:var(--overlay0);font-size:11px;margin-top:8px">
      Run this to install Raindrop Workshop locally
    </div>
  </div>
</div>"""

    sdk_badge = badge("instrumented", "ok") if ws.get("instrumented") else badge("not instrumented", "warn")

    eval_btn_html = ""
    if companion:
        rp_js = html.escape(json.dumps(repo_path))
        rn_js = html.escape(json.dumps(Path(repo_path).name))
        if ws.get("instrumented"):
            eval_btn_html = f"""<button id="ws-eval-btn"
               style="background:var(--mauve);color:var(--crust);border:none;
                      border-radius:6px;padding:9px 18px;font-size:12px;font-weight:600;
                      cursor:pointer;letter-spacing:.3px;white-space:nowrap;flex-shrink:0"
               onclick="runEvalLoop({rp_js},{rn_js})">
            ⚗ Run Eval Loop
          </button>"""
        else:
            eval_btn_html = """<div style="color:var(--overlay0);font-size:11px;
                                           white-space:nowrap;flex-shrink:0">
              run /raindrop-instrument-agent to enable evals
            </div>"""

    event_name = Path(repo_path).name
    en_attr    = html.escape(event_name)

    open_ws_btn = refresh_btn = ""
    if companion:
        open_ws_btn = """<a href="http://localhost:5899" target="_blank"
           style="background:var(--surface0);color:var(--text);text-decoration:none;
                  border-radius:6px;padding:9px 14px;font-size:12px;font-weight:600;
                  white-space:nowrap;flex-shrink:0">
            ↗ Full UI
          </a>"""
        refresh_btn = """<button
           style="background:transparent;color:var(--subtext0);border:1px solid var(--surface0);
                  border-radius:6px;padding:9px 14px;font-size:12px;cursor:pointer;
                  white-space:nowrap;flex-shrink:0"
           onclick="loadWorkshopRuns()">↺</button>"""

    header_html = f"""<div style="display:flex;align-items:center;background:var(--base);
                           border-bottom:1px solid var(--surface0);padding:8px 12px;
                           flex-shrink:0;gap:8px">
    <div style="flex:1;display:grid;grid-template-columns:repeat(3,1fr);gap:1px;
                background:var(--surface0);border-radius:6px;overflow:hidden">
      <div style="background:var(--base);padding:8px 10px;text-align:center">
        <div style="color:var(--teal);font-size:14px;font-weight:700;line-height:1.2">🔬</div>
        <div class="label">Workshop</div></div>
      <div style="background:var(--base);padding:8px 10px;text-align:center">
        <div style="font-size:12px;font-weight:600;color:var(--text);line-height:1.2">{repo_name}</div>
        <div class="label">repo</div></div>
      <div style="background:var(--base);padding:8px 10px;text-align:center">
        <div style="padding:2px 0">{sdk_badge}</div>
        <div class="label">SDK</div></div>
    </div>
    {eval_btn_html}
    {open_ws_btn}
    {refresh_btn}
  </div>"""

    eval_note = (
        "The <strong style='color:var(--text)'>Run Eval Loop</strong> button launches a Claude session "
        "that replays recent Workshop runs against a self-healing test harness — useful for catching "
        "regressions after code changes. Requires the repo to be instrumented first."
        if ws.get("instrumented") else
        "The <strong style='color:var(--text)'>SDK badge</strong> above shows <em>not instrumented</em> — "
        "run <code>/instrument-agent</code> in that repo's Claude session to wire up tracing, then "
        "restart the app. The <strong>Run Eval Loop</strong> button will appear once instrumented."
    )
    desc = section_desc(
        "<strong style='color:var(--text)'>Raindrop Workshop</strong> captures AI agent traces for "
        f"<code>{h(event_name)}</code> — each run records the input sent to the agent, the LLM and tool "
        "calls it made, and its final output. Runs appear here automatically whenever the app is invoked "
        "with Workshop running. Filter is scoped to this repo's <code>event_name</code> so switching "
        "repos shows only that repo's traces. " + eval_note,
        icon="🔬", color="var(--teal)"
    )

    runs_panel = f"""<div id="ws-runs-panel" data-event-name="{en_attr}"
      style="flex:1;overflow-y:auto;min-height:0;background:var(--mantle)">
      <div style="color:var(--subtext0);padding:40px;text-align:center">Loading…</div>
    </div>"""

    return f"""<div style="display:flex;flex-direction:column;height:100vh;overflow:hidden">
  {header_html}
  <div style="padding:12px 16px 0;flex-shrink:0">{desc}</div>
  {runs_panel}
</div>"""

def render_hooks_history(rd):
    hooks = rd["hooks"]
    obs   = rd["observations"]
    if not hooks:
        return empty_state("No hooks found in .claude/hooks/")

    all_obs = sorted(
        [(d, tag, t) for tag, entries in obs.items() for d, t in entries],
        key=lambda x: x[0], reverse=True
    )

    event_map = {
        "session-start":        "SessionStart",
        "stop":                 "Stop",
        "memory-discipline":    "PreToolUse",
        "impeccable-detect":    "PostToolUse",
        "revert-detect":        "PostToolUse",
        "hook-added-notify":    "PostToolUse",
        "ccr-routine-added":    "PostToolUse",
        "gbrain-agent-spawn":   "PreToolUse",
        "gbrain-memory-write":  "PreToolUse",
        "gbrain-external":      "PreToolUse",
        "compaction-discipline":"PreCompact",
        "scan-pii":             "PostToolUse",
        "pre-tool-use-gitnexus":"PreToolUse",
    }

    desc = section_desc(
        "Hooks are shell scripts that Claude Code calls automatically at lifecycle events. "
        "They run outside Claude's permission system. "
        "<strong style='color:var(--text)'>Click any hook</strong> to see its recorded activity in observations. "
        "Hooks without observations either haven't fired yet or don't write to observations.md."
    )

    cards = ""
    for hook_file in hooks:
        stem  = hook_file.replace(".sh", "")
        event = next((v for k, v in event_map.items() if k in stem), "Unknown")
        descr = next((v for k, v in HOOK_DESCRIPTIONS.items() if k in stem), "")

        # Collect all observations that plausibly mention this hook
        key_parts = [p for p in stem.replace("-hook", "").split("-") if len(p) > 3]
        matching = [
            (d, tag, t) for d, tag, t in all_obs
            if any(p in t.lower() or p in tag.lower() for p in key_parts)
        ]
        last_activity = matching[0] if matching else None

        # Last activity chip
        if last_activity:
            la_date, la_tag, la_text = last_activity
            la_html = (f'<span style="color:var(--subtext1);font-size:11px">'
                       f'{h(la_date)}</span>'
                       f'<span style="color:var(--overlay0);font-size:11px;margin-left:6px">'
                       f'{h(la_text[:80])}{"…" if len(la_text)>80 else ""}</span>')
        else:
            la_html = '<span style="color:var(--overlay0);font-size:11px;font-style:italic">no recorded activity</span>'

        # Activity detail: list all matching observations
        if matching:
            detail_items = "".join(
                f'<div style="padding:4px 0;border-bottom:1px solid rgba(49,50,68,0.4);'
                f'font-size:11px;color:var(--subtext0)">'
                f'<span style="color:var(--overlay0);margin-right:8px">{h(d)}</span>'
                f'<span style="color:var(--mauve);margin-right:6px;font-size:9px">[{h(tag)}]</span>'
                f'{h(t)}</div>'
                for d, tag, t in matching[:10]
            )
            detail_html = (
                f'<div style="padding:10px 12px;background:rgba(0,0,0,0.15);'
                f'border-top:1px solid var(--surface0)">'
                f'<div style="font-size:9px;text-transform:uppercase;letter-spacing:1px;'
                f'color:var(--overlay0);margin-bottom:6px">Recorded activity (newest first)</div>'
                f'{detail_items}</div>'
            )
            container = "details"
            header_tag = "summary"
            header_extra = "cursor:pointer;"
        else:
            detail_html = ""
            container = "div"
            header_tag = "div"
            header_extra = ""

        event_color = {
            "SessionStart": "#a6e3a1", "Stop": "#f38ba8",
            "PreToolUse": "#89b4fa", "PostToolUse": "#94e2d5", "PreCompact": "#cba6f7",
        }.get(event, "#a6adc8")

        cards += (
            f'<{container} style="border:1px solid var(--surface0);border-radius:7px;'
            f'overflow:hidden;margin-bottom:6px">'
            f'<{header_tag} style="display:grid;grid-template-columns:180px 100px 1fr auto;'
            f'gap:12px;align-items:center;padding:8px 12px;background:var(--base);{header_extra}">'
            f'<code style="color:var(--mauve);font-size:10px;overflow:hidden;'
            f'text-overflow:ellipsis;white-space:nowrap">{h(hook_file)}</code>'
            f'<span style="color:{event_color};font-size:10px;font-weight:600">{h(event)}</span>'
            f'<span style="font-size:11px;color:var(--subtext0)">'
            f'{h(descr) if descr else la_html}</span>'
            f'{badge("Active","active")}'
            f'</{header_tag}>'
            f'{detail_html}'
            f'</{container}>'
        )

    return f"""<div class="section-inner">
  <h2 class="section-title">Hooks History</h2>
  {desc}
  {cards}
</div>"""

def render_ccr_routines(hd):
    routines = hd["ccr_routines"]
    if not routines:
        return empty_state("No CCR routines found in docs/ccr-routines/README.md")

    harness_note = """<div style="background:var(--surface0);border-radius:6px;padding:8px 12px;
          margin-bottom:14px;font-size:11px;color:var(--subtext0);display:flex;gap:8px;
          align-items:center">
      <span style="color:var(--blue)">ℹ</span>
      CCR routines run against the <strong style="color:var(--text)">sdd-harness</strong> repo on GitHub — they are harness-wide, not per-repo.
      Local daily maintenance (judge / reflect / keep-rate) runs via Task Scheduler and is shown in <em>Maintenance Status</em>.
    </div>"""

    cards = ""
    for r in routines:
        ms     = r["miss_status"]
        border = ("var(--red)"     if ms == "missed" else
                  "var(--yellow)"  if ms == "warn"   else "var(--surface0)")
        bg     = ("rgba(243,139,168,0.06)" if ms == "missed" else
                  "rgba(249,226,175,0.04)" if ms == "warn"   else "transparent")
        sbadge = (badge("MISSED",  "missed") if ms == "missed" else
                  badge("WARNING", "warn")   if ms == "warn"   else badge("OK", "ok"))

        out_html = "—"
        if r["output_file"]:
            out_path = HARNESS_DIR / r["output_file"]
            if out_path.exists():
                uri = out_path.as_uri()
                out_html = (f'<a href="{h(uri)}" target="_blank" '
                            f'style="color:var(--mauve);font-size:11px">'
                            f'{h(r["output_file"])} ↗</a>')
            else:
                out_html = (f'<span style="color:var(--overlay0);font-size:11px">'
                            f'{h(r["output_file"])} (not yet generated)</span>')

        debug = ""
        if ms == "missed":
            od = r["overdue_secs"]
            od_str = (f"{int(od/86400)}d overdue" if od > 86400
                      else f"{int(od/3600)}h overdue")
            debug = f"""<div style="background:rgba(243,139,168,0.08);
                             border:1px solid rgba(243,139,168,0.3);
                             border-radius:6px;padding:10px 12px;margin-top:10px">
        <div style="color:var(--red);font-size:11px;font-weight:600;margin-bottom:6px">
          ⚠ {h(od_str)} — possible causes:
        </div>
        <ul style="margin:0;padding-left:16px;color:var(--subtext0);
                   font-size:11px;line-height:1.9">
          <li>GitHub App permissions revoked —
              <a href="https://claude.ai/settings" style="color:var(--mauve)">
              check claude.ai/settings</a></li>
          <li>Repo renamed or moved — trigger IDs are path-bound</li>
          <li>Trigger deleted — re-run
              <code style="background:var(--surface0);padding:1px 4px;border-radius:3px">
              /schedule</code> to recreate</li>
          <li>Output file path changed — routine writing to wrong location</li>
        </ul>
      </div>"""

        cards += f"""<div style="border:1px solid {border};border-radius:10px;
                        overflow:hidden;margin-bottom:14px;background:{bg}">
      <div style="background:rgba(0,0,0,0.2);padding:10px 14px;
                  display:flex;align-items:center;gap:10px;
                  border-bottom:1px solid {border}33">
        <span style="color:var(--text);font-weight:600;font-size:13px;flex:1">
          {h(r["name"])}</span>
        <code style="color:var(--overlay0);font-size:10px">{h(r["id"][:28])}…</code>
        {sbadge}
      </div>
      <div style="padding:12px 14px;display:grid;
                  grid-template-columns:repeat(4,1fr);gap:12px">
        <div><div class="label">Schedule</div>
             <div style="color:var(--subtext1);font-size:12px;margin-top:3px">
               {h(r["schedule_human"])}</div></div>
        <div><div class="label">Last ran</div>
             <div style="color:var(--subtext1);font-size:12px;margin-top:3px">
               {h(r["last_run_rel"])}</div></div>
        <div><div class="label">Next expected</div>
             <div style="color:var(--blue);font-size:12px;margin-top:3px">
               {h(r["next_run"])}</div></div>
        <div><div class="label">Output</div>
             <div style="margin-top:3px">{out_html}</div></div>
      </div>
      {debug}
    </div>"""

    cards += f"""<div style="border:1px solid var(--surface0);border-radius:8px;
                    padding:10px 14px;background:rgba(49,50,68,0.3);margin-top:4px">
    <div style="color:var(--subtext0);font-size:11px;font-weight:600;margin-bottom:3px">
      📋 Local Daily Maintenance (Task Scheduler)</div>
    <div style="color:var(--overlay0);font-size:11px">
      Runs via Windows Task Scheduler / session-start hook catch-up.
      See <strong>Maintenance Status</strong> for per-repo run history.</div>
  </div>"""

    return f'<div class="section-inner"><h2 class="section-title">CCR Routines</h2>{harness_note}{cards}</div>'

def render_memory_changes(rd, hd):
    cards    = rd.get("memory_cards", [])
    obs      = rd.get("observations", {})

    git_entries     = [e for e in rd.get("memory_changes", []) if e.get("hash")]
    harness_entries = hd.get("harness_memory", [])

    git_based = bool(git_entries)
    desc_text = (
        "Git commits that touched memory files — shown alongside live file content below."
        if git_based else
        "<strong style='color:var(--text)'>.claude/memory/ is gitignored in this repo</strong> — "
        "git history is unavailable. Showing live file content and the observations feed instead. "
        "Files are updated by daily-maintenance (judge · reflect · housekeep) and Claude sessions."
    )

    # ── Observations feed (all tags, newest-first) ────────────────────────────
    all_obs = sorted(
        [(d, tag, t) for tag, entries in obs.items() for d, t in entries],
        key=lambda x: x[0], reverse=True
    )

    TAG_COLORS = {
        "judge":            "#cba6f7",
        "session-quality":  "#89b4fa",
        "keep-rate":        "#94e2d5",
        "memory-gap":       "#f9e2af",
        "debug":            "#a6e3a1",
        "impl":             "#a6e3a1",
        "decision":         "#fab387",
        "insight":          "#89b4fa",
        "design":           "#cba6f7",
        "spec":             "#cba6f7",
        "friction":         "#f38ba8",
        "pattern":          "#94e2d5",
        "kaizen":           "#fab387",
    }

    obs_rows = ""
    for date_str, tag, text in all_obs[:50]:
        tc = TAG_COLORS.get(tag, "#a6adc8")
        tag_pill = (
            f'<span style="font-size:9px;padding:1px 5px;border-radius:8px;'
            f'background:{tc}18;color:{tc};flex-shrink:0;font-weight:600">'
            f'[{h(tag)}]</span>'
        )
        obs_rows += (
            f'<div style="padding:6px 0;border-bottom:1px solid rgba(49,50,68,0.4);'
            f'display:flex;gap:8px;align-items:baseline">'
            f'<span style="color:var(--overlay0);font-size:10px;flex-shrink:0;min-width:72px">'
            f'{h(date_str)}</span>'
            f'{tag_pill}'
            f'<span style="flex:1;font-size:11px;color:var(--subtext1);line-height:1.5">'
            f'{h(text)}</span>'
            f'</div>'
        )

    # ── Memory file cards ──────────────────────────────────────────────────────
    file_cards = ""
    for c in cards:
        trunc_note = (
            f'<span style="color:var(--overlay0);font-size:9px"> (truncated at 4000 chars)</span>'
            if c.get("truncated") else ""
        )
        file_cards += (
            f'<details style="border:1px solid var(--surface0);border-radius:7px;'
            f'overflow:hidden;margin-bottom:6px">'
            f'<summary style="display:flex;align-items:center;gap:10px;padding:7px 12px;'
            f'background:var(--base);cursor:pointer">'
            f'<code style="color:var(--mauve);font-size:11px;flex:1">{h(c["name"])}</code>'
            f'<span style="color:var(--overlay0);font-size:10px">{c["lines"]} lines</span>'
            f'<span style="color:var(--overlay0);font-size:10px">{h(c["rel"])}</span>'
            f'</summary>'
            f'<div style="padding:10px 12px;background:rgba(0,0,0,0.15)">'
            f'<pre style="font-size:10px;color:var(--subtext0);white-space:pre-wrap;'
            f'word-break:break-word;margin:0;line-height:1.6">'
            f'{h(c["content"])}</pre>'
            f'{trunc_note}'
            f'</div>'
            f'</details>'
        )

    if not obs_rows and not file_cards:
        return f"""<div class="section-inner">
  <h2 class="section-title">Memory Changes</h2>
  {section_desc(desc_text)}
  {empty_state("No memory files found in .claude/memory/")}
</div>"""

    # ── Memory file cards with diff ───────────────────────────────────────────
    file_cards_html = ""
    for c in cards:
        # Status chip
        ds = c.get("diff_summary", "")
        if c.get("diff_lines"):
            chip_color, chip_bg = "#a6e3a1", "rgba(166,227,161,0.12)"
        elif "unchanged" in ds:
            chip_color, chip_bg = "#6c7086", "rgba(108,112,134,0.1)"
        else:
            chip_color, chip_bg = "#89b4fa", "rgba(137,180,250,0.1)"
        status_chip = (
            f'<span style="font-size:9px;padding:2px 7px;border-radius:8px;'
            f'background:{chip_bg};color:{chip_color};white-space:nowrap">'
            f'{h(ds)}</span>'
        )

        # Diff view (if there are changes)
        diff_html = ""
        if c.get("diff_lines"):
            rendered = ""
            for line in c["diff_lines"][:80]:
                if line.startswith("+") and not line.startswith("+++"):
                    rendered += (f'<div style="color:#a6e3a1;background:rgba(166,227,161,0.07);'
                                 f'white-space:pre-wrap;word-break:break-all">{h(line)}</div>')
                elif line.startswith("-") and not line.startswith("---"):
                    rendered += (f'<div style="color:#f38ba8;background:rgba(243,139,168,0.07);'
                                 f'white-space:pre-wrap;word-break:break-all">{h(line)}</div>')
                elif line.startswith("@@"):
                    rendered += (f'<div style="color:#89b4fa;opacity:0.6;'
                                 f'white-space:pre-wrap">{h(line)}</div>')
            diff_html = (
                f'<div style="padding:8px 12px;border-top:1px solid var(--surface0);'
                f'background:rgba(0,0,0,0.15)">'
                f'<div style="font-size:9px;text-transform:uppercase;letter-spacing:1px;'
                f'color:var(--overlay0);margin-bottom:6px">Diff (since last snapshot)</div>'
                f'<pre style="font-size:10px;line-height:1.55;margin:0">{rendered}</pre>'
                f'</div>'
            )

        # Full content (always available, collapsed by default when diff exists)
        trunc = ('<span style="color:var(--overlay0);font-size:9px"> …truncated</span>'
                 if c.get("truncated") else "")
        full_html = (
            f'<details style="border-top:1px solid var(--surface0)">'
            f'<summary style="padding:5px 12px;font-size:9px;text-transform:uppercase;'
            f'letter-spacing:1px;color:var(--overlay0);cursor:pointer;list-style:none">'
            f'Full content ({c["lines"]} lines){trunc}</summary>'
            f'<div style="padding:8px 12px;background:rgba(0,0,0,0.1)">'
            f'<pre style="font-size:10px;color:var(--subtext0);white-space:pre-wrap;'
            f'word-break:break-word;margin:0;line-height:1.6">{h(c["content"])}</pre>'
            f'</div></details>'
        )

        file_cards_html += (
            f'<div style="border:1px solid var(--surface0);border-radius:7px;'
            f'overflow:hidden;margin-bottom:8px">'
            f'<div style="display:flex;align-items:center;gap:10px;padding:8px 12px;'
            f'background:var(--base)">'
            f'<code style="color:var(--mauve);font-size:11px;flex:1">{h(c["name"])}</code>'
            f'{status_chip}'
            f'<span style="color:var(--overlay0);font-size:10px">{h(c["rel"])}</span>'
            f'</div>'
            f'{diff_html}'
            f'{full_html}'
            f'</div>'
        )

    if not obs_rows and not file_cards_html:
        return f"""<div class="section-inner">
  <h2 class="section-title">Memory Changes</h2>
  {section_desc(desc_text)}
  {empty_state("No memory files found in .claude/memory/")}
</div>"""

    n_obs   = len(all_obs)
    n_cards = len(cards)
    # Tab buttons use the global switchTab() from JS_TEMPLATE — no inline script needed
    return f"""<div class="section-inner">
  <h2 class="section-title">Memory Changes</h2>
  {section_desc(desc_text)}
  <div style="display:flex;gap:0;margin-bottom:14px;border-bottom:1px solid var(--surface0)">
    <button onclick="switchTab('mc','obs')"   id="mc-tab-obs"
            style="padding:6px 14px;font-size:11px;font-weight:600;cursor:pointer;border:none;
                   border-bottom:2px solid var(--mauve);background:transparent;color:var(--mauve)">
      Observations ({n_obs})</button>
    <button onclick="switchTab('mc','files')" id="mc-tab-files"
            style="padding:6px 14px;font-size:11px;font-weight:600;cursor:pointer;border:none;
                   border-bottom:2px solid transparent;background:transparent;color:var(--overlay0)">
      Memory Files ({n_cards})</button>
  </div>
  <div id="mc-pane-obs">{obs_rows if obs_rows else empty_state("No observations yet.")}</div>
  <div id="mc-pane-files" style="display:none">
    {file_cards_html if file_cards_html else empty_state("No .md files in .claude/memory/")}
  </div>
</div>"""

def render_skill_changes(hd):
    content  = hd.get("skill_report_content")
    last_mod = hd.get("skill_report_age")
    if not content:
        ccr = next((r for r in hd.get("ccr_routines", [])
                    if "skill" in r["name"].lower() or "curator" in r["name"].lower()), None)
        next_run = ccr["next_run"] if ccr else "next Monday at 09:00 IDT"
        d = section_desc(
            "The weekly CCR routine (<em>Weekly Skill-Curator + Memory Governance</em>) audits all "
            "skills in <code>~/.claude/skills/</code>, prunes stale ones, and writes a report here. "
            f"<strong style='color:var(--text)'>Next run: {next_run}</strong>. "
            "Until then, skill changes are visible via <em>Automation Audit</em> (session-quality entries)."
        )
        return f"""<div class="section-inner">
  <h2 class="section-title">Skill Changes</h2>
  {d}
  {empty_state("No report yet — waiting for first CCR run.")}
</div>"""
    return f"""<div class="section-inner">
  <h2 class="section-title">Skill Changes</h2>
  <div style="display:flex;align-items:center;gap:10px;margin-bottom:16px">
    <span style="color:var(--overlay0);font-size:12px">
      Last audit: <strong style="color:var(--subtext1)">{h(last_mod)}</strong></span>
    {badge("Weekly CCR", "info")}
  </div>
  <div style="font-size:12px;line-height:1.7">{mini_md(content)}</div>
</div>"""

def render_session_quality(rd):
    obs = rd["observations"]
    sq  = obs.get("session-quality", [])
    kr  = obs.get("keep-rate", [])
    mg  = obs.get("memory-gap", [])

    if not sq and not kr:
        return empty_state("No session quality data yet. Run daily-maintenance to start tracking.")

    score_re = re.compile(r'Score=(\d+)/5')
    keep_re  = re.compile(r'(\d+)%')
    gap_re   = re.compile(r'(\d+)\s+re-explanation')

    scores, keeps, gaps = [], [], []
    for d, t in sq:
        m = score_re.search(t)
        if m:
            scores.append((d, int(m.group(1))))
    for d, t in kr:
        m = keep_re.search(t)
        if m:
            keeps.append((d, int(m.group(1))))
    for d, t in mg:
        m = gap_re.search(t)
        if m:
            gaps.append((d, int(m.group(1))))

    avg_score  = sum(s for _, s in scores) / len(scores) if scores else None
    avg_keep   = sum(k for _, k in keeps)  / len(keeps)  if keeps  else None
    total_gaps = sum(g for _, g in gaps)

    sc  = ("#a6e3a1" if (avg_score or 0) >= 4 else
           "#f9e2af" if (avg_score or 0) >= 2.5 else "#f38ba8")
    kc  = ("#a6e3a1" if (avg_keep or 0) >= 70 else
           "#f9e2af" if (avg_keep or 0) >= 40  else "#f38ba8")
    gc  = ("var(--red)"    if total_gaps > 5 else
           "var(--yellow)" if total_gaps > 0  else "var(--green)")

    summary = f"""<div style="display:grid;grid-template-columns:repeat(3,1fr);
                       gap:12px;margin-bottom:20px">
    <div class="stat-card">
      <div class="stat-val" style="color:{sc}">
        {f"{avg_score:.1f}/5" if avg_score is not None else "—"}</div>
      <div class="stat-lbl">avg session score</div></div>
    <div class="stat-card">
      <div class="stat-val" style="color:{kc}">
        {f"{avg_keep:.0f}%" if avg_keep is not None else "—"}</div>
      <div class="stat-lbl">avg keep-rate</div></div>
    <div class="stat-card">
      <div class="stat-val" style="color:{gc}">{total_gaps}</div>
      <div class="stat-lbl">memory gaps (total)</div></div>
  </div>"""

    timeline = ""
    if scores:
        bars = ""
        for d, s in scores[-20:]:
            bh = int(s / 5 * 44)
            bc = ("#a6e3a1" if s >= 4 else "#f9e2af" if s >= 2.5 else "#f38ba8")
            bars += (
                f'<div title="{h(d)}: {s}/5" style="flex:1;display:flex;flex-direction:column;'
                f'align-items:center;justify-content:flex-end;gap:2px;min-width:14px">'
                f'<div style="font-size:8px;color:{bc};font-weight:600">{s}</div>'
                f'<div style="background:{bc};height:{bh}px;width:100%;border-radius:2px 2px 0 0;'
                f'opacity:0.85"></div></div>'
            )
        timeline = (
            f'<div class="label" style="margin-bottom:6px">Session scores (recent, 0–5)</div>'
            f'<div style="display:flex;align-items:flex-end;gap:3px;height:64px;'
            f'margin-bottom:16px">{bars}</div>'
        )

    recent = ""
    if mg:
        items = "".join(
            f'<li style="margin:3px 0">{h(d)}: {h(t[:120])}</li>'
            for d, t in mg[-5:]
        )
        recent = (f'<div class="label" style="margin-bottom:6px">Recent memory gaps</div>'
                  f'<ul style="padding-left:16px;margin:0;color:var(--subtext0);'
                  f'font-size:12px">{items}</ul>')

    glossary = """<div style="display:grid;grid-template-columns:repeat(3,1fr);gap:10px;margin-top:20px">
    <div style="background:var(--surface0);border-radius:6px;padding:10px 12px;font-size:11px">
      <div style="color:var(--blue);font-weight:600;margin-bottom:4px">📊 Session Score (0–5)</div>
      <div style="color:var(--subtext0);line-height:1.55">
        Rated by <code style="font-size:10px">impeccable-detect-hook</code> after each session.
        Measures tool discipline, instruction adherence, revert rate.
        <strong style="color:var(--subtext1)">Different from trust battery</strong> —
        trust is cumulative long-term; session score is per-session behavior.
      </div>
    </div>
    <div style="background:var(--surface0);border-radius:6px;padding:10px 12px;font-size:11px">
      <div style="color:var(--teal);font-weight:600;margin-bottom:4px">📌 Keep-Rate %</div>
      <div style="color:var(--subtext0);line-height:1.55">
        Of all changes Claude made in a session, what % was actually kept.
        100% = all work accepted. 50% = half was reverted.
        Low keep-rate often means unclear instructions or scope creep.
      </div>
    </div>
    <div style="background:var(--surface0);border-radius:6px;padding:10px 12px;font-size:11px">
      <div style="color:var(--yellow);font-weight:600;margin-bottom:4px">🧠 Memory Gaps</div>
      <div style="color:var(--subtext0);line-height:1.55">
        Times Claude re-explained something it should have remembered from memory.
        Detected by <code style="font-size:10px">memory-discipline-hook</code> at compaction.
        High gaps → add a memory entry for the repeated topic.
      </div>
    </div>
  </div>"""
    return f"""<div class="section-inner">
  <h2 class="section-title">Session Quality</h2>
  {summary}{timeline}{recent}
  {glossary}
</div>"""

def render_maintenance_status(selected_rd, all_repos_data, hd):
    runs = hd.get("orchestrator_runs", [])
    latest = {}
    for run in runs:
        p = run["path"]
        if p not in latest or run["ts"] > latest[p]["ts"]:
            latest[p] = run

    ccr_note = section_desc(
        "<strong style='color:var(--text)'>Local daily maintenance</strong> — runs via Windows Task Scheduler "
        "(judge · reflect · keep-rate · housekeep · augment). "
        "Not a CCR routine: it needs direct access to "
        "<code>.claude/memory/</code> which Anthropic's cloud cannot reach. "
        "Full per-event history is in <em>Automation Audit</em>."
    )

    SCHED_HOUR  = 18   # Windows Task Scheduler fires daily-orchestrator.sh at 18:00
    GRACE_SECS  = 2 * 3600  # 2h grace after scheduled time before OVERDUE

    def _repo_card(rd, compact=False):
        path     = rd["path"]
        name     = Path(path).name
        last_run = rd.get("last_routine_run")
        run_info = latest.get(path)

        if last_run:
            now_local   = datetime.now()
            today_sched = now_local.replace(
                hour=SCHED_HOUR, minute=0, second=0, microsecond=0)
            last_local  = (last_run.astimezone().replace(tzinfo=None)
                           if last_run.tzinfo else last_run)

            if last_local.date() == now_local.date():
                run_status = "ok"
            elif now_local < today_sched + timedelta(seconds=GRACE_SECS):
                run_status = "pending"   # today's 18:00 slot hasn't fired yet
            else:
                run_status = "overdue"

            run_str = rel_time(last_run.isoformat())
            run_col = {"ok": "var(--green)",
                       "pending": "var(--yellow)",
                       "overdue": "var(--red)"}[run_status]
            sbadge  = {"ok":      badge("OK",      "ok"),
                       "pending": badge("PENDING",  "warn"),
                       "overdue": badge("OVERDUE",  "missed")}[run_status]

            # "next run" hint for the detail card
            if run_status == "ok":
                next_hint = "Next: tomorrow at 18:00"
            elif run_status == "pending":
                next_hint = f"Scheduled today at {SCHED_HOUR:02d}:00"
            else:
                next_hint = f"Was due at {SCHED_HOUR:02d}:00 today — check Task Scheduler"
        else:
            run_str   = "never run"
            run_col   = "var(--overlay0)"
            sbadge    = badge("UNKNOWN", "default")
            next_hint = f"Next: today at {SCHED_HOUR:02d}:00 (if installed)"

        ec_html = dur_html = "—"
        if run_info:
            ec      = run_info["exit"]
            ec_col  = "var(--green)" if ec == 0 else "var(--red)"
            ec_html = f'<span style="color:{ec_col}">exit {ec}</span>'
            d       = run_info["duration"]
            dur_html = f"{d}s" if d > 0 else "—"

        if compact:
            return (
                f'<div style="background:var(--surface0);border-radius:6px;padding:10px 12px">'
                f'<div style="font-size:11px;font-weight:600;color:var(--text);'
                f'margin-bottom:4px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">'
                f'{h(name)}</div>'
                f'<div style="display:flex;gap:6px;align-items:center;flex-wrap:wrap">'
                f'{sbadge}'
                f'<span style="color:{run_col};font-size:10px">{h(run_str)}</span>'
                f'</div></div>'
            )

        return f"""<div style="border:1px solid var(--surface0);border-radius:8px;
                       padding:16px 18px;margin-bottom:12px">
      <div style="display:flex;align-items:center;gap:10px;margin-bottom:12px">
        <span style="font-size:14px;font-weight:700;color:var(--text)">{h(name)}</span>
        {sbadge}
      </div>
      <div style="display:grid;grid-template-columns:repeat(4,1fr);gap:12px">
        <div>
          <div class="label">Last run</div>
          <div style="color:{run_col};font-size:13px;margin-top:3px">{h(run_str)}</div>
        </div>
        <div>
          <div class="label">Next run</div>
          <div style="font-size:12px;color:var(--subtext0);margin-top:3px">{h(next_hint)}</div>
        </div>
        <div>
          <div class="label">Duration</div>
          <div style="font-size:13px;color:var(--subtext1);margin-top:3px">{dur_html}</div>
        </div>
        <div>
          <div class="label">Exit code</div>
          <div style="font-size:13px;margin-top:3px">{ec_html}</div>
        </div>
      </div>
    </div>"""

    sel_path = selected_rd["path"]
    others   = [rd for rd in all_repos_data if rd["path"] != sel_path]

    other_html = ""
    if others:
        grid = "".join(_repo_card(rd, compact=True) for rd in others)
        other_html = (
            f'<div style="margin-top:8px">'
            f'<div class="label" style="margin-bottom:8px">Other repos</div>'
            f'<div style="display:grid;grid-template-columns:repeat(auto-fill,minmax(160px,1fr));'
            f'gap:8px">{grid}</div></div>'
        )

    log_tail = ""
    if ORCH_LOG.exists():
        lines    = ORCH_LOG.read_text().splitlines()[-12:]
        log_tail = (
            f'<details style="margin-top:16px">'
            f'<summary style="cursor:pointer;font-size:9px;text-transform:uppercase;'
            f'letter-spacing:1px;color:var(--overlay0);list-style:none;'
            f'padding:4px 0">Orchestrator log (last 12 lines)</summary>'
            f'<pre style="background:var(--crust);border-radius:6px;padding:12px;margin-top:6px;'
            f'font-size:10px;color:var(--subtext0);overflow-x:auto;white-space:pre-wrap">'
            f'{h(chr(10).join(lines))}</pre></details>'
        )

    return f"""<div class="section-inner">
  <h2 class="section-title">Maintenance Status</h2>
  {ccr_note}
  {_repo_card(selected_rd)}
  {other_html}
  {log_tail}
</div>"""

def render_automation_audit(rd, hd):
    """Timeline of every automated event: maintenance, trust judge, session signals, CCR."""
    from collections import defaultdict

    events = []
    repo_path = rd["path"]

    # 1. Orchestrator maintenance runs for this repo
    for run in hd.get("orchestrator_runs", []):
        if run["path"] == repo_path:
            ok = run["exit"] == 0
            events.append({
                "ts":      run["ts"],
                "icon":    "🔧",
                "label":   "Daily Maintenance",
                "color":   "#a6e3a1" if ok else "#f38ba8",
                "summary": f"exit {run['exit']} · {run['duration']}s",
                "detail":  None,
                "scope":   "local",
            })

    # 2. Trust judge entries (structured, from trust-score.jsonl)
    for score in rd.get("trust_scores", []):
        ts    = score.get("ts", "")
        delta = score.get("delta_applied", 0)
        cur   = score.get("score", 0)
        if delta > 0:
            delta_str, color = f"▲ +{delta:.1f}", "#a6e3a1"
        elif delta < 0:
            delta_str, color = f"▼ {delta:.1f}", "#f38ba8"
        else:
            delta_str, color = "▬ ±0", "#6c7086"
        events.append({
            "ts":      ts,
            "icon":    "⚡",
            "label":   "Trust Judge",
            "color":   color,
            "summary": f"{delta_str} → {cur:.0f}%",
            "detail":  score.get("summary") or None,
            "scope":   "local",
        })

    # 3. Automated observation tags (session signals, memory, skill queue)
    obs = rd.get("observations", {})
    OBS_TAGS = [
        ("session-quality",  "📊", "Session Quality", "#89b4fa"),
        ("keep-rate",        "📌", "Keep-Rate",        "#94e2d5"),
        ("memory-gap",       "🧠", "Memory Gap",       "#f9e2af"),
        ("skill-audit-queue","🎯", "Skill Queue",      "#fab387"),
    ]
    for tag, icon, label, color in OBS_TAGS:
        for date_str, text in obs.get(tag, []):
            events.append({
                "ts":      date_str + "T12:00:00+00:00",
                "icon":    icon,
                "label":   label,
                "color":   color,
                "summary": text[:110],
                "detail":  text if len(text) > 110 else None,
                "scope":   "local",
            })

    # 4. CCR routine runs (harness-wide, shown for context)
    for r in hd.get("ccr_routines", []):
        ts_iso = r.get("last_run_ts_iso")
        if ts_iso:
            events.append({
                "ts":      ts_iso,
                "icon":    "📅",
                "label":   r["name"],
                "color":   "#cba6f7",
                "summary": f"CCR · {r['schedule_human']} · next: {r['next_run']}",
                "detail":  f"Trigger ID: {r['id']}\nOutput: {r.get('output_file') or '—'}",
                "scope":   "harness",
            })

    if not events:
        return f"""<div class="section-inner">
  <h2 class="section-title">Automation Audit</h2>
  {empty_state("No automation history yet. Run daily-maintenance to start tracking.")}
</div>"""

    events.sort(key=lambda e: e["ts"], reverse=True)

    # Group by calendar date
    by_date = defaultdict(list)
    for ev in events[:100]:
        by_date[ev["ts"][:10]].append(ev)

    feed = ""
    for date_key in sorted(by_date.keys(), reverse=True):
        day_evs = by_date[date_key]
        try:
            dt   = datetime.fromisoformat(date_key + "T12:00:00+00:00")
            secs = (NOW - dt).total_seconds()
            if secs < 86400:
                rel = "today"
            elif secs < 172800:
                rel = "yesterday"
            else:
                rel = f"{int(secs/86400)}d ago"
            date_lbl = dt.strftime("%a %d %b %Y")
        except Exception:
            date_lbl, rel = date_key, ""

        n = len(day_evs)
        feed += (
            f'<div style="margin-bottom:18px">'
            f'<div style="display:flex;align-items:center;gap:10px;margin-bottom:8px">'
            f'<span style="font-size:11px;font-weight:700;color:var(--subtext1)">{h(date_lbl)}</span>'
            f'<span style="font-size:10px;color:var(--overlay0)">{h(rel)}</span>'
            f'<div style="flex:1;height:1px;background:var(--surface0)"></div>'
            f'<span style="font-size:10px;color:var(--overlay0)">'
            f'{n} event{"s" if n != 1 else ""}</span>'
            f'</div>'
        )

        for ev in day_evs:
            scope_pill = (
                '<span style="font-size:9px;padding:1px 5px;border-radius:8px;'
                'background:rgba(137,180,250,0.12);color:#89b4fa">local</span>'
                if ev["scope"] == "local" else
                '<span style="font-size:9px;padding:1px 5px;border-radius:8px;'
                'background:rgba(203,166,247,0.12);color:#cba6f7">harness</span>'
            )
            row_inner = (
                f'<span style="font-size:14px;width:22px;text-align:center;flex-shrink:0">'
                f'{h(ev["icon"])}</span>'
                f'<span style="font-size:12px;font-weight:600;min-width:134px;flex-shrink:0;'
                f'color:{h(ev["color"])}">{h(ev["label"])}</span>'
                f'{scope_pill}'
                f'<span style="flex:1;font-size:11px;color:var(--subtext0);'
                f'overflow:hidden;text-overflow:ellipsis;white-space:nowrap;'
                f'padding:0 8px">{h(ev["summary"])}</span>'
                f'<span style="font-size:10px;color:var(--overlay0);flex-shrink:0">'
                f'{h(rel_time(ev["ts"]))}</span>'
            )
            wrap_s = ("margin-bottom:3px;border:1px solid var(--surface0);"
                      "border-radius:6px;overflow:hidden")
            row_s  = ("display:flex;align-items:center;gap:8px;padding:7px 12px;"
                      "background:var(--base)")
            if ev.get("detail"):
                detail_block = (
                    f'<div style="padding:8px 12px 8px 38px;font-size:11px;'
                    f'color:var(--subtext0);background:rgba(0,0,0,0.2);'
                    f'border-top:1px solid var(--surface0);line-height:1.65;'
                    f'white-space:pre-wrap;word-break:break-word">'
                    f'{h(ev["detail"])}</div>'
                )
                feed += (
                    f'<details style="{wrap_s}">'
                    f'<summary style="{row_s};cursor:pointer">{row_inner}</summary>'
                    f'{detail_block}</details>'
                )
            else:
                feed += (
                    f'<div style="{wrap_s}">'
                    f'<div style="{row_s}">{row_inner}</div></div>'
                )

        feed += "</div>"

    return f"""<div class="section-inner">
  <h2 class="section-title">Automation Audit</h2>
  <div style="color:var(--overlay0);font-size:11px;margin-bottom:16px">
    Every automated task and scheduled routine — what ran and what changed.
    Click any row with a ▶ to expand detail.
  </div>
  {feed}
</div>"""

# ── CSS ───────────────────────────────────────────────────────────────────────

CSS = """
*,*::before,*::after{box-sizing:border-box;margin:0;padding:0}
:root{
  --base:#1e1e2e;--mantle:#181825;--crust:#11111b;
  --surface0:#313244;--surface1:#45475a;
  --overlay0:#6c7086;--overlay1:#7f849c;
  --subtext0:#a6adc8;--subtext1:#bac2de;--text:#cdd6f4;
  --mauve:#cba6f7;--red:#f38ba8;--peach:#fab387;
  --yellow:#f9e2af;--green:#a6e3a1;--teal:#94e2d5;--blue:#89b4fa;
}
html,body{height:100%;background:var(--mantle);color:var(--text);
  font-family:system-ui,-apple-system,sans-serif;font-size:14px;line-height:1.5}
.app{display:flex;height:100vh;overflow:hidden}
.sidebar{width:210px;min-width:210px;background:var(--base);
  border-right:1px solid var(--surface0);display:flex;
  flex-direction:column;overflow-y:auto}
.sidebar-header{padding:18px 16px 14px;font-size:15px;font-weight:700;
  color:var(--text);letter-spacing:-.3px;border-bottom:1px solid var(--surface0)}
.sidebar-header span{color:var(--mauve)}
.repo-wrap{padding:10px 12px;border-bottom:1px solid var(--surface0)}
.repo-wrap select{width:100%;background:var(--surface0);color:var(--text);
  border:1px solid var(--surface1);border-radius:6px;padding:5px 8px;
  font-size:11px;cursor:pointer;outline:none}
.repo-wrap select:focus{border-color:var(--mauve)}
.nav-group-label{padding:10px 14px 4px;font-size:9px;text-transform:uppercase;
  letter-spacing:1.2px;color:var(--overlay0)}
.nav-item{display:flex;align-items:center;gap:8px;padding:7px 14px;
  font-size:12px;color:var(--subtext0);cursor:pointer;
  border-left:2px solid transparent;text-decoration:none;
  transition:all .12s;user-select:none}
.nav-item:hover{background:rgba(255,255,255,.04);color:var(--text)}
.nav-item.active{color:var(--mauve);border-left-color:var(--mauve);
  background:rgba(203,166,247,.08)}
.nav-icon{font-size:13px}
.sidebar-footer{margin-top:auto;padding:12px 14px;
  border-top:1px solid var(--surface0)}
.content{flex:1;overflow-y:auto;background:var(--mantle)}
.section-inner{padding:24px 28px;max-width:920px}
.section-title{font-size:18px;font-weight:700;color:var(--text);margin-bottom:20px}
.label{font-size:9px;text-transform:uppercase;letter-spacing:1px;color:var(--overlay0)}
.stat-card{background:var(--surface0);border-radius:8px;padding:12px 14px;text-align:center}
.stat-val{font-size:22px;font-weight:800;font-family:ui-monospace,Consolas,monospace}
.stat-lbl{font-size:10px;color:var(--overlay0);text-transform:uppercase;
  letter-spacing:.8px;margin-top:2px}
.th{text-align:left;padding:8px 10px;font-size:9px;text-transform:uppercase;
  letter-spacing:.8px;color:var(--overlay0);font-weight:600}
td{padding:8px 10px;border-bottom:1px solid rgba(49,50,68,.5)}
"""

# ── JS ────────────────────────────────────────────────────────────────────────

JS_TEMPLATE = r"""
const SD = __SECTIONS_JSON__;
let repo = __INIT_REPO__;
let sec  = 'trust_battery';

function show(sectionKey) {
  // Release gitnexus WebGL context before destroying the iframe element
  var oldFrame = document.getElementById('gn-frame');
  if (oldFrame && oldFrame.src) { oldFrame.src = ''; }
  _gnProbing = false;
  sec = sectionKey;
  var d = SD[repo];
  document.getElementById('panel').innerHTML =
    d ? (d[sectionKey] || '<div class="section-inner"><p style="color:var(--overlay0)">Not available.</p></div>')
      : '<div class="section-inner"><p style="color:var(--overlay0)">No data.</p></div>';
  document.querySelectorAll('.nav-item').forEach(function(el) {
    el.classList.toggle('active', el.dataset.s === sectionKey);
  });
  if (sectionKey === 'gitnexus') probeGitnexus();
  if (sectionKey === 'workshop') loadWorkshopRuns();
}

function switchRepo(v) { repo = v; show(sec); }

var _gnProbing = false;
function probeGitnexus() {
  if (_gnProbing) return;
  _gnProbing = true;
  var ctrl  = new AbortController();
  var timer = setTimeout(function() { ctrl.abort(); }, 2500);
  fetch('http://localhost:4747', { mode: 'no-cors', signal: ctrl.signal })
    .then(function() {
      clearTimeout(timer);
      _gnProbing = false;
      var f  = document.getElementById('gn-frame');
      var fb = document.getElementById('gn-fallback');
      if (f)  { f.src = f.dataset.src || 'http://localhost:4747'; f.style.display = 'block'; }
      if (fb) fb.style.display = 'none';
    })
    .catch(function() {
      clearTimeout(timer);
      _gnProbing = false;
      var st    = document.getElementById('gn-status');
      var btn   = document.getElementById('gn-copy-btn');
      var hint  = document.getElementById('gn-copy-hint');
      var sbtn  = document.getElementById('gn-start-btn');
      var rbtn  = document.getElementById('gn-retry-btn');
      if (st)   st.textContent = 'GitNexus not running';
      if (btn)  btn.style.display  = 'block';
      if (hint) hint.style.display = 'block';
      if (sbtn) sbtn.style.display = 'block';
      if (rbtn) rbtn.style.display = 'block';
    });
}

__GN_SERVE_FUNS__

__WORKSHOP_FUNS__

// Generic tab switcher — used by Memory Changes and any future tabbed section.
// Tab pane IDs follow the pattern: <prefix>-pane-<name>
// Tab button IDs follow: <prefix>-tab-<name>
function switchTab(prefix, pane, panes) {
  panes = panes || ['obs', 'files'];
  panes.forEach(function(p) {
    var el  = document.getElementById(prefix + '-pane-' + p);
    var btn = document.getElementById(prefix + '-tab-' + p);
    if (el)  el.style.display = (p === pane) ? 'block' : 'none';
    if (btn) {
      btn.style.borderBottomColor = (p === pane) ? 'var(--mauve)' : 'transparent';
      btn.style.color             = (p === pane) ? 'var(--mauve)' : 'var(--overlay0)';
    }
  });
}

document.addEventListener('DOMContentLoaded', function() { show('trust_battery'); });
"""

# ── HTML Assembly ─────────────────────────────────────────────────────────────

def build_html(repos_data, harness_data, initial_idx=0, companion=False):
    repos = [rd["path"] for rd in repos_data]

    repo_opts = "\n".join(
        f'<option value="{h(p)}"{"" if i != initial_idx else " selected"}>'
        f'{h(Path(p).name)}</option>'
        for i, p in enumerate(repos)
    )

    nav = "\n".join(
        f'<a class="nav-item{" active" if key == "trust_battery" else ""}" '
        f'data-s="{key}" href="#" '
        f'onclick="show(\'{key}\');return false;">'
        f'<span class="nav-icon">{icon}</span><span>{label}</span></a>'
        for key, icon, label in SECTION_DEFS
    )

    # Render all sections for every repo once
    ccr_html    = render_ccr_routines(harness_data)
    skill_html  = render_skill_changes(harness_data)

    sections_map = {}
    for rd in repos_data:
        sections_map[rd["path"]] = {
            "trust_battery":      render_trust_battery(rd),
            "gitnexus":           render_gitnexus(rd, companion=companion),
            "workshop":           render_workshop(rd, companion=companion),
            "hooks_history":      render_hooks_history(rd),
            "ccr_routines":       ccr_html,
            "memory_changes":     render_memory_changes(rd, harness_data),
            "skill_changes":      skill_html,
            "session_quality":    render_session_quality(rd),
            "maintenance_status": render_maintenance_status(rd, repos_data, harness_data),
            "automation_audit":   render_automation_audit(rd, harness_data),
        }

    sj  = json.dumps(sections_map, ensure_ascii=False)
    # Escape any </script> or </Script> etc. that would break the enclosing script tag
    import re as _re
    sj  = _re.sub(r'(?i)</script>', r'<\/script>', sj)
    ir  = json.dumps(repos[initial_idx] if repos else "")

    gn_funs = """
function startGitnexus(repoPath) {
  var st   = document.getElementById('gn-status');
  var sbtn = document.getElementById('gn-start-btn');
  var cbtn = document.getElementById('gn-copy-btn');
  var hint = document.getElementById('gn-copy-hint');
  if (st)   st.textContent = 'Starting gitnexus serve…';
  if (sbtn) sbtn.style.display = 'none';
  if (cbtn) cbtn.style.display = 'none';
  if (hint) hint.style.display = 'none';
  fetch('/api/gitnexus-serve?repo=' + encodeURIComponent(repoPath), { method: 'POST' })
    .then(function() { pollGitnexus(0); })
    .catch(function() {
      if (st) st.textContent = 'Could not reach companion server';
    });
}
function pollGitnexus(n) {
  var st = document.getElementById('gn-status');
  if (n > 20) {
    if (st) st.textContent = 'Timed out — is gitnexus installed?';
    return;
  }
  if (st) st.textContent = 'Waiting for gitnexus… (' + (n + 1) + '/20)';
  var ctrl = new AbortController();
  setTimeout(function() { ctrl.abort(); }, 1500);
  fetch('http://localhost:4747', { mode: 'no-cors', signal: ctrl.signal })
    .then(function() {
      var f  = document.getElementById('gn-frame');
      var fb = document.getElementById('gn-fallback');
      if (f)  { f.src = f.dataset.src || 'http://localhost:4747'; f.style.display = 'block'; }
      if (fb) { fb.style.display = 'none'; }
    })
    .catch(function() {
      setTimeout(function() { pollGitnexus(n + 1); }, 1000);
    });
}""" if companion else ""

    workshop_funs = """
function _wsOpen()       { window.open('http://localhost:5899', '_blank'); }
function _wsHover(el,on) { el.style.background = on ? 'var(--surface0)' : ''; }
function _wsCopy(el)     { navigator.clipboard.writeText('raindrop workshop'); el.textContent = '✓ Copied!'; }

function loadWorkshopRuns() {
  var panel = document.getElementById('ws-runs-panel');
  if (!panel) return;
  var eventName = panel.dataset.eventName || '';
  panel.innerHTML = '<div style="color:var(--subtext0);padding:40px;text-align:center">Loading…</div>';
  fetch('/api/workshop-runs?event_name=' + encodeURIComponent(eventName))
    .then(function(r) { if (!r.ok) throw new Error('offline'); return r.json(); })
    .then(function(runs) { _wsRenderRuns(runs, panel, eventName); })
    .catch(function() { _wsRenderOffline(panel); });
}

function _wsRelTime(ms) {
  var d = Date.now() - ms;
  if (d < 60000)   return Math.round(d / 1000) + 's ago';
  if (d < 3600000) return Math.round(d / 60000) + 'm ago';
  if (d < 86400000) return Math.round(d / 3600000) + 'h ago';
  return new Date(ms).toLocaleDateString();
}

function _wsEsc(s) {
  return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
}

function _wsRenderRuns(runs, panel, eventName) {
  if (!runs.length) {
    panel.innerHTML =
      '<div style="color:var(--subtext0);padding:40px;text-align:center">' +
      '<div style="font-size:28px;margin-bottom:8px">🔬</div>' +
      '<div>No runs yet for <code style="color:var(--text)">' + _wsEsc(eventName) + '</code></div>' +
      '<div style="margin-top:8px;font-size:11px;color:var(--overlay0)">Run the app and a trace will appear here.</div>' +
      '</div>';
    return;
  }
  var shown = Math.min(runs.length, 50);
  var rows = runs.slice(0, shown).map(function(r) {
    var ts     = _wsRelTime(r.started_at);
    var input  = '';
    try { input = (JSON.parse(r.metadata || '{}').input || '').slice(0, 80); } catch(e) {}
    if (!input) input = '(no input)';
    var status = r.finished
      ? '<span style="color:var(--green)">&#x2713;</span>'
      : '<span style="color:var(--yellow)">⧗ live</span>';
    var user   = _wsEsc(r.user_id || '–');
    var convo  = r.convo_id ? '<span style="color:var(--overlay0)">' + _wsEsc(r.convo_id) + '</span>' : '';
    var spans  = r.span_count || 0;
    return '<tr style="border-bottom:1px solid var(--surface0);cursor:pointer"'
      + ' onclick="_wsOpen()" onmouseenter="_wsHover(this,true)" onmouseleave="_wsHover(this,false)">' +
      '<td style="padding:10px 12px;color:var(--subtext1);font-size:11px;white-space:nowrap">' + ts + '</td>' +
      '<td style="padding:10px 12px;max-width:280px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;font-size:12px">' + _wsEsc(input) + '</td>' +
      '<td style="padding:10px 12px;font-size:11px;color:var(--subtext1)">' + user + (convo ? '<br>' + convo : '') + '</td>' +
      '<td style="padding:10px 8px;font-size:11px;text-align:center">' + status + '</td>' +
      '<td style="padding:10px 12px;font-size:11px;color:var(--overlay0);text-align:right">' + spans + '</td>' +
      '</tr>';
  }).join('');
  panel.innerHTML =
    '<div style="padding:8px 12px;font-size:11px;color:var(--subtext0);' +
    'border-bottom:1px solid var(--surface0);display:flex;justify-content:space-between;align-items:center">' +
    '<span>Showing ' + shown + ' of ' + runs.length + ' runs — click a row to open in Workshop</span>' +
    '<span style="color:var(--overlay0)">' + _wsEsc(eventName) + '</span></div>' +
    '<table style="width:100%;border-collapse:collapse"><thead>' +
    '<tr style="background:var(--base)">' +
    '<th style="padding:6px 12px;text-align:left;font-size:10px;color:var(--overlay0);font-weight:500">TIME</th>' +
    '<th style="padding:6px 12px;text-align:left;font-size:10px;color:var(--overlay0);font-weight:500">INPUT</th>' +
    '<th style="padding:6px 12px;text-align:left;font-size:10px;color:var(--overlay0);font-weight:500">USER / SESSION</th>' +
    '<th style="padding:6px 8px;font-size:10px;color:var(--overlay0);font-weight:500">OK</th>' +
    '<th style="padding:6px 12px;text-align:right;font-size:10px;color:var(--overlay0);font-weight:500">SPANS</th>' +
    '</tr></thead><tbody>' + rows + '</tbody></table>';
}

function _wsRenderOffline(panel) {
  panel.innerHTML =
    '<div style="display:flex;flex-direction:column;align-items:center;justify-content:center;' +
    'height:240px;gap:12px;padding:40px;text-align:center">' +
    '<div style="font-size:32px">🔬</div>' +
    '<div style="color:var(--subtext0);font-size:13px">Workshop not running</div>' +
    '<button style="background:var(--teal);color:var(--crust);border:none;border-radius:6px;' +
    'padding:9px 18px;font-size:12px;font-weight:600;cursor:pointer" ' +
    'onclick="startWorkshop()">▶ Start raindrop workshop</button>' +
    '<div style="background:var(--surface0);border-radius:6px;padding:8px 16px;' +
    'font-family:monospace;font-size:12px;color:var(--text);cursor:pointer" ' +
    'onclick="_wsCopy(this)">raindrop workshop  📋</div>' +
    '</div>';
}

function startWorkshop() {
  var panel = document.getElementById('ws-runs-panel');
  if (panel) panel.innerHTML = '<div style="color:var(--subtext0);padding:40px;text-align:center">Starting Workshop…</div>';
  fetch('/api/workshop-start', { method: 'POST' })
    .then(function() { _wsPollThenLoad(0); })
    .catch(function() {
      if (panel) panel.innerHTML = '<div style="color:var(--red);padding:40px;text-align:center">Could not reach companion server</div>';
    });
}

function _wsPollThenLoad(n) {
  if (n > 20) { var panel = document.getElementById('ws-runs-panel'); if (panel) _wsRenderOffline(panel); return; }
  fetch('/api/workshop-runs')
    .then(function(r) { if (r.ok) loadWorkshopRuns(); else throw new Error(); })
    .catch(function() { setTimeout(function() { _wsPollThenLoad(n + 1); }, 1000); });
}

function runEvalLoop(repoPath, repoName) {
  var btn = document.getElementById('ws-eval-btn');
  if (btn) { btn.disabled = true; btn.textContent = '⚗ Starting…'; }
  fetch('/api/workshop-eval?repo=' + encodeURIComponent(repoPath), { method: 'POST' })
    .then(function(r) { return r.json(); })
    .then(function() {
      if (btn) { btn.textContent = '✓ Running in terminal'; }
      setTimeout(function() { if (btn) { btn.disabled = false; btn.textContent = '⚗ Run Eval Loop'; } }, 8000);
    })
    .catch(function() { if (btn) { btn.disabled = false; btn.textContent = '⚗ Run Eval Loop'; } });
}""" if companion else ""

    js  = (JS_TEMPLATE
           .replace("__SECTIONS_JSON__", sj)
           .replace("__INIT_REPO__", ir)
           .replace("__GN_SERVE_FUNS__", gn_funs)
           .replace("__WORKSHOP_FUNS__", workshop_funs))
    ts  = datetime.now().strftime("%Y-%m-%d %H:%M")

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width,initial-scale=1.0">
  <title>SDD Harness Dashboard</title>
  <style>{CSS}</style>
</head>
<body>
<div class="app">
  <aside class="sidebar">
    <div class="sidebar-header"><span>⬡</span> SDD Harness</div>
    <div class="repo-wrap">
      <div class="label" style="margin-bottom:5px">Repository</div>
      <select onchange="switchRepo(this.value)">{repo_opts}</select>
    </div>
    <div class="nav-group-label">Sections</div>
    <nav>{nav}</nav>
    <div class="sidebar-footer">
      <div style="color:var(--overlay0);font-size:10px">Generated {ts}</div>
    </div>
  </aside>
  <main class="content"><div id="panel"></div></main>
</div>
<script>{js}</script>
</body>
</html>"""

# ── Companion Server ──────────────────────────────────────────────────────────

def _wsl_to_windows(path: str) -> str | None:
    """Convert /mnt/c/foo → C:\\foo. Returns None if not a /mnt/<drive>/ path."""
    import re as _re
    m = _re.match(r'^/mnt/([a-zA-Z])(/.*)?$', path)
    if not m:
        return None
    drive   = m.group(1).upper()
    rest    = (m.group(2) or "").replace("/", "\\")
    return f"{drive}:{rest}"


def _start_gitnexus_serve(repo_path: str) -> None:
    """Start gitnexus serve for repo_path.

    - Windows filesystem paths (/mnt/<drive>/…) → launch via powershell.exe
      so the database reads happen at native NTFS speed.
    - WSL-native paths → launch directly.
    """
    win_path = _wsl_to_windows(repo_path)
    if win_path:
        # Kill any WSL gitnexus serve first (port 4747 is shared in WSL2)
        subprocess.Popen(
            ["pkill", "-f", "gitnexus serve"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
        import time as _time; _time.sleep(0.8)
        # Launch via PowerShell so it runs as a Windows-native process
        ps_cmd = f"Set-Location '{win_path}'; gitnexus serve"
        try:
            subprocess.Popen(
                ["powershell.exe", "-NoProfile", "-NonInteractive",
                 "-WindowStyle", "Hidden", "-Command", ps_cmd],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            )
            return
        except FileNotFoundError:
            pass  # fall through to WSL attempt
    # WSL-native path (or PowerShell unavailable) — launch directly
    for cmd in [["gitnexus", "serve"], ["npx", "gitnexus", "serve"]]:
        try:
            subprocess.Popen(
                cmd, cwd=repo_path,
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            )
            return
        except FileNotFoundError:
            continue


def _start_workshop() -> None:
    """Start raindrop workshop (port 5899). Workshop runs globally, not per-repo."""
    for cmd in [["raindrop", "workshop"], ["raindrop", "workshop", "--port", "5899"]]:
        try:
            subprocess.Popen(
                cmd,
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            )
            return
        except FileNotFoundError:
            continue


def _run_workshop_eval(repo_path: str) -> None:
    """Spawn a claude --print session to run the raindrop-eval-loop skill for repo_path."""
    repo_name = Path(repo_path).name
    prompt = (
        f"Use the raindrop-eval-loop skill to run the self-healing eval loop "
        f"for the repository '{repo_name}' at {repo_path}. "
        f"Workshop is running at http://localhost:5899."
    )
    env = {**os.environ, "RAINDROP_LOCAL_DEBUGGER": "http://localhost:5899/v1/"}
    for cmd in [["claude", "--print", prompt], ["claude-code", "--print", prompt]]:
        try:
            subprocess.Popen(
                cmd, cwd=repo_path,
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                env=env,
            )
            return
        except FileNotFoundError:
            continue


class _DashboardHandler(BaseHTTPRequestHandler):
    _html: bytes = b""

    GN_PORT = 4747  # gitnexus serve default port
    WS_PORT = 5899  # raindrop workshop default port

    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path == "/":
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(self._html)))
            self.end_headers()
            self.wfile.write(self._html)
        elif parsed.path.startswith("/gn/") or parsed.path == "/gn":
            self._proxy_gitnexus(parsed)
        elif parsed.path == "/api/workshop-runs":
            qs         = parse_qs(parsed.query)
            event_name = qs.get("event_name", [""])[0]
            try:
                req = UrlRequest(f"http://127.0.0.1:{self.WS_PORT}/api/runs")
                with urlopen(req, timeout=3) as resp:
                    all_runs = json.loads(resp.read())
                if event_name:
                    all_runs = [r for r in all_runs if r.get("event_name") == event_name]
                body = json.dumps(all_runs).encode()
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.send_header("Access-Control-Allow-Origin", "*")
                self.end_headers()
                self.wfile.write(body)
            except Exception:
                self.send_response(503)
                self.send_header("Content-Type", "application/json")
                self.send_header("Access-Control-Allow-Origin", "*")
                self.end_headers()
                self.wfile.write(b'{"error":"workshop-offline"}')
        elif parsed.path.startswith("/workshop/") or parsed.path == "/workshop":
            self._proxy_workshop(parsed)
        else:
            self.send_error(404)

    def _proxy_gitnexus(self, parsed):
        """Proxy to gitnexus serve, injecting auto-repo-select script into HTML."""
        qs_params = parse_qs(parsed.query)
        auto_repo = qs_params.pop("autoRepo", [None])[0]

        # Build target path (strip /gn prefix)
        gn_path = parsed.path[3:] or "/"
        target_qs = urlencode({k: v[0] for k, v in qs_params.items()})
        target_url = f"http://127.0.0.1:{self.GN_PORT}{gn_path}"
        if target_qs:
            target_url += f"?{target_qs}"

        try:
            req = UrlRequest(target_url, headers={"Accept": self.headers.get("Accept", "*/*")})
            with urlopen(req, timeout=8) as resp:
                content     = resp.read()
                content_type = resp.headers.get("Content-Type", "application/octet-stream")
                status       = resp.status
        except URLError:
            self.send_error(502, "gitnexus serve not reachable at port 4747")
            return
        except Exception as e:
            self.send_error(502, str(e))
            return

        # For HTML: rewrite absolute /assets/ and /api/ URLs to point at gitnexus,
        # then inject the auto-repo-select script.
        if b"text/html" in content_type.encode() and b"</head>" in content:
            gn_origin = f"http://127.0.0.1:{self.GN_PORT}"
            # Rewrite absolute-path references so browser fetches from gitnexus, not 4569
            content = content.replace(b'href="/', f'href="{gn_origin}/'.encode())
            content = content.replace(b'src="/',  f'src="{gn_origin}/'.encode())

            if auto_repo:
                inject = f"""<script>
(function(){{
  var want = {json.dumps(auto_repo)};
  function tryClick(){{
    var cards = document.querySelectorAll('[data-testid="landing-repo-card"]');
    for(var i=0;i<cards.length;i++){{
      if(cards[i].textContent.indexOf(want) !== -1){{ cards[i].click(); return true; }}
    }}
    return false;
  }}
  var n=0;
  function poll(){{ if(n++>40||tryClick()) return; setTimeout(poll,250); }}
  if(document.readyState==='loading')
    document.addEventListener('DOMContentLoaded', function(){{ setTimeout(poll,100); }});
  else setTimeout(poll,100);
}})();
</script>
</head>""".encode()
                content = content.replace(b"</head>", inject, 1)

        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(content)

    def _proxy_workshop(self, parsed):
        """Proxy to raindrop workshop UI at port 5899."""
        ws_path = parsed.path[9:] or "/"  # strip /workshop prefix
        target_url = f"http://127.0.0.1:{self.WS_PORT}{ws_path}"
        if parsed.query:
            target_url += f"?{parsed.query}"

        try:
            req = UrlRequest(target_url, headers={"Accept": self.headers.get("Accept", "*/*")})
            with urlopen(req, timeout=8) as resp:
                content      = resp.read()
                content_type = resp.headers.get("Content-Type", "application/octet-stream")
                status       = resp.status
        except URLError:
            self.send_error(502, "Raindrop Workshop not reachable at port 5899")
            return
        except Exception as e:
            self.send_error(502, str(e))
            return

        if b"text/html" in content_type.encode() and b"</head>" in content:
            ws_origin = f"http://127.0.0.1:{self.WS_PORT}"
            content = content.replace(b'href="/', f'href="{ws_origin}/'.encode())
            content = content.replace(b'src="/',  f'src="{ws_origin}/'.encode())

        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(content)

    def do_POST(self):
        parsed = urlparse(self.path)
        if parsed.path == "/api/gitnexus-serve":
            qs = parse_qs(parsed.query)
            repo_path = qs.get("repo", [""])[0]
            if repo_path and Path(repo_path).is_dir():
                _start_gitnexus_serve(repo_path)
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(b'{"ok":true}')
        elif parsed.path == "/api/workshop-start":
            _start_workshop()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(b'{"ok":true}')
        elif parsed.path == "/api/workshop-eval":
            qs = parse_qs(parsed.query)
            repo_path = qs.get("repo", [""])[0]
            if repo_path and Path(repo_path).is_dir():
                _run_workshop_eval(repo_path)
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(b'{"ok":true}')
        else:
            self.send_error(404)

    def log_message(self, *_args):
        """Suppress default request logging."""


def serve_companion(html_content: str, port: int, open_browser_fn):
    _DashboardHandler._html = html_content.encode("utf-8")
    httpd = HTTPServer(("127.0.0.1", port), _DashboardHandler)
    url = f"http://localhost:{port}"
    print(f"   Dashboard: {url}  (Ctrl+C to stop)")
    open_browser_fn(url)
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n   Stopped.")


# ── Browser Open ──────────────────────────────────────────────────────────────

def open_browser(url: str):
    try:
        with open("/proc/version") as f:
            if "microsoft" in f.read().lower():
                for cmd in [["wslview", url], ["explorer.exe", url]]:
                    try:
                        subprocess.Popen(cmd,
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                        return
                    except FileNotFoundError:
                        continue
    except Exception:
        pass
    for cmd in [["xdg-open", url], ["sensible-browser", url]]:
        try:
            subprocess.Popen(cmd,
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return
        except FileNotFoundError:
            continue
    print(f"   Open manually: {url}")

# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    ap = argparse.ArgumentParser(description="SDD Harness Dashboard")
    ap.add_argument("--repo",    help="Pre-select a repo path or name")
    ap.add_argument("--no-open", action="store_true",
                    help="Start server without opening browser")
    ap.add_argument("--static",  action="store_true",
                    help="Write static file to .dashboard/index.html instead of starting server")
    args = ap.parse_args()

    print("⬡  SDD Harness Dashboard")
    print(f"   Harness: {HARNESS_DIR}")

    repos = discover_repos()
    if not repos:
        print(f"   No repos found in {PROJECTS_FILE}")
        sys.exit(1)

    print(f"   Repos:   {', '.join(r.name for r in repos)}")

    initial_idx = 0
    if args.repo:
        for i, r in enumerate(repos):
            if str(r) == args.repo or r.name == args.repo:
                initial_idx = i
                break

    print("   Collecting data...", end="", flush=True)

    repos_data = []
    for repo in repos:
        repos_data.append({
            "path":             str(repo),
            "trust_scores":     parse_trust_scores(repo),
            "observations":     parse_observations(repo),
            "hooks":            list_hooks(repo),
            "last_routine_run": read_last_routine_run(repo),
            "gitnexus":         gitnexus_stats(repo),
            "workshop":         workshop_stats(repo),
            "memory_changes":   git_log_memory(repo),
            "memory_cards":     read_memory_file_cards(repo),
        })

    skill_content, skill_age = read_skill_report()
    harness_data = {
        "ccr_routines":         parse_ccr_routines(),
        "orchestrator_runs":    parse_orchestrator_log(),
        "skill_report_content": skill_content,
        "skill_report_age":     skill_age,
        "harness_memory":       git_log_harness_memory(),
    }

    print(" done.")
    print("   Rendering...", end="", flush=True)

    companion = not args.static
    html_content = build_html(repos_data, harness_data, initial_idx, companion=companion)
    print(" done.")

    if args.static:
        DASHBOARD_DIR.mkdir(exist_ok=True)
        OUTPUT_FILE.write_text(html_content, encoding="utf-8")
        size_kb = OUTPUT_FILE.stat().st_size // 1024
        print(f"   Output:  {OUTPUT_FILE} ({size_kb} KB)")
        if not args.no_open:
            open_browser(OUTPUT_FILE.as_uri())
    else:
        serve_companion(
            html_content,
            COMPANION_PORT,
            open_browser_fn=(lambda url: None) if args.no_open else open_browser,
        )
        print("   Opening in browser...")

if __name__ == "__main__":
    main()
