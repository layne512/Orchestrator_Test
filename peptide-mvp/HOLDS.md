# Holds — peptide-website MVP

Tasks excluded from the orchestrator's `eligible.json` per user instruction. These remain in the master task list for record-keeping but will not dispatch.

---

## F1 — Fix SensitivityChart.tsx:215 build break

**Hold reason:** investor-relations on user hold
**Effect:** Production deploys remain frozen at March 31 (`3f5b0ea`) until F1 unfrozen. All Step 5 merges land on `main` but DO NOT reach live site.
**Unfreeze trigger:** user gives explicit green light on investor-relations sub-project.
**Related parked work:** auto-claude/068, /070, /071 (financial model rebuild + audit + v4 baseline) — all OUT_OF_SCOPE while F1 is held.

## F2 — Stage + commit irreplaceable untracked source

**Hold reason:** investor-related untracked source
**Effect:** Tests, aperant prompts, MVP_PLAN.md, 503B research, `bigcommerce_setup_superprompt.md`, `docs/0[123]-*.md`, `PasswordGate.tsx`, `clinical-vendor-research/`, `financial-model-build-canonical/` remain untracked.
**Unfreeze trigger:** F1 unfrozen + decision on which subset is investor-only vs. MVP-relevant.

## F4 — auto-claude/053 (blog slug uniqueness)

**Hold reason:** blog deferred — not on critical path for IRB-study MVP
**Effect:** Blog slug duplication possible but blog isn't in MVP UX.
**Unfreeze trigger:** Phase 2 (post-MVP) when blog goes live.

## F5 — auto-claude/054 (blog tag filtering)

**Hold reason:** blog deferred
**Effect:** No interactive tag filtering on blog.
**Unfreeze trigger:** Phase 2.

---

## How holds are enforced

Per `ORCHESTRATOR.md` Step 4 eligibility: a task is eligible only if its spec exists in `SHAKEDOWN/` (or in this case, `peptide-mvp/specs/<wave>/`) AND its dependencies are in `completed.json`. Held tasks have no spec file in any wave directory, so the orchestrator's eligibility check naturally excludes them.

If a hold needs to be lifted mid-wave: drop the spec file into the appropriate wave directory and the orchestrator will pick it up on next cycle.
