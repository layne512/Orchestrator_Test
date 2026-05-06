---
task_id: F41-F64-bundle
title: "Bundle: security headers (F41) + Sentry source-map upload (F64)"
wave: W0
tier: 2
depends_on: [F104]
blocks: []
files_owned:
  - next.config.ts
  - sentry.client.config.ts
  - sentry.server.config.ts
  - sentry.edge.config.ts
  - .sentryclirc
  - package.json
must_read_before_writing:
  - peptide-mvp/CODEBASE-CONVENTIONS.md
  - peptide-mvp/EXISTING-CODE-MAP.md
  - next.config.ts
  - sentry.client.config.ts
  - sentry.server.config.ts
schema_dependencies: []
vendor_blocks: []
estimated_effort: 1d
---

## User capability delivered

1. Every HTTP response includes correct security headers (CSP, HSTS, X-Frame-Options, X-Content-Type-Options, Referrer-Policy, Permissions-Policy).
2. Sentry production stack traces are symbolicated — engineers see real source lines + filenames in alerts.

## Why bundled

Both tasks edit `next.config.ts`. Dispatched in parallel they conflict every time. Bundling avoids the merge race.

## Coordination warning

Touches `package.json` (to add `@sentry/cli` if missing). **Must dispatch AFTER `W0-package-json-cleanup`** to avoid conflict.

## Technical scope

### F41 — security headers

In `next.config.ts`, add to the config object:

```ts
async headers() {
  return [
    {
      source: '/(.*)',
      headers: [
        {
          key: 'Strict-Transport-Security',
          value: 'max-age=63072000; includeSubDomains; preload',
        },
        {
          key: 'X-Content-Type-Options',
          value: 'nosniff',
        },
        {
          key: 'X-Frame-Options',
          value: 'DENY',
        },
        {
          key: 'Referrer-Policy',
          value: 'strict-origin-when-cross-origin',
        },
        {
          key: 'Permissions-Policy',
          value: 'camera=(self), microphone=(self), geolocation=()',
        },
        {
          key: 'Content-Security-Policy',
          value: [
            "default-src 'self'",
            "script-src 'self' 'unsafe-inline' https://js.stripe.com https://www.daily.co https://*.daily.co https://browser.sentry-cdn.com",
            "style-src 'self' 'unsafe-inline'",
            "img-src 'self' data: blob: https:",
            "connect-src 'self' https://*.supabase.co wss://*.supabase.co https://api.stripe.com https://*.daily.co wss://*.daily.co https://*.sentry.io",
            "frame-src 'self' https://js.stripe.com https://*.daily.co",
            "font-src 'self' data:",
            "object-src 'none'",
            "base-uri 'self'",
            "form-action 'self' https://checkout.stripe.com",
          ].join('; '),
        },
      ],
    },
  ];
},
```

`camera`/`mic` allowed because Daily.co consult requires them. Stripe + Daily.co + Sentry CSP allowlists match the vendor list in `CODEBASE-CONVENTIONS.md`.

### F64 — Sentry source-map upload

1. Confirm `@sentry/nextjs` is installed (it is, per master list).
2. Install `@sentry/cli` as devDep if missing: `npm install --save-dev @sentry/cli`.
3. Wrap the Next config export with `withSentryConfig`:
   ```ts
   import { withSentryConfig } from '@sentry/nextjs';

   const nextConfig = { /* ... existing ... + headers() above */ };

   export default withSentryConfig(nextConfig, {
     org: process.env.SENTRY_ORG,
     project: process.env.SENTRY_PROJECT,
     authToken: process.env.SENTRY_AUTH_TOKEN, // build-time only
     silent: !process.env.CI,
     widenClientFileUpload: true,
     hideSourceMaps: true,
     disableLogger: true,
   });
   ```
4. Document required env vars in `.env.example`: `SENTRY_ORG`, `SENTRY_PROJECT`, `SENTRY_AUTH_TOKEN` (build-time, in Vercel project settings).
5. Verify `sentry.client.config.ts` and `sentry.server.config.ts` exist; create from defaults if missing.

## Verifiable acceptance criteria

```bash
# (a) headers configured
grep -q "Content-Security-Policy" next.config.ts
grep -q "Strict-Transport-Security" next.config.ts
grep -q "X-Frame-Options" next.config.ts

# (b) withSentryConfig wraps export
grep -q "withSentryConfig" next.config.ts

# (c) sentry CLI available
npx sentry-cli --version

# (d) build passes (this also exercises sentry source-map upload locally — should warn-not-fail without auth token)
SENTRY_AUTH_TOKEN= npm run build

# (e) start prod server, hit homepage, assert headers present
npm run start &
PID=$!
sleep 5
HEADERS=$(curl -sI http://localhost:3000/)
kill $PID
echo "$HEADERS" | grep -qi "strict-transport-security:"
echo "$HEADERS" | grep -qi "x-frame-options: deny"
echo "$HEADERS" | grep -qi "x-content-type-options: nosniff"
echo "$HEADERS" | grep -qi "content-security-policy:"
echo "$HEADERS" | grep -qi "referrer-policy:"
echo "$HEADERS" | grep -qi "permissions-policy:"

# (f) typecheck passes
npm run typecheck
```

## Pivot triggers

- If CSP breaks any existing page in dev (Stripe Checkout, Daily.co iframe, Supabase realtime): adjust the allowlist for the specific origin and re-test. Do NOT add `'unsafe-eval'` or wildcard `*`.
- If `withSentryConfig` is already in `next.config.ts`: F64 was partially done — verify completeness against the option list above, do not duplicate the wrapper.
- If `sentry.*.config.ts` files contain hardcoded DSN: move to env var (`NEXT_PUBLIC_SENTRY_DSN`).

## Notes for executor

Test the CSP empirically: open the prod build locally, walk through signup → intake → consult booking, watch the browser console for CSP violation warnings. Each warning = a missing allowlist entry. Iterate until clean.

This is the W0 task most likely to need a re-spin; the CSP allowlist often needs one or two adjustments after seeing real browser behavior.
