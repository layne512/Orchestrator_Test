---
task_id: SHAKEDOWN-02
title: Missing-file stuck — verify heal protocol triggers correctly
kind: TEST
wave: T1
estimated_minutes: 10
calibrated_minutes: 10
dependencies: [SHAKEDOWN-01]
merge_order_after: []
files_owned:
  - MARKERS/SHAKEDOWN-02.txt
  - PR_SIMULATIONS/SHAKEDOWN-02.json
target_wave_branch: sandbox-staging-T1
ai_review_required: false
human_review_required: false
integration_smoke_test:
  - "Stuck protocol triggered (this task SHOULD fail)"
expected_marker_content: "(none — this task is designed to NOT write a marker)"
downstream_blocker_count: 0
priority_score: 110
---

# SHAKEDOWN-02 — Missing-file stuck (designed to fail STEP 0)

You are the **expert of this task**. This task is **DESIGNED TO FAIL** at STEP 0 to verify the orchestrator's stuck-detection and heal protocol. Do not try to make it succeed.

## Goal
Trigger the stuck protocol cleanly:
1. STEP 0 self-heal references a path that doesn't exist and CANNOT be created.
2. You write the two stuck reports (`Error4Orchestrator.md` + `ErrorDoubleCheck4Orchestrator.md`) per SPEC_TEMPLATE.md STUCK PROTOCOL.
3. Exit non-zero with `STUCK:` summary.

The orchestrator should detect the failure (mechanism 1: no marker; mechanism 2: STUCK report), read your reports in the correct order (Report 1 first, then Report 2), and either match against existing pattern P-001 (missing file) or spawn failure-analyst.

This task verifies dispatch ordering: it has `dependencies: [SHAKEDOWN-01]` so the orchestrator must NOT dispatch this until SHAKEDOWN-01 is in completed.json.

## Context
- ORCHESTRATOR.md Step 6 (heal protocol with Phase 6.A and 6.B)
- SPEC_TEMPLATE.md STUCK PROTOCOL
- FAILURE_PATTERNS.md P-001 (missing file)

## STEP 0 — Self-heal (this is where you fail)
```bash
set -uo pipefail
REPO_ROOT="$(git rev-parse --show-toplevel)"

# DETECT a path that genuinely does not exist and CANNOT be self-healed
DECOY_PATH="$REPO_ROOT/lib/intentionally-nonexistent/required-by-shakedown-02.dat"
if [[ ! -f "$DECOY_PATH" ]]; then
  echo "STUCK: required file $DECOY_PATH not present, no canonical source to copy from"
  # Do NOT mkdir + touch a stub — that would defeat the test
  # Write the two stuck reports per SPEC_TEMPLATE.md, then exit non-zero
  # (continue to the WORK section's stuck-protocol writeup below)
fi
```

## STEP 1 — Smoke test
N/A — STEP 0 fails before we get here.

## WORK — write the two stuck reports, then exit

When STEP 0 fails (which it WILL):

### Write Report 1
Create `STUCK_STATE/SHAKEDOWN-02_Error4Orchestrator.md`:

```markdown
# SHAKEDOWN-02 — Error report for orchestrator

**Task:** SHAKEDOWN-02
**Wave:** T1
**Timestamp:** <fill in current ISO timestamp>
**Step where I failed:** STEP 0 self-heal

## Exact error
\`\`\`
STUCK: required file lib/intentionally-nonexistent/required-by-shakedown-02.dat not present, no canonical source to copy from
exit code: 1
\`\`\`

## What I was trying to do at that moment
Verify a required dependency file exists at lib/intentionally-nonexistent/required-by-shakedown-02.dat per the spec's STEP 0 self-heal block.

## Single most likely cause (gut check)
The file was never created because the path is intentionally fictitious for this shakedown — no real component creates it.

---
**End of Report 1.** Detailed analysis in `SHAKEDOWN-02_ErrorDoubleCheck4Orchestrator.md`.
```

### Write Report 2
Create `STUCK_STATE/SHAKEDOWN-02_ErrorDoubleCheck4Orchestrator.md`:

```markdown
# SHAKEDOWN-02 — Detailed double-check for orchestrator

**Task:** SHAKEDOWN-02
**Wave:** T1
**Read this AFTER you've formed initial diagnosis from Report 1.**

## Section A — What I KNOW happened (verified facts only)
- I verified the path `lib/intentionally-nonexistent/required-by-shakedown-02.dat` does not exist via `test -f`.
- I verified the parent directory `lib/intentionally-nonexistent/` does not exist via `test -d`.
- I observed STEP 0 exited non-zero with "STUCK:" output.

## Section B — What I THINK happened (skip — Section A is complete)

## Section C — How it IS fixed
Three options, in order of preference:
1. **Recognize this is the designed failure for this shakedown** — no fix needed; the orchestrator should match against pattern P-001 (missing file) and proceed via heal protocol. This task is supposed to fail.
2. If this were a real task and the file SHOULD exist: the canonical source needs to be identified and copied/created.
3. If the file genuinely shouldn't exist: the spec is wrong and should be corrected.

## Section D — How it COULD be fixed (skip — Section C is complete)

## Open questions for the orchestrator
- Did the orchestrator correctly read Report 1 BEFORE this Report 2? (Verifiable by ORCHESTRATOR_LOG.md timestamp ordering.)
- Did the orchestrator's initial diagnosis match Report 1's "single most likely cause" (designed-failure scenario)?
- Did the orchestrator use Report 2's open question above to confirm read-order?
```

### Exit non-zero
After writing both reports, return summary:
```
STUCK: missing file lib/intentionally-nonexistent/required-by-shakedown-02.dat — designed failure for shakedown-02; reports written to STUCK_STATE/
```

Exit non-zero.

## Acceptance criteria
This task SUCCEEDS in the test sense if:
- Both stuck reports exist in STUCK_STATE/
- Orchestrator's log shows Report 1 read before Report 2 (timestamp ordering)
- Orchestrator's initial diagnosis was formed before reading Report 2
- Orchestrator either matched pattern P-001 OR spawned failure-analyst (logged either way)

## Pivot triggers
None — this task is designed to fail. If you find yourself "succeeding" (writing a marker), STOP — that defeats the test.

## STUCK PROTOCOL
This entire task IS a stuck-protocol exercise. See WORK section above.

## 3-strikes rule
N/A — single deliberate failure.

## Open PR (simulated)
None — this task does not create a PR; it tests the heal path.
