# PeptideOS MVP Task List — Master

**Date:** 2026-04-30
**Scope:** 503A Texas telehealth + IRB-study first use case (Cat 1 peptides + branded GLP-1s + NAD+ IM)
**Anchor commit (deployed):** `3f5b0ea` on `Layne512/peptide-website` `main`
**Target launch:** 7–9 calendar weeks (gated by DoseSpot Surescripts certification long pole)
**Companion files:**
- `PeptideOS_MVP_Gap_Analysis_2026-04-30.md` — 91-row capability matrix
- `PeptideOS_MVP_Project_Plan_2026-04-30.md` — phased plan with vendor track
- `PeptideOS_MVP_Tasks.csv` — flat task export for PM-tool import
- `PeptideOS_MVP_Plan_rev2.docx` — stakeholder Word doc
- `HIPAA_AUDIT_2026-04-30.md` — pending (F0a output)

---

## Locked Decisions

| Decision | Value |
|---|---|
| Model | 503A telehealth (Rx → 503A → patient) — NOT BYOP |
| First commercial use case | **IRB-approved research study** (REDCap or external eClinical for research-data capture; PeptideOS for intake + consult + Rx) |
| Launch state | Texas only at MVP |
| Catalog scope (peptides) | 17 Cat 1 compounded peptides only |
| Catalog scope (FDA-approved) | Branded GLP-1s (Ozempic, Wegovy, Mounjaro, Zepbound) + NAD+ IM kits |
| Excluded peptides | All Cat 2 restricted (MK-677, GHRP-2/6, Kisspeptin-10, Cathelicidin LL-37) |
| TRT | Deferred to Phase 2 (Schedule III gates: DEA + EPCS + PDMP) |
| NAD+ IV at clinics | Deferred to Phase 2 |
| Compounded GLP-1s | Excluded (FDA crackdown) |
| Patient + MD MFA | Phase 2 with TRT (admin MFA at MVP) |
| Realtime messaging | Phase 2 |
| Build My Protocol generator | v2 (deterministic Convergence Engine) at runtime; v1 (LLM) repurposed as admin-only batch content tool |
| Protocol generation workflow | Scripted LLM batch over (goal × symptom) combos → MD review → hardcode into KB → v2 serves at runtime (NO LLM in production prescribing path) |
| Citation source | Existing `/Users/marshall/Developer/peptide-website/pubmed/` folder |
| MD modification at MVP | Accept/reject canonical + dose-setting per peptide (within IRB-approved ranges) — NOT free-form (free-form deferred to Phase 2) |
| Modification protocol for IRB | Formal modification-request workflow (F77) — MD submits, routes to PI/coordinator approval |
| Patient visibility | Final approved protocol only + "Modified by Dr. X" note; full rationale on HIPAA right-of-access request |
| Pharmacy partner model | Single hardcoded 503A partner at MVP (Empower TX as default candidate); pharmacy handles tracking + cold-chain shipping + delivery comms |
| F78 IRB infrastructure | DEFERRED entirely (γ) — REDCap or external eClinical handles research-data capture |
| F61 pricing reconciliation | Handled in parallel outside this task list |

---

## Headline Counts

| Phase | Feature count | Effort (eng-wks) | Calendar (3-eng team) |
|---|---:|---:|---:|
| F0a (cross-cutting HIPAA audit) | 1 | 0.5 | parallel |
| Phase A — Unstick & Foundation | 16 (4 on hold) | 1.5–2 | 1 wk |
| Phase B — Pharmacy & e-Rx + Catalog | 17 | ~5 | 1.5 wk |
| Phase C — Real Data + Dashboards + Labs + MD Decision Support | 22 | ~10 (parallelizable) | 4 wk |
| Phase D — Security, Infra, Launch Readiness | 21 | 2.5 | 1 wk |
| **TOTAL** | **77 features** | **~20–22 eng-wks** | **~7–9 calendar wks** |

Vendor/non-code track (parallel): 15 items, 4–8 wk lead time, gated by DoseSpot Surescripts cert.

---

## Status Legend

| Symbol | Meaning |
|---|---|
| ✅ Deployed | Built and live at commit `3f5b0ea` |
| ⚠️ Partial | Deployed but broken / regressed / mock data |
| 🟨 Built-unmerged | Code exists in named local branch; needs PR + merge |
| 🟥 Not built | Engineering work required at MVP |
| 🚫 Non-code blocker | Vendor cert, legal, contract, BAA |
| ⛔ Out of scope | Deferred to Phase 2 / 3 |
| 🅷 HOLD | Explicit user hold; not in this MVP cycle |

---

# F0a — Brutal HIPAA + Research-Regulatory Audit

| Attribute | Value |
|---|---|
| Type | ADD (research/audit work, not engineering) |
| Effort | M (2–3 days) |
| Phase | Cross-cutting (week 1, runs in parallel with everything else) |
| Depends on | None |
| Status | 🟥 Not built — currently RUNNING via 7-subagent fan-out in this session |
| Output | `/Users/marshall/Developer/peptide-website/HIPAA_AUDIT_2026-04-30.md` |

**Description:** No-pulled-punches HIPAA Privacy Rule + Security Rule + Breach Notification Rule audit, expanded with Common Rule (45 CFR 46) for IRB study layer, FDA 21 CFR Part 11 for electronic records/signatures, Texas Health & Safety Code Title 2 Subtitle H, and AE reporting requirements.

