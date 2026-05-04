#!/usr/bin/env bash
# Minimal integration test for orchestrator shakedown.
# Iteration 1 scope: verify the just-merged task's executor wrote its expected marker file with expected content.
# No typecheck, no build, no deploy.
#
# Usage:
#   bash integration-test.sh --wave=T1 --post-merge=<task-id>
#
# The task spec frontmatter must declare:
#   integration_smoke_test:
#     - "MARKERS/<task-id>.txt exists"
#     - "MARKERS/<task-id>.txt contains '<expected-content>'"
#
# This script reads those checks (passed via env var EXPECTED_MARKER_CONTENT) and verifies them.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

WAVE="T1"
TASK_ID=""
for arg in "$@"; do
  case "$arg" in
    --wave=*)       WAVE="${arg#--wave=}" ;;
    --post-merge=*) TASK_ID="${arg#--post-merge=}" ;;
  esac
done

if [[ -z "$TASK_ID" ]]; then
  echo "[integration-test] ERROR: --post-merge=<task-id> required"
  exit 2
fi

echo "[integration-test] wave=$WAVE post-merge=$TASK_ID"

# Phase 1: marker file exists
MARKER="$REPO_ROOT/MARKERS/${TASK_ID}.txt"
if [[ ! -f "$MARKER" ]]; then
  echo "[integration-test] FAIL: $MARKER not present"
  echo "  the executor for $TASK_ID did not write its marker file"
  exit 1
fi
echo "[integration-test] phase 1 (marker exists): OK"

# Phase 2: content check (orchestrator passes EXPECTED_MARKER_CONTENT env var if spec demanded specific content)
if [[ -n "${EXPECTED_MARKER_CONTENT:-}" ]]; then
  if ! grep -qF "$EXPECTED_MARKER_CONTENT" "$MARKER"; then
    echo "[integration-test] FAIL: marker content mismatch"
    echo "  expected to find: '$EXPECTED_MARKER_CONTENT'"
    echo "  actual content:"
    cat "$MARKER" | sed 's/^/    /'
    exit 1
  fi
  echo "[integration-test] phase 2 (marker content): OK"
fi

# Phase 3: PR simulation file exists (simulates real PR creation in iter 1)
PR_SIM="$REPO_ROOT/PR_SIMULATIONS/${TASK_ID}.json"
if [[ ! -f "$PR_SIM" ]]; then
  echo "[integration-test] FAIL: $PR_SIM not present"
  echo "  the executor for $TASK_ID did not write its PR simulation file"
  exit 1
fi
echo "[integration-test] phase 3 (PR simulation): OK"

# Phase 4: state files still valid JSON (sanity check post-merge)
for f in "$REPO_ROOT"/STATE/*.json; do
  python3 -c "import json,sys; json.load(open('$f'))" 2>/dev/null \
    || { echo "[integration-test] FAIL: invalid JSON in $f"; exit 1; }
done
echo "[integration-test] phase 4 (STATE JSON valid): OK"

echo "[integration-test] PASSED for $TASK_ID"
exit 0
