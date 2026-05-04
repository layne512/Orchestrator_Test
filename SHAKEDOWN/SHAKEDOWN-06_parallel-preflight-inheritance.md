---
task_id: SHAKEDOWN-06
title: Parallel preflight inheritance — two tasks dispatch concurrently, one patches preflight, both must inherit
kind: TEST
wave: T1
estimated_minutes: 20
calibrated_minutes: 20
dependencies: []
merge_order_after: []
files_owned:
  - MARKERS/SHAKEDOWN-06.txt
  - PR_SIMULATIONS/SHAKEDOWN-06.json
target_wave_branch: sandbox-staging-T1
ai_review_required: true
human_review_required: false
integration_smoke_test:
  - "MARKERS/SHAKEDOWN-06.txt exists with 'parallel-pass-2026-05-03'"
  - "If concurrent peer was running, both completed without file conflicts"
expected_marker_content: "parallel-pass-2026-05-03"
downstream_blocker_count: 1
priority_score: 120
---

# SHAKEDOWN-06 — Parallel preflight inheritance

You are the **expert of this task**. This task is **DESIGNED TO PASS**, but specifically tests the orchestrator's parallel-dispatch behavior.

## Goal
This shakedown verifies parallel dispatch and preflight inheritance:

1. The orchestrator should dispatch SHAKEDOWN-06 in parallel with another eligible non-overlapping task (e.g., a fresh dispatch of SHAKEDOWN-09 if eligible) — using its "up to 2 concurrent" rule.
2. If one of those parallel tasks (e.g., SHAKEDOWN-04) is in the heal cycle and patches preflight while we're running, the next quick-preflight check must detect the checksum diff and re-run.
3. Both tasks complete cleanly without conflicting on `files_owned` (we own only `MARKERS/SHAKEDOWN-06.txt` and `PR_SIMULATIONS/SHAKEDOWN-06.json`).

The "inheritance" aspect is verified by checking ORCHESTRATOR_LOG.md for entries like "parallel dispatch: SHAKEDOWN-06 + SHAKEDOWN-09" and "preflight checksum diff detected mid-cycle; re-running."

## Context
- ORCHESTRATOR.md Step 4 (dispatch up to 2 concurrent if files_owned non-overlapping)
- ORCHESTRATOR.md Step 6.A/6.B (heal protocol may patch preflight while we're running)
- preflight.sh quick-mode (checksum diff detection)

## STEP 0 — Self-heal
```bash
set -uo pipefail
REPO_ROOT="$(git rev-parse --show-toplevel)"

for d in MARKERS PR_SIMULATIONS; do
  if [[ ! -d "$REPO_ROOT/$d" ]]; then
    mkdir -p "$REPO_ROOT/$d" || { echo "STUCK: cannot create $d/"; exit 1; }
  fi
done
echo "STEP 0: OK"
```

## STEP 1 — Smoke test (also exercises mid-task preflight check)
```bash
REPO_ROOT="$(git rev-parse --show-toplevel)"
# Re-run preflight quick mode mid-task to test inheritance
bash "$REPO_ROOT/preflight.sh" --task=SHAKEDOWN-06 --quick || { echo "STUCK: mid-task preflight failed"; exit 1; }
echo "STEP 1: preflight quick re-check passed"
```

## WORK
```bash
REPO_ROOT="$(git rev-parse --show-toplevel)"

# Write marker with expected content
echo "parallel-pass-2026-05-03" > "$REPO_ROOT/MARKERS/SHAKEDOWN-06.txt"

# Write PR simulation
cat > "$REPO_ROOT/PR_SIMULATIONS/SHAKEDOWN-06.json" <<EOF
{
  "task_id": "SHAKEDOWN-06",
  "title": "SHAKEDOWN-06: parallel preflight inheritance",
  "body": "Verifies parallel dispatch + checksum-based preflight inheritance. Designed to run concurrent with another eligible task.",
  "head": "sandbox/test-06-parallel",
  "base": "sandbox-staging-T1",
  "files_changed": ["MARKERS/SHAKEDOWN-06.txt"],
  "simulated": true,
  "concurrent_dispatch_expected": true,
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

git add MARKERS/SHAKEDOWN-06.txt PR_SIMULATIONS/SHAKEDOWN-06.json
echo "WORK done"
```

## Acceptance criteria
```bash
test -f MARKERS/SHAKEDOWN-06.txt
grep -qF "parallel-pass-2026-05-03" MARKERS/SHAKEDOWN-06.txt
test -f PR_SIMULATIONS/SHAKEDOWN-06.json
```

The orchestrator log should also show:
- "parallel dispatch: SHAKEDOWN-06 + <peer-task>" OR "dispatched SHAKEDOWN-06 alone (no parallel-safe peer eligible this cycle)"
- If dispatched in parallel: "concurrent execution observed; no file_owned conflicts"

## Pivot triggers
None.

## STUCK PROTOCOL
Standard. If stuck, write the two reports.

## 3-strikes rule
Standard.

## Open PR
PR simulation written in WORK section.
