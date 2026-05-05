# Canonical Task Spec Template

Every task spec follows this template. Authors instantiate it; orchestrator dispatches the result; spec-analyst proposes updates to this file when lessons emerge.

**Template version:** 3 (added L-001: acceptance criteria must be verifiable bash commands, not prose)

---

## Frontmatter (YAML, required)

```yaml
---
task_id: <KIND>-<NN>_<slug>
title: <human-readable title>
kind: <TEST | FEAT | FIX | INFRA | INTG>
wave: <T1 | W0 | W1 | ...>
estimated_minutes: <int>
calibrated_minutes: <int>
dependencies: []                       # task IDs that must START AFTER (controls dispatch order)
merge_order_after: []                  # task IDs that must MERGE AFTER (controls integration order)
files_owned:                           # for run-time parallelism
  - <glob or path>
target_feature_branch: null
target_wave_branch: <sandbox-staging-T1 | mvp-staging-W{n}>
preserves_until: wave_approved
ai_review_required: true
human_review_required: false
integration_smoke_test:
  - "<plain-language assertion>"
expected_marker_content: "<string>"
downstream_blocker_count: <int>
priority_score: <int>
---
```

## Body sections (all required)

### `# <task_id> — <title>`

H1 line repeats task ID + title.

### `## Goal`

One paragraph: what this task delivers, why.

### `## Context`

Links + relevant excerpts from architecture / DB schema / design docs.

### `## STEP 0 — Self-heal (DETECT + CREATE)`

Bash commands that **DETECT** every path/file/condition referenced in the spec body **AND CREATE** missing items where possible.

```bash
set -uo pipefail
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "$(pwd)")"

# DETECT + CREATE: required directories
for d in MARKERS PR_SIMULATIONS STUCK_STATE; do
  if [[ ! -d "$REPO_ROOT/$d" ]]; then
    echo "WARN: $d/ missing — attempting self-heal"
    mkdir -p "$REPO_ROOT/$d" || { echo "STUCK: cannot create $d/"; exit 1; }
  fi
done

# DETECT + RESTORE: files that need specific content (from git)
for f in STATE/eligible.json; do
  if [[ ! -f "$REPO_ROOT/$f" ]]; then
    echo "WARN: $f missing — restoring from git"
    git -C "$REPO_ROOT" checkout HEAD -- "$f" || { echo "STUCK: cannot restore $f"; exit 1; }
  fi
done

# Final verification (must succeed)
test -d "$REPO_ROOT/MARKERS" || { echo "STUCK: MARKERS/ self-heal failed"; exit 1; }
echo "STEP 0: self-heal complete"
```

### `## STEP 1 — Smoke test (30 sec, no external services)`

Fast checks that prove environment is healthy enough for THIS task's scope.

### `## WORK`

Numbered steps the executor must execute. Each step concrete (specific commands, specific edits). No hand-waves.

### `## Acceptance criteria`

This section MUST consist exclusively of bash commands (or equivalent runnable checks) inside a fenced ```bash block. Each command MUST exit 0 on success and non-zero on failure. The orchestrator (or a CI harness) runs the entire block; if every command exits 0, the task is done.

Forbidden in this section (orchestrator pre-dispatch validator rejects on match):
- Prose-only criteria ("the marker file should be acceptable", "looks reasonable").
- Subjective adjectives: `acceptable`, `appropriate`, `good enough`, `reasonable`, `nice`, `clean enough`.
- Self-referential standards: "you should know it when you see it", "use your judgment", "subjective".
- Mixed prose-and-command lists where the prose carries the actual criterion.

If the task produces a marker file, frontmatter MUST set `expected_marker_content` to the EXACT string the marker should contain (no placeholders like `"(none)"` or `"TBD"`), and the acceptance criteria MUST verify that exact value, e.g.:

```bash
set -euo pipefail
REPO_ROOT="$(git rev-parse --show-toplevel)"
test -f "$REPO_ROOT/MARKERS/<task_id>.txt"
diff <(printf '%s\n' "<exact expected_marker_content>") \
     "$REPO_ROOT/MARKERS/<task_id>.txt"
```

If the task has no objective acceptance condition, it is not yet ready to dispatch — return it to spec authoring, do not paper over with subjective language.

### `## Pivot triggers`

Explicit "if X happens, ABANDON and file follow-up <kind> task."

### `## STUCK PROTOCOL (MANDATORY — write 2 reports before exiting)`

