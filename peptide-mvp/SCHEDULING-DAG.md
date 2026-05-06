# Scheduling DAG — peptide-website MVP

**Anchor:** `486f63b` on `Layne512/peptide-website` `main`
**Sources:** master list (77 tasks) + F105 + F106 + F107 reconciliation
**Date:** 2026-05-05

This is the reconciled, dispatchable plan. It supersedes the master list's Phase A-E sequencing. Wave grouping reflects actual dependency edges, not original Phase letters.

---

## Reconciliation summary (applied to master list)

| Outcome | Count | Task IDs |
|---|---:|---|
| HOLD (excluded from waves) | 4 | F1, F2, F4, F5 |
| ALREADY_DONE (drop) | 6 | F8, F9, F30, F47, F55, F58 |
| STALE auto-claude refs (rewrite or drop) | 6 | F0a, F3, F6, F7, F18-as-stated, F33-as-stated |
| NOT_FOUND_IN_MAIN (build fresh) | 24 | F10b, F11, F13, F14, F15, F19, F20, F21, F22, F31, F32, F34, F35, F36, F37, F38, F40, F44, F46, F48, F50, F51, F52, F54 |
| CONFIRMED as-stated | 34 | remainder |
| NEW (added by reconciliation) | 4 | F104 (orchestrator infra), F88 (Daily.co room provisioning), F89 (funnel state machine), F12-as-W1-schema-batch (replaces 11 ad-hoc schema tasks) |

**Net active task count:** ~75 (down from 77 raw).

---

## Wave structure

| Wave | Theme | Schema dep | Vendor block | Calendar |
|---|---|---|---|---|
| W0 | Unstick + foundation + orchestrator infra | none | none | 1 wk |
| W1 | Subscriptions + funnel state + e-Rx + catalog | `024_w1_schema_batch.sql` (last manual migration) | V.1, V.2 (DoseSpot) | 2 wk |
| W2 | Pharmacy + labs + consult + notifications | F62b (adopt Supabase CLI) → `025_w2_schema_batch.sql` (first CLI migration) | V.5, V.6, V.7, V.17 | 2 wk |
| W3 | Compliance hardening + audit logs + admin tools | `026_w3_schema_batch.sql` | V.4, V.8, V.11 | 2 wk |
| W4 | Launch readiness (E2E, perf, monitoring, docs) | none | V.9, V.10, V.16 | 1-2 wk |

Total calendar: 8-9 wk eng, gated by V.2 (Surescripts cert) and V.16 (IRB).

---

## Wave-batch schema pattern

> **Rule (locked):** No feature task writes a migration file. Each wave has exactly one schema-batch task that aggregates every column / table / RLS change the wave needs. Feature tasks declare `schema_dependencies` in YAML; the schema-batch task declares `blocks: [list of every feature task in the wave]`.

Why: parallel feature tasks that each add a column to the same table racing each other = the F63 collision pattern, repeated forever. Wave-batching kills that class entirely.

Schema-batch tasks:
- W0: none (no schema changes — F63 is a *resolution* of an existing collision, not new schema)
- W1: F12 — `024_w1_schema_batch.sql` (subscriptions, funnel_state column, RLS for new tables)
- W2: F25 — `025_w2_schema_batch.sql` (pharmacy_orders, lab_orders extensions, consultation rooms)
- W3: F45 — `026_w3_schema_batch.sql` (audit_logs expansion, admin_actions)

---

## W0 — Unstick & Foundation (10 tasks)

See `W0-PLAN.md` for full detail. Summary:

| ID | Title | Tier | Effort | files_owned (key) |
|---|---|---|---|---|
| F104 | Bootstrap orchestrator infra | 0 | 1.5d | `STATE/`, `MARKERS/`, `CLAUDE.md`, `preflight.sh` |
| W0-package-json-cleanup | Bundle F62+F70+F71 | 1 | 0.5d | `package.json` |
| F11 | Disclaimer label change | 1 | 0.1d | `components/intake/step-build-protocol.tsx` |
| F10a | Admin gate v1 LLM | 1 | 0.25d | `app/api/protocol/generate/route.ts` |
| F63 | Resolve 018 collision | 1 | 0.5d | `supabase/migrations/018*.sql` |
| F10c | Delete 21 dead-code files | 2 | 0.5d | (delete-only — see spec) |
| F69 | Wire Stripe Identity button | 2 | 0.25d | `components/md/application-form.tsx` |
| F49 | Pre-commit secret scan | 2 | 0.25d | `.gitleaks.toml`, `.husky/pre-commit` |
| F41+F64 | Security headers + Sentry source map | 2 | 1d | `next.config.ts`, `sentry.*.config.ts` |