**Coverage:** PHI flow mapping / per-vendor BAA + PHI flow / per-table RLS coverage matrix / RBAC enforcement / audit-log coverage proof / logging hygiene scan / encryption at rest + in transit / secrets management / session security / data lifecycle (retention + deletion + backup) / disaster recovery / breach notification readiness / workforce sanctions / subcontractor management / IRB consent / 21 CFR Part 11 / FDA peptide compliance.

**Notes:** Findings will fold into F66, F67, F68 + may surface new tasks. F0a runs in parallel with engineering work; output informs Phase B/C/D scope.

---

# PHASE A — Unstick & Foundation (1.5–2 eng-wks, 1 engineer)

## F1 — Fix SensitivityChart.tsx:215 build break

| Attribute | Value |
|---|---|
| Type | FIX |
| Effort | XS (0.5 d) |
| Status | 🅷 **HOLD** (per user — investor-relations on hold) |
| Evidence | `investor-relations/src/components/charts/SensitivityChart.tsx:215` |
| Depends on | None |
| Notes | Production deploys remain frozen at March 31 (`3f5b0ea`) until F1 unfrozen. All Step 5–11 merges land on `main` but DO NOT reach live site. Recharts type mismatch on `YAxis tick` prop. Fix options: cast `props: any` OR exclude `investor-relations/` from main `tsconfig.json` (cleaner). |

## F2 — Stage + commit irreplaceable untracked source

| Attribute | Value |
|---|---|
| Type | FIX |
| Effort | S (0.5 d) |
| Status | 🅷 **HOLD** (per user) |
| Depends on | F4 (.gitignore done) ✅ |
| Notes | Targets: tests, aperant prompts, MVP_PLAN.md, 503B research, `bigcommerce_setup_superprompt.md`, `docs/0[123]-*.md`, `PasswordGate.tsx`, `clinical-vendor-research/`, `financial-model-build-canonical/`. Push to website-WIP branch (NOT main). |

## F3 — Merge auto-claude/060 (codebase audit doc archive)

| Attribute | Value |
|---|---|
| Type | ADD |
| Effort | XS (0.2 d) |
| Status | 🟨 Built-unmerged → ready to merge |
| Branch | `auto-claude/060-comprehensive-peptide-telehealth-codebase-audit` |
| Depends on | None |
| Notes | Doc-only merge. Zero code risk. Audit content already consumed during this session's MVP planning. Merge just archives the file on `main`. |

## F4 — auto-claude/053 (blog slug uniqueness)

| Attribute | Value |
|---|---|
| Type | ADD |
| Effort | S (0.5 d) |
| Status | 🅷 **HOLD** (per user — blog deferred) |
| Branch | `auto-claude/053-add-slug-uniqueness-validation-to-blog-cms` |
| Notes | Blog functionality not on critical path for IRB-study MVP. |

## F5 — auto-claude/054 (blog tag filtering)

| Attribute | Value |
|---|---|
| Type | ADD |
| Effort | S (0.5 d) |
| Status | 🅷 **HOLD** (per user — blog deferred) |
| Branch | `auto-claude/054-implement-interactive-tag-filtering-for-blog-posts` |

## F6 — Merge auto-claude/052 (admin users auth guard)

| Attribute | Value |
|---|---|
| Type | ADD |
| Effort | S (0.5 d) |
| Status | 🟨 Built-unmerged |
| Branch | `auto-claude/052-wire-admin-users-page-with-auth-guard` |
| Depends on | None |
| Notes | LOW risk. Apply 6-step verification (checkout → build → test → manual smoke → PR → merge). |

## F7 — Merge auto-claude/051 (MD labs verify)

| Attribute | Value |
|---|---|
| Type | ADD |
| Effort | S (0.5 d) |
| Status | 🟨 Built-unmerged |
| Branch | `auto-claude/051-verify-md-labs-page-with-real-data-and-edge-cases` |
| Depends on | None |
| Notes | Apply 6-step verification. |

## F8 — Merge auto-claude/036 (MD schedule page with calendar)

| Attribute | Value |
|---|---|
| Type | ADD |
| Effort | M (1.5 d) |
| Status | 🟨 Built-unmerged |
| Branch | `auto-claude/036-wire-md-schedule-page-with-calendar-component` |
| Depends on | F7 |
| Notes | Touches Daily.co integration. Apply 6-step verification with extra care on calendar/booking flow. |

## F9 — Merge auto-claude/048 (MD-message user-ID security FIX)

| Attribute | Value |
|---|---|
| Type | FIX |
| Effort | M (1 d) |
| Status | 🟨 Built-unmerged — **P0 SECURITY** |
| Branch | `auto-claude/048-replace-hardcoded-user-id-in-md-messages` |
| Depends on | None |
| Evidence | `app/api/messaging/messages/route.ts` has hardcoded user ID |
| Notes | **Blocks-launch security item.** Prevents one MD from impersonating message authorship. Apply 6-step verification. |

## F10a — Keep v1 LLM generator → admin-only internal tool

