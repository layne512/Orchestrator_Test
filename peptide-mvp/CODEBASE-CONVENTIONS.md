# peptide-website Codebase Conventions

**Authority:** Every executor subagent MUST read this doc before writing any code in `peptide-website`. This compiles patterns from existing code, audit findings (F0a/F66/F67/F68 will refine), and locked decisions from the master task list.

---

## Stack

- Next.js 14+ (app router)
- TypeScript strict mode
- Supabase (Postgres + Auth + Storage + RLS)
- Tailwind CSS
- Vercel (hosting + CDN)
- Stripe (subscriptions + Connect for MD payouts + Identity)
- DoseSpot (e-prescribing, Surescripts cert pending)
- Quest Diagnostics (lab orders/results, vendor onboarding pending)
- Daily.co HIPAA tier (consults, BAA pending V.17)
- Postmark (transactional email)
- Twilio (SMS)
- Sentry (error monitoring with PHI scrubbing)
- OpenAI (intake assistant + admin Brainstormer batch tool — NEVER in patient-facing prescribing path)

Forbidden:
- `ai` SDK package (F62 — uninstall in W0; codebase uses `openai` directly)
- `postgres` direct client (F70 — devDep only, will be removed)
- Compounded GLP-1s (FDA crackdown)
- TRT (Phase 2 only)

---

## Data access patterns

### `createClient()` (RLS-respecting) — DEFAULT

Use this for any user-facing or per-user-scoped query. RLS policies enforce ownership, role-based access, audit-log triggers fire, and the audit trail captures the actor.

```ts
import { createClient } from '@/lib/supabase/server'

const supabase = await createClient()
const { data, error } = await supabase.from('lab_results').select('*').eq('patient_id', userId)
```

### `createServiceClient()` (RLS bypass) — JUSTIFIED ONLY

Per F65 audit finding: 169 occurrences of `createServiceClient` in `app/api/`. Many are appropriate (cron jobs, webhooks, system operations); some are not. Use ONLY when:
- Operation is server-side system action (cron, webhook receiver, scheduled job)
- Operation legitimately spans multiple users (admin view, support tooling)
- RLS policy doesn't cover the legitimate access pattern (rare; usually means the policy is wrong)

Every `createServiceClient()` use MUST:
1. Have an inline comment explaining why RLS bypass is needed
2. Write to `audit_logs` capturing the operation, actor (system or admin user), and affected rows
3. Be flagged in PR description for review

**FORBIDDEN:** `createServiceClient()` on public-facing pages (F43 surfaced this on `app/(marketing)/conditions/[slug]/page.tsx` and `app/(marketing)/peptides/[slug]/page.tsx` — fixed in W2).

---

## Auth + RBAC

> **VERIFIED against `486f63b` on 2026-05-06** (post-F10a halt). All exports below were `rg`-confirmed.

### Auth surface

- Supabase auth with email/password
- Session validation via `middleware.ts` and `lib/auth/guards.ts`
- `lib/auth/roles.ts` exports the `UserRole` enum + permission helpers:
  ```ts
  export enum UserRole {
    Patient = 'patient',
    MD = 'md',
    NP = 'np',
    PA = 'pa',
    Pharmacist = 'pharmacist',
    AdminSupport = 'admin_support',
    AdminManager = 'admin_manager',
    AdminSuper = 'admin_super',
  }
  ```
  No bare `'admin'` member. Admin checks must use one of `AdminSupport | AdminManager | AdminSuper`.

### `lib/auth/guards.ts` — page-flow helpers (NOT for API routes)

```ts
export async function requireAuth(): Promise<AuthUser>           // no args; redirects /auth/sign-in if unauthed
export async function requireRole(minimumRole: UserRole): Promise<AuthUser>  // redirects /unauthorized if below
export async function verifyDbRole(userId: string, allowedRoles: string[]): Promise<boolean>
export async function resolveDbRole(userId: string): Promise<UserRole>
```

These call `redirect()` from `next/navigation` on failure. In an API-route context that surfaces as a 307 redirect, NOT a 401/403 JSON response. **Do NOT use `requireAuth` / `requireRole` in API routes.**

### API-route auth pattern (canonical)

