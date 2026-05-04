---
task_id: SHAKEDOWN-08
title: Wave QA gate — verify orchestrator detects wave-complete + halts dispatch
kind: TEST
wave: T1
estimated_minutes: 5
calibrated_minutes: 5
dependencies: [SHAKEDOWN-01, SHAKEDOWN-02, SHAKEDOWN-03, SHAKEDOWN-04, SHAKEDOWN-05, SHAKEDOWN-06, SHAKEDOWN-07, SHAKEDOWN-09, SHAKEDOWN-10, SHAKEDOWN-11]
merge_order_after: []
files_owned:
  - MARKERS/SHAKEDOWN-08.txt
  - PR_SIMULATIONS/SHAKEDOWN-08.json
target_wave_branch: sandbox-staging-T1
ai_review_required: true
human_review_required: false
integration_smoke_test:
  - "MARKERS/SHAKEDOWN-08.txt contains 'wave-qa-gate-pass-2026-05-03'"
  - "Orchestrator log shows 'WAVE T1 COMPLETE' after this task merges"
  - "wave-T1-complete-* tag exists on git"
expected_marker_content: "wave-qa-gate-pass-2026-05-03"
downstream_blocker_count: 0
priority_score: 5
---

# SHAKEDOWN-08 — Wave QA gate

You are the **expert of this task**. This task is **DESIGNED TO PASS** as the FINAL shakedown that triggers the wave-complete check.

## Goal
This task has `dependencies: [SHAKEDOWN-01..07,09,10,11]` (10 tasks) — ALL other shakedowns must be in `completed.json` before this dispatches. The orchestrator must:
1. NOT dispatch this task while ANY dep is still missing → log "skipped SHAKEDOWN-08 dispatch — dependency <X> not yet completed"
2. Once all deps are done, dispatch this task
3. Task succeeds normally
4. After this task merges → `completed.json` now has all 11 shakedowns
5. Orchestrator's Step 7 wave-complete check fires
6. Orchestrator tags `wave-T1-complete-<timestamp>`
7. Orchestrator halts the in-session loop and pings human

## Context
- ORCHESTRATOR.md Step 7 (wave-complete check)
- Dependency ordering enforcement

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
# Sanity check: all 10 prereq shakedowns should be in completed.json by the time we get here
REPO_ROOT="$(git rev-parse --show-toplevel)"
for prereq in SHAKEDOWN-01 SHAKEDOWN-02 SHAKEDOWN-03 SHAKEDOWN-04 SHAKEDOWN-05 SHAKEDOWN-06 SHAKEDOWN-07 SHAKEDOWN-09 SHAKEDOWN-10 SHAKEDOWN-11; do
  if ! grep -q "$prereq" "$REPO_ROOT/STATE/completed.json" 2>/dev/null; then
    echo "STUCK: dependency $prereq not in completed.json — orchestrator dispatched too early"
    exit 1
  fi
done
echo "STEP 1: all 10 deps satisfied"
```

## WORK
```bash
REPO_ROOT="$(git rev-parse --show-toplevel)"

echo "wave-qa-gate-pass-2026-05-03" > "$REPO_ROOT/MARKERS/SHAKEDOWN-08.txt"

cat > "$REPO_ROOT/PR_SIMULATIONS/SHAKEDOWN-08.json" <<EOF
{
  "task_id": "SHAKEDOWN-08",
  "title": "SHAKEDOWN-08: wave QA gate trigger",
  "body": "Final shakedown of wave T1. Triggers wave-complete check after merge.",
  "head": "sandbox/test-08-wave-qa-gate",
  "base": "sandbox-staging-T1",
  "files_changed": ["MARKERS/SHAKEDOWN-08.txt"],
  "simulated": true,
  "is_final_wave_task": true,
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

git add MARKERS/SHAKEDOWN-08.txt PR_SIMULATIONS/SHAKEDOWN-08.json
echo "WORK done"
```

## Acceptance criteria
```bash
test -f MARKERS/SHAKEDOWN-08.txt
grep -qF "wave-qa-gate-pass-2026-05-03" MARKERS/SHAKEDOWN-08.txt
# After merge, orchestrator should:
git tag -l 'wave-T1-complete-*' | head -1   # at least one wave-complete tag
grep -q "WAVE T1 COMPLETE" ORCHESTRATOR_LOG.md   # log entry
# All 11 in completed
python3 -c "import json; d=json.load(open('STATE/completed.json')); assert len(d['tasks'])==11, f'expected 11, got {len(d[\"tasks\"])}'"
```

## Pivot triggers
- If STEP 1 finds a dep missing → STUCK (orchestrator dispatched too early). Write stuck reports.

## STUCK PROTOCOL
Standard if stuck. Most likely cause if stuck would be orchestrator dispatching this task before all deps were satisfied.

## 3-strikes rule
Standard.

## Open PR
PR simulation in WORK section.