| Attribute | Value |
|---|---|
| Type | FIX |
| Effort | XS (0.25 d) |
| Status | 🟥 Not built |
| Evidence | `app/api/protocol/generate/route.ts` (v1, 185 LOC, currently orphaned) |
| Depends on | None |
| Notes | Add admin-role gate. Used by F10b Brainstormer batch script. NEVER called from patient-facing flow. |

## F10c — Delete 21 dead-code files (NOT v1 generator)

| Attribute | Value |
|---|---|
| Type | FIX |
| Effort | S (0.5 d) |
| Status | 🟥 Not built |
| Depends on | F10a |
| Notes | List of 21 files in `/Users/marshall/Developer/peptide-website/.assessment-intermediate/01-deployed-code.md` (dead-code section). Includes `lib/i18n/translations.ts` (466 LOC), unused marketing SDKs, dead vendor integrations, `.tsx.deprecated` files. |

## F11 — Disclaimer label change

| Attribute | Value |
|---|---|
| Type | FIX |
| Effort | XS (0.1 d) |
| Status | 🟥 Not built |
| Evidence | `components/intake/step-build-protocol.tsx:285` |
| Depends on | F10a |
| Notes | New label: **"Not AI-generated — composed from a curated knowledge base built by licensed physicians, with PubMed citations"** + decision-support clause per F75: "Your physician will review and may modify this recommendation before prescribing." |

## F62 — Remove unused `ai` SDK package (~2.4 MB)

| Attribute | Value |
|---|---|
| Type | FIX |
| Effort | XS (0.25 d) |
| Status | 🟥 Not built |
| Depends on | None |
| Notes | `ai` v6 installed without `@ai-sdk/openai` provider. Codebase uses `openai` package directly. Surfaced in audit §1.2. |

## F63 — Resolve migration 018 naming collision

| Attribute | Value |
|---|---|
| Type | FIX |
| Effort | XS (0.5 d) |
| Status | 🟥 Not built |
| Evidence | `supabase/migrations/018_rls_knowledge_base.sql` vs `018_rls_phi_gaps.sql` |
| Notes | Surfaced in audit §4.10. Risk: out-of-order application. |

## F70 — Audit `postgres` devDep usage; remove if unused

| Attribute | Value |
|---|---|
| Type | FIX |
| Effort | XS (0.25 d) |
| Status | 🟥 Not built |
| Notes | Direct PostgreSQL client in devDeps; no obvious caller. Surfaced in audit §1.2. |

## F71 — Move `@types/web-push` to devDependencies

| Attribute | Value |
|---|---|
| Type | FIX |
| Effort | XS (0.1 d) |
| Status | 🟥 Not built |
| Notes | Currently in `dependencies`; should be devDeps. Surfaced in audit §1.2. |

---

# PHASE B — Pharmacy & e-Rx + Catalog Setup (~5 eng-wks, 1 engineer + parallel vendor track)

## F12 — Schema: add compoundable_503a + prescription_route to peptide_protocols

| Attribute | Value |
|---|---|
| Type | ADD |
| Effort | XS (0.5 d) |
| Status | 🟥 Not built |
| Notes | New BOOLEAN `compoundable_503a` + ENUM `prescription_route` (`compounded_503a` / `branded_retail`). Migration. Required so Build My Protocol filter can route Rx to right pharmacy type. |

## F13 — Formulary seed: 17 Cat 1 peptides

| Attribute | Value |
|---|---|
| Type | ADD |
| Effort | M (5 d) |
| Status | 🟥 Not built |
| Depends on | F12 |
| Notes | BPC-157, TB-500, GHK-Cu, CJC-1295, Ipamorelin, AOD-9604, Tα1, Sermorelin, Tesamorelin, Semax, Selank, Epitalon, MOTS-c, KPV, DSIP, PEG-MGF, Melanotan II. Each entry: dose ranges, indications, contraindications, key warnings, source citations from `pubmed/` folder. SME work — can split with content team. |

## F14 — Formulary seed: 4 GLP-1 brand entries

| Attribute | Value |
|---|---|
| Type | ADD |
| Effort | S (1 d) |
| Status | 🟥 Not built |
| Depends on | F12 |
| Notes | Ozempic, Wegovy, Mounjaro, Zepbound. `prescription_route='branded_retail'` triggers retail-pharmacy routing via Surescripts (NOT through 503A partner). |

## F15 — Formulary seed: NAD+ IM kit

| Attribute | Value |
|---|---|
| Type | ADD |
| Effort | XS (0.5 d) |
| Status | 🟥 Not built |
| Depends on | F12 |
| Notes | `prescription_route='compounded_503a'`. Requires sterile-compounding pharmacy capability. |

## F16 — Update Build My Protocol filter to MVP formulary

| Attribute | Value |
|---|---|
| Type | ADD |
| Effort | S (1 d) |
| Status | 🟥 Not built |
| Depends on | F13, F14, F15 |
| Evidence | `lib/intake/convergence-scorer.ts`, `app/api/intake/generate-protocol/route.ts` |
| Notes | Filter: `WHERE compoundable_503a = TRUE OR prescription_route = 'branded_retail'` AND state-allowed for Texas. |

## F17 — Build DoseSpot API integration