---

## W1 — Subscriptions + Funnel + e-Rx + Catalog

**Entry gate:** all W0 in `completed.json`, V.1 contracted, V.2 in progress.

| ID | Title | Depends on | Effort | files_owned (key) |
|---|---|---|---|---|
| F12 | **W1 schema batch** (`024_w1_schema_batch.sql`) | — | 1d | `supabase/migrations/024_w1_schema_batch.sql` |
| F89 | **NEW** Funnel state machine | F12 | 1d | `lib/funnel/state-machine.ts`, `lib/funnel/transitions.ts` |
| F13 | Define + seed 17 Cat 1 peptide catalog | F12 | 1d | `scripts/seed/peptides.ts`, `lib/catalog/peptides.ts` |
| F14 | Define + seed GLP-1 brands (4) | F12 | 0.5d | `scripts/seed/glp1.ts` |
| F15 | Define + seed NAD+ IM | F12 | 0.25d | `scripts/seed/nad.ts` |
| F16 | Stripe 3-tier subscription wiring | F12, F89 | 1.5d | `lib/billing/tiers.ts`, `app/api/stripe/checkout/route.ts` |
| F17 | DoseSpot client production hardening | F12, V.1 | 2d | `lib/dosespot/client.ts` |
| F18 | Send-Rx route + MD signing flow | F17, F89 | 1.5d | `app/api/rx/send/route.ts`, `components/md/rx-review.tsx` |
| F19 | DoseSpot per-MD identity proofing flow | F17, V.3 | 1d | `app/(md)/onboarding/dosespot/page.tsx` |
| F21 | Convergence v2 — patient prescribing path | F12 | 2d | `lib/convergence/v2/` |
| F22 | Convergence v2 — output protocol persistence | F21 | 0.5d | `lib/convergence/v2/persist.ts` |
| F31 | Patient-side intake completion → state transition | F89 | 0.5d | `lib/intake/complete.ts` |
| F32 | MD queue card view (intake submitted, awaiting review) | F89 | 0.5d | `app/(md)/queue/page.tsx` |

**W1 active task count:** 13.

---

## W2 — Pharmacy + Labs + Consult + Notifications

**Entry gate:** W1 complete, V.5/V.6 (pharmacy contract) signed, V.7 (Quest) onboarding done, V.17 (Daily.co BAA) signed.

| ID | Title | Depends on | Effort | files_owned (key) |
|---|---|---|---|---|
| F62b | **Adopt Supabase CLI migration runner** + backfill `schema_migrations` registry | F12 | 0.75d | `package.json`, `supabase/config.toml`, `supabase/README.md`, `scripts/backfill-schema-migrations.sql` |
| F25 | **W2 schema batch** (`025_w2_schema_batch.sql`) — first migration shipped via CLI | F62b | 1d | `supabase/migrations/025_w2_schema_batch.sql` |
| F20 | Empower TX 503A pharmacy adapter | F25, V.5 | 1.5d | `lib/pharmacy/empower.ts` |
| F26 | Pharmacy order placement API | F20, F18 | 1d | `app/api/pharmacy/order/route.ts` |
| F27 | Pharmacy webhook (shipment notification) | F20 | 0.5d | `app/api/pharmacy/webhook/route.ts` |
| F33 | Quest Diagnostics provider wiring | F25, V.7 | 1.5d | `lib/labs/providers/quest.ts` |
| F34 | Lab order placement API (signup→intake→labs flow B) | F33, F89 | 1d | `app/api/labs/order/route.ts` |
| F35 | Lab results webhook + funnel transition | F33, F89 | 1d | `app/api/labs/webhook/route.ts` |
| F88 | **NEW** Daily.co room provisioning | F25, V.17 | 1d | `lib/daily/client.ts`, `app/api/consult/room/route.ts` |
| F36 | Consult booking flow (LABS_BACK → CONSULT_BOOKED) | F88, F89 | 1d | `app/(patient)/consult/book/page.tsx` |
| F37 | Consult MD-side join + transition | F88, F89 | 0.5d | `components/md/consult-room.tsx` |
| F38 | Notification dispatcher hooks per state transition | F89 | 1d | `lib/notifications/dispatch.ts` |
| F40 | SMS/email templates for funnel transitions | F38 | 0.5d | `lib/notifications/templates/` |

