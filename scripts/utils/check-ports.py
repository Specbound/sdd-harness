#!/usr/bin/env python3
"""Guard: every TCP port the harness uses is claimed by exactly one service.

The harness runs several resident local services (dashboard, GitNexus, Raindrop
workshop, jeff, the headroom proxy, the router's worker and sentinel), each with
a port literal declared in its own file. Nothing tied those literals together,
so a new service could pick a number another one already binds and nothing
would notice until one of them failed to start on someone's machine.

scripts/utils/ports.txt is the single registry: one "<port> <service> <path>"
line per file that names a port. Three things fail the run:

  1. Registry conflict — one port claimed by two services, or one service
     claiming two ports.
  2. Unregistered use — a port literal in a file that has no registry line for
     that (port, path). A brand-new port must be registered (which runs it
     through rule 1); a port that already belongs to a service cannot be
     borrowed by another file without saying, on the record, that the file
     talks to that same service.
  3. Stale entry — a registry line whose file no longer names that port, so
     the registry cannot quietly keep a freed port reserved or drift from code.

What counts as a port literal (no regex — see check-no-regex.py), on a
non-comment line, a 4-5 digit number in 1024-65535 that either
  - directly follows a loopback host: 127.0.0.1:N, localhost:N, 0.0.0.0:N, or
  - is the value of a name that is `port` or ends in `_port` / `_port_default`
    (any case): WORKER_PORT = 8798, port = 8799, ${HEADROOM_PORT:-8787},
    JEFF_PORT_DEFAULT="8000", router.get("port", 8799), "--port", "5899".
A bare number passed some other way (`listen_addr 8798`) is not seen; declare
ports through one of the forms above.

Scope: scripts/, hooks/, templates/ and the top-level *.sh. Tests
(*.test.sh, test_*.py) bind throwaway ports and are skipped; docs/ and skills/
are prose and vendored code.

This is a static gate over the repo. It cannot see a foreign process already
holding a port on a given machine — that is each setup script's preflight.

Usage (from the harness repo root):
  python3 scripts/utils/check-ports.py          # verdict; exit 0 clean, 1 on violations
  python3 scripts/utils/check-ports.py --list   # every port literal found, as "<port> <path>"
Exit 2 when the registry is missing or malformed.
"""

import os
import sys

REGISTRY = "scripts/utils/ports.txt"
SCAN_DIRS = ("scripts", "hooks", "templates")
SKIP_DIRS = ("node_modules", ".git", "__pycache__")
SKIP_NAMES = ("check-ports.py", "ports.txt")
SKIP_SUFFIXES = (".test.sh", ".bak")
SKIP_PREFIXES = ("test_",)
CODE_SUFFIXES = (".sh", ".py", ".toml", ".template", ".json", ".js")
HASH_COMMENT_SUFFIXES = (".sh", ".py", ".toml", ".template")
HOST_PREFIXES = ("127.0.0.1:", "localhost:", "0.0.0.0:")
VALUE_SEPARATORS = " \t=:-\"',"
MAX_SEPARATOR_RUN = 24
PORT_MIN = 1024
PORT_MAX = 65535
IDENT_EXTRA = "_"


class RegistryError(Exception):
    pass


def is_ident_char(ch):
    return ch.isalnum() or ch in IDENT_EXTRA


def read_port_at(line, start):
    """Return the port whose digits begin at `start`, or None."""
    end = start
    while end < len(line) and line[end].isdigit():
        end += 1
    digits = line[start:end]
    if len(digits) < 4 or len(digits) > 5:
        return None
    # 8787abc, 8787.5 and 2026-11-12 are not ports.
    if end < len(line) and (is_ident_char(line[end]) or line[end] in ".-"):
        return None
    value = int(digits)
    if value < PORT_MIN or value > PORT_MAX:
        return None
    return value


def is_port_name(name):
    lowered = name.lower()
    for tail in ("port", "port_default"):
        if lowered == tail or lowered.endswith("_" + tail):
            return True
    return False


def ports_after_hosts(line):
    found = set()
    for prefix in HOST_PREFIXES:
        at = line.find(prefix)
        while at != -1:
            port = read_port_at(line, at + len(prefix))
            if port is not None:
                found.add(port)
            at = line.find(prefix, at + 1)
    return found


def ports_after_names(line):
    found = set()
    lowered = line.lower()
    at = lowered.find("port")
    while at != -1:
        begin = at
        while begin > 0 and is_ident_char(line[begin - 1]):
            begin -= 1
        end = at
        while end < len(line) and is_ident_char(line[end]):
            end += 1
        if is_port_name(line[begin:end]):
            cursor = end
            while (
                cursor < len(line)
                and cursor - end < MAX_SEPARATOR_RUN
                and line[cursor] in VALUE_SEPARATORS
            ):
                cursor += 1
            if cursor > end:
                port = read_port_at(line, cursor)
                if port is not None:
                    found.add(port)
        at = lowered.find("port", max(end, at + 1))
    return found


