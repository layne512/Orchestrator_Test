# Existing Code Map — peptide-website

Generated 2026-05-05 from `486f63b` (current `main`). This is the orientation doc executors read before opening any files. It tells them where things live so they don't reinvent or duplicate.

> **Rule:** if you're about to write a new file in a subsystem listed below, first read the existing files in that area. Most "new feature" specs in the master list are actually "extend existing scaffolding" tasks — F17 DoseSpot, F18 Rx route, F33 lab provider, F69 Stripe Identity all already exist in skeleton form.

---

## Repo top-level

```
peptide-website/
├── app/                     Next.js 14 app router (pages + API routes)
├── components/              React components, grouped by domain
├── lib/                     server-side helpers, clients, utilities
├── supabase/migrations/     SQL migrations (numbered 001-023)
├── scripts/                 one-off ops scripts (seed, backfill, audit)
├── tests/                   Playwright E2E + Vitest unit
├── docs/                    architecture + runbooks
├── public/                  static assets
├── next.config.ts           CSP, headers, Sentry source maps go here
├── middleware.ts            auth gate + role routing
└── package.json
```

---

## Subsystem map

### Auth + sessions

> **VERIFIED against `486f63b` on 2026-05-06** (post-F10a halt). All paths/exports `rg`-confirmed. Earlier draft of this section described files that never existed — corrected after F10a Tier-1 halt. See SPEC_LESSONS L-002.

| Concern | Location | Notes |
|---|---|---|
| Supabase user-scoped client | `lib/supabase/server.ts` → `createClient()` | RLS-respecting; default for user-facing queries |
| Supabase service-role client | `lib/supabase/server.ts` → `createServiceClient()` | RLS bypass; server-only; 169 occurrences in `app/api/` per F65 audit |
| Auth guards (page flow) | `lib/auth/guards.ts` → `requireAuth()`, `requireRole(UserRole)` | **`redirect()` on failure** — NOT for API routes |
| Role check (boolean) | `lib/auth/guards.ts` → `verifyDbRole(userId, allowedRoles[])` | Returns `Promise<boolean>`; safe for API routes |
| Role resolution | `lib/auth/guards.ts` → `resolveDbRole(userId)` | Returns highest active `UserRole` from `user_roles` table |
| Role enum | `lib/auth/roles.ts` → `UserRole` | `Patient \| MD \| NP \| PA \| Pharmacist \| AdminSupport \| AdminManager \| AdminSuper`. **No bare `'admin'`.** |
| Permission helpers | `lib/auth/roles.ts` → `hasPermission`, `hasMinRole`, `isValidRole`, `getRoleLevel` | |
| Middleware route guard | `middleware.ts` | |
| Sign-in/up flows | `app/(auth)/signup/page.tsx`, `app/auth/callback/route.ts` | |

**API-route auth pattern (canonical):** see `CODEBASE-CONVENTIONS.md` → Auth + RBAC → "API-route auth pattern". TL;DR: inline `createClient().auth.getUser()` for 401, then `verifyDbRole(user.id, [...])` for 403. Do NOT use `requireAuth` / `requireRole` in API routes — they redirect.

**Forbidden:** `SKIP_AUTH=true` env shim (F42 root cause — currently lives inside `requireAuth()`). Never re-introduce. Inline API-route auth using `createClient().auth.getUser()` directly is immune to this bypass — extra security side-benefit.

### Subscriptions + billing (Stripe)

| Concern | Location |
|---|---|
| Stripe client | `lib/stripe/client.ts` |
| Checkout session API | `app/api/stripe/checkout/route.ts` |
| Webhook handler | `app/api/stripe/webhook/route.ts` |
| Customer portal | `app/api/stripe/portal/route.ts` |
| Stripe Identity verification | `app/api/stripe/identity/route.ts` (button exists in `components/md/application-form.tsx` — F69 wires them) |
| Subscription tier definitions | `lib/billing/tiers.ts` (placeholders — replaced in W1 with 3 locked tiers) |

### Intake (multi-step wizard)

| Concern | Location |
|---|---|
| Wizard shell | `app/(patient)/intake/page.tsx` |
| Step components | `components/intake/step-*.tsx` (step-build-protocol, step-goals, step-history, step-review, …) |
| Persistence | `lib/intake/session.ts` (writes `intake_sessions` table per migration 019) |
| Conditions catalog | `lib/conditions/catalog.ts` |
| Disclaimer text (F11) | `components/intake/step-build-protocol.tsx` |

### Convergence Engine (protocol generation)

| Concern | Location |
|---|---|
| v2 deterministic engine | `lib/convergence/v2/` — locked path for patient prescribing |
| v1 LLM generator | `app/api/protocol/generate/route.ts` — admin-only after F10a; deprecated for patient flow |
| Goal-protocol mapping | `lib/convergence/goal-protocols.ts` (loads from `goal_protocols` table per migration 021) |
| Protocol output schema | `lib/convergence/types.ts` |

**Locked decision:** v2 deterministic only in patient prescribing path. v1 stays for internal admin tools.

### Prescribing (DoseSpot e-Rx)

| Concern | Location |
|---|---|
| DoseSpot client | `lib/dosespot/client.ts` (skeleton — F17 fleshes out, blocked by V.1+V.2) |
| Send-Rx API route | `app/api/rx/send/route.ts` (skeleton — F18 completes) |
| MD signing UI | `components/md/rx-review.tsx` |
| Audit log | writes to `prescriptions` table (migration 007) |

### Pharmacy fulfillment (503A — Empower TX)

