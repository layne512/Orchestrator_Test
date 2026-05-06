---
task_id: F10a
title: "Add admin role gate to v1 LLM protocol generator (route already has 401 — adding 403 role check)"
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
  - lib/auth/guards.ts
  - lib/auth/roles.ts
schema_dependencies: []
vendor_blocks: []
estimated_effort: 0.25d
spec_revision: 2
spec_revision_notes: |
  v1 was authored against helpers (`lib/auth/require-auth.ts`,
  `requireRole(session, 'admin')`) that don't exist on `486f63b`.
  Tier-1 dispatch caught the defect — see STUCK_STATE/F10a_*.md and
  SPEC_LESSONS L-002. v2 rewritten against verified-real auth surface
  in `lib/auth/guards.ts`.
---

## User capability delivered

Closes a cost-vector and PHI-leak hole. The v1 LLM generator route currently has a 401-on-no-user check (lines 41-46) but **no role check** — any authenticated user (including a brand-new patient) can invoke the LLM. After this task, only callers whose `user_roles` row resolves to `admin_super | admin_manager | admin_support` can hit it.

## Background — verified state of `app/api/protocol/generate/route.ts` at `486f63b`

The route ALREADY has this auth block (lines 41-46):

```ts
const authClient = await createClient()
const { data: { user }, error: authError } = await authClient.auth.getUser()
if (authError || !user) {
  return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
}
```

This block stays. It's the canonical API-route 401 pattern (see `CODEBASE-CONVENTIONS.md` → Auth + RBAC). **Do not remove it. Do not replace it with `requireAuth()` from `guards.ts`** — that helper redirects, which surfaces as 307 in API context, breaking the 401 contract.

## Why we don't use `lib/auth/guards.ts::requireRole(UserRole)`

`requireRole(UserRole)` in `guards.ts` calls `redirect('/unauthorized')` on failure. In an API route, `redirect()` from `next/navigation` surfaces as a 307. We need a 403 JSON response. So we use the boolean variant — `verifyDbRole(userId, allowedRoles[])` — and return `NextResponse.json` ourselves.

## Technical scope

Insert a role check **immediately after** the existing 401 block (between lines 46 and the next non-blank line). Use the verified-real `verifyDbRole` import:

```ts
import { verifyDbRole } from '@/lib/auth/guards'

// ... existing imports + 401 block unchanged ...

const isAdmin = await verifyDbRole(user.id, [
  'admin_super',
  'admin_manager',
  'admin_support',
])
if (!isAdmin) {
  return NextResponse.json({ error: 'Forbidden' }, { status: 403 })
}

// ... rest of handler unchanged ...
```

That's the entire change. No new files. No deps. No edits to `guards.ts`. No removal of the existing 401 block. Total diff: ~7 lines added, 0 modified, 0 deleted.

## Verifiable acceptance criteria

```bash
# (a) verifyDbRole imported from guards
grep -q "verifyDbRole" app/api/protocol/generate/route.ts
grep -qE "from '@/lib/auth/guards'" app/api/protocol/generate/route.ts

# (b) all three admin role strings present
grep -q "'admin_super'" app/api/protocol/generate/route.ts
grep -q "'admin_manager'" app/api/protocol/generate/route.ts
grep -q "'admin_support'" app/api/protocol/generate/route.ts

# (c) existing 401 block preserved (still returns 401 on no-user)
grep -q "status: 401" app/api/protocol/generate/route.ts
grep -q "auth.getUser()" app/api/protocol/generate/route.ts

# (d) new 403 response present
grep -q "status: 403" app/api/protocol/generate/route.ts

# (e) role check runs BEFORE any LLM call (string-position check)
node -e "
const src = require('fs').readFileSync('app/api/protocol/generate/route.ts','utf8');
const post = src.indexOf('export async function POST');
const verify = src.indexOf('verifyDbRole', post);
const llm = ['openai','OpenAI(','getOpenAI'].map(s => {const i = src.indexOf(s, post); return i < 0 ? Infinity : i;}).reduce((a,b)=>Math.min(a,b));
process.exit(verify > post && verify < llm ? 0 : 1);
"

# (f) typecheck (substitute npx tsc if no script)
(npm run typecheck 2>/dev/null) || (npx tsc --noEmit 2>&1 | grep -v "investor-relations" | grep "error TS" | wc -l | (read N; [ "$N" = "0" ]))

# (g) build still passes (the only acceptable error is the pre-existing F1-hold SensitivityChart.tsx)
npm run build 2>&1 | tee /tmp/f10a-build.log
grep -E "error|Error" /tmp/f10a-build.log | grep -v "SensitivityChart" | grep -v "investor-relations" | (read line; [ -z "$line" ])
```

All checks must exit 0.

## Pivot triggers

- If `verifyDbRole` is not exported from `lib/auth/guards.ts` (someone refactored it since `486f63b`): halt and report — do NOT fall back to `requireRole(UserRole.AdminSuper)` (that redirects).
- If the existing 401 block at lines 41-46 has been modified since `486f63b`: halt and report — the line numbers may have drifted but the *block* should still be present; locate by content, not line number.
- If a third pivot fires (e.g., `verifyDbRole` signature changed): halt — write a new STUCK_STATE entry, do NOT guess the new signature.

## Notes for executor

This is the simplest possible fix for the bug — keep what works (the 401 block), add what's missing (the 403 role check), avoid the helper-refactor rabbit hole. Spec was rewritten 2026-05-06 against verified-real `lib/auth/guards.ts` exports. If you find drift between this spec and the actual code, the spec is wrong, not the code — halt and write STUCK_STATE.
