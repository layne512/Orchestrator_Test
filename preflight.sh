#!/usr/bin/env bash
# Minimal preflight for orchestrator shakedown test.
# Iteration 1 scope: filesystem + branch + state-file existence.
# No external services. No env vars beyond defaults. No node/npm/CLI tools required.
#
# Usage:
#   bash preflight.sh --wave=T1 --baseline    # full run + record baseline
#   bash preflight.sh --task=<id> --quick     # checksum diff; skip if unchanged
#   bash preflight.sh --full                  # full run, no baseline write
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASELINE_DIR="$REPO_ROOT/PREFLIGHT_BASELINE"

MODE=""
WAVE="T1"
TASK=""
for arg in "$@"; do
  case "$arg" in
    --baseline) MODE="baseline" ;;
    --quick)    MODE="quick" ;;
    --full)     MODE="full" ;;
    --wave=*)   WAVE="${arg#--wave=}" ;;
    --task=*)   TASK="${arg#--task=}" ;;
  esac
done

# === Check 00 — filesystem ===
check_filesystem() {
  echo "[00_filesystem] checking required folders + files"
  for d in STATE STUCK_STATE INTEGRATION_FAILURES MERGE_QUEUE PREFLIGHT_BASELINE MARKERS PR_SIMULATIONS SHAKEDOWN; do
    test -d "$REPO_ROOT/$d" || { echo "MISSING: $d/"; return 1; }
  done
  for f in ORCHESTRATOR.md SCHEDULING_DAG.md FAILURE_PATTERNS.md SPEC_LESSONS.md SPEC_TEMPLATE.md ORCHESTRATOR_LOG.md README.md CLAUDE.md preflight.sh integration-test.sh; do
    test -f "$REPO_ROOT/$f" || { echo "MISSING: $f"; return 1; }
  done
  for f in eligible running pending_review pending_merge completed stuck; do
    test -f "$REPO_ROOT/STATE/$f.json" || { echo "MISSING: STATE/$f.json"; return 1; }
  done
  echo "[00_filesystem] OK"
}

# === Check 50 — branch ===
check_branch() {
  echo "[50_branch] checking current branch"
  local branch
  branch="$(cd "$REPO_ROOT" && git rev-parse --abbrev-ref HEAD)"
  case "$branch" in
    sandbox-staging|sandbox-staging-T*|sandbox/test-*|main)
      echo "[50_branch] OK (on $branch)"
      ;;
    *)
      echo "[50_branch] WARN: on '$branch' — expected sandbox-staging, sandbox-staging-T*, sandbox/test-*, or main"
      # not fatal in shakedown; orchestrator may need to switch
      ;;
  esac
}

# === Check 99 — STATE shape ===
check_state_shape() {
  echo "[99_state_shape] checking STATE/*.json valid JSON"
  for f in "$REPO_ROOT"/STATE/*.json; do
    python3 -c "import json,sys; json.load(open('$f'))" 2>/dev/null \
      || { echo "MISSING/INVALID JSON: $f"; return 1; }
  done
  echo "[99_state_shape] OK"
}

run_full() {
  echo "[preflight] full run for wave=$WAVE task=${TASK:-none}"
  check_filesystem
  check_branch
  check_state_shape
  echo "[preflight] all checks passed"
}

write_baseline() {
  mkdir -p "$BASELINE_DIR"
  local out="$BASELINE_DIR/.preflight-baseline-${WAVE}"
  : > "$out"
  shasum -a 256 "$REPO_ROOT/preflight.sh" >> "$out"
  echo "[preflight] baseline written to $out"
}

quick_diff() {
  local baseline="$BASELINE_DIR/.preflight-baseline-${WAVE}"
  if [[ ! -f "$baseline" ]]; then
    echo "[preflight] no baseline for $WAVE; running full"
    run_full
    write_baseline
    return 0
  fi
  local current
  current="$(shasum -a 256 "$REPO_ROOT/preflight.sh")"
  local recorded
  recorded="$(cat "$baseline")"
  if [[ "$current" == "$recorded" ]]; then
    echo "[preflight] checksums match baseline; skipping full run"
    exit 0
  else
    echo "[preflight] checksum diff detected; running full"
    run_full
    write_baseline
  fi
}

case "$MODE" in
  baseline) run_full; write_baseline ;;
  quick)    quick_diff ;;
  full)     run_full ;;
  *)        echo "Usage: $0 {--baseline|--quick|--full} [--wave=T{n}] [--task=<id>]"; exit 2 ;;
esac
