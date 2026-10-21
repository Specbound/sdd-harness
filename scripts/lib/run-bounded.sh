# shellcheck shell=bash
# =============================================================================
# run-bounded.sh — wall-clock budget for one unattended routine step
# =============================================================================
# Source, then prefix the step's command:
#   . "$__here/../lib/run-bounded.sh"
#   (cd "$repo" && run_bounded bash .claude/scripts/routines/x-runner.sh) 2>"$errbuf"
#
# Why: nothing bounded a routine step, so one hung `claude --print` held the
# daily tick for 54h (2026-10-09/10) and swallowed the following days' ticks.
# Cloudflare saw the same shape in their AI reviewer — 358 of 446 cancelled jobs
# kept running (blog.cloudflare.com/obsessive-inference-optimization).
#
# The step runs in its own process group, and the whole group is signalled on
# expiry: killing only the runner's bash would orphan the `claude` child that is
# the thing actually hung. TERM first, KILL 10s later for anything still alive.
#
#   SDD_STEP_BUDGET_S=7200   default — 2h per step
#   SDD_STEP_BUDGET_S=off    disable
#
# Exit status: the step's own, 128+N if it died on signal N, 124 on budget
# expiry (same convention as GNU timeout, which macOS does not ship).
# Call site: scripts/orchestration/daily-orchestrator.sh.
# =============================================================================

# run_bounded <cmd> [args...]
run_bounded() {
  local budget="${SDD_STEP_BUDGET_S:-7200}"
  if [ "$budget" = "off" ]; then
    "$@"
    return
  fi
  case "$budget" in
    ''|*[!0-9]*|0)
      echo "run_bounded: SDD_STEP_BUDGET_S='$budget' must be a positive whole number of seconds or 'off'" >&2
      return 2 ;;
  esac
  if ! command -v perl >/dev/null 2>&1; then
    echo "run_bounded: perl not found — running '$1' WITHOUT the ${budget}s budget" >&2
    "$@"
    return
  fi
  perl -e '
    use strict; use warnings; use Errno qw(EINTR);
    my $budget = shift @ARGV;
    my $pid = fork();
    die "run_bounded: fork failed: $!\n" unless defined $pid;
    if ($pid == 0) {
      setpgrp(0, 0);
      { no warnings "exec"; exec { $ARGV[0] } @ARGV; }
      print STDERR "run_bounded: cannot exec $ARGV[0]: $!\n";
      exit 127;
    }
    setpgrp($pid, $pid);  # parent sets it too, so the group exists before any kill
    my $timed_out = 0;
    $SIG{ALRM} = sub {
      if (!$timed_out) {
        $timed_out = 1;
        print STDERR "run_bounded: $ARGV[0] exceeded ${budget}s budget — sending TERM to its process group\n";
        kill "TERM", -$pid;
        alarm 10;
      } else {
        kill "KILL", -$pid;
      }
    };
    alarm $budget;
    my $status;
    while (1) {
      my $r = waitpid($pid, 0);
      if ($r == $pid) { $status = $?; last; }
      next if $r == -1 && $! == EINTR;
      die "run_bounded: waitpid failed: $!\n";
    }
    alarm 0;
    if ($timed_out) {
      kill "KILL", -$pid;  # stragglers that outlived the group leader
      exit 124;
    }
    exit($status & 127 ? 128 + ($status & 127) : $status >> 8);
  ' "$budget" "$@"
}