```ts
import { createClient } from '@/lib/supabase/server'
import { verifyDbRole } from '@/lib/auth/guards'

export async function POST(req: NextRequest) {
  const authClient = await createClient()
  const { data: { user }, error: authError } = await authClient.auth.getUser()
  if (authError || !user) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  // Role gate (when needed)
  const isAdmin = await verifyDbRole(user.id, ['admin_super', 'admin_manager', 'admin_support'])
  if (!isAdmin) {
    return NextResponse.json({ error: 'Forbidden' }, { status: 403 })
  }

  // ... handler body
}
```

This is the verified-correct pattern for any API route that needs auth + role gating. F10a Tier-1 halt was caused by a spec that referenced a non-existent helper file structure (`lib/auth/require-auth.ts`, `requireRole(session, 'admin')`) — those NEVER existed; the spec was authored against inferred conventions instead of grep results. See SPEC_LESSONS L-002.

### Forbidden patterns

- **`SKIP_AUTH` bypass.** F42 — `requireAuth()` in `lib/auth/guards.ts` has a `process.env.SKIP_AUTH === 'true'` short-circuit returning a mock user. Slated for removal in W0/W3. Do NOT add new ones. **Inline API-route auth using `createClient().auth.getUser()` is NOT subject to this bypass — additional security side-benefit of the inline pattern above.**
- **Hardcoded user IDs.** F9 surfaced this in `app/api/messaging/messages/route.ts`; sister bug F47 fixed via PR #31. Always use `user.id` from the verified-real Supabase session — never trust client-provided user IDs.
- **Anonymous DB queries on PHI tables.** Every PHI table read/write must run as the authenticated user (RLS enforces this).

---

## API route patterns

### File location

- Patient endpoints: `app/api/<domain>/<action>/route.ts`
- Admin endpoints: `app/api/admin/<domain>/<action>/route.ts`
- MD endpoints: `app/api/md/<domain>/<action>/route.ts`
- System/webhook: `app/api/webhooks/<provider>/route.ts`

### Required boilerplate for every PHI-touching route

```ts
import { requireAuth } from '@/lib/auth/guards'
import { logPHIAccessFromRequest } from '@/lib/audit/phi-access'
import { z } from 'zod'

const InputSchema = z.object({
  // ...
})

export async function POST(req: Request) {
  const session = await requireAuth()
  const body = InputSchema.parse(await req.json())  // throws 400 on validation fail
  const supabase = await createClient()
  
  // ... actual work ...
  
  await logPHIAccessFromRequest(req, {
    actor_id: session.user.id,
    action: 'create_lab_order',
    resource_type: 'lab_orders',
    resource_id: result.id,
  })
  
  return Response.json(result)
}
```

### F45 — Zod input validation

Currently ~5% coverage. Every NEW POST/PATCH route MUST include a Zod schema. Existing routes get audited + back-filled in W3.

### F66 — Audit-log coverage

Currently 8 of ~70 routes call `logPHIAccessFromRequest` (~11%). Every NEW PHI route must log; existing routes get audited + back-filled in W2.

### F46 — Prompt injection defense (intake/chat)