**W2 active task count:** 13.

---

## W3 — Compliance Hardening + Admin

**Entry gate:** W2 complete, V.4 (legal review) deliverables in hand, V.8 BAAs largely signed.

| ID | Title | Depends on | Effort |
|---|---|---|---|
| F45 | **W3 schema batch** (`026_w3_schema_batch.sql`) | F25 | 1d |
| F44 | Audit log expansion (every state transition + every PHI read) | F45, F89 | 1.5d |
| F46 | Admin user-management page (with `requireAuth() + requireRole('admin')`) | — | 1d |
| F48 | Admin search + impersonation guardrails | F46 | 1d |
| F50 | Consent agreements UI + persistence | F45 | 1d |
| F51 | HIPAA NPP delivery + acknowledgment tracking | F50 | 0.5d |
| F52 | IRB study consent flow | F50, V.16 | 1d |
| F54 | Data export request handler (HIPAA right of access) | F44 | 1d |
| F57 | Compliance review checklist completion | F50, F51, F52, V.4 | 0.5d |

**W3 active task count:** 9.

---

## W4 — Launch Readiness

**Entry gate:** W3 complete, V.9 (state telehealth reg), V.10 (malpractice), V.11 (pen test) all done.

| ID | Title | Effort |
|---|---|---|
| F56 | GA4, sitemap, robots, OG (V.15 input) | 0.5d |
| F59 | Full E2E playwright suite | 2d |
| F60 | Performance pass (Lighthouse, bundle size) | 1d |
| F61 | Sentry alert rules + on-call rotation | 0.5d |
| F65 | Postmortem of any prod-touching change in W0-W3 | 0.5d |
| F72 | Runbook docs (incident, rotation, recovery) | 1d |
| F74 | Final go/no-go review | 0.25d |

**W4 active task count:** 7.

---

## Held / out-of-scope

| ID | Status | Why |
|---|---|---|
| F1 | HOLD | investor-relations |
| F2 | HOLD | investor-related untracked source |
| F4 | HOLD | blog deferred (Phase 2) |
| F5 | HOLD | blog deferred (Phase 2) |
| F73 (TRT branch) | DEFERRED | Phase 2 |
| auto-claude/068, /070, /071 | OUT_OF_SCOPE | financial model rebuild — separate sub-project |

---

## Total picture

```
Wave  Tasks  Eng-days  Calendar (2-3 eng parallel)
W0    10     ~5d       1 wk
W1    13     ~14d      2 wk
W2    12     ~12d      2 wk
W3    9      ~8d       2 wk
W4    7      ~5d       1-2 wk
─────────────────────────────────
Total 51     ~44d      8-9 wk
```

**Critical path** = V.2 (DoseSpot Surescripts) + V.16 (IRB). Engineering is not the long pole; vendor lead times are. W0 + W1 can both complete before V.2 fully clears.

---

## Re-dispatch rules (when a task fails)

Per orchestrator protocol, a stuck task generates a `STUCK_STATE/<task-id>.md`. Recovery options:

1. **Spec defect (executor blocked because spec wrong):** spec-analyst writes `SPEC_LESSONS.md` entry, spec rewritten, re-dispatched.
2. **Environmental defect (preflight should have caught it):** failure-analyst writes `FAILURE_PATTERNS.md` entry, `preflight.sh` extended, task re-dispatched.
3. **Vendor block (waiting on V.x):** task moves to `BLOCKED/`, wave can continue with siblings, task re-eligible when vendor item clears.
4. **Genuine code complexity (executor needs more context):** task split into 2-3 sub-tasks with new spec each.

No task gets re-dispatched without a documented reason.
