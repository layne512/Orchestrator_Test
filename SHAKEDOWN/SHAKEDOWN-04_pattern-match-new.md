---
task_id: SHAKEDOWN-04
title: Pattern match (new) — verify failure-analyst spawn for novel pattern + merge ordering
kind: TEST
wave: T1
estimated_minutes: 15
calibrated_minutes: 15
dependencies: []
merge_order_after: [SHAKEDOWN-03]
files_owned:
  - MARKERS/SHAKEDOWN-04.txt
  - PR_SIMULATIONS/SHAKEDOWN-04.json
target_wave_branch: sandbox-staging-T1
ai_review_required: false
human_review_required: false
integration_smoke_test:
  - "Novel pattern triggered failure-analyst spawn; new entry P-005 added to FAILURE_PATTERNS.md"
expected_marker_content: "(none — designed to fail with novel pattern)"
downstream_blocker_count: 1
priority_score: 115
---

# SHAKEDOWN-04 — Pattern match new (designed to trigger failure-analyst)

You are the **expert of this task**. This task is **DESIGNED TO FAIL** in a way that does NOT match any existing seed pattern (P-001 through P-004). The orchestrator should:
- Read Report 1, form initial diagnosis
- Read Report 2, attempt to match against patterns
- Find no match → spawn `failure-analyst` subagent
- failure-analyst returns 4-field response (classification, proposed_check_patch, pattern_entry, other_failures_covered)
- Orchestrator validates, applies patch to preflight, appends new pattern P-005 to FAILURE_PATTERNS.md

This task also tests **merge ordering**: `merge_order_after: [SHAKEDOWN-03]`. Even though SHAKEDOWN-03 ALSO fails, this 04 should not be merged before 03's heal completes (since 03 is in the merge chain conceptually).

## The novel failure (designed not to match P-001..P-004)
- Not a missing file (P-001)
- Not a missing env var (P-002)
- Not a wrong branch (P-003)
- Not invalid STATE JSON (P-004)
- Instead: simulated git LFS quota exhaustion (a class no seed pattern covers)

## Context
- ORCHESTRATOR.md Step 6 phase 6.D (failure-analyst dispatch)
- FAILURE_PATTERNS.md analyst contract

## STEP 0 — Self-heal
```bash
set -uo pipefail
REPO_ROOT="$(git rev-parse --show-toplevel)"

# Simulate the novel failure: a check that doesn't fit any P-001..P-004 class
SIMULATED_QUOTA=99999999
ACTUAL_USAGE=$((SIMULATED_QUOTA + 1))   # always exceeds (designed)
if [[ $ACTUAL_USAGE -gt $SIMULATED_QUOTA ]]; then
  echo "STUCK: simulated git LFS quota exhausted ($ACTUAL_USAGE > $SIMULATED_QUOTA)"
  # No existing pattern matches; orchestrator must spawn failure-analyst
fi
```

## STEP 1 — Smoke test
N/A.

## WORK — write stuck reports, exit

### Report 1 — `STUCK_STATE/SHAKEDOWN-04_Error4Orchestrator.md`

```markdown
# SHAKEDOWN-04 — Error report for orchestrator

**Task:** SHAKEDOWN-04
**Wave:** T1
**Timestamp:** <ISO>
**Step where I failed:** STEP 0 self-heal

## Exact error
\`\`\`
STUCK: simulated git LFS quota exhausted (100000000 > 99999999)
exit code: 1
\`\`\`

## What I was trying to do at that moment
Verify git LFS quota is not exhausted (simulated check unique to this shakedown).

## Single most likely cause (gut check)
LFS quota for the test environment was exceeded. None of the seed patterns P-001..P-004 cover this class.

---
**End of Report 1.** Detailed analysis in Report 2.
```

### Report 2 — `STUCK_STATE/SHAKEDOWN-04_ErrorDoubleCheck4Orchestrator.md`

```markdown
# SHAKEDOWN-04 — Detailed double-check

## Section A — What I KNOW
- The error message reports a simulated quota check (not a real LFS quota).
- This is designed to NOT match P-001..P-004 in FAILURE_PATTERNS.md.

## Section B — What I THINK
- The orchestrator should walk diagnostic checklist; closest matches are "external service unreachable" or "logic error" — but neither perfectly fits.
- Therefore the orchestrator should classify as a NOVEL pattern and spawn failure-analyst.

## Section C — How it IS fixed
- Orchestrator spawns failure-analyst subagent.
- failure-analyst returns:
  - classification: external (or a new sub-class for quota issues)
  - proposed_check_patch: add a quota-check function to preflight
  - pattern_entry: new "Pattern P-005: Storage/quota exhaustion" with template fields filled
  - other_failures_covered: GitHub API rate limits, Vercel deploy quota, Supabase row count limit, Stripe API rate limit, etc.
- Orchestrator applies the patch and appends P-005 to FAILURE_PATTERNS.md.

## Section D — How it COULD be fixed (skip — C is concrete)

## Open questions for the orchestrator
- Did failure-analyst's response have all 4 required fields?
- Did orchestrator validate the proposed_check_patch before applying?
- Is the new P-005 entry well-formed per FAILURE_PATTERNS.md template?
```

### Exit
Summary: `STUCK: novel quota exhaustion failure — no existing pattern; failure-analyst dispatch expected`. Exit non-zero.

## Acceptance criteria
- Both stuck reports written
- Orchestrator log shows "no pattern match; spawning failure-analyst"
- failure-analyst returned 4-field response
- New `Pattern P-005:` entry exists in FAILURE_PATTERNS.md
- Preflight has new check (e.g., `30_credentials.sh` or new `70_quotas.sh`) covering the generalized failure class
- Orchestrator log shows merge of SHAKEDOWN-04 was HELD until SHAKEDOWN-03 was processed (merge_order_after enforcement)

## Pivot triggers
None.

## 3-strikes rule
N/A.

## Open PR
None.