| Concern | Location |
|---|---|
| Pharmacy adapter pattern | `lib/pharmacy/` (single adapter for now — Empower TX) |
| Order placement | `app/api/pharmacy/order/route.ts` (W2 work) |
| Shipment notification webhook | `app/api/pharmacy/webhook/route.ts` (W2) |
| Pharmacy table | `pharmacies` (migration 010) |

### Labs (Quest Diagnostics)

| Concern | Location |
|---|---|
| Lab provider abstraction | `lib/labs/provider.ts` (already exists — F33 wires Quest to it) |
| Lab order API | `app/api/labs/order/route.ts` |
| Lab results webhook | `app/api/labs/webhook/route.ts` |
| Tables | `lab_orders`, `lab_results` (migration 009) |

### Consults (Daily.co — HIPAA tier)

| Concern | Location |
|---|---|
| Daily.co client | NOT YET CREATED — F88 (NEW) builds it |
| Room provisioning API | NOT YET CREATED — F88 |
| Consult scheduling UI | `components/consult/scheduler.tsx` (skeleton) |
| Tables | `consultations` (migration 006) |

**Blocker:** V.17 Daily.co BAA must land before F88 can dispatch.

### Notifications

| Concern | Location |
|---|---|
| Email (Postmark) | `lib/notifications/email.ts` |
| SMS (Twilio) | `lib/notifications/sms.ts` |
| Notification dispatcher | `lib/notifications/dispatch.ts` (writes to `notifications` table per migration 013) |
| Templates | `lib/notifications/templates/` |

### Dashboards

| Patient | `app/(patient)/dashboard/page.tsx` |
| MD | `app/(md)/dashboard/page.tsx`, `app/(md)/queue/page.tsx`, `app/(md)/labs/page.tsx`, `app/(md)/schedule/page.tsx` |
| Admin | `app/(admin)/users/page.tsx` (lacks `requireAuth()` — surfaced by F6 audit, fix in W2) |

---

## Funnel state machine (the patient journey)

The MVP narrative collapses to this state sequence on `profiles.funnel_state`:

```
SIGNED_UP
  → INTAKE_IN_PROGRESS
  → INTAKE_COMPLETE
  → LABS_ORDERED
  → LABS_PENDING
  → LABS_BACK
  → CONSULT_BOOKED
  → CONSULT_COMPLETE
  → RX_SENT
  → SHIPPED
```

Source of truth for transitions: `lib/funnel/state-machine.ts` (W1 work — does not exist yet). Each transition gets an audit row.

---

## Existing migration sequence

```
001 initial_schema                    Tables: profiles, peptides, peptide_protocols
002 fix_cluster_function              pg function fix
003 protocol_citations                Citations table
004 supplement_type                   Supplements typing
005 user_management                   Roles, profile fields
006 health_consultations              consultations table
007 messaging_payments_rx             messages, payments, prescriptions tables
008 rls_policies                      First RLS pass
009 lab_orders                        lab_orders, lab_results
010 pharmacies_and_rx_updates         pharmacies table
011 consent_agreements                consents table
012 e2e_integration_fixes             cleanup
013 health_logs_notifications         health_logs, notifications
014 blog_marketing                    blog tables (deferred per F4/F5)
015 affiliates                        affiliates table
016 md_profile_fields                 MD-specific profile cols
017 fix_roles_seed                    Roles enum fix
018 rls_knowledge_base                **COLLISION — F63 fixes**
018 rls_phi_gaps                      **COLLISION — F63 fixes**
019 intake_session_persistence        intake_sessions
020 wizard_columns                    intake_sessions cols
021 goal_protocol_engine              goal_protocols
022 supplements_table                 supplements
023 fix_symptom_conditions            cleanup
```

**Next safe migration number after F63 resolves:** `024`. W1 schema batch lands as `024_w1_schema_batch.sql`.

---

## Where vendor secrets live

Server-only env (set in Vercel + `.env.local`, never client):
- `SUPABASE_SERVICE_ROLE_KEY`
- `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`
- `DOSESPOT_CLIENT_KEY`, `DOSESPOT_CLINIC_KEY` (per migration 010 lookup pattern)
- `QUEST_API_KEY`
- `DAILY_API_KEY` (W2)
- `POSTMARK_SERVER_TOKEN`
- `TWILIO_AUTH_TOKEN`
- `SENTRY_AUTH_TOKEN` (build-time only)

Client-safe:
- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`
- `NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY`
- `NEXT_PUBLIC_SENTRY_DSN`

---

## Key gotchas (read before writing)

1. **`createServiceClient()` bypasses RLS.** Use only in webhooks, cron jobs, or admin routes that have already authenticated the caller. Never expose to the patient app.
2. **`profiles.id === auth.users.id`** — never invent your own user ID join. F9 burned us once.
3. **Migration 018 is a duplicate-numbered collision.** Don't write a 24th migration assuming sequential numbering until F63 resolves it.
4. **The MD application form already has a Stripe Identity button** in `components/md/application-form.tsx`, but the click handler is a no-op. F69 just wires it.
5. **`app/api/protocol/generate/route.ts` is the v1 LLM generator and currently has no auth gate.** F10a closes that hole. Until then, treat as patient-data-leak risk.
6. **Sentry is installed but source-map upload is broken.** F64 fixes — symbolicated stack traces blocked until then.
7. **`next.config.ts` is the chokepoint** for security headers (F41) and Sentry (F64). Bundle the two PRs (F41+F64) to avoid a merge collision.
