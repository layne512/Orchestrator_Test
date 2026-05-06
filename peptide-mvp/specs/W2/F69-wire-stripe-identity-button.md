---
task_id: F69
title: "Wire Stripe Identity verification into MD application form"
wave: W2
tier: 2
depends_on: [F104, F69-pre-A, F69-pre-B]
blocks: []
files_owned:
  - components/md/application-form.tsx
  - app/api/stripe/identity/route.ts   # CREATED by F69-pre-A, owned by this task only after creation
must_read_before_writing:
  - peptide-mvp/CODEBASE-CONVENTIONS.md
  - peptide-mvp/EXISTING-CODE-MAP.md
  - components/md/application-form.tsx
  - app/api/stripe/identity/route.ts
  - app/api/identity/verify/route.ts   # the existing identity route — must understand before duplicating
schema_dependencies: []
vendor_blocks: []
estimated_effort: 0.25d
spec_revision: 3
spec_revision_notes: |
  v1 authored against inferred conventions; deferred from W0 cycle 3 (2026-05-06).
  F69 STUCK at 486f63b: app/api/stripe/identity/route.ts doesn't exist
  (entire app/api/stripe/ subtree absent); components/md/application-form.tsx
  has zero "Verify identity" button copy. SPEC_LESSONS L-002 trigger fired
  exactly as the spec's own "unverified — grep before dispatch" warning predicted.

  v3 moves F69 to W2 alongside V.3 (per-MD DoseSpot identity proofing) where
  the broader MD onboarding flow is being built. Two prerequisite tasks
  (F69-pre-A: build the Stripe Identity API route; F69-pre-B: add the button
  to application-form.tsx) must land first. F69 itself remains the wire-up.

  Open question for spec author at W2 entry: is Stripe Identity even the
  chosen MD identity-verification vendor, or do we use the existing
  app/api/identity/verify route (vendor unknown — needs audit)? If the
  existing route is the canonical path, F69 is retracted entirely and a
  different task wires the existing route's button hook.
---

## Status: deferred from W0 to W2

This spec was authored before the MD onboarding flow existed in code. At `486f63b` neither the Stripe Identity API route nor the form button exists, so there are no "wires" to wire up. Re-spec at W2 entry, after V.3 vendor work has clarified which identity-verification vendor MDs use and the broader MD onboarding flow has been built (likely via a sibling task in W2).

## (Below: original W0 spec content kept for forensic reference. Do NOT execute as written.)

## User capability delivered

MD applicants click "Verify identity" and are taken into Stripe Identity's hosted flow. Verification result writes back to their profile.

## Background

Per `EXISTING-CODE-MAP.md`, both pieces are claimed to exist:
- `components/md/application-form.tsx` renders a "Verify identity" button — currently a no-op.
- `app/api/stripe/identity/route.ts` creates a Stripe Identity verification session and returns the redirect URL.

> **⚠ unverified — grep before dispatch (per SPEC_LESSONS L-002):**
> Both file paths above were authored from inferred conventions, not grep-verified against `486f63b`. Before dispatch, the executor MUST run:
> ```bash
> ls components/md/application-form.tsx app/api/stripe/identity/route.ts
> rg "Verify identity|Stripe Identity|stripe.identity" components app
> ```
> If either file is missing or the button text differs, fire pivot trigger and halt before any edit. Do NOT invent the API route or the button — F69 is "wire-up only", and if the wires don't exist the task is mis-scoped.

This task is purely the wire-up — no new infra, no new dependencies.

## Technical scope

1. In `components/md/application-form.tsx`, find the "Verify identity" button.
2. Replace its no-op `onClick` with a handler that:
   - POSTs to `/api/stripe/identity` (no body required — route reads `userId` from session).
   - Receives `{ url: string }` JSON response.
   - `window.location.href = url;` to redirect.
   - On error: render an inline error state (use the form's existing error pattern — read what other handlers in the file do, do not invent a new pattern).
3. Add a loading state (button disabled + label change to "Redirecting…") while the POST is in flight.
4. No changes to the Stripe Identity API route. No new env vars. No new components.

## Verifiable acceptance criteria

```bash
# (a) onClick now does something
! grep -E "onClick=\{\(\) => \{\}\}|onClick=\{noop\}" components/md/application-form.tsx

# (b) POST to /api/stripe/identity present in the file
grep -q "/api/stripe/identity" components/md/application-form.tsx

# (c) loading state handled
grep -qE "Redirecting|isVerifying|isSubmitting" components/md/application-form.tsx

# (d) build + typecheck pass
npm run build
npm run typecheck

# (e) no new direct dependency on stripe SDK in the component (it should call the API route, not import stripe)
! grep -qE "from ['\"]stripe['\"]|@stripe/stripe-js" components/md/application-form.tsx
```

## Pivot triggers

- If the Stripe Identity API route is missing or returns a non-`{url}` shape: halt — F69 expanded scope, escalate to orchestrator.
- If the button does not exist (was removed in a recent commit): halt and report — spec is stale.

## Notes for executor

A 30-minute task. The whole change is one button's click handler.
