---
task_id: SHAKEDOWN-01
title: Happy path — write marker file with expected content
kind: TEST
wave: T1
estimated_minutes: 5
calibrated_minutes: 5
dependencies: []
merge_order_after: []
files_owned:
  - MARKERS/SHAKEDOWN-01.txt
  - PR_SIMULATIONS/SHAKEDOWN-01.json
target_feature_branch: null
target_wave_branch: sandbox-staging-T1
preserves_until: wave_approved
ai_review_required: true
human_review_required: false
integration_smoke_test:
  - "MARKERS/SHAKEDOWN-01.txt exists"
  - "MARKERS/SHAKEDOWN-01.txt contains 'happy-path-pass-2026-05-02'"
  - "PR_SIMULATIONS/SHAKEDOWN-01.json exists with valid JSON"
expected_marker_content: "happy-path-pass-2026-05-02"
downstream_blocker_count: 0
priority_score: 5
---

# SHAKEDOWN-01 — Happy path

## Goal
Validate the orchestrator's baseline dispatch → executor → AI review → integration test → squash-merge → tag flow with a task that has zero failures. If this doesn't work cleanly, nothing else will. Run this first.

## Context
- Test plan: `ORCHESTRATOR.md` (your operating manual as orchestrator)
- This is the simplest possible shakedown. Executor writes one marker file, simulates one PR, exits cleanly.

## STEP 0 — Self-heal
```bash
test -d "$(git rev-parse --show-toplevel)/MARKERS" || { echo "MISSING: MARKERS/ directory"; exit 1; }
test -d "$(git rev-parse --show-toplevel)/PR_SIMULATIONS" || { echo "MISSING: PR_SIMULATIONS/ directory"; exit 1; }
```

## STEP 1 — Smoke test
```bash
git rev-parse --abbrev-ref HEAD     # should be on sandbox-staging-T1 or sandbox/test-* derivative
which git                            # required tool
which jq 2>/dev/null || echo "WARN: jq not present; orchestrator will use grep/sed instead"
```

## WORK

You are the **executor** for this happy-path test. Do exactly this:

1. **Write the marker file** with the exact expected content:
   ```bash
   REPO_ROOT="$(git rev-parse --show-toplevel)"
   echo "happy-path-pass-2026-05-02" > "$REPO_ROOT/MARKERS/SHAKEDOWN-01.txt"
   ```

2. **Write the PR simulation file** (this stands in for `gh pr create` in iter 1):
   ```bash
   cat > "$REPO_ROOT/PR_SIMULATIONS/SHAKEDOWN-01.json" <<'EOF'
   {
     "task_id": "SHAKEDOWN-01",
     "title": "SHAKEDOWN-01: happy path marker",
     "body": "Writes MARKERS/SHAKEDOWN-01.txt with expected content. No production code changes.",
     "head": "sandbox/test-01-happy-path",
     "base": "sandbox-staging-T1",
     "files_changed": ["MARKERS/SHAKEDOWN-01.txt"],
     "simulated": true,
     "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
   }
   EOF
   ```

3. **Stage the changes** (no commit — orchestrator does the squash-merge):
   ```bash
   cd "$REPO_ROOT"
   git add MARKERS/SHAKEDOWN-01.txt PR_SIMULATIONS/SHAKEDOWN-01.json
   ```

4. **Return a summary** to the orchestrator with:
   - Confirmation marker file written + content
   - Confirmation PR sim written
   - Exit code 0

## Acceptance criteria
```bash
REPO_ROOT="$(git rev-parse --show-toplevel)"
test -f "$REPO_ROOT/MARKERS/SHAKEDOWN-01.txt"                                                          # exists
grep -qF "happy-path-pass-2026-05-02" "$REPO_ROOT/MARKERS/SHAKEDOWN-01.txt"                            # exact content
test -f "$REPO_ROOT/PR_SIMULATIONS/SHAKEDOWN-01.json"                                                   # exists
python3 -c "import json; json.load(open('$REPO_ROOT/PR_SIMULATIONS/SHAKEDOWN-01.json'))"               # valid JSON
git -C "$REPO_ROOT" status --short MARKERS/SHAKEDOWN-01.txt                                            # staged
```

## Pivot triggers
None expected. If somehow this fails, that's a real bug in either:
- The orchestrator's executor dispatch (wrong agent type, wrong prompt format, etc.) — diagnose in ORCHESTRATOR.md
- The integration-test.sh script (false negative on a happy path) — diagnose in integration-test.sh
- The repo state (missing dirs, etc.) — diagnose via preflight.sh

If you (the executor) cannot complete this trivial task, do NOT loop or retry. Report the exact error and exit non-zero. The orchestrator will route you to the heal protocol; we'll diagnose from STUCK_STATE doc.

## 3-strikes rule
N/A — this task is too simple for retry loops. One attempt, succeed or report failure.

## Open PR (simulated)
The PR simulation file written in WORK step 2 IS the PR. Orchestrator reads it for AI review and integration test. No real `gh pr create` is invoked.

When orchestrator advances this task to merged status, it tags `task-merged-T1-SHAKEDOWN-01-<sha>` and updates STATE/completed.json.

## Expected orchestrator behavior validating this shakedown

Verify after running:
- `STATE/eligible.json` → started empty
- `STATE/running.json` → had SHAKEDOWN-01 entry mid-cycle
- `STATE/pending_review.json` → had SHAKEDOWN-01 entry after executor returned
- `STATE/pending_merge.json` → had SHAKEDOWN-01 entry after AI review approved
- `STATE/completed.json` → has SHAKEDOWN-01 entry after integration test passed + squash-merge
- `MARKERS/SHAKEDOWN-01.txt` → exists with `happy-path-pass-2026-05-02`
- `PR_SIMULATIONS/SHAKEDOWN-01.json` → exists with valid JSON
- `git log sandbox-staging-T1 --oneline` → shows squash-merge commit "SHAKEDOWN-01: happy path marker"
- `git tag -l 'task-merged-T1-SHAKEDOWN-01-*'` → returns one tag
- `ORCHESTRATOR_LOG.md` → has cycle entry with exit reason "merged"

If any of these fail, that's a finding to capture and iterate on `ORCHESTRATOR.md` before writing SHAKEDOWN-02.