| Attribute | Value |
|---|---|
| Type | ADD |
| Effort | M (8 d) |
| Status | 🟥 Not built — **CRITICAL PATH** |
| Depends on | DoseSpot vendor V.1 (contract + sandbox) |
| Evidence | `lib/prescriptions/dosespot.ts` (currently DEAD shell, throws on missing env vars) |
| Notes | REST API integration: Rx send, refill request, status webhook, drug-interaction check, allergy check, formulary lookup. Long pole = DoseSpot Surescripts certification (V.2, 2–4 wk vendor-side). |

## F18 — Wire prescriptions API route to DoseSpot

| Attribute | Value |
|---|---|
| Type | ADD |
| Effort | S (2 d) |
| Status | 🟥 Not built |
| Evidence | `app/api/prescriptions/route.ts` (currently stub) |
| Depends on | F17 |

## F19 — Per-MD DoseSpot onboarding workflow

| Attribute | Value |
|---|---|
| Type | ADD |
| Effort | S (3 d) |
| Status | 🟥 Not built |
| Depends on | F17 |
| Notes | Admin UI to verify NPI in DoseSpot per MD; trigger identity-proofing process (V.3, 1–2 wk per batch). |

## F20 — Hardcode single pharmacy as default destination

| Attribute | Value |
|---|---|
| Type | ADD |
| Effort | XS (0.25 d) — **REDUCED from 3 d** per single-pharmacy assumption |
| Status | 🟥 Not built |
| Depends on | V.5 (pharmacy contract) |
| Notes | Single pharmacy at MVP (e.g., Empower TX). Config constant in `lib/prescriptions/`. No directory UI, no patient choice. Patient choice / multi-pharmacy = Phase 2. |

## F22 — Refill request workflow + auto-renewal cadence (simplified)

| Attribute | Value |
|---|---|
| Type | ADD |
| Effort | S (2 d) — **SIMPLIFIED from 3 d** (single pharmacy → no routing logic) |
| Status | 🟥 Not built |
| Depends on | F17 |
| Notes | Patient-initiated refill requests; auto-renewal trigger at 7-day-remaining mark. |

## F23 — Patient self-injection training UI

| Attribute | Value |
|---|---|
| Type | ADD |
| Effort | S (5 d) |
| Status | 🟥 Not built |
| Depends on | None |
| Notes | Required for IM peptides + NAD+. Video + step-by-step + sharps disposal info. Platform's job (not pharmacy's). |

## F25 — Platform "Rx submitted to pharmacy" notification

| Attribute | Value |
|---|---|
| Type | ADD |
| Effort | XS (0.5 d) — **REDUCED from 2 d** (pharmacy handles fill/ship/deliver comms) |
| Status | 🟥 Not built |
| Depends on | F17 |
| Notes | Platform-side: only the "Rx submitted" notification via Postmark/Twilio. Pharmacy handles all subsequent status comms (filled, shipped, delivered, exception) directly to patient via their own channels. |

## F10b — Admin Protocol Brainstormer (batch script + review UI)

| Attribute | Value |
|---|---|
| Type | ADD |
| Effort | M (5 d) — 3 d batch script + 2 d review UI |
| Status | 🟥 Not built |
| Depends on | F10a, F73 |
| Notes | Batch script: takes (goal × symptom) combos as input → calls v1 LLM with `pubmed/` folder citation source → outputs structured protocols to MD review queue. Review UI: MD reviews each output, edits, verifies citations, approves → writes to `peptide_protocols` + `goal_protocols` + `condition_protocols` tables. |

## F73 — PubMed citation infrastructure

| Attribute | Value |
|---|---|
| Type | ADD |
| Effort | M (3 d) |
| Status | 🟥 Not built |
| Depends on | F10b |
| Notes | Schema: `peptide_protocols.source_citations TEXT[]` already exists per audit §4. Need to populate from existing `/Users/marshall/Developer/peptide-website/pubmed/` folder. Citation rendering UI in Brainstormer + MD review + patient view. LLM proposes which `pubmed/` entry supports each protocol element; MD verifies during review (per-citation checkbox). |

## F10d — Generate 30–60 canonical scenarios via batch

| Attribute | Value |
|---|---|
| Type | ADD |
| Effort | S (1 d eng + ~2 wk MD curation, parallel) |
| Status | 🟥 Not built |
| Depends on | F10b, F73 |
| Notes | Pick canonical user scenarios (goal × top-symptom combos), run batch through v1 → MD curation queue. Engineering = 1 d; MD curation = ~2 wk SME work in parallel with everything else. |

## F69 — Wire Stripe Identity verification button

| Attribute | Value |
|---|---|
| Type | ADD |
| Effort | S (1 d) |
| Status | 🟥 Not built |
| Evidence | `lib/identity/stripe-identity.ts` exists; `components/identity/verification-button.tsx` is DEAD code |
| Depends on | None |

---

# PHASE C — Real Data + Dashboards + Labs + MD Decision Support (~10 eng-wks, parallelizable to ~4 calendar wks with 2 engineers)

## F26 — Provision Supabase tables: dosing_reminders, wellness_logs, adherence_events

| Attribute | Value |
|---|---|
| Type | ADD |
| Effort | XS (0.5 d) |
| Status | 🟥 Not built |
| Notes | Migration + RLS policies. Required by F27 (un-mock patient dashboard). |

## F27 — Rebuild patient dashboard real-data layer

