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

(none yet — populated as shakedown SHAKEDOWN-09 runs and as real W1+ work surfaces them)