`app/api/intake/chat/route.ts` is high-risk. New AI-touching routes must:
1. Validate input via Zod
2. Use system-prompt sandbox (prefix/suffix tokens that the user can't replicate)
3. Output post-filter for PHI/system-prompt leakage
4. Never inject session_context unsanitized

---

## Migrations

### Wave-batch pattern (NEW for orchestrator era)

Per the discussion that produced this orchestrator setup: **feature tasks do NOT write migrations**. Each wave has ONE schema-batch task that aggregates all schema changes for the wave's features. This eliminates the F63-class collision permanently.

Process:
1. Wave's first task is the schema batch (e.g., F12 = W1 schema batch, F26 = W2 schema batch)
2. Each feature task in the wave declares its `schema_dependencies` in its spec frontmatter
3. The schema-batch task reads all wave specs and writes ONE migration file
4. After the schema batch merges, `supabase gen types typescript` regenerates `types/database.types.ts`
5. Feature tasks dispatch only AFTER the schema batch is in `STATE/completed.json`

If a feature task discovers it needs a schema change late, file as a follow-up migration in the SAME wave (don't sneak it into a feature commit).

### F63 collision (W0 fix)

`supabase/migrations/018_rls_knowledge_base.sql` and `018_rls_phi_gaps.sql` both exist. Verify which applied first on prod (`SELECT * FROM supabase_migrations.schema_migrations ORDER BY version`), then renumber the other. Recommended: keep `018_rls_knowledge_base.sql`, rename `018_rls_phi_gaps.sql` → `024_rls_phi_gaps.sql` (highest free slot after 023).

### Existing migration sequence (24 files at `486f63b`)

| # | File | Domain |
|---|---|---|
| 001 | initial_schema.sql | KB: symptoms, conditions, peptide_protocols (318 lines) |
| 002 | fix_cluster_function.sql | function fix |
| 003 | protocol_citations.sql | adds `peptide_protocols.source_citations TEXT[]` |
| 004 | supplement_type.sql | adds `peptide_protocols.type` |
| 005 | user_management.sql | profiles, roles, user_roles, md_credentials, md_state_licenses |
| 006 | health_consultations.sql | health_history, consultations |
| 007 | messaging_payments_rx.sql | conversations, conversation_participants, messages, prescriptions |
| 008 | rls_policies.sql | RLS for users, MD creds |
| 009 | lab_orders.sql | lab_orders, lab_results |
| 010 | pharmacies_and_rx_updates.sql | pharmacies + prescriptions.pharmacy_id |
| 011 | consent_agreements.sql | consent_documents, patient_consents |
| 012 | e2e_integration_fixes.sql | column adds to user_intake_sessions, protocols, consultations |
| 013 | health_logs_notifications.sql | patient_health_logs, dosing_reminders |
| 014 | blog_marketing.sql | blog_posts, marketing_campaigns (HOLD) |
| 015 | affiliates.sql | affiliates, affiliate_referrals |
| 016 | md_profile_fields.sql | column adds to md_credentials |
| 017 | fix_roles_seed.sql | roles seed fix |
| 018a | rls_knowledge_base.sql | RLS for KB (CONFLICT — to be resolved in W0/F63) |
| 018b | rls_phi_gaps.sql | RLS for PHI gaps (CONFLICT — to be resolved in W0/F63) |
| 019 | intake_session_persistence.sql | column adds |
| 020 | wizard_columns.sql | column adds |
| 021 | goal_protocol_engine.sql | goal_protocols, protocol_supplements, protocol_phases (8907 lines, mostly seed data) |
| 022 | supplements_table.sql | supplements, supplement_brands |
| 023 | fix_symptom_conditions.sql | symptom-conditions fix |

---

## Component patterns

### File naming

- Pages: `app/<route>/page.tsx`
- Layouts: `app/<route>/layout.tsx` + optionally `layout-client.tsx` for client-only sections
- Components: `components/<domain>/<component-name>.tsx` (kebab-case)
- Hooks: `hooks/use-<thing>.ts`
- Utilities: `lib/<domain>/<thing>.ts`

### Server vs. client components

Default to server components. Mark `"use client"` only when:
- Browser-only API (window, localStorage, etc.)
- React hooks (useState, useEffect, useRouter)
- Event handlers
- Third-party client-only library

PHI fetching MUST be server-side. Never pass PHI to a client component as a prop without scrubbing.

---

## Build gates (executor must verify before claiming done)

Every executor's acceptance criteria MUST include all of:

```bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

npm install
npm run typecheck    # MUST pass — currently failing on F1 hold (SensitivityChart.tsx); ignore that, your task should not introduce new failures
npm run build        # MUST pass for non-investor-relations changes
npm run test         # MUST pass — 360 tests at last count
```

The F1 hold means `npm run build` fails on `investor-relations/src/components/charts/SensitivityChart.tsx:215` regardless of your work. Acceptance check should grep build output for "investor-relations" and fail only if NEW errors appear outside that scope.

---

## Forbidden additions (until specific Fix tasks land)

- New `SKIP_AUTH` bypasses (F42)
- New hardcoded user IDs (F9)
- New `createServiceClient()` on marketing pages (F43)
- New API routes without Zod input validation (F45)
- New PHI routes without `logPHIAccessFromRequest` (F66)
- New `ON DELETE CASCADE` on PHI tables (F67/F68 — use `ON DELETE RESTRICT` + soft-delete pattern instead)
- New tables without RLS policies (F0a class)
- Recording flags on Daily.co rooms (no-recording locked decision)
- LLM in patient-facing prescribing path (admin batch tool only — F10a)
- Cat 2 restricted peptides (MK-677, GHRP-2/6, Kisspeptin-10, Cathelicidin LL-37)
- Compounded GLP-1s (excluded entirely)

---

## Notification preferences

Per locked decision (F99): patients can opt in/out of email/SMS for each notification type. New notification triggers MUST check `notification_preferences` (table to be added in W2 schema batch) before sending. Defaults: email enabled, SMS opt-in only.

---

## Locked decisions affecting code

| Decision | Implication |
|---|---|
| Texas only at MVP | state-licensure check on every MD action; no multi-state routing logic |
| 17 Cat 1 peptides + 4 GLP-1 brands + NAD+ IM | hardcoded formulary list in W1 schema seed |
| Single pharmacy at MVP (Empower TX default) | no multi-pharmacy routing UI; config constant in `lib/prescriptions/` |
| v2 deterministic Convergence Engine at runtime | NO LLM calls in patient prescribing path; LLM only for admin Brainstormer batch (F10a/b) |
| MD modification = accept/reject + dose-setting | NO free-form modification UI at MVP (Phase 2); enforce dose ranges from peptide spec |
| IRB study constraint | F77 modification-request workflow REQUIRED for any deviation from approved protocol |
| Subscription: 3 tiers, prices/vials TBD | schema with placeholder values + `fill_before_launch` flag |
| Lab ordering: post-intake, pre-MD-consult | funnel state machine: SIGNED_UP → INTAKE_IN_PROGRESS → INTAKE_COMPLETE → LABS_ORDERED → LABS_PENDING → LABS_BACK → CONSULT_BOOKED → CONSULT_COMPLETE → RX_SENT → SHIPPED |
| Daily.co recording: no | `enable_recording: false` on every room; no recording storage workflow |
| Patient + MD MFA: deferred to Phase 2 | admin MFA at MVP only (F39) |
| Realtime messaging: Phase 2 | message polling acceptable at MVP |
| Patient sees: "Modified by Dr. X" only | full rationale via HIPAA right-of-access only |

---

## Vendor BAAs (V.8)

Production deploys MUST not connect to a vendor without a signed BAA. Each vendor's client should check a `<VENDOR>_BAA_SIGNED=true` env flag at startup and refuse to operate if false. Pattern (example for Daily.co):

```ts
if (process.env.NODE_ENV === 'production' && process.env.DAILY_BAA_SIGNED !== 'true') {
  throw new Error('Daily.co BAA not signed; refusing to create rooms in production')
}
```

Status (as of `486f63b`):
- Supabase: signed
- OpenAI: signed
- Postmark: signed
- Sentry: signed
- Daily.co: PENDING (V.17)
- Twilio: PENDING
- Dropbox Sign: PENDING
- DoseSpot: PENDING (V.1 contract)

---

## Where to look for examples

| Pattern | Reference file |
|---|---|
| RLS-respecting query | `app/api/users/health-history/route.ts` |
| Service-role with audit | `app/api/labs/orders/route.ts` (lines around `getLabProvider`) |
| Zod validation | `app/api/ai/soap-notes/route.ts` (`SOAPNoteSchema`) |
| `requireAuth` with role | `app/api/admin/users/route.ts` |
| PHI access logging | `lib/audit/phi-access.ts` + any of the 8 currently-instrumented routes |
| Stripe webhook | `lib/stripe/webhooks.ts` |
| Provider abstraction | `lib/labs/providers/` (Quest abstraction is in here) |
| Migration with RLS | `supabase/migrations/008_rls_policies.sql` |
| Type-safe Supabase | `types/database.types.ts` (regenerate after each schema-batch wave) |

---

## Audit findings to honor (from F0a class — refined in W2)

These will be enforced by `preflight.sh` checks added in F104:

- Every PHI table has RLS enabled
- Every PHI route logs to audit_logs
- No `createServiceClient()` outside `app/api/` or `lib/`
- No env vars in client-side code
- No PHI in URL query strings
- No PHI in Sentry breadcrumbs (server-side scrubbing already in `sentry.server.config.ts`; client-side scrubbing pending)

---

## When in doubt

1. Read 2-3 similar existing files first (per `must_read_before_writing` in your task spec)
2. If pattern is ambiguous, escalate via STUCK PROTOCOL — don't guess
3. Never invent new patterns — match existing ones exactly until a refactor task is approved
