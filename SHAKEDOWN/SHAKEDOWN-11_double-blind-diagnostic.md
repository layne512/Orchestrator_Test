---
task_id: SHAKEDOWN-11
title: Double-blind diagnostic — verify orchestrator reads Report 1 BEFORE Report 2 + initial vs final diagnoses differ
kind: TEST
wave: T1
estimated_minutes: 12
calibrated_minutes: 12
dependencies: []
merge_order_after: []
files_owned:
  - MARKERS/SHAKEDOWN-11.txt
  - PR_SIMULATIONS/SHAKEDOWN-11.json
target_wave_branch: sandbox-staging-T1
ai_review_required: false
human_review_required: false
integration_smoke_test:
  - "Orchestrator log timestamps prove Report 1 read BEFORE Report 2"
  - "Initial diagnosis (from Report 1 alone) differs from final diagnosis (after Report 2 reconciliation)"
  - "Reconciliation outcome documented as DISAGREE-root-cause or DISAGREE-fix"
expected_marker_content: "(none — designed to be stuck with deliberately misleading Report 1)"
downstream_blocker_count: 1
priority_score: 112
---

# SHAKEDOWN-11 — Double-blind diagnostic verification

You are the **expert of this task**. This task is **DESIGNED TO FAIL** with a deliberate twist: Report 1 contains a **misleading hypothesis** that should drive an INCORRECT initial diagnosis from the orchestrator. Report 2 then provides the correct reasoning. This proves the orchestrator's read-order discipline (Report 1 first) AND that Report 2's reconciliation actually changes the final diagnosis.

## Goal
1. STEP 0 deliberately fails with a confusing error (looks like one cause but is actually another).
2. You write Report 1 with a wrong-but-plausible hypothesis ("missing env var").
3. You write Report 2 with the correct full reasoning ("actually a stale STATE file from a prior cycle").
4. Orchestrator's heal protocol Phase 6.A reads Report 1 → forms initial diagnosis "missing env var" → matches Pattern P-002.
5. Orchestrator logs Phase 6.A timestamp + initial proposed fix.
6. Orchestrator's Phase 6.B reads Report 2 → sees Section A confirms a STATE file issue, NOT env var.
7. Orchestrator reconciles: DISAGREE on root cause. Final diagnosis: STATE file issue (matches Pattern P-004).
8. Orchestrator logs reconciliation timestamp + final diagnosis (different from initial).

## Context
- ORCHESTRATOR.md Step 6.A and 6.B (read-order enforcement)
- SPEC_TEMPLATE.md STUCK PROTOCOL (two-report pattern)

## STEP 0 — Self-heal (deliberately confusing failure)

```bash
set -uo pipefail
REPO_ROOT="$(git rev-parse --show-toplevel)"

# DELIBERATELY MISLEADING: failure that LOOKS like env var but isn't
# Real cause: a corrupted STATE file (we'll simulate this)
# Apparent cause from error message: env var missing

# Simulate corruption (don't actually corrupt — just produce misleading error)
APPARENT_ERROR="env var SHAKEDOWN_11_MAGIC missing or empty"
ACTUAL_CAUSE="STATE/eligible.json was malformed in a prior cycle (simulated)"

echo "STUCK: $APPARENT_ERROR"
echo "(actual cause hidden — see Report 2 Section A for the verified truth)"
# Exit non-zero so orchestrator triggers heal protocol
exit 1
```

## STEP 1 — Smoke test
N/A.

## WORK — write reports with deliberate misdirection in Report 1

### Report 1 — `STUCK_STATE/SHAKEDOWN-11_Error4Orchestrator.md`

This report is **deliberately wrong** in its "single most likely cause" — should drive orchestrator to wrong initial diagnosis.

```markdown
# SHAKEDOWN-11 — Error report for orchestrator

**Task:** SHAKEDOWN-11
**Wave:** T1
**Timestamp:** <ISO>
**Step where I failed:** STEP 0

## Exact error
\`\`\`
STUCK: env var SHAKEDOWN_11_MAGIC missing or empty
exit code: 1
\`\`\`

## What I was trying to do at that moment
Verify a required env var was set before proceeding with WORK.

## Single most likely cause (gut check)
The env var SHAKEDOWN_11_MAGIC was never set in this shell. Self-heal cannot fix env vars.

(Hint to orchestrator: this is what the error MESSAGE says. Section A of Report 2 has the verified reality.)

---
**End of Report 1.** Detailed analysis in Report 2.
```

### Report 2 — `STUCK_STATE/SHAKEDOWN-11_ErrorDoubleCheck4Orchestrator.md`

This report contains the **correct reasoning** that orchestrator only sees AFTER forming initial diagnosis.

```markdown
# SHAKEDOWN-11 — Detailed double-check

## Section A — What I KNOW (verified facts that contradict Report 1's gut-check)
- I checked `env | grep SHAKEDOWN_11_MAGIC` — and surprisingly found it WAS set with a valid value.
- I checked the actual failure path: STEP 0's error message about env var was MISLEADING. The real issue: I tried to load `STATE/eligible.json` and it returned malformed JSON (one truncated line).
- I verified by running `python3 -c "import json; json.load(open('STATE/eligible.json'))"` — it threw a JSONDecodeError.
- The env-var check was happening AFTER the JSON load, but the script's error message mistakenly attributed failure to env var (poor error reporting in this shakedown's STEP 0 by design).

## Section B — What I THINK (skip; A is conclusive)

## Section C — How it IS fixed
This is a STATE-corruption issue, not an env-var issue. Match against `FAILURE_PATTERNS.md` Pattern P-004 (Invalid STATE JSON). Specific fix: restore STATE/eligible.json from git (`git checkout HEAD -- STATE/eligible.json`).

## Section D — How it COULD be fixed (skip; C is concrete)

## Open questions for the orchestrator
- Did you initially diagnose this as P-002 (env var) based on Report 1 alone?
- After reading Report 2 Section A, did you change diagnosis to P-004 (STATE JSON)?
- Did you log the DISAGREE-root-cause reconciliation outcome?
- Did you apply the FIX from Section C (restore STATE file from git), not the misleading P-002 fix?

This shakedown PASSES if your final diagnosis differs from your initial diagnosis AND your log timestamps prove read-order respected (Report 1 timestamp < Report 2 timestamp < final-diagnosis timestamp).
```

### Exit
Summary: `STUCK: STEP 0 failed; reports written; this is the double-blind diagnostic test`. Exit non-zero.

## Acceptance criteria
The shakedown PASSES if `ORCHESTRATOR_LOG.md` shows:
1. Read-order: timestamp of "read Error4Orchestrator.md" < timestamp of "read ErrorDoubleCheck4Orchestrator.md"
2. Initial diagnosis (from Report 1 alone) was something like "missing env var, P-002 candidate"
3. Final diagnosis (after Report 2) was "STATE corruption, P-004 candidate"
4. Reconciliation outcome logged as `DISAGREE-root-cause`
5. Final fix applied was related to STATE file restoration (not env var)

## Pivot triggers
None — this task IS a stuck-protocol exercise.

## STUCK PROTOCOL
This entire task IS the stuck-protocol exercise. See WORK section.

## 3-strikes rule
N/A.

## Open PR
None.
