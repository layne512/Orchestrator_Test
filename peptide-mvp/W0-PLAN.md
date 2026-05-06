# Wave 0 — Unstick & Foundation (peptide-website)

**Date:** 2026-05-05
**Anchor:** `486f63b` on `Layne512/peptide-website` `main` (re-anchored from stale `3f5b0ea`)
**Sources:** `PeptideOS_MVP_Task_List_2026-04-30.md` (master list, 77 tasks) + `peptide-branch-audit.md` (F105) + `F106-task-reconciliation.md` + `F107-unlisted-branches-audit.md`
**Goal:** Land all foundation cleanups, security fixes, and orchestrator infrastructure so W1 (pharmacy + e-Rx) can begin against a clean base.

---

## Headline

| Bucket | Count | Notes |
|---|---:|---|
| Original Phase A tasks | 16 | from master list |
| Holds (excluded) | 4 | F1, F2, F4, F5 |
| Reconciliation drops | 3 | F3, F8, F9 (already done or never built) |
| Active engineering | 9 | reduced from 12 |
| Plus orchestrator infra | 1 | F104 (NEW) |
| **W0 total** | **10 dispatchable tasks** | |

Effort: ~2-2.5 eng-weeks, calendar 1 week with 2-3 engineers in parallel.

---

## W0 dispatch order

Tasks group into 3 dispatch tiers based on dependencies:

### Tier 0 — Bootstrap (must complete before any other W0 dispatch)

| # | Task | Effort | Status |
|---|---|---|---|
| F104 | Bootstrap orchestrator infrastructure in peptide-website | 1.5d | NEW |

F104 must land before any other W0 task. It sets up `STATE/`, `MARKERS/`, `STUCK_STATE/`, `PR_SIMULATIONS/`, `INTEGRATION_FAILURES/`, the peptide-website-specific `preflight.sh`, `CLAUDE.md` hard rules, and `CODEBASE-CONVENTIONS.md` reference doc.

### Tier 1 — Parallel-safe small fixes (dispatch all concurrently after F104)

| # | Task | Effort | Owns | Notes |
|---|---|---|---|---|
| F62 | Remove unused `ai` SDK package | XS (0.25d) | `package.json` | trivial diff |
| F63 | Resolve migration 018 naming collision | XS (0.5d) | `supabase/migrations/018_*.sql` | rename one file |
| F70 | Audit + remove `postgres` devDep | XS (0.25d) | `package.json` | confirm unused first |
| F71 | Move `@types/web-push` to devDependencies | XS (0.1d) | `package.json` | trivial |
| F11 | Disclaimer label change | XS (0.1d) | `components/intake/step-build-protocol.tsx` | one component edit |
| F10a | Add admin gate to v1 LLM generator | XS (0.25d) | `app/api/protocol/generate/route.ts` | auth check addition |

These 6 tasks have NO file overlap. All can dispatch in parallel after F104. Total wall-clock if dispatched all at once: ~0.5d.

**WARNING:** F62, F70, F71 all touch `package.json`. Despite my "no file overlap" claim above, they collide. Recommendation: bundle into one task (`W0-package-json-cleanup`) that does all 3 in a single PR. Reduces 3 tasks to 1, eliminates the conflict.

### Tier 2 — Sequential after Tier 1 settles

| # | Task | Effort | Depends on | Notes |
|---|---|---|---|---|
| F10c | Delete 21 dead-code files (NOT v1 generator) | S (0.5d) | F10a | bulk delete |
| F69 | Wire existing Stripe Identity button into MD app form | XS (0.25d) | none (but small) | infra exists, hookup only |
| F49 | Add secret-scanning pre-commit hook | XS (0.25d) | none | gitleaks config |
| F41+F64 bundle | Security headers + Sentry source-map (one PR, both edit `next.config.ts`) | S (1d) | none | bundled to avoid file collision |

---

## Dropped from W0 (reconciled)

| # | Original status | Verified status | Why dropped |
|---|---|---|---|
| F0a | Not built (running) | NOT_FOUND_IN_MAIN | Embedded session never produced output. F66/F67/F68 already enumerate the downstream work; the audit itself is superseded. |
| F1 | HOLD | HOLD | investor-relations on user hold |
| F2 | HOLD | HOLD | investor-related untracked source |
| F3 | Built-unmerged | STALE | `auto-claude/060` doesn't exist on origin; doc-merge with no source |
| F4 | HOLD | HOLD | blog deferred |
| F5 | HOLD | HOLD | blog deferred |
| F6 | Built-unmerged | STALE | `auto-claude/052` doesn't exist; admin-users page lacks guard but no fix to merge |
| F7 | Built-unmerged | STALE | `auto-claude/051` doesn't exist; MD labs page already uses real Supabase queries |
| F8 | Built-unmerged | ALREADY_DONE | MD schedule + calendar shipped via `db9613d` |
| F9 | Built-unmerged | ALREADY_DONE | P0 user-ID security fix shipped via PR #31 (`0e4462b`) — sister branch 047, not 048 |

F6 surfaced a real gap (admin-users page lacks `requireAuth()` guard) but the fix needs to be built fresh — moved to W2 as part of the broader auth-hardening work, not W0.

---

## What lands at end of W0

- All `package.json` cleanup applied
- Migration 018 collision resolved
- v1 LLM generator gated to admin role
- 21 dead-code files deleted
- Disclaimer label updated
- Stripe Identity button wired into MD application flow
- Security headers (CSP, HSTS, etc.) on every response
- Sentry source-map upload working
- Pre-commit secret-scanning hook installed
- Orchestrator infra running in peptide-website (STATE/, preflight, executor protocol)

Wave entry gate to W1: all 10 W0 tasks in `STATE/completed.json`, preflight green, working tree clean.

---

## Critical reminders for W0 executors

1. **No migrations in this wave.** F12 (W1 schema batch) hasn't run yet. Any task that thinks it needs a migration is mis-scoped.
2. **`auto-claude/*` branch references are toxic** — F105 + F107 proved 90% are ghosts. Any new task spec claiming "merge auto-claude/XXX" must be rewritten as direct-on-main work.
3. **Existing scaffolding is more advanced than the master list claims** in several places (F17 DoseSpot, F18 Rx route, F69 Stripe Identity, F33 lab provider abstraction). Executor should always read existing files before writing new code (per `CODEBASE-CONVENTIONS.md`'s `must_read_before_writing` requirement).
4. **F63 is a real collision, not a documentation issue.** Both `018_rls_knowledge_base.sql` and `018_rls_phi_gaps.sql` exist on main. Resolution requires renaming one to `018a_*` and the other to `018b_*` (or renumbering whichever applied second to `024_*` — check Supabase `schema_migrations` table on prod to determine the order).

---

## Next steps after W0

W1 (Pharmacy + e-Rx + Catalog) starts with the W1 schema batch (renumbered F12) — see `SCHEDULING-DAG.md` for the full reconciled plan.
