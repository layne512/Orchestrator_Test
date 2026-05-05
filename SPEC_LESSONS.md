# Spec Authoring Lessons

Append-only library of lessons learned about writing task specs. Each entry captures a specific spec-induced stuck, the lesson generalized, and the rule now enforced in `SPEC_TEMPLATE.md`.

## Entry template

```markdown
## Lesson L-NNN: <short name>

**First seen:** YYYY-MM-DD (<task-id>)
**Recurrences:** <count>
**Class:** <ambiguous-acceptance | missing-context | underspecified-work | wrong-pivot-trigger | bad-smoke-test | missing-frontmatter-field | ...>

**What went wrong:** the executor got stuck because <spec gap>. Specifically: <quote from spec showing the issue>.

**Why it was a spec issue, not infrastructure:** <reasoning — preflight couldn't have caught this because ...>

**Bad exemplar (from the original spec):**

\`\`\`
<excerpt of the problematic spec language>
\`\`\`

**Fixed exemplar (how it should have been written):**

\`\`\`
<excerpt of the corrected spec language>
\`\`\`

**Generalized rule (now in SPEC_TEMPLATE.md):** <rule that catches THIS + similar>

**Other patterns this covers:**
- <bullet list>

**Prevention scope:** all future task specs (template enforces from version <N>)
```

## Spec-analyst subagent contract

When a stuck task's diagnosis points to the spec itself, the orchestrator spawns a `spec-analyst` subagent. It receives:
- Stuck task error trail
- The task's spec content
- This file (SPEC_LESSONS.md)
- SPEC_TEMPLATE.md

It must return EXACTLY 4 fields per the contract in `ORCHESTRATOR.md` Step 6b.

The orchestrator validates the response and applies — same review-gate pattern as failure-analyst.

---

## Lessons (chronological)

## Lesson L-001: Ambiguous acceptance criteria (subjective prose instead of verifiable commands)

**First seen:** 2026-05-05 (SHAKEDOWN-09)
**Recurrences:** 0
**Class:** ambiguous-acceptance

**What went wrong:** The executor reached the end of the WORK section but could not determine whether it had satisfied the acceptance criterion, because the criterion was written as subjective prose rather than as an executable check. Specifically, the spec's `## Acceptance criteria` section read: "The marker file should be acceptable. Acceptability is subjective. You should know it when you see it." With no measurable assertion (expected content, exact size, required pattern) and no `expected_marker_content` field in frontmatter (it was set to "(none — designed to be spec-stuck)"), no executor could decide deterministically whether to declare done, write the marker, or escalate. The WORK section reinforced the ambiguity ("Make the marker file 'good enough'... appropriate. Use your judgment.").

**Why it was a spec issue, not infrastructure:** Preflight, self-heal, and smoke test all passed. STEP 0 created `MARKERS/`, `PR_SIMULATIONS/`, `STUCK_STATE/` cleanly; no env vars, paths, dependencies, or git state were in error. The executor's STUCK Report 2 Section A confirms infrastructure was healthy. The only blocker was that no objective predicate existed in the spec — a defect that lives in the spec text itself, not in the runtime environment. No amount of preflight checking against the filesystem, git, or env can detect "this prose is not a bash command." The fault is upstream of execution.

**Bad exemplar (from the original spec):**

```
## Acceptance criteria

The marker file should be acceptable. Acceptability is subjective. You should know it when you see it.

(This is the designed ambiguity — no measurable acceptance criterion. You cannot determine when you're done.)
```

(Frontmatter compounded this: `expected_marker_content: "(none — designed to be spec-stuck)"` and `integration_smoke_test: ["Spec-analyst subagent spawned; new entry in SPEC_LESSONS.md; SPEC_TEMPLATE.md possibly updated"]` — neither is a runnable check.)

**Fixed exemplar (how it should have been written):**

```
## Acceptance criteria

All of the following bash commands MUST exit 0:

\`\`\`bash
set -euo pipefail
REPO_ROOT="$(git rev-parse --show-toplevel)"

test -f "$REPO_ROOT/MARKERS/SHAKEDOWN-09.txt"

EXPECTED="SHAKEDOWN-09 marker: spec-analyst dispatch verified"
diff <(printf '%s\n' "$EXPECTED") "$REPO_ROOT/MARKERS/SHAKEDOWN-09.txt"

SIZE=$(wc -c < "$REPO_ROOT/MARKERS/SHAKEDOWN-09.txt")
[[ "$SIZE" -ge 10 && "$SIZE" -le 200 ]]

test -f "$REPO_ROOT/PR_SIMULATIONS/SHAKEDOWN-09.json"
python3 -c 'import json,sys; json.load(open(sys.argv[1]))' \
  "$REPO_ROOT/PR_SIMULATIONS/SHAKEDOWN-09.json"
\`\`\`

If every command above exits 0, the task is done. If any exits non-zero, fix or invoke STUCK PROTOCOL.
```

(And the frontmatter would carry a concrete `expected_marker_content: "SHAKEDOWN-09 marker: spec-analyst dispatch verified"` matching the diff above.)

**Generalized rule (now in SPEC_TEMPLATE.md):** Every `## Acceptance criteria` section MUST consist exclusively of bash commands (or other runnable checks) that exit 0 on success and non-zero on failure. Prose, subjective adjectives ("acceptable", "appropriate", "good enough", "reasonable", "use your judgment"), and "I'll know it when I see it" formulations are forbidden. If the task produces a marker or artifact, the frontmatter MUST contain a non-placeholder `expected_marker_content` (or equivalent expected-artifact field), and the acceptance criteria MUST diff/grep against that exact value. Specs that fail this check are rejected by the orchestrator before dispatch.

**Other patterns this covers:**
- Frontmatter fields with placeholder values like "(none — designed to be spec-stuck)", "TBD", "see WORK", or empty strings used where a concrete value is required.
- WORK sections that defer to executor judgment ("appropriate", "use your judgment", "make it nice") instead of giving concrete commands/edits.
- `integration_smoke_test` entries that describe orchestrator behavior or process outcomes ("subagent spawned") rather than verifiable assertions about repo state.
- Pivot triggers stated in subjective terms ("if it feels off") rather than "if exit code != 0" or "if file X missing."
- Acceptance criteria that mix prose and commands — the prose half always wins ambiguity, so the commands stop being authoritative.

**Prevention scope:** all future task specs (template enforces from version 3 onward). Orchestrator pre-dispatch validator should grep `## Acceptance criteria` for forbidden phrases ("subjective", "should know it when", "good enough", "appropriate", "use your judgment") and refuse dispatch on match. Spec authors must update existing W0/W1 specs that fail the check before they enter the eligible queue.
