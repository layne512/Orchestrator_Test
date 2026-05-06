---
task_id: F63
title: "Resolve migration 018 naming collision (rename to 018a/018b)"
wave: W0
tier: 1
depends_on: [F104]
blocks: [F12]
files_owned:
  - supabase/migrations/018_rls_knowledge_base.sql
  - supabase/migrations/018_rls_phi_gaps.sql
must_read_before_writing:
  - peptide-mvp/CODEBASE-CONVENTIONS.md
  - peptide-mvp/EXISTING-CODE-MAP.md
  - supabase/migrations/018_rls_knowledge_base.sql
  - supabase/migrations/018_rls_phi_gaps.sql
schema_dependencies: []
vendor_blocks: []
estimated_effort: 0.25d
spec_revision: 2
spec_revision_notes: |
  v1 required querying production Supabase to determine apply order.
  Investigation 2026-05-06 confirmed prod has NO supabase_migrations.schema_migrations
  table — migrations were applied manually via Dashboard SQL Editor without
  tracking. There is no registry to reconcile. Resolution simplifies to a
  pure source-file rename, alphabetical order.
---

## User capability delivered

None directly. Unblocks F12 (W1 schema batch) by removing the duplicate `018` prefix that breaks lex-order safety on future migrations.

## Background — verified state

Both files exist on `486f63b`:
- `supabase/migrations/018_rls_knowledge_base.sql` — 322 lines, RLS on 16 KB tables. NOT idempotent (no `DROP POLICY IF EXISTS`).
- `supabase/migrations/018_rls_phi_gaps.sql` — 70 lines, RLS on `user_intake_sessions` + `protocols`. IS idempotent.

**No migration registry in prod.** Confirmed 2026-05-06 via Supabase Dashboard SQL Editor — `supabase_migrations.schema_migrations` does not exist. Migrations were applied directly via Dashboard SQL Editor or `psql`, no version tracking. **There is no prod state to reconcile.**

Therefore the resolution is a simple source-file rename for lex-order safety, alphabetical order chosen.

## Out of scope

The non-idempotent nature of `018_rls_knowledge_base.sql` (no `DROP POLICY IF EXISTS`) means re-running it will fail. Not F63's problem; only matters if a re-run is ever needed.

## Technical scope

Use `git mv` (preserves blame + history) to rename:

```bash
cd <peptide-website-root>
git mv supabase/migrations/018_rls_knowledge_base.sql supabase/migrations/018a_rls_knowledge_base.sql
git mv supabase/migrations/018_rls_phi_gaps.sql supabase/migrations/018b_rls_phi_gaps.sql
```

No content changes inside either file. No registry update. No DB action.

## Verifiable acceptance criteria

```bash
# (a) no two files share an 018 prefix
[ "$(ls supabase/migrations/018_*.sql 2>/dev/null | wc -l)" = "0" ]

# (b) both renamed files exist
[ -f supabase/migrations/018a_rls_knowledge_base.sql ]
[ -f supabase/migrations/018b_rls_phi_gaps.sql ]

# (c) rename used git mv (so blame/history follow)
git log --follow --format='%H' -- supabase/migrations/018a_rls_knowledge_base.sql | head -1 | grep -E "^[0-9a-f]{40}$"
git log --follow --format='%H' -- supabase/migrations/018b_rls_phi_gaps.sql | head -1 | grep -E "^[0-9a-f]{40}$"

# (d) git treats both as renames, not delete+create
git diff --name-status main..HEAD -- supabase/migrations/ | grep -E "^R" | wc -l | (read N; [ "$N" = "2" ])

# (e) file content unchanged (only paths moved)
git diff main..HEAD -- supabase/migrations/018a_rls_knowledge_base.sql | wc -l | (read N; [ "$N" = "0" ])
git diff main..HEAD -- supabase/migrations/018b_rls_phi_gaps.sql | wc -l | (read N; [ "$N" = "0" ])

# (f) lex order is preserved (no migration sorts before 017 or after 019 unexpectedly)
ls supabase/migrations/ | sort | grep -E "^01[789]" | head -5
# expected output:
#   017_fix_roles_seed.sql
#   018a_rls_knowledge_base.sql
#   018b_rls_phi_gaps.sql
#   019_intake_session_persistence.sql

# (g) build + typecheck unchanged (sanity — file rename shouldn't affect TS)
npm run build 2>&1 | tee /tmp/f63-build.log
grep -E "error|Error" /tmp/f63-build.log | grep -v "SensitivityChart" | grep -v "investor-relations" | (read line; [ -z "$line" ])
```

## Pivot triggers

- If `supabase_migrations.schema_migrations` actually DOES exist in prod (e.g., the user later adopts Supabase CLI and the table appears): halt and write STUCK_STATE — F63 v3 is needed with a registry-update step.
- If there are >2 files matching `018_*.sql` (an unexpected third file): halt and report — investigation needed.
- If `git mv` fails or git treats the operation as delete+create instead of rename: halt — the operation must preserve history.

## Notes for executor

This is a pure rename. If you find yourself editing file contents, you've gone off-script. The whole task is two `git mv` invocations + commit.

PR description should explicitly note: "No prod DB action required — peptide-website does not currently use Supabase CLI's `schema_migrations` registry. Resolution is source-only."
