---
task_id: F12
title: "W1 schema batch — subscriptions + funnel state + RLS"
wave: W1
tier: 0
depends_on: [F63]
blocks:
  - F89   # funnel state machine reads funnel_state column
  - F13   # peptide catalog reads peptides table extensions
  - F14   # GLP-1 brands seed reads peptides extensions
  - F15   # NAD+ seed reads peptides extensions
  - F16   # Stripe 3-tier wiring reads subscription_tiers
  - F17   # DoseSpot prod hardening reads prescription_status enum extensions
  - F18   # Send-Rx route reads prescriptions extensions
  - F21   # Convergence v2 reads goal_protocols extensions
  - F31   # intake completion writes funnel_state
  - F32   # MD queue reads funnel_state
files_owned:
  - supabase/migrations/024_w1_schema_batch.sql
must_read_before_writing:
  - peptide-mvp/CODEBASE-CONVENTIONS.md
  - peptide-mvp/EXISTING-CODE-MAP.md
  - supabase/migrations/  # entire directory — must understand existing schema
schema_dependencies: []
vendor_blocks: []
estimated_effort: 1d
---

## User capability delivered

None directly. Prerequisite for every W1 feature task. **No W1 feature task may write a migration; all schema changes go through this batch file.**

## Why a wave-batch

Per `CODEBASE-CONVENTIONS.md` "Wave-batch migration pattern": parallel feature tasks racing to add columns to the same table generated F63 (the 018_* collision) historically. Wave-batching kills that class entirely by serializing all schema changes into one migration per wave, which all feature tasks declare a dependency on.

## Technical scope — single migration file

`supabase/migrations/024_w1_schema_batch.sql` aggregates every schema change W1 needs.

### 1. `subscription_tiers` table (new)

```sql
CREATE TABLE subscription_tiers (
  id text PRIMARY KEY,                    -- e.g. 'tier_1', 'tier_2', 'tier_3'
  display_name text NOT NULL,
  monthly_price_cents int NOT NULL,
  vials_included int NOT NULL,            -- TBD per locked decision; column exists, value seeded later
  stripe_price_id text NOT NULL UNIQUE,
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE subscription_tiers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "subscription_tiers_read_anon" ON subscription_tiers
  FOR SELECT USING (active = true);

CREATE POLICY "subscription_tiers_write_admin" ON subscription_tiers
  FOR ALL USING (
    (SELECT role FROM profiles WHERE id = auth.uid()) = 'admin'
  );
```

### 2. `profiles.funnel_state` column (new)

```sql
CREATE TYPE funnel_state_enum AS ENUM (
  'SIGNED_UP',
  'INTAKE_IN_PROGRESS',
  'INTAKE_COMPLETE',
  'LABS_ORDERED',
  'LABS_PENDING',
  'LABS_BACK',
  'CONSULT_BOOKED',
  'CONSULT_COMPLETE',
  'RX_SENT',
  'SHIPPED'
);

ALTER TABLE profiles ADD COLUMN funnel_state funnel_state_enum NOT NULL DEFAULT 'SIGNED_UP';
ALTER TABLE profiles ADD COLUMN funnel_state_updated_at timestamptz NOT NULL DEFAULT now();

CREATE INDEX idx_profiles_funnel_state ON profiles(funnel_state) WHERE funnel_state != 'SHIPPED';
```

### 3. `funnel_transitions` table (new — audit log)

```sql
CREATE TABLE funnel_transitions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  from_state funnel_state_enum,
  to_state funnel_state_enum NOT NULL,
  triggered_by text NOT NULL,             -- e.g. 'intake_complete', 'lab_webhook', 'md_consult_finish'
  metadata jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_funnel_transitions_user ON funnel_transitions(user_id, created_at DESC);

ALTER TABLE funnel_transitions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "funnel_transitions_read_self" ON funnel_transitions
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "funnel_transitions_read_md" ON funnel_transitions
  FOR SELECT USING (
    (SELECT role FROM profiles WHERE id = auth.uid()) IN ('md', 'admin')
  );

-- Writes only via service-role (server-side state-machine code).
```

### 4. `peptides` table extensions (existing table — add cols for catalog)

