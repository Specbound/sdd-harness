# Daily Security Report — 2026-06-08

## Summary
- Files scanned: 1 (from git changes in last 25h)
- Findings: 0 critical, 0 high, 2 medium
- Status: ISSUES FOUND

## Findings

### [MEDIUM] CORS wildcard on action API endpoints
**File:** `scripts/dashboard.py:3517,3523,3633,3641,3650`
**Pattern:** `Access-Control-Allow-Origin: *` set on POST endpoints `/api/gitnexus-serve`, `/api/workshop-start`, `/api/workshop-eval` that spawn local subprocesses (gitnexus, raindrop workshop, `claude --print`).
**Risk:** Any browser tab (including a malicious page the user visits) can POST to these loopback endpoints and trigger process execution on the local machine. Loopback binding to `127.0.0.1` limits exposure to the local browser, but does not prevent cross-origin requests when CORS is open.
**Fix:** Replace `Access-Control-Allow-Origin: *` with an explicit allowlist (`http://localhost:<port>`) on write/action endpoints, or add a CSRF token check before accepting POST requests to action routes.

### [MEDIUM] PowerShell command string injection via unescaped repo path
**File:** `scripts/dashboard.py:3420`
**Pattern:** `ps_cmd = f"Set-Location '{win_path}'; gitnexus serve"` — `win_path` is derived from a user-supplied POST query parameter (`?repo=...`) via `_wsl_to_windows()`. Single quotes in the path are not escaped before interpolation into the PowerShell command string.
**Risk:** A path containing `'` (e.g., `C:\Users\Dan's Projects\repo`) breaks the PS string literal. A crafted path like `/mnt/c/dir'; Invoke-Expression <payload>; #` (where that directory exists on disk) could inject arbitrary PowerShell commands. The `is_dir()` check mitigates this in practice, but the underlying string construction is unsafe.
**Fix:** Escape single quotes in `win_path` before interpolation (`win_path.replace("'", "''")`), or use PowerShell's `-LiteralPath` parameter: `Set-Location -LiteralPath '{escaped_win_path}'`.

## Clean Files
`scripts/dashboard.py` — no critical or high findings; no hardcoded secrets, no SQL injection, no unsafe deserialization, no `eval()`/`exec()` with user input.

## Notes
- The dashboard server binds to `127.0.0.1` only (line 3662), which significantly reduces the attack surface for both findings above. Both are still flagged because a malicious browser tab in the same user session can reach loopback.
- No dependency files (`requirements.txt`, `pyproject.toml`) were changed in this diff.
