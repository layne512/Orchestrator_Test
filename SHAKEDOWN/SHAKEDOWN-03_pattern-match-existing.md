---
task_id: SHAKEDOWN-03
title: Pattern match (existing) — verify orchestrator increments recurrence without spawning analyst
kind: TEST
wave: T1
estimated_minutes: 8
calibrated_minutes: 8
dependencies: []
merge_order_after: []
files_owned:
  - MARKERS/SHAKEDOWN-03.txt
  - PR_SIMULATIONS/SHAKEDOWN-03.json
target_wave_branch: sandbox-staging-T1
ai_review_required: false
human_review_required: false
integration_smoke_test:
  - "Existing pattern P-002 recurrence counter incremented; no failure-analyst spawn"
expected_marker_content: "(none — designed to fail with known pattern)"
downstream_blocker_count: 1
priority_score: 108
---

# SHAKEDOWN-03 — Pattern match existing (designed to hit seed pattern P-002)

You are the **expert of this task**. This task is **DESIGNED TO FAIL** in a way that matches an existing seed pattern in `FAILURE_PATTERNS.md` (P-002: Missing or empty env var). The orchestrator should match the pattern, increment its recurrence counter, and NOT spawn a failure-analyst (since the failure class is already known).

## Goal
1. STEP 0 requires an env var `SHAKEDOWN_03_REQUIRED_KEY` that is intentionally not set.
2. Self-heal cannot fix this (env vars must be set externally).
3. You write the two stuck reports.
4. Exit non-zero with STUCK summary.

Orchestrator should:
- Read Report 1, form initial diagnosis ("missing env var")
- Read Report 2, confirm
- Match against `FAILURE_PATTERNS.md` Pattern P-002
- Increment P-002 recurrences from 0 to 1
- NOT spawn failure-analyst (existing pattern)
- Log "matched pattern P-002; recurrence now 1"

## Context
- FAILURE_PATTERNS.md Pattern P-002 (missing or empty env var)
- ORCHESTRATOR.md Step 6 phase 6.A diagnosis matching

## STEP 0 — Self-heal
```bash
set -uo pipefail
REPO_ROOT="$(git rev-parse --show-toplevel)"

# Check required env var
if [[ -z "${SHAKEDOWN_03_REQUIRED_KEY:-}" ]]; then
  echo "STUCK: env var SHAKEDOWN_03_REQUIRED_KEY is not set or is empty"
  # Self-heal cannot fix env vars — write stuck reports + exit
fi
```

## STEP 1 — Smoke test
N/A — STEP 0 fails first.

## WORK — write stuck reports, exit

### Report 1 — `STUCK_STATE/SHAKEDOWN-03_Error4Orchestrator.md`

```markdown
# SHAKEDOWN-03 — Error report for orchestrator

**Task:** SHAKEDOWN-03
**Wave:** T1
**Timestamp:** <ISO timestamp>
**Step where I failed:** STEP 0 self-heal

## Exact error
\`\`\`
STUCK: env var SHAKEDOWN_03_REQUIRED_KEY is not set or is empty
exit code: 1
\`\`\`

## What I was trying to do at that moment
Verify required env var SHAKEDOWN_03_REQUIRED_KEY is set per spec's STEP 0.

## Single most likely cause (gut check)
Env var was never exported in this shell session. Self-heal cannot fix env vars — they must be set externally.

---
**End of Report 1.** Detailed analysis in `SHAKEDOWN-03_ErrorDoubleCheck4Orchestrator.md`.
```

### Report 2 — `STUCK_STATE/SHAKEDOWN-03_ErrorDoubleCheck4Orchestrator.md`

```markdown
# SHAKEDOWN-03 — Detailed double-check for orchestrator

## Section A — What I KNOW happened (verified)
- `echo "${SHAKEDOWN_03_REQUIRED_KEY:-EMPTY}"` returned "EMPTY"
- The env var is not present in `env | grep SHAKEDOWN_03`
- STEP 0 exited non-zero with the STUCK message

## Section B — What I THINK happened (skip; A complete)

## Section C — How it IS fixed
This failure should match `FAILURE_PATTERNS.md` Pattern P-002 (Missing or empty env var). The orchestrator should:
1. Increment P-002's Recurrences counter from 0 to 1
2. NOT spawn failure-analyst (pattern already exists)
3. Log "matched pattern P-002 — recurrence now 1"

The class-level fix (preflight 10_env_vars.sh) is already documented in P-002. For this specific shakedown, no real fix needed because this is a designed failure.

## Section D — How it COULD be fixed (skip)

## Open questions for the orchestrator
- Did you correctly identify this as Pattern P-002 (vs spawning a new failure-analyst)?
- Did you increment the recurrence counter as P-002 specifies?
```

### Exit
Return summary: `STUCK: env var SHAKEDOWN_03_REQUIRED_KEY missing — matches existing pattern P-002`. Exit non-zero.

## Acceptance criteria
- Both stuck reports written
- Orchestrator log shows "matched pattern P-002 — recurrence now 1"
- Orchestrator did NOT spawn failure-analyst (no analyst dispatch entry in log)
- FAILURE_PATTERNS.md shows updated `**Recurrences:** 1 (SHAKEDOWN-03)` for P-002

## Pivot triggers
None — designed failure.

## 3-strikes rule
N/A.

## Open PR
None.