| Attribute | Value |
|---|---|
| Type | FIX |
| Effort | M (3 d) |
| Status | ⚠️ Partial (currently mock data hotfix from March 24 outage) |
| Evidence | `app/dashboard/patient/page.tsx` |
| Depends on | F26 |
| Notes | Un-mock the regression hotfix from the March 24 incident. Wire to real Supabase queries against the new tables. |

## F28 — Convert 6 mock-data admin pages to real queries

| Attribute | Value |
|---|---|
| Type | FIX |
| Effort | M (4 d) |
| Status | ⚠️ Partial |
| Notes | Per MVP_PLAN.md PART 3: 6 of 13 admin pages still use mock data. List in `app/dashboard/admin/`. |

## F29 — Merge auto-claude/050 (Stripe Connect earnings real)

| Attribute | Value |
|---|---|
| Type | FIX |
| Effort | S (1.5 d) |
| Status | 🟨 Built-unmerged |
| Branch | `auto-claude/050-integrate-stripe-connect-earnings-data-for-physici` |
| Notes | Currently `app/dashboard/md/earnings/page.tsx` ships `mockPayouts`. Merge replaces with real Stripe Connect data. |

## F30 — Merge auto-claude/044 (patient health-history server-side)

| Attribute | Value |
|---|---|
| Type | ADD |
| Effort | S (1 d) |
| Status | 🟨 Built-unmerged |
| Branch | `auto-claude/044-migrate-patient-health-history-to-server-side-fetc` |
| Notes | Rebase against current main first. |

## F31 — Merge auto-claude/041 (DB-driven medication catalog)

| Attribute | Value |
|---|---|
| Type | ADD |
| Effort | M (2 d) |
| Status | 🟨 Built-unmerged |
| Branch | `auto-claude/041-implement-database-driven-medication-catalog-with-` |
| Depends on | F26 |
| Notes | Apply migration. Replaces hardcoded medication catalog with Supabase-driven. |

## F32 — Merge auto-claude/057 (patient lab upload + OCR)

| Attribute | Value |
|---|---|
| Type | ADD |
| Effort | M (2 d) |
| Status | 🟨 Built-unmerged |
| Branch | `auto-claude/057-implement-patient-lab-upload-with-ocr-parsing` |
| Notes | Provision Supabase Storage bucket. |

## F33 — Build Quest Diagnostics API integration

| Attribute | Value |
|---|---|
| Type | ADD |
| Effort | M (10 d) |
| Status | 🟥 Not built |
| Depends on | Quest vendor V.7 |
| Evidence | `app/api/labs/orders/route.ts`, `app/api/labs/results/route.ts` (currently mock) |
| Notes | Real lab integration. Replaces mock. |

## F34 — Wire MD lab review UI to live Quest data

| Attribute | Value |
|---|---|
| Type | ADD |
| Effort | S (3 d) |
| Status | ⚠️ Partial |
| Evidence | `app/dashboard/md/labs/` UI exists, mock data |
| Depends on | F32, F33 |

## F35 — Lab result alerting (out-of-range)

| Attribute | Value |
|---|---|
| Type | ADD |
| Effort | S (2 d) |
| Status | 🟥 Not built |
| Depends on | F33 |
| Notes | Trigger alerts to MD + patient. |

## F36 — Renewal flow (Rx + subscription)

| Attribute | Value |
|---|---|
| Type | ADD |
| Effort | M (5 d) |
| Status | 🟥 Not built |
| Depends on | F22, F72 |
| Notes | Auto-trigger consult booking when refills run low. **Must use most-recent MD-approved version of patient's protocol** (from F72), not canonical baseline. |

## F37 — Patient deletion endpoint (HIPAA right to erasure)

| Attribute | Value |
|---|---|
| Type | ADD |
| Effort | S (2 d) |
| Status | 🟥 Not built |
| Notes | Cascading delete with audit log. Required for HIPAA + state laws (CCPA, GDPR-equivalent). |

## F38 — 7-year retention policy + automated archival

| Attribute | Value |
|---|---|
| Type | ADD |
| Effort | S (3 d) |
| Status | 🟥 Not built |
| Notes | Cold-storage archival job + deletion after retention window. HIPAA: 6 years minimum + 1-year buffer. Texas may require longer for adult patient records. |

## F39 — HIPAA admin MFA enforcement

| Attribute | Value |
|---|---|
| Type | ADD |
| Effort | S (1 d) |
| Status | 🟥 Not built |
| Notes | Admin accounts only at MVP. Provider/patient MFA deferred to Phase 2 with TRT. |

## F40 — Refunds / disputes flow

| Attribute | Value |
|---|---|
| Type | ADD |
| Effort | M (5 d) |
| Status | 🟥 Not built |
| Notes | Required for chargebacks. Wires Stripe Refund API into admin UI. |

## F72 — MD protocol modification UI (REDUCED scope)

| Attribute | Value |
|---|---|
| Type | ADD |
| Effort | M (3 d) — **REDUCED from 5 d** (accept/reject + dose-setting only) |
| Status | 🟥 Not built |
| Depends on | F17, F22 |
| Notes | MVP scope: MD reviews canonical recommendation + patient's last-Rx'd protocol + blank-slate option; sets dose per peptide (within IRB-approved ranges); accepts/rejects canonical. Free-form modification of all fields = Phase 2. **For IRB study:** any deviation triggers F77 modification-request workflow. |

