---
task_id: SHAKEDOWN-09
title: Spec-induced stuck — verify spec-analyst spawns + SPEC_LESSONS entry created
kind: TEST
wave: T1
estimated_minutes: 12
calibrated_minutes: 12
dependencies: []
merge_order_after: []
files_owned:
  - MARKERS/SHAKEDOWN-09.txt
  - PR_SIMULATIONS/SHAKEDOWN-09.json
target_wave_branch: sandbox-staging-T1
ai_review_required: false
human_review_required: false
integration_smoke_test:
  - "Spec-analyst subagent spawned; new entry in SPEC_LESSONS.md; SPEC_TEMPLATE.md possibly updated"
expected_marker_content: "(none — designed to be spec-stuck)"
downstream_blocker_count: 1
priority_score: 112
---

# SHAKEDOWN-09 — Spec-induced stuck (designed for spec-analyst spawn)

You are the **expert of this task**. This spec is **DELIBERATELY UNDERSPECIFIED** to test the orchestrator's spec-analyst dispatch.

## Goal
Reach an ambiguous acceptance criterion that you (the executor) cannot definitively meet. Write the two stuck reports identifying that **the spec itself is the problem** (not infrastructure). Orchestrator should:
1. Read Report 1, walk diagnostic checklist, find no infrastructure cause
2. Read Report 2, see Section A confirms "spec is ambiguous" — classification = `spec`
3. Spawn spec-analyst subagent
4. Spec-analyst returns 4-field response:
   - `is_spec_issue: true`
   - `lesson_text` — for SPEC_LESSONS.md
   - `proposed_template_update` — diff against SPEC_TEMPLATE.md (e.g., "every spec must have measurable acceptance criteria")
   - `recommended_action: fix-spec-and-redispatch` (or similar)
5. Orchestrator appends lesson to `SPEC_LESSONS.md`
6. Orchestrator updates `SPEC_TEMPLATE.md` if patch present
7. Task moves to stuck.json with status `awaiting_spec_revision`

## Context
- ORCHESTRATOR.md Step 6 phase 6.C (spec-analyst dispatch)
- SPEC_LESSONS.md analyst contract
- SPEC_TEMPLATE.md (will be updated based on lesson)

## STEP 0 — Self-heal
```bash
set -uo pipefail
REPO_ROOT="$(git rev-parse --show-toplevel)"

for d in MARKERS PR_SIMULATIONS STUCK_STATE; do
  if [[ ! -d "$REPO_ROOT/$d" ]]; then
    mkdir -p "$REPO_ROOT/$d" || { echo "STUCK: cannot create $d/"; exit 1; }
  fi
done
echo "STEP 0: OK"
```

## STEP 1 — Smoke test
N/A.

## WORK — DELIBERATELY AMBIGUOUS

Make the marker file "good enough" — but I (the spec author) won't tell you what "good enough" means. There's no objective test. The marker file should be... appropriate. Use your judgment.

Hint: there is no correct answer here. Any content you write could be argued to be "good enough" or "not good enough" by a reasonable reviewer. This is the designed ambiguity.

## Acceptance criteria

The marker file should be acceptable. Acceptability is subjective. You should know it when you see it.

(This is the designed ambiguity — no measurable acceptance criterion. You cannot determine when you're done.)

## Pivot triggers

If you find yourself unable to determine whether you've met the acceptance criterion → that IS the trigger. Write the two stuck reports with the spec-issue diagnosis.

## STUCK PROTOCOL — write reports identifying spec ambiguity

### Report 1 — `STUCK_STATE/SHAKEDOWN-09_Error4Orchestrator.md`

```markdown
# SHAKEDOWN-09 — Error report for orchestrator

**Task:** SHAKEDOWN-09
**Wave:** T1
**Timestamp:** <ISO>
**Step where I failed:** Acceptance criteria check

## Exact error
\`\`\`
Cannot determine whether marker content meets "good enough" criterion.
The spec defines acceptability as "subjective; you should know it when you see it."
No objective test exists.
\`\`\`

## What I was trying to do at that moment
Verify my marker file content against the acceptance criterion before declaring the task complete.

## Single most likely cause (gut check)
The spec's acceptance criterion is ambiguous by design — there is no objective test.

---
**End of Report 1.** Detailed analysis in Report 2.
```

### Report 2 — `STUCK_STATE/SHAKEDOWN-09_ErrorDoubleCheck4Orchestrator.md`

```markdown
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
```

### Exit
Summary: `STUCK: SHAKEDOWN-09 spec is ambiguous; cannot determine acceptance; spec-analyst dispatch expected`. Exit non-zero.

## 3-strikes rule
N/A.

## Open PR
None.
