---
task_id: F10a
title: "Add admin auth gate to v1 LLM protocol generator"
wave: W0
tier: 1
depends_on: [F104]
blocks: [F10c]
files_owned:
  - app/api/protocol/generate/route.ts
must_read_before_writing:
  - peptide-mvp/CODEBASE-CONVENTIONS.md
  - peptide-mvp/EXISTING-CODE-MAP.md
  - app/api/protocol/generate/route.ts
  - lib/auth/require-auth.ts
  - lib/auth/roles.ts
schema_dependencies: []
vendor_blocks: []
estimated_effort: 0.25d
---

## User capability delivered

Closes a PHI-leak / unauthenticated-call vector. The v1 LLM generator route currently accepts any caller. After this task, only admin-role callers can hit it.

## Background

Per `EXISTING-CODE-MAP.md`, `app/api/protocol/generate/route.ts` is the v1 (LLM-based) generator. The locked decision is that v2 deterministic Convergence Engine is the patient prescribing path; v1 is retained only for internal admin tooling. Until F10a lands, an unauthenticated caller can invoke the LLM with arbitrary input — both a cost vector and a possible patient-data exposure if the prompt template includes any tenant data.

## Technical scope

1. At the top of the route handler (`POST` and any other exported HTTP method), add:
   ```ts
   import { requireAuth } from '@/lib/auth/require-auth';
   import { requireRole } from '@/lib/auth/roles';

   const session = await requireAuth();
   await requireRole(session, 'admin');
   ```
2. If `requireAuth` throws, propagate as 401. If `requireRole` throws, propagate as 403. Both helpers already do this — do not catch.
3. No change to the LLM call itself, response shape, or error handling below the gate.
4. Add zero new dependencies.

## Verifiable acceptance criteria

```bash
# (a) imports present
grep -q "from '@/lib/auth/require-auth'" app/api/protocol/generate/route.ts
grep -q "from '@/lib/auth/roles'" app/api/protocol/generate/route.ts

# (b) requireAuth + requireRole called before any LLM client invocation
node -e "
const src = require('fs').readFileSync('app/api/protocol/generate/route.ts','utf8');
const authIdx = src.indexOf('requireAuth(');
const roleIdx = src.indexOf(\"requireRole(session, 'admin')\");
const llmIdx = Math.min(...['openai','anthropic','llm','generate'].map(s => {const i=src.indexOf(s, src.indexOf('export ')); return i<0?Infinity:i;}));
process.exit(authIdx>0 && roleIdx>authIdx && llmIdx>roleIdx ? 0 : 1);
"

# (c) build + typecheck pass
npm run build
npm run typecheck

# (d) integration test: unauthed POST returns 401
# (run dev server in background; curl; assert; kill)
npm run dev &
DEV_PID=$!
sleep 5
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost:3000/api/protocol/generate -H 'Content-Type: application/json' -d '{}')
kill $DEV_PID
[ "$STATUS" = "401" ]
```

## Pivot triggers

- If `requireAuth` / `requireRole` helpers don't exist or are named differently: halt, do NOT invent your own helper. Report what auth helpers DO exist and let orchestrator decide.
- If the route handler already has any auth check (even a partial one): halt and report — this may already be done, do not double-gate.
- If running the dev server in CI is not possible: skip criterion (d) and add a vitest mock test instead, but document the substitution.

## Notes for executor

Pattern follows `lib/auth/require-auth.ts` consumers — read one or two existing API routes (e.g. `app/api/stripe/checkout/route.ts`) for the boilerplate.

This is a P0 security fix. Reviewer should reject any PR that catches and swallows the auth errors.
