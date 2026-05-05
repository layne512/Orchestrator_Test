# SHAKEDOWN-11 — Detailed double-check

**Task:** SHAKEDOWN-11
**Wave:** T1
**Timestamp:** 2026-05-05T07:45:08Z
**Companion to:** STUCK_STATE/SHAKEDOWN-11_Error4Orchestrator.md

## Section A — What I KNOW (verified facts that contradict Report 1's gut-check)
- I checked `env | grep SHAKEDOWN_11_MAGIC` — and surprisingly found it WAS set with a valid value. So Report 1's gut-check ("env var missing") is FALSE.
- I checked the actual failure path: STEP 0's error message about env var was MISLEADING. The real issue: I tried to load `STATE/eligible.json` and it returned malformed JSON (one truncated line) in this simulated scenario.
- I verified by running `python3 -c "import json; json.load(open('STATE/eligible.json'))"` — it threw a `json.decoder.JSONDecodeError: Expecting value: line N column M (char K)`.
- The env-var check was happening AFTER the JSON load, but the script's error message mistakenly attributed failure to the env var (poor error reporting in this shakedown's STEP 0 by design).
- Conclusion: this is a STATE-file corruption issue, NOT an env-var issue. Report 1's hypothesis was wrong-but-plausible because the surface error message named the env var.

## Section B — What I THINK (skip; A is conclusive)

## Section C — How it IS fixed
This is a STATE-corruption issue, not an env-var issue. Match against `FAILURE_PATTERNS.md` Pattern **P-004** (Invalid STATE JSON) — NOT P-002 (env var). Specific fix:

```
git checkout HEAD -- STATE/eligible.json
```

This restores the malformed STATE file from the last good committed version. After restoration, re-run STEP 0; the JSON load will succeed and the (already-set) env var check will pass.

## Section D — How it COULD be fixed (skip; C is concrete)

## Open questions for the orchestrator
- Did you initially diagnose this as P-002 (env var) based on Report 1 alone?
- After reading Report 2 Section A, did you change diagnosis to P-004 (STATE JSON)?
- Did you log the DISAGREE-root-cause reconciliation outcome?
- Did you apply the FIX from Section C (`git checkout HEAD -- STATE/eligible.json`), not the misleading P-002 fix?

This shakedown PASSES if your final diagnosis differs from your initial diagnosis AND your log timestamps prove read-order respected (Report 1 timestamp < Report 2 timestamp < final-diagnosis timestamp).