## F77 — IRB modification-request workflow (NEW)

| Attribute | Value |
|---|---|
| Type | ADD |
| Effort | M (3 d) |
| Status | 🟥 Not built |
| Depends on | F72 |
| Notes | MD reviews canonical protocol; if wants to deviate from IRB-approved protocol, submits formal modification-request form (patient ID, requested change, rationale). Routes to admin/PI/IRB-coordinator queue for approval. Approved → applied to patient's protocol + audit-logged + IRB-reportable. Denied → MD must follow canonical or refer out. |

## F74 — Protocol-modification audit trail

| Attribute | Value |
|---|---|
| Type | ADD |
| Effort | S (2 d) |
| Status | 🟥 Not built |
| Depends on | F72, F77 |
| Notes | New table `protocol_modifications`: per-event `protocol_id`, `patient_id`, `md_id`, `consult_id`, `original_protocol_jsonb`, `modified_protocol_jsonb`, `md_rationale_text`, `timestamp`. Hooks into F72 + F77 save flows. Surfaces in admin audit-log viewer + per-patient history. **Required for legal defensibility** — proves MD made the prescribing decision. |

## F75 — Medical-decision-support framing

| Attribute | Value |
|---|---|
| Type | ADD |
| Effort | S (1 d eng + legal review) |
| Status | 🟥 Not built |
| Depends on | F11, F57 |
| Notes | Update copy across patient + MD UIs + ToS + HIPAA Notice of Privacy Practices. Patient-facing: "This is a recommended protocol your physician will review and may modify." MD-facing: "Your judgment overrides system recommendations." |

## F66 — Expand audit-log coverage to every PHI read/write op

| Attribute | Value |
|---|---|
| Type | ADD |
| Effort | M (3 d) |
| Status | 🟥 Not built |
| Depends on | F0a findings |
| Notes | Audit §2.4 finding: audit-log coverage incomplete (only some PHI ops logged). HIPAA Security Rule § 164.312(b) requirement. Per-PHI-table per-operation matrix from F0a will enumerate what's missing. |

## F67 — Standardize soft-delete pattern across PHI tables

| Attribute | Value |
|---|---|
| Type | FIX |
| Effort | S (2 d) |
| Status | 🟥 Not built |
| Depends on | F0a findings |
| Notes | Audit §4.8 finding: soft-delete inconsistency. Risk for HIPAA compliance (premature data loss vs improper retention). |

## F68 — Audit + remediate FK cascade strategies on PHI tables

| Attribute | Value |
|---|---|
| Type | FIX |
| Effort | S (2 d) |
| Status | 🟥 Not built |
| Depends on | F0a findings |
| Notes | Audit §4.5 finding: some FK cascade strategies risky for HIPAA (`ON DELETE CASCADE` on PHI parents could prematurely delete records that must be retained 6+ years). |

## F65 — Audit + replace unnecessary createServiceClient() usage

| Attribute | Value |
|---|---|
| Type | FIX |
| Effort | M (3 d) |
| Status | 🟥 Not built |
| Depends on | F0a findings |
| Notes | Audit §5 finding: several routes use `createServiceClient()` (RLS bypass) where `createClient()` (RLS-respecting) would be safer. Includes the marketing-page service-role-key issue (F43). |

---

# PHASE D — Security, Infra & Launch Readiness (2.5 eng-wks, 1 engineer)

## F41 — Add CSP, HSTS, X-Frame-Options, Referrer-Policy headers

| Attribute | Value |
|---|---|
| Type | FIX |
| Effort | XS (0.5 d) |
| Status | 🟥 Not built |
| Evidence | `next.config.ts` (currently empty 4 LOC stub) |

## F42 — Remove SKIP_AUTH bypass

| Attribute | Value |
|---|---|
| Type | FIX |
| Effort | XS (0.25 d) |
| Status | ⚠️ Partial — production blocker |
| Evidence | `middleware.ts:84-95`, `lib/auth/guards.ts:93` |
| Notes | Critical. Currently guarded by `NODE_ENV === 'development'` but if Vercel ever sets `NODE_ENV=development` for a preview, every auth check passes. |

## F43 — Replace SUPABASE_SERVICE_ROLE_KEY on marketing pages

| Attribute | Value |
|---|---|
| Type | FIX |
| Effort | S (1 d) |
| Status | ⚠️ Partial |
| Evidence | `app/(marketing)/conditions/[slug]/page.tsx:103`, `app/(marketing)/peptides/[slug]/page.tsx:93` |
| Notes | Use anon key + public RLS policy. Bypassing RLS on unauthenticated public pages is a HIPAA-adjacent leak risk. |

## F44 — Rate limiting on public APIs

| Attribute | Value |
|---|---|
| Type | ADD |
| Effort | S (1 d) |
| Status | 🟥 Not built |
| Notes | Upstash + `@upstash/ratelimit`. Protects DoseSpot quota + OpenAI cost-blow risk. All 98 API endpoints currently unlimited. |

## F45 — Zod input validation on all api/* POST/PATCH

| Attribute | Value |
|---|---|
| Type | ADD |
| Effort | M (3 d) |
| Status | ⚠️ Partial |
| Notes | Currently ~5% coverage. |

## F46 — Prompt injection defense on /api/intake/chat

