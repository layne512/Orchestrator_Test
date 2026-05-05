# INTEGRATION FAILURE — SHAKEDOWN-05

**Detected:** 2026-05-05T00:11:00Z
**Wave:** T1
**Branch:** sandbox-staging-T1

## Failed check
- Phase 2 of `integration-test.sh` (marker content match)
- Expected `MARKERS/SHAKEDOWN-05.txt` to contain: `integration-fail-pass-2026-05-03`
- Actual content: `WRONG-CONTENT-deliberately-mismatches-expected-2026-05-03`

## Root cause
SHAKEDOWN-05 is **designed-to-fail** at the integration test stage. The executor wrote intentionally-wrong marker content per spec WORK section, AI review approved (under the orchestrator-set philosophy that content-vs-frontmatter is integration's job), the orchestrator squash-merged, and integration-test.sh's phase-2 grep -F caught the mismatch. The "failure" is the test's purpose: verifying the orchestrator's auto-revert path works end-to-end.

## Pre-merge tag
`merge-pre-SHAKEDOWN-05-1777963123` (forensic)

## Failed merge commit
`02a4df7b63f5ad99b983904ea20195843efa8b1f` — `SHAKEDOWN-05: title: Integration test fail — verify auto-revert on post-merge integration regression`

## Revert
- Action: `git revert HEAD --no-edit`
- Revert tag: `failed-merge-T1-SHAKEDOWN-05-<revert-sha>` (forensic)
- Working tree restored — MARKERS/SHAKEDOWN-05.txt and PR_SIMULATIONS/SHAKEDOWN-05.json removed by revert

## Outcome
- Task moved to STATE/stuck.json with status `needs_fix`
- Auto-resume disabled per ORCHESTRATOR.md iter-1 rule
- Wave continues — bad task does NOT block subsequent merges (Step 5 fail-path explicitly states this)

## Required follow-up (out-of-scope for iter 1)
- Author a corrected version of SHAKEDOWN-05's WORK block that writes the correct marker content
- Re-dispatch task; expect it to pass integration test on the corrected attempt
