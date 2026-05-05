# SHAKEDOWN-09 — Detailed double-check

## Section A — What I KNOW
- The acceptance criterion section reads: "The marker file should be acceptable. Acceptability is subjective. You should know it when you see it."
- This contains no measurable assertion (no expected content, no exact size, no required pattern).
- The WORK section similarly says "appropriate. Use your judgment."
- No `expected_marker_content` field in frontmatter (it's "(none — designed to be spec-stuck)").

## Section B — What I THINK
This is a SPEC issue, not an infrastructure issue:
- Infrastructure (preflight, env vars, dependencies, paths) is all fine.
- Self-heal succeeded; smoke test passed; STEP 0 + STEP 1 fine.
- The blocker is purely the spec — no executor can complete this without subjective interpretation.

## Section C — How it IS fixed
Not fixable from executor side. Requires SPEC REVISION:
1. Replace acceptance criteria with measurable assertions (e.g., "marker contains exact string X").
2. Add an `expected_marker_content` field to frontmatter.
3. Define WORK steps with concrete instructions.

## Section D — How it COULD be fixed (skip; C is concrete)

## Open questions for the orchestrator
- Did you correctly classify this as `spec` (not preflight-fixable)?
- Did you spawn spec-analyst (not failure-analyst)?
- Did spec-analyst return all 4 required fields?
- Was the proposed_template_update meaningful? (Suggested rule: "every acceptance criterion must be a verifiable command, not prose.")
