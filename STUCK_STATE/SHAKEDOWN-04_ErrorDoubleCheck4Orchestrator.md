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
