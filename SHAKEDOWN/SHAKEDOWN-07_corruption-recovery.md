---
task_id: SHAKEDOWN-07
title: Corruption recovery — verify revert + FIX targets preserved feature branch
kind: TEST
wave: T1
estimated_minutes: 15
calibrated_minutes: 15
dependencies: []
merge_order_after: []
files_owned:
  - MARKERS/SHAKEDOWN-07.txt
  - PR_SIMULATIONS/SHAKEDOWN-07.json
target_wave_branch: sandbox-staging-T1
ai_review_required: true
human_review_required: false
integration_smoke_test:
  - "MARKERS/SHAKEDOWN-07.txt contains 'recovery-pass-2026-05-03'"
  - "After human-injected corruption, revert + FIX path completes cleanly"
expected_marker_content: "recovery-pass-2026-05-03"
downstream_blocker_count: 1
priority_score: 115
---

# SHAKEDOWN-07 — Corruption recovery

You are the **expert of this task**. This task is **DESIGNED TO PASS NORMALLY** on first run. The "corruption" is injected MANUALLY by the human AFTER the task merges, to test the revert + FIX-on-preserved-branch flow.

## Goal

Two-phase test:

**Phase 1 (this task as written):**
1. STEP 0 + STEP 1 succeed.
2. WORK writes correct marker content.
3. AI review approves.
4. Orchestrator merges.
5. Integration test passes.
6. Task moves to `completed.json`.

**Phase 2 (manual injection by human):**
After Phase 1 completes, the human runs the following on their machine to inject corruption:
```bash
# Corrupt the merged marker
echo "CORRUPTED-after-merge-not-pass" > MARKERS/SHAKEDOWN-07.txt
git add MARKERS/SHAKEDOWN-07.txt
git commit -m "manual corruption injection for SHAKEDOWN-07 test"
```

Then re-invoke the orchestrator. Orchestrator should detect via integration test re-run (or manual trigger) that SHAKEDOWN-07's marker no longer contains expected content. Orchestrator triggers revert + FIX flow.

## Context
- ORCHESTRATOR.md Step 5 fail path (revert + FIX with target_feature_branch)
- Design spec §6.4 (single-task corruption recovery)

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
test -d MARKERS && test -d PR_SIMULATIONS
```

## WORK (Phase 1 — pass normally)
```bash
REPO_ROOT="$(git rev-parse --show-toplevel)"

echo "recovery-pass-2026-05-03" > "$REPO_ROOT/MARKERS/SHAKEDOWN-07.txt"

cat > "$REPO_ROOT/PR_SIMULATIONS/SHAKEDOWN-07.json" <<EOF
{
  "task_id": "SHAKEDOWN-07",
  "title": "SHAKEDOWN-07: corruption recovery (Phase 1)",
  "body": "Phase 1 passes normally. Phase 2 (corruption injection + recovery) tested by manual flow per spec.",
  "head": "sandbox/test-07-corruption-recovery",
  "base": "sandbox-staging-T1",
  "files_changed": ["MARKERS/SHAKEDOWN-07.txt"],
  "simulated": true,
  "phase": 1,
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

git add MARKERS/SHAKEDOWN-07.txt PR_SIMULATIONS/SHAKEDOWN-07.json
echo "Phase 1 done"
```

## Acceptance criteria

**Phase 1:**
```bash
test -f MARKERS/SHAKEDOWN-07.txt
grep -qF "recovery-pass-2026-05-03" MARKERS/SHAKEDOWN-07.txt
git log --oneline | head -1 | grep "SHAKEDOWN-07"
```

**Phase 2 (after manual corruption + orchestrator re-invoke):**
```bash
# Orchestrator should have:
git tag -l 'failed-merge-T1-SHAKEDOWN-07-*'    # forensic tag from revert
test -f INTEGRATION_FAILURES/SHAKEDOWN-07.md   # forensic doc
git log --oneline | head -3 | grep -q "Revert"  # revert commit on staging branch
```

The "preserved feature branch" check is conceptual in iter 1 (no real feature branches; just the test repo). In production it would verify `mvp/w1-test-07-corruption-recovery` still exists and the FIX task targets it.

## Pivot triggers
None for Phase 1. For Phase 2, the orchestrator handles corruption per its standard revert flow.

## STUCK PROTOCOL
Phase 1 should not get stuck. If it does, write the two reports.

## 3-strikes rule
Standard.

## Open PR
PR simulation written in Phase 1.

## Manual injection commands (run by human after Phase 1 completes)

To trigger Phase 2 testing:
```bash
cd ~/Documents/Orchestrator_Test
echo "CORRUPTED-after-merge-not-pass" > MARKERS/SHAKEDOWN-07.txt
git add MARKERS/SHAKEDOWN-07.txt
git commit -m "test: inject corruption for SHAKEDOWN-07 Phase 2"

# Now re-invoke orchestrator. It should detect corruption on next integration check.
# In iter 1, the orchestrator's auto-detection of post-merge corruption requires a forced re-check.
# Easiest: run integration-test.sh manually first to confirm it detects:
EXPECTED_MARKER_CONTENT="recovery-pass-2026-05-03" bash integration-test.sh --post-merge=SHAKEDOWN-07
# Should fail with content mismatch.

# Then re-invoke orchestrator. It should observe SHAKEDOWN-07 in completed.json,
# but integration check now fails. The handling here is best-effort in iter 1
# and may require explicit instruction to the orchestrator: "SHAKEDOWN-07 marker
# was corrupted; please revert + log."
```