```sql
ALTER TABLE peptides ADD COLUMN IF NOT EXISTS category text NOT NULL DEFAULT 'cat_1';
  -- 'cat_1' | 'glp1' | 'nad'
ALTER TABLE peptides ADD COLUMN IF NOT EXISTS brand_name text;
ALTER TABLE peptides ADD COLUMN IF NOT EXISTS active boolean NOT NULL DEFAULT true;
```

### 5. `prescriptions` table extensions

```sql
ALTER TYPE prescription_status_enum ADD VALUE IF NOT EXISTS 'sent_to_pharmacy';
ALTER TYPE prescription_status_enum ADD VALUE IF NOT EXISTS 'shipped';

ALTER TABLE prescriptions ADD COLUMN IF NOT EXISTS dosespot_prescription_id text UNIQUE;
ALTER TABLE prescriptions ADD COLUMN IF NOT EXISTS sent_at timestamptz;
```

### 6. `goal_protocols` extensions (Convergence v2)

```sql
ALTER TABLE goal_protocols ADD COLUMN IF NOT EXISTS deterministic_version int NOT NULL DEFAULT 2;
ALTER TABLE goal_protocols ADD COLUMN IF NOT EXISTS clinical_review_required boolean NOT NULL DEFAULT true;
```

### 7. RLS policies for new + extended tables

(Inline above where each table is created. No additional grants in this section.)

## Verifiable acceptance criteria

```bash
# (a) migration file present + numbered correctly
[ -f supabase/migrations/024_w1_schema_batch.sql ]

# (b) no other 024_*.sql exists (collision check)
[ "$(ls supabase/migrations/024_*.sql | wc -l)" = "1" ]

# (c) migration applies cleanly to a fresh local supabase
npx supabase db reset
# (above command runs all migrations 001..024 from scratch — must exit 0)

# (d) all expected objects exist after apply
psql "$LOCAL_DB_URL" -c "SELECT 1 FROM subscription_tiers LIMIT 0;"
psql "$LOCAL_DB_URL" -c "SELECT funnel_state FROM profiles LIMIT 0;"
psql "$LOCAL_DB_URL" -c "SELECT 1 FROM funnel_transitions LIMIT 0;"
psql "$LOCAL_DB_URL" -c "SELECT category, brand_name FROM peptides LIMIT 0;"
psql "$LOCAL_DB_URL" -c "SELECT dosespot_prescription_id FROM prescriptions LIMIT 0;"
psql "$LOCAL_DB_URL" -c "SELECT deterministic_version FROM goal_protocols LIMIT 0;"

# (e) RLS enabled on new tables
psql "$LOCAL_DB_URL" -tAc "
SELECT relname FROM pg_class
WHERE relname IN ('subscription_tiers','funnel_transitions')
AND relrowsecurity = true;
" | wc -l | grep -q 2

# (f) type definitions in lib regenerated (if using supabase gen types)
npx supabase gen types typescript --local > lib/supabase/database.types.ts
git diff --quiet lib/supabase/database.types.ts || echo "types updated — commit them"

# (g) build + typecheck pass with new types
npm run build
npm run typecheck
```

## Pivot triggers

- If `prescription_status_enum` doesn't exist (was named differently in earlier migration): read `migrations/007_messaging_payments_rx.sql`, use the actual name. Do NOT create a duplicate enum.
- If a feature task in W1 needs a column not listed here: HALT the feature task, amend F12 to add the column, re-apply, then resume the feature task. Never write a 024b_*.sql or 025_*.sql in W1 to bolt on a missed column.
- If `npx supabase db reset` fails on an earlier migration (001-023): F12 is blocked on F63 not being fully applied. Verify F63 marker in `STATE/completed.json` before retrying.

## Notes for executor

This file will be ~250 lines of SQL. Treat it as the most-reviewed PR of W1 — every reviewer should verify their own feature task's columns are present. Use a checklist in the PR description listing every blocking task and confirming each one's needs are met.

**Production deploy of this migration must wait until F1 unfreezes** (per `HOLDS.md`). Until then, F12 lands on `main` and applies on dev/staging only. The wave can still complete locally.
