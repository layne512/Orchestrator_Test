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

---

## Lesson L-002: Spec referenced helpers / file paths that don't exist in the actual codebase (inferred conventions vs. verified conventions)

**First seen:** 2026-05-06 (F10a, peptide-website W0 Tier 1)
**Recurrences:** 0
**Class:** missing-context (sub-class: code-drift-from-planning-doc)

**What went wrong:** The F10a spec instructed the executor to import `requireAuth` from `'@/lib/auth/require-auth'` and `requireRole` from `'@/lib/auth/roles'` and call `await requireRole(session, 'admin')`. Reality on `peptide-website` `486f63b`:
- `lib/auth/require-auth.ts` does not exist. Only `lib/auth/guards.ts` and `lib/auth/roles.ts` exist.
- `requireRole` is exported from `guards.ts` (not `roles.ts`), takes a single `UserRole` enum argument (not `(session, 'admin')`), and calls `redirect()` (not throws) — yielding a 307 redirect, not the 401/403 the spec's acceptance criterion (d) tests for.
- `UserRole` enum has no bare `'admin'` member. Admins are `AdminSupport | AdminManager | AdminSuper`.
- The route already has a partial 401 auth check at lines 41-46 — pivot trigger 2 ("do not double-gate") fires.

The executor halted correctly per pivot triggers, no edits, no commit. Roughly 47k tokens of context spent producing two well-reasoned STUCK_STATE reports. Cost is small per-incident; cost compounds across many specs if the underlying authoring practice doesn't change.

The compounding source: `peptide-mvp/CODEBASE-CONVENTIONS.md` and `peptide-mvp/EXISTING-CODE-MAP.md` themselves described `lib/auth/require-auth.ts` and `requireRole('admin'|'md'|'patient')` from `lib/auth/roles.ts` as the canonical pattern. The F10a spec wasn't a one-off mistake — it inherited a documentation-vs-code drift that would have repeated across every API-route auth-gating task in W0/W1/W2.

