#!/usr/bin/env bash
# Minimal preflight for orchestrator shakedown test.
# Iteration 1 scope: comprehensive filesystem + branch + state-file validation.
# No external services. No env vars beyond defaults. No node/npm/CLI tools required.
#
# Usage:
#   bash preflight.sh --wave=T1 --baseline    # full run + record baseline
#   bash preflight.sh --task=<id> --quick     # checksum diff; skip if unchanged
#   bash preflight.sh --full                  # full run, no baseline write
set -uo pipefail

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

# === Check 00 — filesystem (COMPREHENSIVE — collects ALL missing in one pass) ===
check_filesystem() {
  echo "[00_filesystem] checking required folders + files (comprehensive)"
  local missing=()

  # Required folders
  for d in STATE STUCK_STATE INTEGRATION_FAILURES MERGE_QUEUE PREFLIGHT_BASELINE MARKERS PR_SIMULATIONS SHAKEDOWN; do
    [[ ! -d "$REPO_ROOT/$d" ]] && missing+=("DIR: $d/")
  done

  # Required top-level files
  for f in ORCHESTRATOR.md SCHEDULING_DAG.md FAILURE_PATTERNS.md SPEC_LESSONS.md SPEC_TEMPLATE.md ORCHESTRATOR_LOG.md README.md CLAUDE.md preflight.sh integration-test.sh; do
    [[ ! -f "$REPO_ROOT/$f" ]] && missing+=("FILE: $f")
  done

  # Required STATE files
  for f in eligible running pending_review pending_merge completed stuck; do
    [[ ! -f "$REPO_ROOT/STATE/$f.json" ]] && missing+=("FILE: STATE/$f.json")
  done

  # At least one shakedown spec must exist
  local shakedown_count
  shakedown_count=$(ls "$REPO_ROOT/SHAKEDOWN/"SHAKEDOWN-*.md 2>/dev/null | wc -l | tr -d ' ')
  [[ "$shakedown_count" -eq 0 ]] && missing+=("CONTENT: SHAKEDOWN/ folder has zero spec files")

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "[00_filesystem] FAIL: ${#missing[@]} missing item(s):"
    printf '  - %s\n' "${missing[@]}"
    return 1
  fi
  echo "[00_filesystem] OK ($((${#missing[@]:-0} + 8)) folders + $((${#missing[@]:-0} + 16)) files verified, $shakedown_count shakedown spec(s))"
  return 0
}

# === Check 50 — branch ===
check_branch() {
  echo "[50_branch] checking current branch"
  local branch
  branch="$(cd "$REPO_ROOT" && git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "no-head")"
  case "$branch" in
    sandbox-staging|sandbox-staging-T*|sandbox/test-*|main)
      echo "[50_branch] OK (on $branch)"
      return 0
      ;;
    no-head)
      echo "[50_branch] WARN: no HEAD yet (uncommitted state)"
      return 0
      ;;
    *)
      echo "[50_branch] WARN: on '$branch' — expected sandbox-staging, sandbox-staging-T*, sandbox/test-*, or main"
      return 0  # not fatal in shakedown; orchestrator may need to switch
      ;;
  esac
}

# === Check 70 — quotas / rate limits (external-blocker-quota class) ===
check_quotas() {
  echo "[70_quotas] checking external storage/rate-limit quotas"

  # Iter 1: no real services are called, so this check is permissive by default.
  # It only fails if a sentinel is present, which lets the orchestrator
  # exercise this code path deterministically (e.g., SHAKEDOWN-04).
  local sentinel_file="$REPO_ROOT/STATE/.simulated_quota_exhausted"

  if [[ -f "$sentinel_file" ]]; then
    echo "[70_quotas] FAIL: sentinel file present at STATE/.simulated_quota_exhausted"
    echo "  - simulated external quota/rate-limit exhausted"
    echo "  - remove the sentinel (or resolve the underlying real quota) before dispatching"
    return 1
  fi

  if [[ "${SIMULATED_QUOTA_EXHAUSTED:-0}" == "1" ]]; then
    echo "[70_quotas] FAIL: env SIMULATED_QUOTA_EXHAUSTED=1"
    echo "  - simulated external quota/rate-limit exhausted via env trigger"
    echo "  - unset SIMULATED_QUOTA_EXHAUSTED before dispatching"
    return 1
  fi

  # In production iterations this block will probe real services
  # (git LFS quota, GitHub API rate-limit headers, Vercel deploy quota,
  # Supabase row count, Stripe API limits, S3 bucket quota, etc.)
  # and fail fast with the offending service name. Stub for iter 1.

  echo "[70_quotas] OK"
  return 0
}

# === Check 99 — STATE shape (JSON validity) ===
check_state_shape() {
  echo "[99_state_shape] checking STATE/*.json valid JSON"
  local invalid=()
  for f in "$REPO_ROOT"/STATE/*.json; do
    [[ -f "$f" ]] || continue
    if ! python3 -c "import json,sys; json.load(open('$f'))" 2>/dev/null; then
      invalid+=("$(basename "$f")")
    fi
  done
  if [[ ${#invalid[@]} -gt 0 ]]; then
    echo "[99_state_shape] FAIL: invalid JSON in: ${invalid[*]}"
    return 1
  fi
  echo "[99_state_shape] OK"
  return 0
}

run_full() {
  echo "[preflight] full run for wave=$WAVE task=${TASK:-none}"
  local fail=0
  check_filesystem || fail=1
  check_branch || fail=1
  check_quotas || fail=1
  check_state_shape || fail=1
  if [[ $fail -ne 0 ]]; then
    echo "[preflight] FAILED — see issues above; do NOT dispatch tasks"
    return 1
  fi
  echo "[preflight] all checks passed"
  return 0
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
    run_full || return 1
    write_baseline
    return 0
  fi
  local current
  current="$(shasum -a 256 "$REPO_ROOT/preflight.sh")"
  local recorded
  recorded="$(cat "$baseline")"
  if [[ "$current" == "$recorded" ]]; then
    echo "[preflight] checksums match baseline; skipping full run"
    return 0
  else
    echo "[preflight] checksum diff detected; running full"
    run_full || return 1
    write_baseline
  fi
}

case "$MODE" in
  baseline) run_full && write_baseline ;;
  quick)    quick_diff ;;
  full)     run_full ;;
  *)        echo "Usage: $0 {--baseline|--quick|--full} [--wave=T{n}] [--task=<id>]"; exit 2 ;;
esac
