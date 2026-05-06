# F106 — Task Reconciliation: PeptideOS_MVP_Task_List_2026-04-30.md vs origin/main

**Date:** 2026-05-05
**Repo:** `peptide-website` @ `486f63b` (origin/main)
**Source list:** `PeptideOS_MVP_Task_List_2026-04-30.md` (anchored at `3f5b0ea`, deployed)
**Cross-check:** `peptide-branch-audit.md` (F105 — auto-claude branch audit)
**Method:** Per-task evidence-file inspection in current main, plus F105 cross-check for auto-claude tasks.
**Skipped:** F1, F2, F4, F5 (HOLD per user). 73 tasks evaluated.

---

## Headline

| Bucket | Count |
|---|---:|
| ALREADY_DONE | 5 |
| CONFIRMED | 34 |
| NOT_FOUND_IN_MAIN | 24 |
| STALE | 10 |
| **Total** | **73** |

| Recommendation | Count |
|---|---:|
| KEEP_AS_IS | 43 |
| REWRITE | 19 |
| DROP | 10 |
| SCOPE_CHANGE | 1 |

**Highlights:**
- All 5 auto-claude branch merge tasks (F3, F6, F7, F8, F9, F29, F30, F31, F32) are STALE or ALREADY_DONE — branches don't exist on origin or work already on main. Drop / rewrite as direct-on-main work.
- 5 tasks already done quietly (F8, F9, F47, F55, F58) — drop from active queue.
- 24 NOT_FOUND_IN_MAIN: most are "Not built" tasks where there is no evidence file yet because the work hasn't started — these stay as KEEP_AS_IS (the assertion "not built" is correct, just no file to point at).
- 10 STALE entries reflect partial-or-unexpected state on main (e.g., F18 stores Rx without DoseSpot call; F73 schema column exists but no UI; F28 mock data wider than claimed).

---

## Summary Table

| F# | Original status | Verified status | Recommendation |
|---|---|---|---|
| F0a | Not built (running) | NOT_FOUND_IN_MAIN | DROP |
| F3 | Built-unmerged | STALE | DROP |
| F6 | Built-unmerged | STALE | DROP |
| F7 | Built-unmerged | STALE | DROP |
| F8 | Built-unmerged | ALREADY_DONE | DROP |
| F9 | Built-unmerged (P0 sec) | ALREADY_DONE | DROP |
| F10a | Not built | CONFIRMED | REWRITE |
| F10c | Not built | CONFIRMED | KEEP_AS_IS |
| F11 | Not built | CONFIRMED | KEEP_AS_IS |
| F62 | Not built | CONFIRMED | KEEP_AS_IS |
| F63 | Not built | CONFIRMED | KEEP_AS_IS |
| F70 | Not built | CONFIRMED | KEEP_AS_IS |
| F71 | Not built | CONFIRMED | KEEP_AS_IS |
| F12 | Not built | NOT_FOUND_IN_MAIN | KEEP_AS_IS |
| F13 | Not built | CONFIRMED | KEEP_AS_IS |
| F14 | Not built | CONFIRMED | KEEP_AS_IS |
| F15 | Not built | CONFIRMED | KEEP_AS_IS |
| F16 | Not built | CONFIRMED | KEEP_AS_IS |
| F17 | Not built | CONFIRMED | KEEP_AS_IS |
| F18 | Not built (stub) | STALE | REWRITE |
| F19 | Not built | NOT_FOUND_IN_MAIN | KEEP_AS_IS |
| F20 | Not built | NOT_FOUND_IN_MAIN | KEEP_AS_IS |
| F22 | Not built | NOT_FOUND_IN_MAIN | KEEP_AS_IS |
| F23 | Not built | NOT_FOUND_IN_MAIN | KEEP_AS_IS |
| F25 | Not built | CONFIRMED | KEEP_AS_IS |
| F10b | Not built | NOT_FOUND_IN_MAIN | KEEP_AS_IS |
| F73 | Not built | STALE | REWRITE |
| F10d | Not built | NOT_FOUND_IN_MAIN | KEEP_AS_IS |
| F69 | Not built (dead code) | STALE | REWRITE |
| F26 | Not built | CONFIRMED (partial) | SCOPE_CHANGE |
| F27 | Partial (mock hotfix) | CONFIRMED | KEEP_AS_IS |
| F28 | Partial (6 pages) | STALE | REWRITE |
| F29 | Built-unmerged | STALE | REWRITE |
| F30 | Built-unmerged | CONFIRMED (already on main) | KEEP_AS_IS |
| F31 | Built-unmerged | CONFIRMED | REWRITE |
| F32 | Built-unmerged | NOT_FOUND_IN_MAIN | DROP |
| F33 | Not built | CONFIRMED | KEEP_AS_IS |
| F34 | Partial | CONFIRMED | KEEP_AS_IS |
| F35 | Not built | CONFIRMED | KEEP_AS_IS |
| F36 | Not built | CONFIRMED | KEEP_AS_IS |
| F37 | Not built | NOT_FOUND_IN_MAIN | KEEP_AS_IS |
| F38 | Not built | CONFIRMED | REWRITE |
| F39 | Not built | NOT_FOUND_IN_MAIN | KEEP_AS_IS |
| F40 | Not built | CONFIRMED | REWRITE |
| F72 | Not built | CONFIRMED | REWRITE |
| F77 | Not built | NOT_FOUND_IN_MAIN | KEEP_AS_IS |
| F74 | Not built | NOT_FOUND_IN_MAIN | KEEP_AS_IS |
| F75 | Not built | CONFIRMED | KEEP_AS_IS |
| F66 | Not built | CONFIRMED | REWRITE |
| F67 | Not built | CONFIRMED | REWRITE |
| F68 | Not built | CONFIRMED | REWRITE |
| F65 | Not built | CONFIRMED | KEEP_AS_IS |
| F41 | Not built | CONFIRMED | REWRITE |
| F42 | Partial — prod blocker | CONFIRMED | REWRITE |
| F43 | Partial | CONFIRMED | KEEP_AS_IS |
| F44 | Not built | NOT_FOUND_IN_MAIN | KEEP_AS_IS |
| F45 | Partial (~5%) | CONFIRMED | REWRITE |
| F46 | Not built | CONFIRMED | REWRITE |
| F47 | Partial | ALREADY_DONE | DROP |
| F48 | Not built | NOT_FOUND_IN_MAIN | KEEP_AS_IS |
| F49 | Not built | NOT_FOUND_IN_MAIN | KEEP_AS_IS |
| F50 | Not built | NOT_FOUND_IN_MAIN | KEEP_AS_IS |
| F51 | Not built | NOT_FOUND_IN_MAIN | KEEP_AS_IS |
| F52 | Not built | NOT_FOUND_IN_MAIN | KEEP_AS_IS |
| F53 | Not built | CONFIRMED (partial) | KEEP_AS_IS |
| F54 | Not built | NOT_FOUND_IN_MAIN | KEEP_AS_IS |
| F55 | Not built | ALREADY_DONE | DROP |
| F56 | Not built | STALE | REWRITE |
| F57 | Not built | NOT_FOUND_IN_MAIN | KEEP_AS_IS |
| F58 | Not built | ALREADY_DONE | DROP |
| F59 | Not built | NOT_FOUND_IN_MAIN | KEEP_AS_IS |
| F60 | Not built | NOT_FOUND_IN_MAIN | KEEP_AS_IS |
| F64 | Not built | NOT_FOUND_IN_MAIN | REWRITE |