def is_comment_line(path, line):
    stripped = line.lstrip()
    if path.endswith(HASH_COMMENT_SUFFIXES) or "." not in os.path.basename(path):
        return stripped.startswith("#")
    if path.endswith(".js"):
        return stripped.startswith("//")
    return False


def ports_in_file(path):
    try:
        with open(path, encoding="utf-8") as fh:
            lines = fh.read().splitlines()
    except UnicodeDecodeError:
        return set()
    found = set()
    for line in lines:
        if is_comment_line(path, line):
            continue
        found |= ports_after_hosts(line)
        found |= ports_after_names(line)
    return found


def wanted(fname):
    if fname in SKIP_NAMES or fname.endswith(SKIP_SUFFIXES) or fname.startswith(SKIP_PREFIXES):
        return False
    # Extensionless files are the git hooks (hooks/git/pre-commit).
    return fname.endswith(CODE_SUFFIXES) or "." not in fname


def candidate_files(root):
    for fname in sorted(os.listdir(root)):
        if fname.endswith(".sh") and os.path.isfile(os.path.join(root, fname)):
            yield os.path.join(root, fname)
    for scan_dir in SCAN_DIRS:
        for dirpath, dirnames, filenames in os.walk(os.path.join(root, scan_dir)):
            dirnames[:] = sorted(d for d in dirnames if d not in SKIP_DIRS)
            for fname in sorted(filenames):
                if wanted(fname):
                    yield os.path.join(dirpath, fname)


def scan(root):
    """Return {(port, repo-relative posix path)} for every port literal found."""
    uses = set()
    for path in candidate_files(root):
        rel = os.path.relpath(path, root).replace(os.sep, "/")
        for port in ports_in_file(path):
            uses.add((port, rel))
    return uses


def load_registry(root):
    """Return [(port, service, path)] from the registry file."""
    path = os.path.join(root, REGISTRY)
    if not os.path.isfile(path):
        raise RegistryError(f"registry not found: {REGISTRY}")
    entries = []
    with open(path, encoding="utf-8") as fh:
        for lineno, line in enumerate(fh, 1):
            stripped = line.strip()
            if not stripped or stripped.startswith("#"):
                continue
            fields = stripped.split()
            if len(fields) != 3 or not fields[0].isdigit():
                raise RegistryError(
                    f"{REGISTRY}:{lineno}: expected '<port> <service> <path>', got: {stripped}"
                )
            entries.append((int(fields[0]), fields[1], fields[2]))
    return entries


def registry_conflicts(entries):
    problems = []
    services_by_port = {}
    ports_by_service = {}
    for port, service, _path in entries:
        services_by_port.setdefault(port, set()).add(service)
        ports_by_service.setdefault(service, set()).add(port)
    for port in sorted(services_by_port):
        services = sorted(services_by_port[port])
        if len(services) > 1:
            problems.append(f"port {port} is claimed by {len(services)} services: {', '.join(services)}")
    for service in sorted(ports_by_service):
        ports = sorted(ports_by_service[service])
        if len(ports) > 1:
            listed = ", ".join(str(p) for p in ports)
            problems.append(f"service '{service}' claims {len(ports)} ports: {listed}")
    return problems


def unregistered_uses(entries, uses):
    registered = {(port, path) for port, _service, path in entries}
    owner = {port: service for port, service, _path in entries}
    problems = []
    for port, path in sorted(uses - registered):
        if port in owner:
            problems.append(
                f"{path} uses port {port}, which belongs to '{owner[port]}'. A different "
                f"service must take a free port; if this file talks to '{owner[port]}', "
                f"add the line: {port} {owner[port]} {path}"
            )
        else:
            problems.append(
                f"{path} uses port {port}, which is not registered. "
                f"Add the line: {port} <service> {path}"
            )
    return problems


def stale_entries(entries, uses):
    return [
        f"{REGISTRY} lists '{port} {service} {path}' but that file no longer names port {port} "
        "— delete the line"
        for port, service, path in sorted(entries)
        if (port, path) not in uses
    ]


def main(argv):
    root = os.getcwd()
    uses = scan(root)
    if "--list" in argv:
        for port, path in sorted(uses):
            print(f"{port} {path}")
        return 0
    try:
        entries = load_registry(root)
    except RegistryError as exc:
        print(f"check-ports: {exc}", file=sys.stderr)
        return 2
    problems = registry_conflicts(entries) + unregistered_uses(entries, uses) + stale_entries(entries, uses)
    if not problems:
        return 0
    print("check-ports: port registry violation(s) — every port has exactly one owning service:")
    for problem in problems:
        print(f"  {problem}")
    print()
    print(f"Registry: {REGISTRY}. See every port literal with: python3 scripts/utils/check-ports.py --list")
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
