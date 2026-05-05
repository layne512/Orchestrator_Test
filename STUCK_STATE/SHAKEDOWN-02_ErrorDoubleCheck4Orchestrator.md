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
