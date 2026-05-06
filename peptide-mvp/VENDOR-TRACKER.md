# Vendor / Non-Code Track — peptide-website MVP

Vendor work is parallel and external — not orchestrator-runnable. This doc tracks lead times, dependencies, and which engineering tasks each vendor item unblocks.

---

## Critical-path vendor items (block engineering tasks)

| ID | Item | Lead time | Cost | Blocks |
|---|---|---|---|---|
| V.1 | Sign DoseSpot contract + sandbox access | 1-2 wk | per contract | F17 |
| V.2 | DoseSpot Surescripts certification (LONG POLE) | 2-4 wk | $5-15K | F17 production-ready |
| V.3 | Per-MD DoseSpot identity proofing (NPI + DEA) | 1-2 wk per batch | varies | F19 production-ready |
| V.5 | 503A pharmacy partner contract (Empower TX default) | 2-4 wk | variable | F20 production-ready |
| V.6 | Confirm pharmacy formulary covers 17 Cat 1 + NAD+ | 1-2 wk | none | V.5; F13/F15 sanity check |
| V.7 | Quest Diagnostics API onboarding | 2-4 wk | $0-10K | F33 production-ready |
| V.17 | Daily.co BAA (HIPAA tier) | 1-2 wk | none direct | F88 (NEW) production-ready |

**Critical path:** V.1 → V.2 (DoseSpot Surescripts cert) is the single longest external blocker. Start this week.

---

## Compliance / legal / business

| ID | Item | Lead time | Cost | Blocks |
|---|---|---|---|---|
| V.4 | Healthcare attorney review (marketplace, prescribing, telehealth, ToS, HIPAA NPP, IRB consent) | 2-4 wk | $15-40K | F57 |
| V.8 | Vendor BAAs (8 vendors: Supabase, OpenAI, Daily.co, Twilio, Postmark, Sentry, Dropbox Sign, DoseSpot) | 4-8 wk parallel | $0 direct (~$1,100/mo recurring) | full HIPAA posture |
| V.9 | Texas state telehealth registration per launch MD | 2-4 wk per MD | $500-2K/MD | per-MD onboarding |
| V.10 | Malpractice insurance (platform entity) | 2 wk | $10-30K/yr | launch |
| V.11 | External HIPAA security assessment / pen-test | 2 wk | $25-60K | launch readiness |
| V.12 | SymCat / SIDER / HPO commercial licensing review | 2-4 wk | $0-50K | KB licensing |
| V.16 | IRB approval for the study + PeptideOS as study platform | 4-12 wk | IRB fees + protocol writing | first-subject enrollment |

---

## Marketing / content / brand

| ID | Item | Lead time | Cost | Blocks |
|---|---|---|---|---|
| V.13 | Initial content authorship (10 conditions + 17 peptides + blog seed) | 4-8 wk | $15-40K | content launch |
| V.14 | Brand / design / logo / illustration assets | 2-4 wk | $5-25K | full UX polish |
| V.15 | Marketing setup (GBP, OG, sitemap, robots, GA4) | 1 wk | $1-5K | F56 |

---

## Action items this week

1. **V.1** — sign DoseSpot contract this week. Without it, V.2 doesn't start, and V.2 is the long pole.
2. **V.17** — request Daily.co BAA. 1-2 wk lead time. Required before F88 (Daily.co room provisioning) can dispatch in W2.
3. **V.16** — IRB submission. 4-12 wk is the widest range here. Start the protocol-writing work in parallel with W0.
4. **V.5 + V.6** — 503A pharmacy outreach. Empower TX as default candidate per locked decision.
5. **V.4** — line up healthcare attorney intake. 2-4 wk to first deliverable.

The 1-week W0 calendar gives breathing room to start V.1, V.4, V.5, V.16, V.17 in parallel with engineering work. By W1 dispatch, contracts should be signed; by W2 dispatch, BAAs and Surescripts cert should be progressing.

---

## Deferred to Phase 2

- TRT vendor stack (DEA per MD per state, EPCS DoseSpot cert, PDMP integration)
- NAD+ IV partner clinic contracts
- Multi-pharmacy + state expansion vendor work