| Attribute | Value |
|---|---|
| Type | FIX |
| Effort | S (1 d) |
| Status | 🟥 Not built |
| Evidence | `app/api/intake/chat/route.ts` |
| Notes | System-prompt sandbox + output filter. Vulnerable to system-prompt extraction + clinical-recommendation manipulation + PHI extraction from session context. |

## F47 — Complete .env.example

| Attribute | Value |
|---|---|
| Type | FIX |
| Effort | XS (0.5 d) |
| Status | ⚠️ Partial |
| Notes | 38 missing env vars per audit §1.5. |

## F48 — Origin allowlist / CORS on APIs

| Attribute | Value |
|---|---|
| Type | ADD |
| Effort | XS (0.25 d) |
| Status | 🟥 Not built |

## F49 — Secret-scanning pre-commit hook

| Attribute | Value |
|---|---|
| Type | ADD |
| Effort | XS (0.25 d) |
| Status | 🟥 Not built |
| Notes | git-secrets or similar. Prevents accidental .env commits. |

## F50 — CI/CD pipeline (.github/workflows/ci.yml)

| Attribute | Value |
|---|---|
| Type | ADD |
| Effort | S (1 d) |
| Status | 🟥 Not built |
| Notes | typecheck + tests + lint + cloc summary on every PR. |

## F51 — Vercel preview deploys per PR

| Attribute | Value |
|---|---|
| Type | ADD |
| Effort | XS (0.25 d) |
| Status | 🟥 Not built |

## F52 — Stand up staging Vercel + Supabase project

| Attribute | Value |
|---|---|
| Type | ADD |
| Effort | S (1 d) |
| Status | 🟥 Not built |

## F53 — Test data fixtures + smoke test script

| Attribute | Value |
|---|---|
| Type | ADD |
| Effort | S (1.5 d) |
| Status | 🟥 Not built |
| Depends on | F52 |
| Notes | Used for staging smoke tests. Synthetic data set + automated end-to-end tests. |

## F54 — Rollback runbook

| Attribute | Value |
|---|---|
| Type | ADD |
| Effort | XS (0.5 d) |
| Status | 🟥 Not built |
| Depends on | F50 |

## F55 — Sentry release tracking + PHI scrubbing

| Attribute | Value |
|---|---|
| Type | FIX |
| Effort | XS (0.5 d) |
| Status | 🟥 Not built |
| Notes | Sentry wired but PHI scrubbing not enforced. Risk: every error report leaks PHI to Sentry. |

## F56 — Sitemap.xml + robots.txt + OG cards

| Attribute | Value |
|---|---|
| Type | ADD |
| Effort | XS (0.25 d) |
| Status | 🟥 Not built |
| Notes | SEO basics. |

## F57 — Privacy policy + ToS + HIPAA NPP pages

| Attribute | Value |
|---|---|
| Type | ADD |
| Effort | S (1 d) |
| Status | 🟥 Not built |
| Depends on | Vendor V.4 (attorney review) |
| Notes | Wire legal-reviewed pages to footer. |

## F58 — Disable / configure SITE_PROTECTION_ENABLED

| Attribute | Value |
|---|---|
| Type | FIX |
| Effort | XS (0.1 d) |
| Status | 🟥 Not built |
| Evidence | `middleware.ts` |
| Notes | HTTP basic auth gate over the whole site. Decide whether to keep for soft launch or disable. |

## F59 — Stripe invoice templates for cash-pay

| Attribute | Value |
|---|---|
| Type | ADD |
| Effort | XS (0.5 d) |
| Status | 🟥 Not built |
| Notes | Configure invoice templates so receipts are branded. |

## F60 — Custom session timeout (30-min idle for PHI access)

| Attribute | Value |
|---|---|
| Type | ADD |
| Effort | XS (0.5 d) |
| Status | 🟥 Not built |
| Evidence | `lib/auth/` (Supabase default longer than 30 min) |

## F64 — Wire Sentry source-map upload via withSentryConfig

| Attribute | Value |
|---|---|
| Type | FIX |
| Effort | XS (0.5 d) |
| Status | 🟥 Not built |
| Notes | Audit §1.2 finding: source maps don't upload to Sentry without `withSentryConfig` wrapper in `next.config.ts`. |

---

# Vendor / Non-Code Track (parallel — runs throughout)

## V.1 — Sign DoseSpot contract + sandbox access

| Attribute | Value |
|---|---|
| Lead time | 1–2 wk |
| Cost | Per contract |
| Notes | Triggers F17. |

## V.2 — DoseSpot Surescripts certification (LONG POLE)

| Attribute | Value |
|---|---|
| Lead time | 2–4 wk |
| Cost | $5–15K cert |
| Depends on | V.1, F17 (Rx flow ready for review) |
| Notes | **Critical-path long pole.** Compliance review of prescribing flow. |

## V.3 — Per-MD DoseSpot identity proofing (NPI + DEA verification)

| Attribute | Value |
|---|---|
| Lead time | 1–2 wk per batch |
| Depends on | V.2 |

## V.4 — Healthcare attorney review

| Attribute | Value |
|---|---|
| Lead time | 2–4 wk |
| Cost | $15–40K |
| Notes | Marketplace structure, prescribing, telehealth, terms/privacy/HIPAA notice, IRB consent forms. Outputs feed F57. |

