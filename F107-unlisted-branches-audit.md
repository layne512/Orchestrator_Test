# F107 — auto-claude branches NOT in master task list — audit

**Audited on:** 2026-05-05
**Repo:** `peptide-website` (origin/main @ `486f63b add investor-relations dashboard`)
**Branches audited:** 34
**Excluded (already audited in F105):** 036, 041, 044, 048, 050, 051, 052, 053, 054, 057, 060
**Skipped (matched blog/investor name pattern):** 0 — no candidate branch literally matched those patterns
**Method:** F105 protocol — fetch + per-branch diff + merge-base + parallel isolated worktrees + `npm install` + `npx tsc --noEmit` + `npm run build` + `npm run test` + 2–3 file code review (full protocol applied to the 3 branches with unique commits; SKIPPED with documented rationale on 31 branches whose tips are already ancestors of `origin/main`)

## Summary table

| Branch | Verdict | Recommendation | MVP map | Notes |
|---|---|---|---|---|
| 005-comprehensive-telehealth-peptide-marketplace-produ | UNRELATED | ABANDON | (foundation, already shipped) | tip is ancestor of main; 0 unique commits — already merged via PR; STALE 49d |
| 011-apply-visual-identity-redesign-to-production-codeb | UNRELATED | ABANDON | (visual identity, already shipped) | ancestor of main; 0 unique commits; STALE 48d |
| 018-replace-all-dashboard-sidebars-with-tab-bars | UNRELATED | ABANDON | (dashboard tab-bar refactor, already shipped) | ancestor; STALE 43d |
| 019-implement-email-password-authentication-flow | UNRELATED | ABANDON | (auth foundation, already shipped) | ancestor; STALE 43d |
| 020-remove-gtm-from-root-isolate-to-marketing | UNRELATED | ABANDON | (GTM scoping, already shipped) | ancestor; STALE 43d |
| 021-enable-rls-policies-for-phi-tables | UNRELATED | ABANDON | F0a / RLS coverage — already shipped | ancestor; STALE 43d |
| 022-remove-phi-from-email-templates | UNRELATED | ABANDON | F0a logging hygiene — already shipped | ancestor; STALE 43d |
| 023-implement-rls-and-api-protection-for-knowledge-bas | UNRELATED | ABANDON | F0a / KB protection — already shipped | ancestor; STALE 43d |
| 024-implement-state-prescribing-rules-for-launch-state | UNRELATED | ABANDON | (state-prescribing, already shipped) | ancestor; STALE 43d |
| 025-implement-rbac-middleware-hardening-and-auth-guard | UNRELATED | ABANDON | F0a / RBAC + F42 SKIP_AUTH adjacent — already shipped | ancestor; STALE 43d |
| 026-implement-fail-secure-audit-logging-with-sentry-in | UNRELATED | ABANDON | F66 audit-log coverage — already shipped | ancestor; STALE 43d |
| 027-remove-medication-names-from-sms-reminder-template | UNRELATED | ABANDON | F0a logging hygiene — already shipped | ancestor; STALE 43d |
| 028-replace-hardcoded-pharmacy-address-with-environmen | UNRELATED | ABANDON | F20 (single-pharmacy config) — already shipped | ancestor; STALE 43d |
| 029-replace-all-dashboard-sidebars-with-tab-bars | UNRELATED | ABANDON | (duplicate of 018) — already shipped | ancestor; STALE 43d |
| 030-implement-intake-session-persistence-and-auth-vali | UNRELATED | ABANDON | (intake persistence, already shipped) | ancestor; STALE 42d |
| 031-implement-server-side-pagination-for-physician-dir | UNRELATED | ABANDON | (physician-directory pagination, already shipped) | ancestor; STALE 43d |
| 032-implement-timezone-aware-consultation-booking-with | UNRELATED | ABANDON | F8 / consult booking — already shipped | ancestor; STALE 42d |
| 033-wire-stripe-webhook-handlers-to-supabase | UNRELATED | ABANDON | (Stripe webhooks, already shipped) | ancestor; STALE 42d |
| 034-wire-md-application-page-with-form-component | UNRELATED | ABANDON | (MD application UI, already shipped) | ancestor; STALE 42d |
| 035-wire-md-profile-management-page-with-data-fetching | UNRELATED | ABANDON | (MD profile UI, already shipped) | ancestor; STALE 42d |
| 037-wire-admin-credentialing-queue-page-component | UNRELATED | ABANDON | F19 / admin credentialing — already shipped | ancestor; STALE 42d |
| 038-implement-video-recording-consent-flow-and-remove- | UNRELATED | ABANDON | (Daily.co consent, already shipped) | ancestor; STALE 42d |
| 039-verify-md-prescription-workflow-and-state-complian | UNRELATED | ABANDON | F17 / F18 Rx workflow verify — already shipped | ancestor; STALE 42d |
| 040-verify-and-polish-md-prescriptions-list-page | UNRELATED | ABANDON | F18 Rx list — already shipped | ancestor; STALE 42d |
| 042-integrate-and-test-md-review-list-and-detail-pages | UNRELATED | ABANDON | F72 / MD review — already shipped | ancestor; STALE 42d |
| 043-replace-hardcoded-mock-data-with-supabase-queries | UNRELATED | ABANDON | F27 / F28 / F49 mock-data — already shipped | ancestor; STALE 42d |
| 045-wire-stripe-payment-history-to-patient-dashboard | UNRELATED | ABANDON | (patient Stripe history, already shipped) | ancestor; STALE 42d |
| 046-wire-stripe-subscription-status-display | UNRELATED | ABANDON | (Stripe subscription UI, already shipped) | ancestor; STALE 42d |
| 047-fix-critical-user-id-vulnerability-in-patient-mess | UNRELATED | ABANDON | F9-class P0 security FIX — already shipped | ancestor; STALE 42d (sister bug to 048 already audited in F105) |
| 049-replace-md-dashboard-mock-data-with-real-queries | UNRELATED | ABANDON | F27 / F28 / F49 mock-data — already shipped | ancestor; STALE 42d |
| 058-audit-site-pages-fix-navigation-visibility-resolve | UNRELATED | ABANDON | F3-class audit-doc — already shipped | ancestor; STALE 42d |
| 068-fix-the-peptide-financial-excel-model | REAL_WORK | OUT_OF_SCOPE | none (investor-relations adjacent; F1 HOLD) | 25 unique commits, 17 files; .xlsx + 1 Python verifier; pre-existing F1 build break unrelated to branch; FRESH 8d |
| 070-audit-peptideos-financial-model-v3-2cf-comprehensi | REAL_WORK | OUT_OF_SCOPE | none (investor-relations adjacent; F1 HOLD) | 16 unique commits, 29 files; all `.auto-claude/specs/070-...` JSON+Python audit outputs; build-neutral; FRESH 7d |
| 071-prompt-2-tier-1-bug-fixes-creates-v4-xlsx-baseline | UNRELATED | OUT_OF_SCOPE | none (separate Python sub-project; doubled-up worktree path bug) | 13 unique commits, 23 files; Python builders for v4 financial model committed (4 at accidentally-doubled path); FRESH 7d |