**This section is non-negotiable. If you (the executor) cannot complete the task — for ANY reason — you must write BOTH reports below to `STUCK_STATE/` before exiting.**

You are the **expert of your task**. The orchestrator is depending on you to clearly explain what went wrong so it can heal correctly.

#### Report 1 — `STUCK_STATE/<task_id>_Error4Orchestrator.md`

Short, factual. ~100-200 words. Read by orchestrator FIRST to form independent diagnosis.

```markdown
# <task_id> — Error report for orchestrator

**Task:** <task_id>
**Wave:** <wave>
**Timestamp:** <ISO timestamp>
**Step where I failed:** <e.g., "STEP 0 self-heal" | "WORK step 3" | "Acceptance criteria check 2">

## Exact error
\`\`\`
<verbatim error output, command that failed, exit code>
\`\`\`

## What I was trying to do at that moment
<one sentence>

## Single most likely cause (gut check)
<one sentence — your top hypothesis only; no exhaustive analysis>

---
**End of Report 1.** Detailed analysis (KNOW/THINK/FIX) is in `<task_id>_ErrorDoubleCheck4Orchestrator.md`.
The orchestrator reads this file first to form an INDEPENDENT diagnosis before reading Report 2.
```

#### Report 2 — `STUCK_STATE/<task_id>_ErrorDoubleCheck4Orchestrator.md`

Long-form, structured. Read by orchestrator AFTER it has formed an initial diagnosis from Report 1.

```markdown
# <task_id> — Detailed double-check for orchestrator

**Task:** <task_id>
**Wave:** <wave>
**Read this AFTER you (orchestrator) have formed an initial diagnosis from Report 1.**
This file presents the executor's full reasoning so the orchestrator can reconcile.

## Section A — What I KNOW happened (verified facts only)
- <fact 1, with how I verified it>
- <fact 2, with verification>
- (only things I directly observed; no inference)

## Section B — What I THINK happened (hypothesis if Section A insufficient)
> Skip if A is complete and explains the failure.
- <hypothesis 1, with reasoning>
- <hypothesis 2, alternative>
- <which I think is most likely and why>

## Section C — How it IS fixed (if I know the fix)
> Skip if you don't know.
- <exact commands/edits>
- <how I verified this would work>

## Section D — How it COULD be fixed (proposal if Section C unknown)
> Skip if C is complete.
- <proposed approach 1, with risks>
- <proposed approach 2, alternative>
- <my recommendation and why>

## Open questions for the orchestrator
- <anything I couldn't determine; orchestrator may have broader context>
```

#### Exit behavior when stuck

After writing both reports:
1. Return summary to orchestrator that begins with: `STUCK: <one-line reason>`
2. Exit non-zero
3. Do NOT loop or retry indefinitely
4. Do NOT delete partial work — leave it for forensic analysis

### `## 3-strikes rule`

If the same error appears 3 times consecutively after fixes, write the two stuck reports, exit non-zero. Standard.

### `## Open PR`

In iteration 1: PR creation is **simulated**. Write `PR_SIMULATIONS/<task_id>.json` with PR metadata (task_id, title, body, head, base, files_changed, simulated: true, created_at).

---

## Lessons-mandated rules (grow over time)

**Template v2 — Stuck protocol (added based on user request 2026-05-03):**

> **From design discussion:** Every executor must produce TWO stuck reports (Error4Orchestrator.md + ErrorDoubleCheck4Orchestrator.md) before exiting. The orchestrator reads them in order to maintain double-blind diagnosis.

**Template v3 — Verifiable acceptance criteria (added 2026-05-05 from Lesson L-001, SHAKEDOWN-09):**

> Every `## Acceptance criteria` section must be a runnable bash block. Prose criteria, subjective adjectives ("acceptable", "appropriate", "good enough"), and "I'll know it when I see it" formulations are forbidden. Tasks producing a marker file must declare a concrete `expected_marker_content` in frontmatter (no `TBD`, no `(none)` placeholders) and the acceptance block must `diff` or `grep` against that exact value. Orchestrator pre-dispatch validator greps for forbidden phrases (`subjective`, `should know it when`, `good enough`, `appropriate`, `use your judgment`) under the Acceptance heading and refuses to dispatch on match. See SPEC_LESSONS.md L-001 for the bad/fixed exemplars.

(Future lessons appear here as they accumulate from SPEC_LESSONS.md.)