---

# Phase A — Unstick & Foundation

## F0a — Brutal HIPAA + Research-Regulatory Audit
- Original status: 🟥 Not built (running via 7-subagent fan-out)
- Verified status: NOT_FOUND_IN_MAIN
- Evidence: Output file `HIPAA_AUDIT_2026-04-30.md` does not exist at peptide-website root; fan-out session evidently did not land output.
- Recommendation: DROP (the embedded run did not produce the artifact; the audit work itself either needs re-running outside this list or is superseded by F66/F67/F68 which already enumerate the audit's downstream tasks).

## F3 — Merge auto-claude/060 (codebase audit doc archive)
- Original status: 🟨 Built-unmerged
- Verified status: STALE
- Evidence: F105 confirms `auto-claude/060` does not exist on origin (sequence skips 058 → 068). No artifact to merge.
- Recommendation: DROP

## F6 — Merge auto-claude/052 (admin users auth guard)
- Original status: 🟨 Built-unmerged
- Verified status: STALE
- Evidence: F105 confirms `auto-claude/052` missing from origin. `app/dashboard/admin/users/page.tsx` exists but has no `requireAuth()` guard — the underlying gap is real but the branch doesn't supply the fix.
- Recommendation: DROP (replace with a fresh "add admin auth guard to /admin/users" task if still needed)

## F7 — Merge auto-claude/051 (MD labs verify with real data)
- Original status: 🟨 Built-unmerged
- Verified status: STALE
- Evidence: F105 confirms `auto-claude/051` missing from origin. `app/dashboard/md/labs/page.tsx` already uses real Supabase queries (`md_credentials`, lab orders fetched from DB at lines 51–58) — the work is on main.
- Recommendation: DROP

## F8 — Merge auto-claude/036 (MD schedule with calendar)
- Original status: 🟨 Built-unmerged
- Verified status: ALREADY_DONE
- Evidence: F105 found branch tip is ancestor of main (zero unique commits). `app/dashboard/md/schedule/page.tsx` and `components/md/schedule-calendar.tsx` both exist on main; work shipped via commit `db9613d` and standardized in `97de6f8`.
- Recommendation: DROP

## F9 — Merge auto-claude/048 (MD-message hardcoded user-ID security FIX) — P0 SECURITY
- Original status: 🟨 Built-unmerged — P0 SECURITY
- Verified status: ALREADY_DONE
- Evidence: F105 confirms `auto-claude/048` missing from origin, BUT the underlying security fix is already merged. `app/api/messaging/messages/route.ts` lines 59–72 (POST) use the authenticated `user.id` as `sender_id` with no hardcoded values. Git log shows PR #31 (`0e4462b`, 2026-03-24) fixed the user-ID vulnerability.
- Recommendation: DROP (verify + close in tracker — security item resolved)

## F10a — Keep v1 LLM generator → admin-only internal tool
- Original status: 🟥 Not built
- Verified status: CONFIRMED
- Evidence: `app/api/protocol/generate/route.ts` (9.2 KB) exists and authenticates the user (`authClient.auth.getUser()` returns 401 if anonymous), but has no admin-role check. Any authenticated user can call it.
- Recommendation: REWRITE (small scope tweak — task description should call out the existing auth and explicitly require an admin-role gate; ~2-line code change)

## F10c — Delete 21 dead-code files (NOT v1 generator)
- Original status: 🟥 Not built
- Verified status: CONFIRMED
- Evidence: `lib/i18n/translations.ts` still exists. `find . -name '*.tsx.deprecated'` returns 5 files (task claims 21). Original list was in `.assessment-intermediate/01-deployed-code.md` — task content still applies.
- Recommendation: KEEP_AS_IS (count may be off but the cleanup task is intact)

## F11 — Disclaimer label change
- Original status: 🟥 Not built
- Verified status: CONFIRMED
- Evidence: `components/intake/step-build-protocol.tsx:273` (line drift from claimed 285) still reads "By generating a protocol you agree that this is **AI-generated educational information**…" — old text intact, new text not applied.
- Recommendation: KEEP_AS_IS (update line reference to 273)

## F62 — Remove unused `ai` SDK package (~2.4 MB)
- Original status: 🟥 Not built
- Verified status: CONFIRMED
- Evidence: `package.json` line 25 still has `"ai": "^6.0.104"` in `dependencies`.
- Recommendation: KEEP_AS_IS

## F63 — Resolve migration 018 naming collision
- Original status: 🟥 Not built
- Verified status: CONFIRMED
- Evidence: Both `supabase/migrations/018_rls_knowledge_base.sql` and `supabase/migrations/018_rls_phi_gaps.sql` are present. Collision unresolved.
- Recommendation: KEEP_AS_IS

## F70 — Audit `postgres` devDep usage; remove if unused
- Original status: 🟥 Not built
- Verified status: CONFIRMED
- Evidence: `package.json:53` has `"postgres": "^3.4.8"` in `devDependencies`. No imports found in source. Removal still warranted.
- Recommendation: KEEP_AS_IS

## F71 — Move `@types/web-push` to devDependencies
- Original status: 🟥 Not built
- Verified status: CONFIRMED
- Evidence: `package.json:23` still has `"@types/web-push": "^3.6.4"` in `dependencies` (should be devDependencies).
- Recommendation: KEEP_AS_IS

---

# Phase B — Pharmacy & e-Rx + Catalog Setup

## F12 — Schema: add compoundable_503a + prescription_route to peptide_protocols
- Original status: 🟥 Not built
- Verified status: NOT_FOUND_IN_MAIN
- Evidence: Grep across all `supabase/migrations/*.sql` returns zero hits for `compoundable_503a` or `prescription_route`. No migration file exists yet.
- Recommendation: KEEP_AS_IS

## F13 — Formulary seed: 17 Cat 1 peptides
- Original status: 🟥 Not built
- Verified status: CONFIRMED
- Evidence: `supabase/seeds/002_peptide_protocols.sql` only seeds 8 peptides (BPC-157, TB-500, Sermorelin, CJC-1295/Ipamorelin, Thymosin Alpha-1, Tesamorelin, PT-141, AOD-9604). Missing 9 of the 17 Cat 1 entries.
- Recommendation: KEEP_AS_IS

## F14 — Formulary seed: 4 GLP-1 brand entries
- Original status: 🟥 Not built
- Verified status: CONFIRMED
- Evidence: `supabase/seeds/003_peptide_reference_guide.sql` mentions Ozempic/Wegovy/Mounjaro/Zepbound only as descriptive prose under a "GLP-1 Agonist Protocol" — no individual brand-row inserts.
- Recommendation: KEEP_AS_IS

## F15 — Formulary seed: NAD+ IM kit
- Original status: 🟥 Not built
- Verified status: CONFIRMED
- Evidence: NAD+ appears in `003_peptide_reference_guide.sql` as a generic anti-aging protocol; no IM kit formulation row.
- Recommendation: KEEP_AS_IS

## F16 — Update Build My Protocol filter to MVP formulary
- Original status: 🟥 Not built
- Verified status: CONFIRMED
- Evidence: `lib/intake/convergence-scorer.ts` (11 KB, multi-channel scoring) and `app/api/intake/generate-protocol/route.ts` (23.6 KB, 11-step pipeline) are real production code, but neither implements the `compoundable_503a OR prescription_route='branded_retail'` filter (depends on F12 schema not yet present).
- Recommendation: KEEP_AS_IS (gated by F12)

## F17 — Build DoseSpot API integration
- Original status: 🟥 Not built — CRITICAL PATH
- Verified status: CONFIRMED
- Evidence: `lib/prescriptions/dosespot.ts` (3.1 KB) is more complete than task implies — has `createPrescription`, `getPrescriptionStatus`, `listPharmacies`, and `doseSpotFetch` helper functions. Throws on missing env vars but is not pure dead-shell. Still no Surescripts cert nor wired-in caller.
- Recommendation: KEEP_AS_IS (clarify in description that scaffolding exists; remaining work is cert + production env vars + caller wiring)

## F18 — Wire prescriptions API route to DoseSpot
- Original status: 🟥 Not built (stub)
- Verified status: STALE
- Evidence: `app/api/prescriptions/route.ts` (5.8 KB) has full POST/GET handlers that create prescriptions in Supabase with state-compliance checks — but ZERO calls to `doseSpotFetch` or `createPrescription` from `dosespot.ts`. It is a store-only path that creates `draft` rows without sending to DoseSpot.
- Recommendation: REWRITE (current task says "stub" but route is more developed than that — rewrite to "wire existing route to dosespot.ts on POST after state-compliance check; mark prescription `sent` on success")

## F19 — Per-MD DoseSpot onboarding workflow
- Original status: 🟥 Not built
- Verified status: NOT_FOUND_IN_MAIN
- Evidence: `app/auth/md-apply/page.tsx` is a basic application form. No NPI-verify or DoseSpot integration in `components/md/application-form.tsx` or `components/md/profile-form.tsx`.
- Recommendation: KEEP_AS_IS

## F20 — Hardcode single pharmacy as default destination
- Original status: 🟥 Not built
- Verified status: NOT_FOUND_IN_MAIN
- Evidence: No pharmacy default constant in `lib/prescriptions/`. `app/api/prescriptions/route.ts` requires explicit `pharmacy_id` from request.
- Recommendation: KEEP_AS_IS

## F22 — Refill request workflow + auto-renewal cadence
- Original status: 🟥 Not built
- Verified status: NOT_FOUND_IN_MAIN
- Evidence: `prescriptions` table has a `refills` count column, but no refill-request endpoints, no auto-renewal cron, no refill-specific files exist.
- Recommendation: KEEP_AS_IS

## F23 — Patient self-injection training UI
- Original status: 🟥 Not built
- Verified status: NOT_FOUND_IN_MAIN
- Evidence: No file matching `*training*`, `*injection*`, or `*self-inject*` in the tree.
- Recommendation: KEEP_AS_IS

## F25 — Platform "Rx submitted to pharmacy" notification
- Original status: 🟥 Not built
- Verified status: CONFIRMED
- Evidence: `lib/notifications/email.ts` references a `prescription_status` notification type but no concrete "Rx submitted" trigger or template; not wired to a draft→sent state transition.
- Recommendation: KEEP_AS_IS

## F10b — Admin Protocol Brainstormer (batch script + review UI)
- Original status: 🟥 Not built
- Verified status: NOT_FOUND_IN_MAIN
- Evidence: No batch script, brainstormer endpoint, or admin review UI under `app/dashboard/admin/` or `app/api/admin/`.
- Recommendation: KEEP_AS_IS

## F73 — PubMed citation infrastructure
- Original status: 🟥 Not built
- Verified status: STALE
- Evidence: Migration `003_protocol_citations.sql` already adds `source_citations TEXT[]` to `peptide_protocols` (schema half is done). But no citation-rendering UI under `components/protocol/` — citations are stored, never displayed.
- Recommendation: REWRITE (split: schema is done; remaining work is patient/MD UI to render citations + Brainstormer integration). Update Notes line to reflect that schema column already exists.

## F10d — Generate 30–60 canonical scenarios via batch
- Original status: 🟥 Not built
- Verified status: NOT_FOUND_IN_MAIN
- Evidence: Grep for "scenario"/"canonical" returns only investor-relations dashboard scenario controls and test descriptions. No batch input data or generation script for protocol scenarios.
- Recommendation: KEEP_AS_IS (gated by F10b + F73)

## F69 — Wire Stripe Identity verification button
- Original status: 🟥 Not built
- Verified status: STALE
- Evidence: `lib/identity/stripe-identity.ts` (7.5 KB) is fully implemented and `components/identity/verification-button.tsx` (4.4 KB) is a functional client component — but the button is NOT imported into `components/md/application-form.tsx` (the credentialing flow). Infrastructure built, hook-up missing.
- Recommendation: REWRITE (rename to "wire existing verification-button into MD credentialing flow"; effort drops to XS)

---

# Phase C — Real Data + Dashboards + Labs + MD Decision Support

## F26 — Provision Supabase tables: dosing_reminders, wellness_logs, adherence_events
- Original status: 🟥 Not built
- Verified status: CONFIRMED (partial — 1 of 3 tables exists)
- Evidence: Migration `013_health_logs_notifications.sql` provisions `dosing_reminders` with full schema/indexes/RLS. Grep for `wellness_logs` and `adherence_events` finds nothing.
- Recommendation: SCOPE_CHANGE (split into: F26a `wellness_logs` + F26b `adherence_events`; mark `dosing_reminders` portion done)

## F27 — Rebuild patient dashboard real-data layer
- Original status: ⚠️ Partial (mock data hotfix from March 24 outage)
- Verified status: CONFIRMED
- Evidence: `app/dashboard/patient/page.tsx:33-72` still has hardcoded mock data: `summaryCards` static "0", empty arrays, mock treatment plan. Comment says "Mock data (will be replaced with real Supabase queries later)".
- Recommendation: KEEP_AS_IS

## F28 — Convert 6 mock-data admin pages to real queries
- Original status: ⚠️ Partial
- Verified status: STALE
- Evidence: At least 8 admin pages have inline mock data (analytics, finance, operations, content, support, compliance, webhooks, audit-logs) — count is higher than the claimed 6. None use real Supabase queries for their primary data displays.
- Recommendation: REWRITE (update count to 8+; enumerate each page as a sub-task; effort needs to grow)

## F29 — Merge auto-claude/050 (Stripe Connect earnings real)
- Original status: 🟨 Built-unmerged
- Verified status: STALE
- Evidence: Branch `auto-claude/050` missing per F105. Meanwhile `app/dashboard/md/earnings/page.tsx:31-72` ships `mockPayouts` array, `isConnected=true` hardcoded, `availableBalance=12400` hardcoded — mock code IS on main; never replaced. Branch was either lost or never created.
- Recommendation: REWRITE (drop the auto-claude branch reference; rewrite as "replace mockPayouts/hardcoded balance in earnings page with real Stripe Connect data")

## F30 — Merge auto-claude/044 (patient health-history server-side)
- Original status: 🟨 Built-unmerged
- Verified status: CONFIRMED (work is already on main)
- Evidence: Branch missing per F105. But `app/dashboard/patient/health-history/page.tsx` already calls `/api/users/health-history`, and `app/api/users/health-history/route.ts` runs real Supabase queries against the `health_history` table. Server-side migration is done.
- Recommendation: KEEP_AS_IS (mark complete in task list and DROP — work is in main)

## F31 — Merge auto-claude/041 (DB-driven medication catalog)
- Original status: 🟨 Built-unmerged
- Verified status: CONFIRMED (catalog still hardcoded on main)
- Evidence: Branch `auto-claude/041` missing per F105. `app/dashboard/md/prescriptions/new/page.tsx` has inline hardcoded medication catalog with `default_refills` config. No `medications_catalog` table in any migration.
- Recommendation: REWRITE (drop branch reference; rewrite as direct work — schema migration + catalog seed + replace hardcoded data structure in new-prescription page)

## F32 — Merge auto-claude/057 (patient lab upload + OCR)
- Original status: 🟨 Built-unmerged
- Verified status: NOT_FOUND_IN_MAIN
- Evidence: Branch missing per F105. No patient lab upload UI under `app/dashboard/patient/`, no OCR integration in `app/api/labs/`. Lab orders are MD-initiated only.
- Recommendation: DROP (or REWRITE as new feature task — branch never delivered any work)

## F33 — Build Quest Diagnostics API integration
- Original status: 🟥 Not built
- Verified status: CONFIRMED
- Evidence: `app/api/labs/orders/route.ts:103-116` calls `getLabProvider(providerKey)` and `provider.orderLab()` — provider abstraction is in place but the Quest-specific client/credentials are not visible (likely placeholder). `app/api/labs/results/route.ts` queries the `lab_results` table.
- Recommendation: KEEP_AS_IS (note: provider-abstraction scaffolding present; reduce effort if the abstraction is proven sound)

## F34 — Wire MD lab review UI to live Quest data
- Original status: ⚠️ Partial
- Verified status: CONFIRMED
- Evidence: `app/dashboard/md/labs/page.tsx:61-81` queries `lab_orders` table directly with real Supabase queries; `md-labs-view.tsx` renders live data. UI is wired to DB; what's missing is real provider data feeding the table (gated on F33).
- Recommendation: KEEP_AS_IS

## F35 — Lab result alerting (out-of-range)
- Original status: 🟥 Not built
- Verified status: CONFIRMED
- Evidence: `lab_results.is_abnormal` column exists; `app/dashboard/patient/labs/page.tsx` filters with `r.is_abnormal`. No active alerting (cron, webhook, email/SMS push) on out-of-range.
- Recommendation: KEEP_AS_IS

## F36 — Renewal flow (Rx + subscription)
- Original status: 🟥 Not built
- Verified status: CONFIRMED
- Evidence: `prescriptions.refills` and per-medication `default_refills` exist as data. No automatic renewal trigger logic in `app/api/prescriptions/` or any cron job.
- Recommendation: KEEP_AS_IS

## F37 — Patient deletion endpoint (HIPAA right to erasure)
- Original status: 🟥 Not built
- Verified status: NOT_FOUND_IN_MAIN
- Evidence: No `/api/users/delete` route. `app/api/users/` only has `health-history` and `profiles` subdirs.
- Recommendation: KEEP_AS_IS (compliance-critical; do NOT drop)

## F38 — 7-year retention policy + automated archival
- Original status: 🟥 Not built
- Verified status: CONFIRMED
- Evidence: `is_archived` flags exist on some tables, but no time-based archival cron/edge function and no retention policy migration.
- Recommendation: REWRITE (note partial schema present; primary work is the archival job + policy doc)

## F39 — HIPAA admin MFA enforcement
- Original status: 🟥 Not built
- Verified status: NOT_FOUND_IN_MAIN
- Evidence: No MFA enforcement in `app/dashboard/admin/` auth guards or middleware.
- Recommendation: KEEP_AS_IS (compliance-critical; do NOT drop)

## F40 — Refunds / disputes flow
- Original status: 🟥 Not built
- Verified status: CONFIRMED
- Evidence: `app/dashboard/admin/finance/page.tsx:118-140` has `demoRefunds` mock + `RefundProcessing` component. UI shell exists; no real Stripe Refund API call.
- Recommendation: REWRITE (note shell exists — task shrinks to "wire RefundProcessing component to Stripe Refund API + replace demoRefunds with real query")

## F72 — MD protocol modification UI (REDUCED scope)
- Original status: 🟥 Not built
- Verified status: CONFIRMED
- Evidence: `app/api/consultations/[id]/review/route.ts` has `if (action === 'modify' && modified_protocol)` branch — backend modification logic exists. No dedicated MD UI surface for it under `app/dashboard/md/`.
- Recommendation: REWRITE (note backend exists; task scope shrinks to UI only)

## F77 — IRB modification-request workflow
- Original status: 🟥 Not built
- Verified status: NOT_FOUND_IN_MAIN
- Evidence: No `modification_requests` table, no related UI/API routes.
- Recommendation: KEEP_AS_IS

## F74 — Protocol-modification audit trail
- Original status: 🟥 Not built
- Verified status: NOT_FOUND_IN_MAIN
- Evidence: No `protocol_modifications` table in any migration. Generic `audit_logs` exists but no per-modification record.
- Recommendation: KEEP_AS_IS

## F75 — Medical-decision-support framing
- Original status: 🟥 Not built
- Verified status: CONFIRMED
- Evidence: Disclaimer text appears on `app/(marketing)/protocol/[id]/page.tsx` and `app/api/protocol/generate/route.ts` ("for educational and research purposes only…"). New framing per F11/F75 not yet applied.
- Recommendation: KEEP_AS_IS

## F66 — Expand audit-log coverage to every PHI read/write op
- Original status: 🟥 Not built
- Verified status: CONFIRMED
- Evidence: 8 routes call `logPHIAccessFromRequest` (labs/results, labs/orders, pharmacy/orders, video/consent, identity/verify, ai/summarize-intake, consultations, etc.). Total ~70 API route files; only ~11% covered.
- Recommendation: REWRITE (update Notes with current coverage + missing-route enumeration; effort likely larger than 3 d)

## F67 — Standardize soft-delete pattern across PHI tables
- Original status: 🟥 Not built
- Verified status: CONFIRMED
- Evidence: 26 PHI parent-table FKs use `ON DELETE CASCADE` (profiles, health_history, consultations, prescriptions). No `deleted_at` soft-delete pattern; hard cascades dominate. Migration 022 mentions soft-delete intent but doesn't standardize it.
- Recommendation: REWRITE (effort likely larger than 2 d given 26 cascades to refactor)

## F68 — Audit + remediate FK cascade strategies on PHI tables
- Original status: 🟥 Not built
- Verified status: CONFIRMED
- Evidence: Same 26 `ON DELETE CASCADE` instances on PHI tables (profiles, consultations, prescriptions, lab_orders, lab_results, messages). Compliance risk for HIPAA audit-trail integrity.
- Recommendation: REWRITE (overlaps significantly with F67 — consider merging or sequencing them)

## F65 — Audit + replace unnecessary createServiceClient() usage
- Original status: 🟥 Not built
- Verified status: CONFIRMED
- Evidence: 169 `createServiceClient` occurrences in `app/api/`. Spot checks (labs/orders, labs/results) show appropriate service-role usage. Full audit needed to identify unnecessary cases.
- Recommendation: KEEP_AS_IS

---

# Phase D — Security, Infra & Launch Readiness

## F41 — Add CSP, HSTS, X-Frame-Options, Referrer-Policy headers
- Original status: 🟥 Not built (4 LOC stub)
- Verified status: CONFIRMED
- Evidence: `next.config.ts` is 7 lines, `const nextConfig: NextConfig = { /* config options here */ }` — empty. No security headers configured.
- Recommendation: REWRITE (add concrete header list to Notes; coordinate with F64 since both edit `next.config.ts`)

## F42 — Remove SKIP_AUTH bypass
- Original status: ⚠️ Partial — production blocker
- Verified status: CONFIRMED
- Evidence: `middleware.ts:88-100` and `lib/auth/guards.ts:92-100` both still implement `SKIP_AUTH` dev-mode bypasses. Line numbers shifted from 84-95 / 93 in the master list.
- Recommendation: REWRITE (update line refs to 88-100 and 92-100)

## F43 — Replace SUPABASE_SERVICE_ROLE_KEY on marketing pages
- Original status: ⚠️ Partial
- Verified status: CONFIRMED
- Evidence: `app/(marketing)/conditions/[slug]/page.tsx:95-104` and `app/(marketing)/peptides/[slug]/page.tsx:85-94` use `SUPABASE_SERVICE_ROLE_KEY` in `generateStaticParams()` (build-time). Line numbers shifted; usage is build-time-only (not runtime), which is less risky than the master list implies.
- Recommendation: KEEP_AS_IS (update line refs; consider lowering severity in Notes — build-time SSG isn't a runtime leak vector)

## F44 — Rate limiting on public APIs
- Original status: 🟥 Not built
- Verified status: NOT_FOUND_IN_MAIN
- Evidence: `@upstash/ratelimit` not in `package.json`. No rate-limit middleware in `app/api/`.
- Recommendation: KEEP_AS_IS

## F45 — Zod input validation on all api/* POST/PATCH
- Original status: ⚠️ Partial (~5%)
- Verified status: CONFIRMED
- Evidence: `zod` is installed (`^4.3.6`). Used in `app/api/ai/soap-notes/route.ts` (`SOAPNoteSchema`) and a few others; spot check of `app/api/admin/users/route.ts` shows manual `sanitizeSearch()` only — coverage estimated <10%.
- Recommendation: REWRITE (audit + enumerate routes needing schemas; effort likely larger than 3 d)

## F46 — Prompt injection defense on /api/intake/chat
- Original status: 🟥 Not built
- Verified status: CONFIRMED
- Evidence: `app/api/intake/chat/route.ts` builds the system prompt from unsanitized session data (lines 81-122). No validation of `messages` array or `session_context`. Direct OpenAI call — no output filter.
- Recommendation: REWRITE (concrete defenses: input schema with Zod, system-prompt sandbox prefix/suffix tokens, output post-filter for PHI/system-prompt leakage)

## F47 — Complete .env.example
- Original status: ⚠️ Partial (38 missing vars per audit §1.5)
- Verified status: ALREADY_DONE
- Evidence: `.env.example` is 72 lines, comprehensive (Supabase, Stripe, Postmark, app config, PHI compliance notes). All env vars referenced in code appear documented.
- Recommendation: DROP

## F48 — Origin allowlist / CORS on APIs
- Original status: 🟥 Not built
- Verified status: NOT_FOUND_IN_MAIN
- Evidence: No CORS middleware or `Access-Control-Allow-Origin` headers found in `lib/` or `app/api/`.
- Recommendation: KEEP_AS_IS

## F49 — Secret-scanning pre-commit hook
- Original status: 🟥 Not built
- Verified status: NOT_FOUND_IN_MAIN
- Evidence: No `.husky/`, `.gitleaks.toml`, or `.pre-commit-config.yaml` in repo root.
- Recommendation: KEEP_AS_IS

## F50 — CI/CD pipeline (.github/workflows/ci.yml)
- Original status: 🟥 Not built
- Verified status: NOT_FOUND_IN_MAIN
- Evidence: No `.github/workflows/` directory.
- Recommendation: KEEP_AS_IS

## F51 — Vercel preview deploys per PR
- Original status: 🟥 Not built
- Verified status: NOT_FOUND_IN_MAIN
- Evidence: No `vercel.json` config. Vercel may auto-handle previews via project settings, but explicit config is absent.
- Recommendation: KEEP_AS_IS

## F52 — Stand up staging Vercel + Supabase project
- Original status: 🟥 Not built
- Verified status: NOT_FOUND_IN_MAIN
- Evidence: No staging env config in `.env.example`. Infra-side work, not visible in repo.
- Recommendation: KEEP_AS_IS

## F53 — Test data fixtures + smoke test script
- Original status: 🟥 Not built
- Verified status: CONFIRMED (partial)
- Evidence: `scripts/verify-e2e-flow.mjs` and `verify-e2e-flow.ts` exist. `__tests__/intake/` has 5 suites (auto-save, convergence-scorer, phase-sequencer, resolve-conditions, session-persistence). Some smoke + fixtures present; staging-targeted smoke test still missing.
- Recommendation: KEEP_AS_IS (note progress; reduce effort)

## F54 — Rollback runbook
- Original status: 🟥 Not built
- Verified status: NOT_FOUND_IN_MAIN
- Evidence: No `RUNBOOK.md` or `docs/RUNBOOK*` in repo.
- Recommendation: KEEP_AS_IS

## F55 — Sentry release tracking + PHI scrubbing
- Original status: 🟥 Not built
- Verified status: ALREADY_DONE (server-side)
- Evidence: `sentry.server.config.ts` (119 lines) implements full PHI scrubbing: `beforeSend()` strips request bodies, query strings, cookies, breadcrumbs; allowlist gates extra fields and tags; user context reduced to ID. Client-side config (`sentry.client.config.ts`) missing.
- Recommendation: DROP (server-side done; if client-side scrubbing also wanted, file as a small follow-up — not the original 0.5 d task)

## F56 — Sitemap.xml + robots.txt + OG cards
- Original status: 🟥 Not built
- Verified status: STALE
- Evidence: No `public/sitemap.xml`, `public/robots.txt`, or `app/sitemap.ts`. `app/layout.tsx` has basic title/description but no openGraph defaults. Marketing slug pages do have `generateMetadata()` with OG. Mixed state.
- Recommendation: REWRITE (clarify: sitemap + robots TODO, OG defaults TODO, slug-page OG already done)

## F57 — Privacy policy + ToS + HIPAA NPP pages
- Original status: 🟥 Not built
- Verified status: NOT_FOUND_IN_MAIN
- Evidence: No `/privacy`, `/terms`, `/hipaa-npp` routes. Only `app/auth/consent/page.tsx`.
- Recommendation: KEEP_AS_IS (gated on V.4 attorney review)

## F58 — Disable / configure SITE_PROTECTION_ENABLED
- Original status: 🟥 Not built
- Verified status: ALREADY_DONE
- Evidence: `middleware.ts:57` already implements full `SITE_PROTECTION_ENABLED` gating with HTTP Basic Auth fallback, configurable creds, and static-asset skip. Configuration is the only outstanding decision.
- Recommendation: DROP (implementation is done — keep only the operational decision out-of-band)

## F59 — Stripe invoice templates for cash-pay
- Original status: 🟥 Not built
- Verified status: NOT_FOUND_IN_MAIN
- Evidence: `.env.example` has Stripe price IDs for subscriptions. `lib/stripe/webhooks.ts` references invoice fields but no custom template config.
- Recommendation: KEEP_AS_IS

## F60 — Custom session timeout (30-min idle for PHI access)
- Original status: 🟥 Not built
- Verified status: NOT_FOUND_IN_MAIN
- Evidence: `lib/auth/guards.ts` and `lib/auth/roles.ts` have no idle/timeout logic. Supabase default session is longer than 30 min.
- Recommendation: KEEP_AS_IS

## F64 — Wire Sentry source-map upload via withSentryConfig
- Original status: 🟥 Not built
- Verified status: NOT_FOUND_IN_MAIN
- Evidence: `next.config.ts` has zero config — no `withSentryConfig` wrapper. `sentry.server.config.ts` exists but isn't integrated into the Next.js build pipeline.
- Recommendation: REWRITE (combine with F41 — both edit `next.config.ts`; one PR, one round of testing)

---

# Cross-Cutting Findings

1. **Auto-claude branches are dead.** Every auto-claude branch task (F3, F6, F7, F8, F9, F29, F30, F31, F32) traces back to a missing or empty branch. Treat the original task list's "🟨 Built-unmerged" state as inaccurate everywhere. Either the work is already on main (F8, F9, F30) or it never got pushed (everything else). Drop the branch references and rewrite as direct-on-main work where the underlying gap still exists.

2. **5 quiet wins.** F8 (MD schedule), F9 (P0 user-ID security), F47 (env example), F55 (Sentry server-side scrubbing), F58 (SITE_PROTECTION_ENABLED) are done. Drop them — 5 tasks (and the P0 security item) can come off the active queue immediately.

3. **`next.config.ts` is the obvious bundle.** F41 (security headers) and F64 (Sentry source-map) both need the file. One PR, not two.

4. **Audit-log/cascade family.** F66, F67, F68 all touch the same PHI-table compliance space. The 26 `ON DELETE CASCADE` instances surfaced here suggest these tasks should be sequenced as one workstream rather than three independents.

5. **Schema half-done patterns.** F73 (citations column without UI) and F26 (1 of 3 tables done) are partial-state cases where splitting "schema" from "UI/data" sub-tasks would prevent confusion.

6. **Critical-path sanity:** F17/F18 (DoseSpot) is more advanced than the master list implies — the helper exists, the route exists, what's missing is the wiring + Surescripts cert. Effort estimate likely overstated.