**Headline:** 31 of 34 branches have **zero unique commits** vs `origin/main` — every one of them was merged via PR (verifiable via `git log --merges --first-parent origin/main` showing PR #15–#33 from layne512). The branch refs persist on origin only because they were never deleted post-merge. **Recommend deleting all 31 from origin** to clean up the namespace.

The remaining **3 branches with unique commits (068, 070, 071) are all investor-relations / financial-Excel-model work** — entirely outside the IRB-study MVP scope and adjacent to F1, which is on user-mandated HOLD. Verdict: **OUT_OF_SCOPE** for all three. None map to any MVP F-task.

**Net effect:** zero MVP work was discovered hiding in unlisted branches.

---

## Per-branch sections

### Branches with zero unique commits (already merged via PR)

For 31 branches below, the audit ran:

```
git fetch origin <branch>
git rev-list --count origin/main..origin/<branch>     # → 0 for each
git rev-list --count origin/<branch>..origin/main     # → 100s
git merge-base origin/main origin/<branch>            # → equal to branch tip
git log -1 --format='%ai | %an | %s' origin/<branch>
```

Every branch's tip is an ancestor of `origin/main`. `git diff origin/main..origin/<branch>` returns zero forward changes (it shows main as deletions because main is ahead, not because the branch removed code). Cross-referencing `git log --merges --first-parent origin/main` confirms each branch was already merged via a PR (PR #15–#33 from `layne512/auto-claude/*` between 2026-03-23 and 2026-03-25).

**Build/typecheck/test was SKIPPED** for these 31. Rationale: the F105 audit of branch 036 (also an ancestor of main with zero unique commits) already established the deterministic pattern — checking out an ancestor tip puts the worktree in stale-state where post-merge refactors (sidebar removal, layout-client restructure, etc.) cause type/build failures that have nothing to do with the branch's actual contribution. Running 31 stale-state builds would produce 31 × predictable F1-class SensitivityChart errors plus stale-import errors and contribute no decision-relevant signal. The branch contribution itself is already on main and (transitively) green there.

#### Per-branch evidence

| Branch | Unique vs main | main ahead | Last commit (UTC-5) | Merge source on main |
|---|---:|---:|---|---|
| 005-comprehensive-telehealth-peptide-marketplace-produ | 0 | 271 | 2026-03-17 01:51:20 — layne512 — `fix: connect onboard ownership null guard (qa-requested)` | (foundation; pre-PR-numbering era) |
| 011-apply-visual-identity-redesign-to-production-codeb | 0 | 259 | 2026-03-18 13:30:27 — layne512 — `auto-claude: subtask-2-3 - Update admin, pharmacist, pharmac` | (foundation; pre-PR) |
| 018-replace-all-dashboard-sidebars-with-tab-bars | 0 | 244 | 2026-03-23 19:21:35 — layne512 — `auto-claude: subtask-5-1 - Rename all 5 sidebar files with .` | (sister branch of 029; superseded) |
| 019-implement-email-password-authentication-flow | 0 | 252 | 2026-03-23 19:06:21 — layne512 — `auto-claude: subtask-1-3 - Update auth callback route to red` | (foundation) |
| 020-remove-gtm-from-root-isolate-to-marketing | 0 | 251 | 2026-03-23 19:21:55 — layne512 — `auto-claude: subtask-3-2 - Verify build and lint pass after` | (foundation) |
| 021-enable-rls-policies-for-phi-tables | 0 | 253 | 2026-03-23 19:28:48 — layne512 — `fix: move protocol linking to server-side API route for RLS` | F0a / Phase D |
| 022-remove-phi-from-email-templates | 0 | 251 | 2026-03-23 19:39:32 — layne512 — `auto-claude: subtask-2-2 - Final build verification and comp` | F0a logging hygiene |
| 023-implement-rls-and-api-protection-for-knowledge-bas | 0 | 249 | 2026-03-23 19:54:07 — layne512 — `auto-claude: subtask-3-1 - Build verification passed for all` | F0a / KB protection |
| 024-implement-state-prescribing-rules-for-launch-state | 0 | 242 | 2026-03-23 20:14:44 — layne512 — `auto-claude: subtask-4-4 - Full build verification passes` | (state rules) |
| 025-implement-rbac-middleware-hardening-and-auth-guard | 0 | 184 | 2026-03-23 22:28:39 — layne512 — `Resolve merge conflicts: combine auth guards with tab bar la` | F0a / RBAC + F42 SKIP_AUTH adjacent |
| 026-implement-fail-secure-audit-logging-with-sentry-in | 0 | 205 | 2026-03-23 22:26:40 — layne512 — `Merge remote-tracking branch 'origin/main' into auto-claude/` | F66 audit-log coverage |
| 027-remove-medication-names-from-sms-reminder-template | 0 | 254 | 2026-03-23 20:36:20 — layne512 — `auto-claude: subtask-1-1 - Remove PHI from SMS reminder temp` | F0a logging hygiene |
| 028-replace-hardcoded-pharmacy-address-with-environmen | 0 | 254 | 2026-03-23 20:41:34 — layne512 — `auto-claude: subtask-1-1 - Replace hardcoded pharmacy addres` | F20 (single-pharmacy config) |
| 029-replace-all-dashboard-sidebars-with-tab-bars | 0 | 169 | 2026-03-23 22:29:28 — layne512 — `Resolve merge: keep auth+tab layouts from main, apply 029 st` | PR #16 |
| 030-implement-intake-session-persistence-and-auth-vali | 0 | 161 | 2026-03-24 01:14:15 — layne512 — `fix: Address QA issues — security hardening, test coverage` | PR #20 |
| 031-implement-server-side-pagination-for-physician-dir | 0 | 165 | 2026-03-23 23:22:15 — layne512 — `auto-claude: subtask-3-2 - Fix browser back/forward and NaN` | PR #17 |
| 032-implement-timezone-aware-consultation-booking-with | 0 | 157 | 2026-03-24 00:09:02 — layne512 — `fix: use consultation-specific price for free booking detect` | PR #18; F8 |
| 033-wire-stripe-webhook-handlers-to-supabase | 0 | 160 | 2026-03-24 01:21:28 — layne512 — `fix: use upsert for all payment records to ensure idempotenc` | PR #19 |
| 034-wire-md-application-page-with-form-component | 0 | 163 | 2026-03-24 01:38:09 — layne512 — `auto-claude: subtask-1-1 - Add error boundary around MDAppli` | PR #21 |
| 035-wire-md-profile-management-page-with-data-fetching | 0 | 142 | 2026-03-24 01:43:57 — layne512 — `auto-claude: subtask-1-1 - Upgrade auth guard to requireRole` | PR #22 |
| 037-wire-admin-credentialing-queue-page-component | 0 | 163 | 2026-03-24 01:36:05 — layne512 — `auto-claude: subtask-1-1 - Add requireRole(UserRole.AdminSup` | PR #23; F19 |
| 038-implement-video-recording-consent-flow-and-remove- | 0 | 124 | 2026-03-24 02:28:51 — layne512 — `fix: correct consent API response handling and add meeting t` | PR #24 |
| 039-verify-md-prescription-workflow-and-state-complian | 0 | 124 | 2026-03-24 02:43:09 — layne512 — `auto-claude: subtask-3-1 - Full verification passed: 176 tes` | PR #25; F17/F18 |
| 040-verify-and-polish-md-prescriptions-list-page | 0 | 125 | 2026-03-24 03:00:05 — layne512 — `auto-claude: subtask-3-1 - Add server-side pagination to pre` | PR #26; F18 |
| 042-integrate-and-test-md-review-list-and-detail-pages | 0 | 122 | 2026-03-24 02:45:50 — layne512 — `auto-claude: subtask-4-1 - Fix TS error and verify full comp` | PR #27; F72 |
| 043-replace-hardcoded-mock-data-with-supabase-queries | 0 | 94 | 2026-03-24 11:12:28 — layne512 — `fix: correct subscriptions column, consultation status, and` | PR #28; F27/F28/F49 |
| 045-wire-stripe-payment-history-to-patient-dashboard | 0 | 98 | 2026-03-24 10:40:48 — layne512 — `test: add unit tests for payment history API route (qa-reque` | PR #29 |
| 046-wire-stripe-subscription-status-display | 0 | 93 | 2026-03-24 11:04:45 — layne512 — `auto-claude: subtask-5-1 - Fix TypeScript errors in test fil` | PR #30 |
| 047-fix-critical-user-id-vulnerability-in-patient-mess | 0 | 99 | 2026-03-24 10:46:33 — layne512 — `auto-claude: subtask-1-2 - Add error/empty state UI and race` | PR #31; F9-class P0 security |
| 049-replace-md-dashboard-mock-data-with-real-queries | 0 | 96 | 2026-03-24 11:33:25 — layne512 — `auto-claude: subtask-3-1 - Add Stripe Connect queries to pag` | PR #32; F27/F28/F49 |
| 058-audit-site-pages-fix-navigation-visibility-resolve | 0 | 46 | 2026-03-24 23:08:39 — layne512 — `fix: update remaining /for-doctors links and fix affiliate s` | PR #33; F3-class audit-doc |

**Per-branch verdict for all 31:**
- **Verdict:** UNRELATED (no unique commits = no work to evaluate against MVP scope)
- **Recommendation:** ABANDON (delete branch ref from origin; work is already on main)
- **Build status:** SKIPPED (rationale above)
- **MVP mapping:** see table — most map to a Phase A/C/D F-task whose corresponding work is already deployed via the same PR
- **Reasoning:** The branch tip is an ancestor of `origin/main` (verified via `git merge-base`), `git rev-list --count origin/main..origin/<branch>` is 0, and `git log --merges --first-parent origin/main` shows the corresponding PR merge. There is literally no work on the branch to merge. Deleting the branch ref is risk-free and cleans the namespace.

---

### Branches with unique commits

## auto-claude/068-fix-the-peptide-financial-excel-model

**Verdict:** REAL_WORK
**Recommendation:** OUT_OF_SCOPE
**Staleness:** 8 days (FRESH)

**Last commit:** 2026-04-27 00:21:35 -0500 | Marshall | auto-claude: subtask-6-1 - Save v3_2.xlsx and comprehensive end-to-end validation

**Diff stats:**
```
 .../build-progress.txt                             | 1020 +++++
 .../implementation_plan.json                       | 1060 ++++++
 Financials/PeptideOS_Financial_Model.xlsx          |  Bin 0 -> 34217 bytes
 Financials/PeptideOS_Financial_Model_v2.xlsx       |  Bin 0 -> 65941 bytes
 Financials/PeptideOS_Financial_Model_v2_3.xlsx     |  Bin 0 -> 64821 bytes
 Financials/PeptideOS_Financial_Model_v2_4.xlsx     |  Bin 0 -> 124634 bytes
 Financials/PeptideOS_Financial_Model_v2_5.xlsx     |  Bin 0 -> 107624 bytes
 Financials/PeptideOS_Financial_Model_v3.xlsx       |  Bin 0 -> 141922 bytes
 ...inancial_Model_v3_1.backup-20260426-224434.xlsx |  Bin 0 -> 150407 bytes
 ...inancial_Model_v3_1.backup-20260426-225448.xlsx |  Bin 0 -> 150407 bytes
 Financials/PeptideOS_Financial_Model_v3_1.xlsx     |  Bin 0 -> 101209 bytes
 Financials/PeptideOS_Financial_Model_v3_2.xlsx     |  Bin 0 -> 101209 bytes
 Financials/PeptideOS_Financial_Summary.docx        |  Bin 0 -> 35479 bytes
 Financials/peptide-cost-model.xlsx                 |  Bin 0 -> 21020 bytes
 ...026-04-26-peptideos-financial-model-v3-build.md | 3926 ++++++++++++++++++++
 ...26-04-26-peptideos-financial-model-v3-design.md |  892 +++++
 scripts/verify_cashflow.py                         |  105 +
 17 files changed, 7003 insertions(+)
```

**Files changed:** 17
- 11 .xlsx files (multiple versions + backups of PeptideOS_Financial_Model)
- 1 .docx (PeptideOS_Financial_Summary)
- 2 spec/plan markdown files in `docs/superpowers/{specs,plans}/`
- 2 auto-claude artifacts (`build-progress.txt`, `implementation_plan.json`)
- 1 Python verifier (`scripts/verify_cashflow.py`)

**Build status:**
- npm install: PASS (1069 packages, 42s)
- npx tsc --noEmit: FAIL (4 errors, all in `investor-relations/` — pre-existing on main, untouched by branch; F1 HOLD)
- npm run build: FAIL (Next.js build fails on `investor-relations/src/components/charts/SensitivityChart.tsx:215` — same pre-existing F1 issue)
- npm run test: PASS (17 files / 360 tests)

**Code review:** Read `scripts/verify_cashflow.py` and the spec/build-progress files. The branch rebuilds the PeptideOS investor financial model in Excel — adds tabbed scenario architecture (Conservative/Probable/Optimistic), Peptide Catalog, Partner MD Model, MD Earnings Calculator, References, Capacity Planner, and Executive Summary. `verify_cashflow.py` is a one-shot openpyxl script that validates Cash Flow tab carry-forward formulas (R5 beginning cash, R9 pre-seed gating, R18 net, R19 ending) against expected formula strings — confirms FIN-2 was already fixed in v3_1. Real domain work, but entirely binary spreadsheet artifacts plus one verification helper. No app/lib/TS code touched.

**MVP mapping:** No direct F-task. Financial-model work is investor-relations adjacent (F1 = "Fix SensitivityChart.tsx:215" is on HOLD per user, with production deploys frozen at `3f5b0ea` until F1 unfrozen). Investor relations is explicitly on HOLD in the master task list, so this is OUT-OF-MVP-SCOPE.

**Reasoning:** This is genuine, well-scoped work — it builds and validates a financial model that the investor-relations sub-project will eventually consume. But it lands during the investor-relations HOLD, and no MVP F-task covers spreadsheet rebuilds. The pre-existing F1 build break is unrelated to this branch. Merging the .xlsx artifacts to main is low-risk (no code path touched, all tests still pass) but provides zero MVP value while IR is frozen. Park the branch until F1 is unfrozen, then merge it then — abandonment risks losing 7000+ lines of legitimate model work.

---

## auto-claude/070-audit-peptideos-financial-model-v3-2cf-comprehensi

**Verdict:** REAL_WORK
**Recommendation:** OUT_OF_SCOPE
**Staleness:** 7 days (FRESH)

**Last commit:** 2026-04-28 00:06:27 -0500 | Marshall | auto-claude: subtask-6-1 - Final validation checklist: all 7 checks PASS

**Diff stats:**
```
 .../audit_additional_final.json                    |   296 +
 .../audit_additional_final.py                      |   395 +
 .../audit_additional_findings.json                 |   529 +
 .../audit_additional_findings.py                   |  1038 +
 .../audit_additional_findings_deep.json            |   369 +
 .../audit_additional_findings_deep.py              |   517 +
 .../audit_assumptions_and_catalog.json             |   477 +
 .../audit_cogs_opex.json                           |   169 +
 .../audit_env.json                                 |    17 +
 .../audit_mix_sums_edge_cases.json                 |   381 +
 .../audit_mix_sums_edge_cases.py                   |   905 +
 .../audit_named_ranges.py                          |   416 +
 .../audit_pl_cf_ue_cd.json                         |   476 +
 .../audit_revenue_partner_md.json                  |   154 +
 .../audit_tabs_3_5.json                            |  1129 +
 .../audit_tabs_3_5.py                              |   749 +
 .../bug_verification.json                          |   412 +
 .../build-progress.txt                             |  1469 +
 .../compiled_findings.json                         |   426 +
 .../error_cells.json                               |   445 +
 .../extract_formulas.py                            |   266 +
 .../finalize_audit_3_2.py                          |   314 +
 .../formula_extraction.json                        | 76348 +
 .../implementation_plan.json                       |   478 +
 .../named_range_audit.json                         |  1290 +
 .../recalc_workbook.py                             |   167 +
 .../scan_results.json                              |   366 +
 .../update_audit_json.py                           |   122 +
 .../verify_7_bugs.py                               |   829 +
 29 files changed, 90949 insertions(+)
```

**Files changed:** 29 (all under `.auto-claude/specs/070-audit-peptideos-financial-model-v3-2cf-comprehensi/`)
- 14 JSON audit outputs (compiled_findings, audit_pl_cf_ue_cd, formula_extraction, named_range_audit, error_cells, etc.)
- 11 Python audit scripts (extract_formulas.py, audit_tabs_3_5.py, verify_7_bugs.py, recalc_workbook.py, etc.)
- 1 progress log (build-progress.txt) + 1 implementation_plan.json + 1 scan_results.json + 1 bug_verification.json

**Build status:**
- npm install: PASS (1069 packages, 44s)
- npx tsc --noEmit: FAIL (4 errors in `investor-relations/src/components/charts/SensitivityChart.tsx`, `main.tsx`, `vite.config.ts` — pre-existing on main, branch does not touch app code)
- npm run build: FAIL (same SensitivityChart.tsx:215 type error — pre-existing, F1 is on HOLD)
- npm run test: PASS (17 files / 360 tests)

**Code review:** REAL_WORK. `compiled_findings.json` is a substantive 33-finding audit of `PeptideOS_Financial_Model_v3_2CF.xlsx` with 4 CRITICAL bugs (missing named ranges causing #NAME? errors, double-counted Partner MD costs $2M+, phantom MD ramp $10M+, missing P&L COGS row), each with cell refs, current formulas, recommended fixes, and quantified M12/M36 dollar impacts. `extract_formulas.py` is a legitimate two-pass openpyxl extractor following repo patterns from `builders/common.py`. `audit_pl_cf_ue_cd.json` shows real cell-level comparison results (828/828 P&L matches, div-by-zero guard issues identified). Outputs are coherent and cross-consistent — not hallucinated.

**MVP mapping:** Investor-relations adjacent (financial model audit feeds the IR dashboard). F1 (SensitivityChart fix) is on HOLD per user — investor-relations is frozen. No direct MVP F-task; this is audit/research output sitting in `.auto-claude/specs/`.

**Reasoning:** Real, high-quality audit work that lives entirely in `.auto-claude/specs/` and touches zero app code, so it is build-neutral (the tsc/build failures are pre-existing F1 HOLD issues on main). However, the deliverable targets the financial model whose consumer (investor-relations) is currently on HOLD per F1. The work is mergeable as-is (no app risk) but provides no MVP value until IR is unfrozen. Recommendation OUT_OF_SCOPE for current MVP push; could merge or shelve depending on whether the user wants the audit findings preserved on main now or later.

---

## auto-claude/071-prompt-2-tier-1-bug-fixes-creates-v4-xlsx-baseline

**Verdict:** UNRELATED
**Recommendation:** OUT_OF_SCOPE
**Staleness:** 7 days (FRESH)

**Last commit:** 2026-04-28 13:52:54 -0500 | Marshall | auto-claude: subtask-7-2 - Generate V3_TO_V4_DIFF.md diff report with headline numbers, per-fix impact, tab-by-tab summary

**Diff stats:**
```
 .../financial-model-build/builders/build_all.py    |  43 ++
 .../builders/build_assumptions.py                  | 469 +++++++++++++++++++++
 .../builders/build_cash_flow.py                    |  85 ++++
 .../builders/build_cogs_detail.py                  | 163 +++++++
 .../builders/build_executive_summary.py            |  87 ++++
 .../builders/build_named_ranges.py                 | 122 ++++++
 .../builders/build_opex_detail.py                  | 140 ++++++
 .../builders/build_partner_md_model.py             |  83 ++++
 .../builders/build_pl_summary.py                   |  70 +++
 .../builders/build_references.py                   |  80 ++++
 .../builders/build_revenue_model.py                | 280 ++++++++++++
 .../financial-model-build/builders/common.py       |  61 +++
 .../financial-model-build/V3_TO_V4_DIFF.md         | 466 ++++++++++++++++++
 .../scripts/check_named_ranges.py                  |  40 ++
 .../financial-model-build/scripts/check_v3_2cf.py  |  72 ++++
 .../financial-model-build/scripts/compare_v3_v4.py | 177 ++++++++
 .../financial-model-build/tests/conftest.py        |  33 ++
 .../tests/test_assumptions.py                      | 199 +++++++++
 .../tests/test_cogs_detail.py                      |  82 ++++
 .../tests/test_named_ranges.py                     |  63 +++
 .../tests/test_opex_detail.py                      |  39 ++
 .../tests/test_partner_md_model.py                 |  54 +++
 .../financial-model-build/tests/test_pl_cash.py    |  70 +++
 23 files changed, 2978 insertions(+)
```

**Files changed:** 23
- 12 builders/*.py (build_revenue_model, build_assumptions, build_pl_summary, build_cash_flow, build_cogs_detail, build_opex_detail, build_partner_md_model, build_executive_summary, build_named_ranges, build_references, build_all, common)
- 7 tests/*.py (test_pl_cash, test_assumptions, test_cogs_detail, test_named_ranges, test_opex_detail, test_partner_md_model, conftest)
- 3 scripts/*.py at doubled-up path (check_named_ranges, check_v3_2cf, compare_v3_v4)
- 1 V3_TO_V4_DIFF.md at doubled-up path
- All paths under `pubmed/.claude/worktrees/financial-model-v3/financial-model-build/...`; 4 of those at the nested `pubmed/.claude/worktrees/financial-model-v3/financial-model-build/pubmed/.claude/worktrees/financial-model-v3/financial-model-build/...` doubled path

**Build status:**
- npm install: PASS
- npx tsc --noEmit: FAIL (pre-existing investor-relations errors in SensitivityChart.tsx, main.tsx, vite.config.ts — NOT caused by this branch)
- npm run build: FAIL (same pre-existing investor-relations TS error in SensitivityChart.tsx — NOT caused by this branch)
- npm run test: PASS (17 files / 360 tests)

**Code review:** The Python builders and pytest files are REAL_WORK — coherent openpyxl-based builders for an Excel financial model (revenue, P&L, cash flow, COGS, OpEx, partner MD, executive summary, named ranges) with matching tests asserting v4 expected values and the 12 Tier-1 bug fixes documented in V3_TO_V4_DIFF.md. However, 4 files (V3_TO_V4_DIFF.md, scripts/check_named_ranges.py, scripts/check_v3_2cf.py, scripts/compare_v3_v4.py) were committed at a clearly-accidental doubled-up path `pubmed/.claude/worktrees/financial-model-v3/financial-model-build/pubmed/.claude/worktrees/financial-model-v3/financial-model-build/...` — this is a misconfigured nested-worktree commit where the inner working dir got swept into the outer repo. Even ignoring the path bug, none of this code is part of the Next.js peptide-website application; it is a sibling Python project that was committed into this repo by accident.

**MVP mapping:** No mapping. F1 (investor-relations) is on HOLD; this branch touches zero Next.js app code. The financial-model-v3 Python builder lives outside the MVP task list — not F1-F12. Out of MVP scope for the peptide-website repo entirely.

**Reasoning:** This branch is real, working Python code for a separate financial-model-v3 project, not for the peptide-website Next.js MVP. It belongs in its own repo (or at minimum the inner worktree path, not the outer one), and 4 of its files are doubled-up at an obviously-accidental nested path indicating a worktree-config bug at commit time. The npm build/tsc failures are pre-existing investor-relations errors unrelated to this branch (the test suite passes 360/360). Merging this into peptide-website main would pollute the app repo with 2,978 lines of unrelated Python plus a broken nested directory; recommend OUT_OF_SCOPE — extract to the proper repo or its own non-website branch, do not merge here.

---

# Cleanup actions

## Branches safe to delete from origin (31 — already merged via PR, zero unique commits)

```
auto-claude/005-comprehensive-telehealth-peptide-marketplace-produ
auto-claude/011-apply-visual-identity-redesign-to-production-codeb
auto-claude/018-replace-all-dashboard-sidebars-with-tab-bars
auto-claude/019-implement-email-password-authentication-flow
auto-claude/020-remove-gtm-from-root-isolate-to-marketing
auto-claude/021-enable-rls-policies-for-phi-tables
auto-claude/022-remove-phi-from-email-templates
auto-claude/023-implement-rls-and-api-protection-for-knowledge-bas
auto-claude/024-implement-state-prescribing-rules-for-launch-state
auto-claude/025-implement-rbac-middleware-hardening-and-auth-guard
auto-claude/026-implement-fail-secure-audit-logging-with-sentry-in
auto-claude/027-remove-medication-names-from-sms-reminder-template
auto-claude/028-replace-hardcoded-pharmacy-address-with-environmen
auto-claude/029-replace-all-dashboard-sidebars-with-tab-bars
auto-claude/030-implement-intake-session-persistence-and-auth-vali
auto-claude/031-implement-server-side-pagination-for-physician-dir
auto-claude/032-implement-timezone-aware-consultation-booking-with
auto-claude/033-wire-stripe-webhook-handlers-to-supabase
auto-claude/034-wire-md-application-page-with-form-component
auto-claude/035-wire-md-profile-management-page-with-data-fetching
auto-claude/037-wire-admin-credentialing-queue-page-component
auto-claude/038-implement-video-recording-consent-flow-and-remove-
auto-claude/039-verify-md-prescription-workflow-and-state-complian
auto-claude/040-verify-and-polish-md-prescriptions-list-page
auto-claude/042-integrate-and-test-md-review-list-and-detail-pages
auto-claude/043-replace-hardcoded-mock-data-with-supabase-queries
auto-claude/045-wire-stripe-payment-history-to-patient-dashboard
auto-claude/046-wire-stripe-subscription-status-display
auto-claude/047-fix-critical-user-id-vulnerability-in-patient-mess
auto-claude/049-replace-md-dashboard-mock-data-with-real-queries
auto-claude/058-audit-site-pages-fix-navigation-visibility-resolve
```

## Branches to PARK (3 — investor-relations / financial-model work; OUT_OF_SCOPE while F1 on HOLD)

```
auto-claude/068-fix-the-peptide-financial-excel-model
auto-claude/070-audit-peptideos-financial-model-v3-2cf-comprehensi
auto-claude/071-prompt-2-tier-1-bug-fixes-creates-v4-xlsx-baseline
```

Recommend leaving these branches on origin until F1 is unfrozen; revisit at that time. 071 additionally needs a path-fix commit (collapse the doubled `pubmed/.claude/worktrees/financial-model-v3/...` nesting) before any merge consideration.

---

**End of F107 audit.**