**Why it was a spec issue, not infrastructure:** Preflight cannot detect "the helper this spec imports doesn't exist as named" because preflight has no visibility into spec contents — it checks repo health, not spec correctness. The `must_read_before_writing` field listed `lib/auth/require-auth.ts` (one of the missing files); a preflight extension that *parses* the YAML and `test -f`s every entry could have caught half of this issue (the file-doesn't-exist half), but not the "wrong signature" or "redirect-vs-throw" halves. Those require parsing the spec body for symbol references and grep-checking each one against actual exports — i.e. a spec validator, not a runtime preflight.

The deeper failure: I (the spec author) was running in a sandbox without the peptide-website checkout mounted. I authored CODEBASE-CONVENTIONS and EXISTING-CODE-MAP from the master task list and inferred patterns rather than from `rg lib/auth/` on the real repo. The F10a spec then inherited those bad citations. The fix is upstream of any individual spec — it's a process rule for the spec author's workflow.

**Bad exemplar (from the original F10a spec, v1):**

```
## Technical scope

1. At the top of the route handler (POST and any other exported HTTP method), add:
   ```ts
   import { requireAuth } from '@/lib/auth/require-auth';
   import { requireRole } from '@/lib/auth/roles';

   const session = await requireAuth();
   await requireRole(session, 'admin');
   ```
2. If `requireAuth` throws, propagate as 401. If `requireRole` throws, propagate as 403.
```

(Verified-against-`486f63b`: `lib/auth/require-auth.ts` does not exist, `requireRole` not in `roles.ts`, signature wrong, no `'admin'` enum member, helpers don't throw — they redirect. Five distinct citations all wrong.)

**Fixed exemplar (F10a spec v2, after grep against `486f63b`):**

```
## Background — verified state of `app/api/protocol/generate/route.ts` at `486f63b`

The route ALREADY has this auth block (lines 41-46):

\`\`\`ts
const authClient = await createClient()
const { data: { user }, error: authError } = await authClient.auth.getUser()
if (authError || !user) {
  return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
}
\`\`\`

This block stays. ...

## Technical scope

Insert a role check immediately after the existing 401 block. Use the verified-real `verifyDbRole` import from `lib/auth/guards.ts`:

\`\`\`ts
import { verifyDbRole } from '@/lib/auth/guards'

const isAdmin = await verifyDbRole(user.id, [
  'admin_super', 'admin_manager', 'admin_support',
])
if (!isAdmin) {
  return NextResponse.json({ error: 'Forbidden' }, { status: 403 })
}
\`\`\`
```

(Every cited file path, function name, signature, and string literal was confirmed via `rg` / `cat` on the actual `486f63b` checkout before this spec was published.)

**Generalized rule (now in SPEC_TEMPLATE.md):** Spec authors MUST verify every cited file path, function name, function signature, type/enum member, route path, table name, and string literal against the actual `main` checkout before publishing the spec. Verification means running `rg`, `cat`, or `ls` on the real repo at the spec's anchor SHA — NOT inferring from master-list paraphrase, planning-doc claims, or "what should exist." Each citation in `must_read_before_writing` and in any code block in `## Technical scope` should be considered a load-bearing claim. If the author cannot verify a citation (e.g. authoring offline), the citation must be marked `# unverified — requires grep before dispatch` and the orchestrator's pre-dispatch validator MUST refuse to dispatch the spec until the marker is removed and the citation is grep-confirmed.

The rule also applies to `CODEBASE-CONVENTIONS.md` and `EXISTING-CODE-MAP.md`: every claim in those docs is a load-bearing claim that downstream specs will inherit. They must carry a "**VERIFIED against `<SHA>` on `<DATE>`**" header per section, and be re-verified on each significant `main` advance.

**Other patterns this covers:**

- Specs that cite a helper, type, or constant by paraphrase rather than by exact identifier.
- Specs whose `must_read_before_writing` lists files that don't exist on the anchor SHA.
- Acceptance criteria that test for HTTP status codes (`STATUS = 401`) when the helpers being used don't actually emit those codes (they redirect, throw `Response`, return JSON, etc.).
- Pivot triggers that mention "if helper X is renamed" but don't tell the executor what to halt-vs-improvise on.
- CODEBASE-CONVENTIONS / EXISTING-CODE-MAP / SCHEDULING-DAG entries that describe an "intended" or "should-be" architecture rather than the actual one.
- Master-list-paraphrase tasks where the master entry says "add admin gate" and the spec author fills in the helper names from imagination rather than from the repo.

**Prevention scope:** all future task specs from version 4 onward. Three reinforcing layers:

1. **Author rule (immediate, doc-only):** every spec / planning doc must carry a "verified against `<SHA>`" header and use the `# unverified` marker for any unconfirmed citation.

2. **Pre-dispatch validator (orchestrator-side, automatable):** before dispatching a task, the orchestrator parses the spec's YAML frontmatter and code blocks, extracts every `from '@/...'` import path, every `<symbol>(` call, and every `must_read_before_writing` entry, and runs:
    ```bash
    test -f "$REPO_ROOT/<path>"               # for each must_read entry
    rg "export.*<symbol>" "<containing-file>" # for each cited import
    ```
    Any miss triggers a "spec defect — halt before dispatch" and routes the spec back to the author. Catches F10a-class issues without spending an executor session.

3. **Authoring environment rule:** the spec author's working session must have the target repo mounted/cloned and the author must `rg` against it as they write. Authoring from a sandbox without the target checkout is the actual root cause; remove the conditions and the failure class can't recur. (For peptide-website, this means future spec writes happen in a session with peptide-website cloned at `/home/user/peptide-website` or equivalent, NOT from `Orchestrator_Test/` alone.)

A one-time follow-up task (F108-codebase-docs-verification) should sweep `CODEBASE-CONVENTIONS.md` + `EXISTING-CODE-MAP.md` + every existing W0/W1 spec against `486f63b` and emit a report of every unverified or stale citation. Run before W1 dispatch begins.
