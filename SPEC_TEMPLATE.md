# Canonical Task Spec Template

Every task spec under `SHAKEDOWN/` (and, in production, every task spec under `aperant-tasks/mvp-2026-05/W{n}/`) follows this template. Authors (Marshall + Claude Code) instantiate it; orchestrator dispatches the result; spec-analyst proposes updates to this file when lessons emerge.

**Template version:** 1 (initial)

**When this template is updated:** spec-analyst returns a `proposed_template_update` field; orchestrator applies the diff; bumps the version. New specs use the latest version. Previously-written specs are NOT retroactively updated.

---

## Frontmatter (YAML, required)

```yaml
---
task_id: <KIND>-<NN>_<slug>          # e.g. SHAKEDOWN-01_happy-path
title: <human-readable title>
kind: <TEST | FEAT | FIX | INFRA | INTG>
wave: <T1 | W0 | W1 | ...>
estimated_minutes: <int>
calibrated_minutes: <int>             # = estimated × current kind multiplier (default 1.0 at start)
dependencies: []                      # task IDs that must START AFTER (controls dispatch order)
merge_order_after: []                 # task IDs that must MERGE AFTER (controls integration order)
files_owned:                          # for run-time parallelism: tasks with overlapping files_owned cannot dispatch concurrently
  - <glob or path>
target_feature_branch: null           # set on FIX tasks to the preserved branch this task should layer onto
target_wave_branch: <sandbox-staging-T1 | mvp-staging-W{n}>
preserves_until: wave_approved
ai_review_required: true
human_review_required: false          # default false; set true for security-sensitive tasks
integration_smoke_test:               # post-merge checks the integration test runs
  - "<plain-language assertion 1>"
  - "<plain-language assertion 2>"
expected_marker_content: "<string>"   # for shakedown: what content the marker file MUST contain
downstream_blocker_count: <int>       # computed; for new specs may be 0
priority_score: <int>                 # = downstream_blocker_count × 100 + calibrated_minutes
---
```

## Body sections (all required)

### `# <task_id> — <title>`

The H1 line repeats the task ID + title.

### `## Goal`

One paragraph stating what this task delivers and why. Must be specific enough that the executor knows when they're done.

### `## Context`

Links + relevant excerpts from design spec, architecture doc, DB schema doc. Anything the executor needs that's not in the WORK section.

### `## STEP 0 — Self-heal`

Bash commands that verify every path/file/condition referenced in the spec body. Aborts with explicit error if anything is missing. Catches "executor's worktree doesn't have what the spec assumes."

### `## STEP 1 — Smoke test`

Bash commands that prove the executor's environment is healthy enough to do this specific task. Fails fast (target < 30 sec). Different from STEP 0 (existence check) — STEP 1 is about *operability*.

### `## WORK`

Numbered steps the executor must execute. Each step concrete (specific commands, specific file edits). No "implement appropriate error handling" hand-waves — actual code.

### `## Acceptance criteria`

Bash commands (NOT prose) that must all return success for the task to be considered done. The orchestrator's integration test gate runs against these.

### `## Pivot triggers`

Explicit conditions under which the executor ABANDONS this task instead of pushing through. For each trigger, name the follow-up task to file (FIX / FEAT / etc.) and the template for that follow-up.

### `## 3-strikes rule`

If the same error appears 3 times consecutively after fixes, capture WIP commit, write `STUCK_STATE/<task-id>.md`, exit non-zero. Standard for all tasks unless specified.

### `## Open PR`

The exact command(s) to push the feature branch + open the PR. In iteration 1 of shakedown, this is **simulated** — write `PR_SIMULATIONS/<task-id>.json` with PR metadata (title, body, head, base, files_changed). Don't run real `gh pr create`.

---

## Lessons-mandated rules (grow over time as SPEC_LESSONS.md accumulates)

**Template v1 — none yet.** This section will populate as spec-analyst returns `proposed_template_update` patches.

When a lesson L-NNN forces a new mandatory rule, it appears here as:

> **From L-NNN:** <rule>. Specs that don't include this fail spec-lint and won't be dispatched.