## V.5 — 503A pharmacy partner contract (Empower TX as default)

| Attribute | Value |
|---|---|
| Lead time | 2–4 wk |
| Cost | Variable |
| Depends on | V.6 |

## V.6 — Confirm pharmacy formulary covers MVP list

| Attribute | Value |
|---|---|
| Lead time | 1–2 wk |
| Notes | Verify single pharmacy compounds all 17 Cat 1 peptides + NAD+. Likely gaps: Melanotan II, KPV, MOTS-c, Selank. |

## V.7 — Quest Diagnostics API onboarding

| Attribute | Value |
|---|---|
| Lead time | 2–4 wk |
| Cost | $0–10K setup |
| Notes | Triggers F33. |

## V.8 — Vendor BAAs (8 vendors)

| Attribute | Value |
|---|---|
| Lead time | 4–8 wk parallel |
| Cost | $0 direct (legal hours; ~$1,100/mo recurring per audit §10) |
| Notes | Supabase, OpenAI, Daily.co, Twilio, Postmark, Sentry, Dropbox Sign, DoseSpot. |

## V.9 — Texas state telehealth registration per launch MD

| Attribute | Value |
|---|---|
| Lead time | 2–4 wk per MD |
| Cost | $500–2K/MD |

## V.10 — Malpractice insurance (platform entity)

| Attribute | Value |
|---|---|
| Lead time | 2 wk |
| Cost | $10–30K/yr |
| Notes | Tech E&O + medical professional liability. |

## V.11 — External HIPAA security assessment / pen-test

| Attribute | Value |
|---|---|
| Lead time | 2 wk |
| Cost | $25–60K |
| Depends on | F60 (Phase D security work done) |
| Notes | Required pre-launch by diligent operators. |

## V.12 — SymCat / SIDER / HPO commercial licensing review

| Attribute | Value |
|---|---|
| Lead time | 2–4 wk |
| Cost | $0–50K |
| Notes | Free for non-commercial; commercial TBD. |

## V.13 — Initial content authorship

| Attribute | Value |
|---|---|
| Lead time | 4–8 wk copywriter |
| Cost | $15–40K |
| Notes | 10 condition + 17 peptide pages + blog seed. Marketing + SEO seed. |

## V.14 — Brand / design / logo / illustration assets

| Attribute | Value |
|---|---|
| Lead time | 2–4 wk |
| Cost | $5–25K |
| Notes | If not already done. |

## V.15 — Marketing setup (GBP, OG, sitemap, robots, GA4)

| Attribute | Value |
|---|---|
| Lead time | 1 wk |
| Cost | $1–5K |
| Notes | Privacy-first analytics. |

## V.16 — IRB approval for the study + PeptideOS as study platform (NEW)

| Attribute | Value |
|---|---|
| Lead time | 4–12 wk |
| Cost | IRB fees + protocol writing |
| Notes | Required before study can enroll first subject. PeptideOS must be approved in the IRB packet as the platform. |

---

# Out of Scope (Phase 2+)

| Item | Reason |
|---|---|
| TRT (Schedule III) | DEA per MD per state + EPCS DoseSpot cert + PDMP integration + extended lab monitoring (~+7 eng-wks, +4–8 wk to launch) |
| Cat 2 restricted peptides (MK-677, GHRP-2/6, Kisspeptin-10, Cathelicidin LL-37) | Per-Rx clinical-justification burden + state-level bans |
| NAD+ IV at partner clinics | New partner type (clinics) + appointment booking + in-person consent capture |
| Patient + MD MFA | Required when TRT is added |
| Realtime messaging (auto-claude/055) | Phase 2 |
| F76 — MD personal saved templates | Phase 2 quality-of-life |
| Free-form MD modification (full F72 scope) | Phase 2 — out of IRB-study constraint |
| F78 — In-platform IRB infrastructure (study coordinator role, AE reporting workflow, screening log, etc.) | Deferred entirely (γ); REDCap or external eClinical handles |
| Renewal + dunning automation polish | Phase 2 |
| Additional states beyond Texas | Phase 2 expansion |
| Compounded GLP-1s | Excluded (FDA crackdown, not deferred) |
| Transcript generation, advanced analytics, AI content recommendations | Phase 3 |

---

# 6-Step Verification Process for Auto-Claude Branch Merges

Applied to F3, F6, F7, F8, F9, F29, F30, F31, F32 (any auto-claude/* branch merge):

1. `git checkout auto-claude/<branch>`
2. `npm install && npm run build` — must pass
3. `npm run test` — must pass
4. `npm run dev` and manually click through the affected screens
5. Open PR, get human review
6. Merge to main, watch staging, then production

---

# Removed from Earlier Plan (superseded)

| # | Reason |
|---|---|
| F10 (original "delete v1 LLM generator") | Superseded by F10a (keep v1 as admin tool for batch content gen) |
| F21 (order tracking UI Rx → ship → deliver) | Pharmacy handles tracking — out of platform scope |
| F24 (cold-chain shipping integration) | Pharmacy handles cold-chain — out of platform scope |
| F61 (pricing reconciliation) | Being handled in parallel outside this plan |
| F76 (MD personal saved templates) | Deferred to Phase 2 |
| F78 (in-platform IRB infrastructure) | Deferred (γ default) — REDCap handles |

---

**End of master task list.**
