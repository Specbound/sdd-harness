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
from urllib.parse import parse_qs, urlparse

# ── Constants ─────────────────────────────────────────────────────────────────

HARNESS_DIR    = Path(__file__).resolve().parent.parent
PROJECTS_FILE  = HARNESS_DIR / "projects.txt"
DASHBOARD_DIR  = HARNESS_DIR / ".dashboard"
OUTPUT_FILE    = DASHBOARD_DIR / "index.html"
ORCH_LOG       = HARNESS_DIR / "logs" / "orchestrator.log"
COMPANION_PORT = 4569

SECTION_DEFS = [
    ("trust_battery",      "⚡", "Trust Battery"),
    ("gitnexus",           "🕸", "GitNexus"),
    ("hooks_history",      "🪝", "Hooks History"),
    ("ccr_routines",       "📅", "CCR Routines"),
    ("memory_changes",     "🧠", "Memory Changes"),
    ("skill_changes",      "🎯", "Skill Changes"),
    ("session_quality",    "📊", "Session Quality"),
    ("maintenance_status", "🔧", "Maintenance Status"),
]

NOW = datetime.now(timezone.utc)

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
    gn_dir = repo / ".gitnexus"
    result = {"available": gn_dir.exists()}
    if gn_dir.exists():
        try:
            mtime = gn_dir.stat().st_mtime
            age = NOW.timestamp() - mtime
            dt = datetime.fromtimestamp(mtime, tz=timezone.utc)
            result["indexed_ago"] = rel_time(dt.isoformat())
            result["stale"]       = age > 86400
            result["very_stale"]  = age > 259200
        except Exception:
            pass
    return result

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
        if sched and last_run_ts:
            interval = sched["interval_seconds"]
            elapsed  = (NOW - last_run_ts).total_seconds()
            overdue_secs = max(0.0, elapsed - interval)
            if overdue_secs > interval * 0.25:
                miss_status = "missed"
            elif overdue_secs > 0:
                miss_status = "warn"
            nxt = last_run_ts + timedelta(seconds=interval)
            d   = (nxt - NOW).total_seconds()
            if d > 0:
                next_run_str = f"in {int(d/3600)}h" if d < 86400 else f"in {int(d/86400)}d"
            else:
                next_run_str = (f"{int(-d/3600)}h overdue" if -d < 86400
                                else f"{int(-d/86400)}d overdue")
        routines.append({
            "name":          name,
            "id":            id_m.group(1),
            "schedule_human": sched["human"] if sched else (cron_m.group(1) if cron_m else "—"),
            "status":        stat_m.group(1) if stat_m else "Unknown",
            "output_file":   out_file,
            "last_run_rel":  rel_time(last_run_ts.isoformat()) if last_run_ts else "never",
            "miss_status":   miss_status,
            "overdue_secs":  overdue_secs,
            "next_run":      next_run_str,
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
    return entries

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

    return f"""<div class="section-inner">
  <h2 class="section-title">Trust Battery</h2>
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

    stats_html = f"""<div style="display:grid;grid-template-columns:repeat(4,1fr);
                          gap:1px;background:var(--surface0);border-radius:8px;
                          overflow:hidden;margin-bottom:14px">
    <div style="background:var(--mantle);padding:10px;text-align:center">
      <div style="color:var(--mauve);font-size:20px;font-weight:700">—</div>
      <div class="label">symbols</div></div>
    <div style="background:var(--mantle);padding:10px;text-align:center">
      <div style="color:var(--teal);font-size:20px;font-weight:700">—</div>
      <div class="label">clusters</div></div>
    <div style="background:var(--mantle);padding:10px;text-align:center">
      <div style="color:var(--red);font-size:20px;font-weight:700">—</div>
      <div class="label">HIGH risks</div></div>
    <div style="background:var(--mantle);padding:10px;text-align:center">
      <div style="color:{stale_color};font-size:13px;font-weight:600">
        {h(gn.get("indexed_ago","unknown"))}</div>
      <div class="label">indexed</div></div>
  </div>"""

    serve_btn = ""
    if companion:
        rp_js = json.dumps(repo_path)
        serve_btn = f"""<button id="gn-start-btn"
           style="display:none;background:var(--mauve);color:var(--crust);border:none;
                  border-radius:6px;padding:9px 18px;font-size:12px;font-weight:600;
                  cursor:pointer;letter-spacing:.3px"
           onclick="startGitnexus({rp_js})">
        ▶ Start gitnexus serve
      </button>"""

    iframe_html = f"""<div style="position:relative;border:1px solid var(--surface0);
                          border-radius:8px;overflow:hidden;background:var(--crust)">
    <iframe id="gn-frame" src="http://localhost:4567"
            style="width:100%;height:440px;border:none;display:none">
    </iframe>
    <div id="gn-fallback" style="display:flex;position:relative;height:440px;
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
    </div>
  </div>
  <script>
  (function() {{
    var ctrl = new AbortController();
    var timer = setTimeout(function() {{ ctrl.abort(); }}, 2000);
    fetch('http://localhost:4567', {{ mode: 'no-cors', signal: ctrl.signal }})
      .then(function() {{
        clearTimeout(timer);
        var f = document.getElementById('gn-frame');
        var fb = document.getElementById('gn-fallback');
        if (f) {{ f.style.display = 'block'; }}
        if (fb) {{ fb.style.display = 'none'; }}
      }})
      .catch(function() {{
        clearTimeout(timer);
        var st   = document.getElementById('gn-status');
        var btn  = document.getElementById('gn-copy-btn');
        var hint = document.getElementById('gn-copy-hint');
        if (st)   st.textContent = 'GitNexus not running';
        if (btn)  btn.style.display = 'block';
        if (hint) hint.style.display = 'block';
        {("var sbtn = document.getElementById('gn-start-btn'); if (sbtn) sbtn.style.display = 'block';" if companion else "")}
      }});
  }})();
  </script>"""

    return f"""<div class="section-inner">
  <h2 class="section-title">GitNexus — {repo_name}</h2>
  {stats_html}
  {iframe_html}
</div>"""

def render_hooks_history(rd):
    hooks = rd["hooks"]
    obs   = rd["observations"]
    if not hooks:
        return empty_state("No hooks found in .claude/hooks/")

    all_obs = [(d, t) for entries in obs.values() for d, t in entries]

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

    rows = ""
    for hook_file in hooks:
        stem  = hook_file.replace(".sh", "")
        event = next((v for k, v in event_map.items() if k in stem), "Unknown")
        # Find last observation mentioning this hook's stem
        stem_parts = stem.split("-")[:2]
        activity = next(
            (f"{d}: {t[:90]}" for d, t in reversed(all_obs)
             if any(p in t.lower() for p in stem_parts if len(p) > 3)),
            None
        )
        act_html = (h(activity[:100]) if activity
                    else '<span style="color:var(--overlay0)">no recorded activity</span>')
        rows += f"""<tr>
      <td><code style="color:var(--mauve);font-size:11px">{h(hook_file)}</code></td>
      <td><span style="color:var(--blue);font-size:11px">{h(event)}</span></td>
      <td style="font-size:11px;color:var(--subtext0);max-width:320px;
                 overflow:hidden;text-overflow:ellipsis;white-space:nowrap">{act_html}</td>
      <td>{badge("Active", "active")}</td>
    </tr>"""

    return f"""<div class="section-inner">
  <h2 class="section-title">Hooks History</h2>
  <table style="width:100%;border-collapse:collapse">
    <thead><tr style="border-bottom:1px solid var(--surface0)">
      <th class="th">Hook</th>
      <th class="th">Event</th>
      <th class="th">Last Activity in Observations</th>
      <th class="th">Status</th>
    </tr></thead>
    <tbody>{rows}</tbody>
  </table>
</div>"""

def render_ccr_routines(hd):
    routines = hd["ccr_routines"]
    if not routines:
        return empty_state("No CCR routines found in docs/ccr-routines/README.md")

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

    return f'<div class="section-inner"><h2 class="section-title">CCR Routines</h2>{cards}</div>'

def render_memory_changes(rd, hd):
    repo_entries    = rd.get("memory_changes", [])
    harness_entries = hd.get("harness_memory", [])

    all_entries = (
        [dict(e, label=".claude/memory") for e in repo_entries] +
        [dict(e, label="~/.claude/projects") for e in harness_entries]
    )
    if not all_entries:
        return empty_state(
            "No memory change history found. Memory changes appear here after git commits."
        )

    rows = ""
    for e in all_entries[:40]:
        src_badge = badge(e["label"], "info" if ".claude/memory" in e["label"] else "default")
        rows += f"""<div style="padding:8px 0;border-bottom:1px solid rgba(49,50,68,0.5);
                        display:flex;gap:10px;align-items:baseline">
      <div style="color:var(--overlay0);font-size:10px;min-width:80px;flex-shrink:0">
        {h(e["rel"])}</div>
      <div style="flex:1;min-width:0;font-size:12px;color:var(--subtext1);
                  overflow:hidden;text-overflow:ellipsis;white-space:nowrap">
        {h(e["subject"])}</div>
      <div style="flex-shrink:0">{src_badge}</div>
    </div>"""

    return f"""<div class="section-inner">
  <h2 class="section-title">Memory Changes</h2>
  <div style="color:var(--overlay0);font-size:11px;margin-bottom:12px">
    Recent git commits touching memory files</div>
  {rows}
</div>"""

def render_skill_changes(hd):
    content  = hd.get("skill_report_content")
    last_mod = hd.get("skill_report_age")
    if not content:
        return f"""<div class="section-inner">
  <h2 class="section-title">Skill Changes</h2>
  {empty_state("No skill curation report yet. The weekly CCR routine writes docs/skill-curation-report.md every Monday at 09:00 IDT.")}
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
            bh    = int(s / 5 * 44)
            bc    = ("#a6e3a1" if s >= 4 else "#f9e2af" if s >= 2.5 else "#f38ba8")
            bars += (f'<div title="{h(d)}: {s}/5" style="flex:1;background:{bc};'
                     f'height:{bh}px;border-radius:2px 2px 0 0;min-width:6px;'
                     f'opacity:0.85"></div>')
        timeline = (f'<div class="label" style="margin-bottom:6px">Session scores (recent)</div>'
                    f'<div style="display:flex;align-items:flex-end;gap:3px;height:48px;'
                    f'margin-bottom:16px">{bars}</div>')

    recent = ""
    if mg:
        items = "".join(
            f'<li style="margin:3px 0">{h(d)}: {h(t[:120])}</li>'
            for d, t in mg[-5:]
        )
        recent = (f'<div class="label" style="margin-bottom:6px">Recent memory gaps</div>'
                  f'<ul style="padding-left:16px;margin:0;color:var(--subtext0);'
                  f'font-size:12px">{items}</ul>')

    return f"""<div class="section-inner">
  <h2 class="section-title">Session Quality</h2>
  {summary}{timeline}{recent}
</div>"""

def render_maintenance_status(all_repos_data, hd):
    runs = hd.get("orchestrator_runs", [])
    latest = {}
    for run in runs:
        p = run["path"]
        if p not in latest or run["ts"] > latest[p]["ts"]:
            latest[p] = run

    rows = ""
    for rd in all_repos_data:
        path      = rd["path"]
        name      = h(Path(path).name)
        last_run  = rd.get("last_routine_run")
        run_info  = latest.get(path)

        if last_run:
            age      = (NOW - last_run).total_seconds()
            overdue  = age > 25 * 3600
            run_str  = rel_time(last_run.isoformat())
            run_col  = "var(--red)" if overdue else "var(--green)"
            st_badge = badge("OVERDUE", "missed") if overdue else badge("OK", "ok")
        else:
            run_str  = "never"
            run_col  = "var(--overlay0)"
            st_badge = badge("UNKNOWN", "default")

        exit_html = dur_html = "—"
        if run_info:
            ec       = run_info["exit"]
            ec_col   = "var(--green)" if ec == 0 else "var(--red)"
            exit_html = f'<span style="color:{ec_col};font-size:11px">exit {ec}</span>'
            d        = run_info["duration"]
            dur_html = f'{d}s' if d > 0 else '<span style="color:var(--overlay0)">—</span>'

        rows += f"""<tr>
      <td style="font-weight:600;color:var(--text);font-size:12px">{name}</td>
      <td style="color:{run_col};font-size:12px">{h(run_str)}</td>
      <td style="font-size:12px;color:var(--subtext0)">{dur_html}</td>
      <td>{exit_html}</td>
      <td>{st_badge}</td>
    </tr>"""

    log_tail = ""
    if ORCH_LOG.exists():
        lines    = ORCH_LOG.read_text().splitlines()[-10:]
        log_tail = (f'<div style="margin-top:20px">'
                    f'<div class="label" style="margin-bottom:6px">Orchestrator log (last 10)</div>'
                    f'<pre style="background:var(--crust);border-radius:6px;padding:12px;'
                    f'font-size:10px;color:var(--subtext0);overflow-x:auto;white-space:pre-wrap">'
                    f'{h(chr(10).join(lines))}</pre></div>')

    return f"""<div class="section-inner">
  <h2 class="section-title">Maintenance Status</h2>
  <table style="width:100%;border-collapse:collapse;margin-bottom:8px">
    <thead><tr style="border-bottom:1px solid var(--surface0)">
      <th class="th">Repo</th>
      <th class="th">Last run</th>
      <th class="th">Duration</th>
      <th class="th">Exit</th>
      <th class="th">Status</th>
    </tr></thead>
    <tbody>{rows}</tbody>
  </table>
  {log_tail}
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
  sec = sectionKey;
  var d = SD[repo];
  document.getElementById('panel').innerHTML =
    d ? (d[sectionKey] || '<div class="section-inner"><p style="color:var(--overlay0)">Not available.</p></div>')
      : '<div class="section-inner"><p style="color:var(--overlay0)">No data.</p></div>';
  document.querySelectorAll('.nav-item').forEach(function(el) {
    el.classList.toggle('active', el.dataset.s === sectionKey);
  });
}

function switchRepo(v) { repo = v; show(sec); }

__GN_SERVE_FUNS__

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
    maint_html  = render_maintenance_status(repos_data, harness_data)

    sections_map = {}
    for rd in repos_data:
        sections_map[rd["path"]] = {
            "trust_battery":     render_trust_battery(rd),
            "gitnexus":          render_gitnexus(rd, companion=companion),
            "hooks_history":     render_hooks_history(rd),
            "ccr_routines":      ccr_html,
            "memory_changes":    render_memory_changes(rd, harness_data),
            "skill_changes":     skill_html,
            "session_quality":   render_session_quality(rd),
            "maintenance_status": maint_html,
        }

    sj  = json.dumps(sections_map, ensure_ascii=False).replace("</script>", r"<\/script>")
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
  fetch('http://localhost:4567', { mode: 'no-cors', signal: ctrl.signal })
    .then(function() {
      var f  = document.getElementById('gn-frame');
      var fb = document.getElementById('gn-fallback');
      if (f)  { f.src = 'http://localhost:4567'; f.style.display = 'block'; }
      if (fb) { fb.style.display = 'none'; }
    })
    .catch(function() {
      setTimeout(function() { pollGitnexus(n + 1); }, 1000);
    });
}""" if companion else ""

    js  = (JS_TEMPLATE
           .replace("__SECTIONS_JSON__", sj)
           .replace("__INIT_REPO__", ir)
           .replace("__GN_SERVE_FUNS__", gn_funs))
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

class _DashboardHandler(BaseHTTPRequestHandler):
    _html: bytes = b""

    def do_GET(self):
        if self.path.split("?")[0] == "/":
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(self._html)))
            self.end_headers()
            self.wfile.write(self._html)
        else:
            self.send_error(404)

    def do_POST(self):
        parsed = urlparse(self.path)
        if parsed.path == "/api/gitnexus-serve":
            qs = parse_qs(parsed.query)
            repo_path = qs.get("repo", [""])[0]
            if repo_path and Path(repo_path).is_dir():
                for cmd in [["gitnexus", "serve"], ["npx", "gitnexus", "serve"]]:
                    try:
                        subprocess.Popen(
                            cmd, cwd=repo_path,
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                        )
                        break
                    except FileNotFoundError:
                        continue
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
            "memory_changes":   git_log_memory(repo),
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
