---
task_id: F63
title: "Resolve migration 018 naming collision"
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
estimated_effort: 0.5d
---

## User capability delivered

None directly — this is infrastructure. Unblocks the W1 schema batch (F12), which cannot safely add `024_*.sql` while two `018_*.sql` files exist.

## Background

Both `supabase/migrations/018_rls_knowledge_base.sql` and `supabase/migrations/018_rls_phi_gaps.sql` exist on `main`. Supabase CLI applies migrations in lexicographic order by filename — with two files sharing the `018` prefix, the apply order depends on the rest of the filename, which is fine for fresh databases but means the `schema_migrations` table on production may have recorded one or both with whichever name applied.

## Required pre-task: determine which applied first on prod

Before renaming, the executor must determine the production apply order:

```bash
# Production Supabase project — read schema_migrations table
# (executor must request access from orchestrator if not already granted)
psql "$PROD_DB_URL" -c "SELECT version, name, executed_at FROM supabase_migrations.schema_migrations WHERE version LIKE '018%' ORDER BY executed_at;"
```

If neither has been applied to prod yet (still only on dev): pick the alphabetic order — `knowledge_base` runs before `phi_gaps`.

## Technical scope

Two acceptable resolutions — pick whichever matches the prod history:

**Option A (preferred — minimum churn):** rename to suffix-letter form.
- `018_rls_knowledge_base.sql` → `018a_rls_knowledge_base.sql`
- `018_rls_phi_gaps.sql` → `018b_rls_phi_gaps.sql`
- (or swap `a`/`b` to match prod apply order)

**Option B:** renumber the second-applied to the next available number.
- Whichever applied later → renamed to `024_<original_name>.sql`
- The other → keep as `018_<name>.sql` (drop suffix)
- ⚠️ Option B requires a `supabase_migrations.schema_migrations` UPDATE on every existing environment (dev, staging, prod) to update the version row. Document this in the PR.

## Verifiable acceptance criteria

```bash
# (a) no two files share an 018 prefix
[ "$(ls supabase/migrations/018*.sql | wc -l)" -le 1 ] || \
  ([ "$(ls supabase/migrations/018a*.sql | wc -l)" = "1" ] && [ "$(ls supabase/migrations/018b*.sql | wc -l)" = "1" ])

# (b) git history preserves the rename (uses git mv, not delete+create)
git log --follow --format='%H' -- supabase/migrations/018a_rls_knowledge_base.sql 2>/dev/null | head -1
git log --follow --format='%H' -- supabase/migrations/018b_rls_phi_gaps.sql 2>/dev/null | head -1

# (c) supabase CLI dry-run does not error
npx supabase db lint || true   # informational
npx supabase migration list

# (d) PR description documents the prod apply order finding + which option chosen + (if Option B) the schema_migrations UPDATE script

# (e) build + typecheck still pass (sanity)
npm run build
npm run typecheck
```

## Pivot triggers

- If the executor cannot access `$PROD_DB_URL` (no service-role key, no admin access): halt, do NOT guess. Orchestrator must escalate to the user for prod inspection.
- If both files have already been applied to multiple envs and the apply order differs across envs: halt, escalate — this is a multi-env reconciliation, not a single rename.
- If the migrations contain `DROP` or destructive DDL: extra caution. Verify against prod schema before any rename — Supabase CLI may attempt to re-run.

## Notes for executor

Use `git mv`, not `rm` + new file, so blame and history follow the rename.

This task is the gating prereq for F12 (W1 schema batch). Don't merge F63 without confirming prod state, even if dev compiles.
