---
task_id: SHAKEDOWN-05
title: Integration test fail — verify auto-revert on post-merge integration regression
kind: TEST
wave: T1
estimated_minutes: 12
calibrated_minutes: 12
dependencies: []
merge_order_after: []
files_owned:
  - MARKERS/SHAKEDOWN-05.txt
  - PR_SIMULATIONS/SHAKEDOWN-05.json
target_wave_branch: sandbox-staging-T1
ai_review_required: true
human_review_required: false
integration_smoke_test:
  - "MARKERS/SHAKEDOWN-05.txt contains 'integration-fail-pass-2026-05-03'"
expected_marker_content: "integration-fail-pass-2026-05-03"
downstream_blocker_count: 1
priority_score: 112
---

# SHAKEDOWN-05 — Integration test fail (designed for auto-revert)

You are the **expert of this task**. This task is **DESIGNED TO PASS** STEP 0 + WORK + AI review, then **DESIGNED TO FAIL** the integration test that runs AFTER the orchestrator squash-merges.

The deliberate trick: you write the WRONG content to the marker file. AI reviewer (which only sees the diff) cannot tell the content is wrong. Integration test catches it because `integration-test.sh` checks `EXPECTED_MARKER_CONTENT` from the spec.

## Goal
1. STEP 0 + STEP 1 succeed.
2. WORK writes a marker — but with **wrong content** (not what `expected_marker_content` says).
3. PR simulation file written normally.
4. AI review approves (it sees the marker exists; doesn't see content mismatch).
5. Orchestrator squash-merges.
6. Orchestrator runs `integration-test.sh --post-merge=SHAKEDOWN-05`.
7. Integration test FAILS because content mismatch.
8. Orchestrator reverts the merge with `git revert HEAD --no-edit`.
9. Orchestrator tags `failed-merge-T1-SHAKEDOWN-05-<sha>`.
10. Orchestrator writes `INTEGRATION_FAILURES/SHAKEDOWN-05.md` with cause.
11. SHAKEDOWN-05 task entry moves to `stuck.json` with status `needs_fix`.
12. Other tasks continue normally — bad task does NOT block the wave.

## Context
- ORCHESTRATOR.md Step 5 (sequential merge with integration test gate)
- integration-test.sh phase 2 (content mismatch)

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

## STEP 1 — Smoke test
```bash
git rev-parse --abbrev-ref HEAD
which jq 2>/dev/null || echo "jq missing — using grep fallback"
```

## WORK — succeed at task work, but write WRONG content

```bash
REPO_ROOT="$(git rev-parse --show-toplevel)"

# Write marker file with INTENTIONALLY WRONG content
# Spec says expected_marker_content is "integration-fail-pass-2026-05-03"
# We write something different to trigger integration test fail
echo "WRONG-CONTENT-deliberately-mismatches-expected-2026-05-03" > "$REPO_ROOT/MARKERS/SHAKEDOWN-05.txt"

# Write PR simulation file (normal, valid)
cat > "$REPO_ROOT/PR_SIMULATIONS/SHAKEDOWN-05.json" <<EOF
{
  "task_id": "SHAKEDOWN-05",
  "title": "SHAKEDOWN-05: integration fail marker (deliberate)",
  "body": "Writes MARKERS/SHAKEDOWN-05.txt with WRONG content to test orchestrator's auto-revert on integration test fail. AI review will approve (only sees diff); integration test will fail (content mismatch).",
  "head": "sandbox/test-05-integration-fail",
  "base": "sandbox-staging-T1",
  "files_changed": ["MARKERS/SHAKEDOWN-05.txt"],
  "simulated": true,
  "designed_to_fail_integration": true,
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

git add MARKERS/SHAKEDOWN-05.txt PR_SIMULATIONS/SHAKEDOWN-05.json
echo "WORK done — wrote marker with WRONG content (designed)"
```

## Acceptance criteria
The orchestrator should observe these post-cycle artifacts:

```bash
# Pre-revert: marker exists, commit happened
test -f MARKERS/SHAKEDOWN-05.txt   # exists
git log --oneline | head -1 | grep "SHAKEDOWN-05"   # squash merge happened

# After integration test fail + revert:
git log --oneline | head -2 | grep "Revert"   # revert commit
git tag -l 'failed-merge-T1-SHAKEDOWN-05-*'   # forensic tag
test -f INTEGRATION_FAILURES/SHAKEDOWN-05.md   # forensic doc
cat STATE/stuck.json | grep -q SHAKEDOWN-05   # in stuck state with needs_fix
```

## Pivot triggers
None — designed for auto-revert path.

## STUCK PROTOCOL
Not stuck per se — this task SUCCEEDS at the executor level (writes marker, returns cleanly). The "failure" happens at integration-test stage, which is orchestrator-side. No stuck reports required.

If the orchestrator's revert fails (e.g., merge conflict on revert), THEN you would write stuck reports. But for the designed scenario, that shouldn't happen.

## 3-strikes rule
N/A.

## Open PR
PR simulation written in WORK section. Designed to be reverted post-merge.
