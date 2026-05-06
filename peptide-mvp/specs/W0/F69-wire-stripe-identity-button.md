---
task_id: F69
title: "Wire existing Stripe Identity button into MD application form"
wave: W0
tier: 2
depends_on: [F104]
blocks: []
files_owned:
  - components/md/application-form.tsx
must_read_before_writing:
  - peptide-mvp/CODEBASE-CONVENTIONS.md
  - peptide-mvp/EXISTING-CODE-MAP.md
  - components/md/application-form.tsx
  - app/api/stripe/identity/route.ts
schema_dependencies: []
vendor_blocks: []
estimated_effort: 0.25d
---

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
