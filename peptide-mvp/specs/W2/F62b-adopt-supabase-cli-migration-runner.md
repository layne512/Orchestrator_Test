---
task_id: F62b
title: "Adopt Supabase CLI migration runner + backfill schema_migrations registry"
wave: W2
tier: 0
depends_on: [F12]
blocks: [F25]
files_owned:
  - package.json
  - supabase/config.toml
  - supabase/README.md
  - scripts/backfill-schema-migrations.sql
must_read_before_writing:
  - peptide-mvp/CODEBASE-CONVENTIONS.md
  - peptide-mvp/EXISTING-CODE-MAP.md
  - supabase/migrations/    # entire directory; need exact file list
  - .github/workflows/      # if CI exists; backfill flow may need a one-time job
schema_dependencies: []
vendor_blocks: []
estimated_effort: 0.75d
spec_revision: 1
---

## User capability delivered

None patient-facing. Ops gains:

1. Every future migration is tracked in `supabase_migrations.schema_migrations` — `supabase migration list --linked` becomes the source of truth for "what's applied where."
2. `018_*.sql` collision class becomes impossible — CLI rejects duplicate version prefixes at push time.
3. Prod schema drift becomes detectable — `supabase db diff --linked` flags unrecorded manual changes.
4. CI can gate deploy on "no unapplied migrations" — prevents partial schema rollouts.

## Background — verified state at W2 entry (after F12 lands)

- `peptide-website` has applied 24 migrations (001-024) directly via Dashboard SQL Editor or manual `psql`. No tracking table exists.
- `supabase_migrations.schema_migrations` confirmed absent on prod (`gnixfygswxfyixecbkyh`) as of 2026-05-06.
- F12 lands `024_w1_schema_batch.sql` near end of W1; that's the last migration applied without tracking.
- F25 (W2 schema batch) is the first migration F62b protects — it must run via CLI, not Dashboard paste.

## Technical scope

### 1. Install + link

```bash
npm install --save-dev supabase
npx supabase init                              # creates supabase/config.toml if absent
npx supabase link --project-ref gnixfygswxfyixecbkyh
```

Linking prompts for the database password — set it once via CLI; do NOT commit it. CLI stores creds in `~/.supabase/access-token` (gitignored by default).

### 2. Backfill `schema_migrations`

Generate `scripts/backfill-schema-migrations.sql` from the directory listing:

```bash
ls supabase/migrations/*.sql | sort | while read f; do
  fname="$(basename "$f" .sql)"
  version="${fname%%_*}"
  name="${fname#*_}"
  echo "INSERT INTO supabase_migrations.schema_migrations (version, name, statements)"
  echo "VALUES ('$version', '$name', ARRAY['-- backfilled $(date -u +%Y-%m-%dT%H:%M:%SZ)'])"
  echo "ON CONFLICT (version) DO NOTHING;"
done > scripts/backfill-schema-migrations.sql
```

Apply via Dashboard SQL Editor (one-time only, before first `supabase db push`). The CLI creates `supabase_migrations` schema on first link; the inserts populate it with the existing 24 rows.

### 3. Verify registry matches files

```bash
npx supabase migration list --linked
```

Output must list every file in `supabase/migrations/` exactly once. Any mismatch = halt.

### 4. Wire npm scripts

Add to `package.json`:

```json
"scripts": {
  "db:push": "supabase db push --linked",
  "db:diff": "supabase db diff --linked --schema public",
  "db:list": "supabase migration list --linked"
}
```

### 5. Document the new flow in `supabase/README.md`

```markdown
# Supabase migrations

All schema changes ship via Supabase CLI. Manual SQL Editor changes are forbidden.

To add a migration:
  npx supabase migration new <descriptive_name>     # creates new file
  # ... write SQL ...
  npm run db:push                                   # applies to linked prod

To view applied state:
  npm run db:list

To diff local files against prod:
  npm run db:diff
```

### 6. Update `CODEBASE-CONVENTIONS.md` migration section

Replace the wave-batch SQL guidance with: "All schema changes via `supabase migration new`. Wave-batch grouping is enforced by orchestrator dispatch (one schema task per wave); CLI naming uses `<timestamp>_w<N>_<description>.sql` rather than the legacy 3-digit prefix."

## Verifiable acceptance criteria

```bash
# (a) supabase devDep installed
grep -q '"supabase":' package.json
test -d node_modules/supabase

# (b) project linked
npx supabase status --linked 2>&1 | grep -q "gnixfygswxfyixecbkyh"

# (c) backfill script generated, row count = file count
[ -f scripts/backfill-schema-migrations.sql ]
FILE_COUNT=$(ls supabase/migrations/*.sql | wc -l)
INSERT_COUNT=$(grep -c "^INSERT INTO supabase_migrations.schema_migrations" scripts/backfill-schema-migrations.sql)
[ "$FILE_COUNT" = "$INSERT_COUNT" ]

# (d) registry on prod matches local files (after backfill applied)
LOCAL=$(ls supabase/migrations/*.sql | wc -l)
REMOTE=$(npx supabase migration list --linked 2>&1 | grep -cE "^[0-9]")
[ "$LOCAL" = "$REMOTE" ]

# (e) npm scripts present
grep -q '"db:push":' package.json
grep -q '"db:diff":' package.json
grep -q '"db:list":' package.json

# (f) README written
test -f supabase/README.md
grep -q "supabase migration new" supabase/README.md

# (g) build + typecheck unaffected
npm run build
npm run typecheck 2>/dev/null || npx tsc --noEmit | grep "error TS" | grep -v investor-relations | wc -l | (read N; [ "$N" = "0" ])
```

## Pivot triggers

- If `supabase link` fails on auth (no DB password access): halt and escalate — needs Supabase project owner credentials, not the executor's.
- If `supabase_migrations.schema_migrations` already exists with non-zero rows when this task starts: halt — someone else (manual or CI) populated it; investigate before backfilling, do not double-insert.
- If `supabase migration list --linked` shows files locally that differ from prod state (e.g. files exist locally that were never applied to prod): halt — pre-existing schema drift; do NOT backfill or push, escalate.
- If CLI version diverges from Supabase platform expectations (`supabase --version` < project's required CLI version): halt and escalate.

## Notes for executor

This is the first task in W2 that touches prod DB state. Treat the backfill INSERTs as production-affecting — verify against a paused / read-only window, not during peak. The PR description must include the exact backfill SQL for review before it runs.

After this task lands, F25 (W2 schema batch) and every subsequent migration uses the CLI flow. The legacy "drop SQL into Dashboard SQL Editor" path is closed.
