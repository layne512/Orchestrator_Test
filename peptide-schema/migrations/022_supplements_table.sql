-- Migration 022: Supplements Table Migration
-- Decouples 87 supplement records from peptide_protocols into a dedicated
-- supplements table, creates supplement_brands table, re-points
-- protocol_supplements.supplement_id FK, soft-deletes originals, adds RLS.
--
-- Depends on: 004_supplement_type.sql, 005_user_management.sql (update_updated_at_column),
--             008_rls_policies.sql (user_has_role), 021_goal_protocol_engine.sql (protocol_supplements)
--
-- Run in Supabase SQL Editor or via supabase db push

-- ============================================================
-- SECTION 1A: CREATE SUPPLEMENTS TABLE
-- ============================================================

CREATE TABLE IF NOT EXISTS supplements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  slug TEXT NOT NULL UNIQUE,
  category TEXT NOT NULL,
  active_compound TEXT,
  mechanism_of_action TEXT,
  description TEXT,
  evidence_level TEXT DEFAULT 'emerging',
  dose_range_low TEXT,
  dose_range_high TEXT,
  dose_unit TEXT,
  frequency TEXT,
  form TEXT,
  timing_notes TEXT,
  food_interaction TEXT,
  key_warnings TEXT[] DEFAULT '{}',
  adverse_reactions TEXT[] DEFAULT '{}',
  contraindication_notes TEXT,
  source_citations TEXT[] DEFAULT '{}',
  pubmed_ids TEXT[] DEFAULT '{}',
  target_sex TEXT DEFAULT 'both',
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_supplements_category ON supplements(category);
CREATE INDEX IF NOT EXISTS idx_supplements_slug ON supplements(slug);
CREATE INDEX IF NOT EXISTS idx_supplements_active ON supplements(is_active) WHERE is_active = true;

-- Auto-update updated_at (reuses function from migration 005)
CREATE TRIGGER supplements_updated_at
  BEFORE UPDATE ON supplements
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- SECTION 1B: CREATE SUPPLEMENT_BRANDS TABLE
-- ============================================================

CREATE TABLE IF NOT EXISTS supplement_brands (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  supplement_id UUID NOT NULL REFERENCES supplements(id) ON DELETE CASCADE,
  manufacturer_name TEXT NOT NULL,
  product_name TEXT,
  quality_tier TEXT NOT NULL DEFAULT 'consumer',
  certifications TEXT[] DEFAULT '{}',
  brand_url TEXT,
  price_tier TEXT DEFAULT 'mid',
  notes TEXT,
  is_recommended BOOLEAN DEFAULT false,
  sort_order INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(supplement_id, manufacturer_name, product_name)
);

CREATE INDEX IF NOT EXISTS idx_supplement_brands_supplement ON supplement_brands(supplement_id);
CREATE INDEX IF NOT EXISTS idx_supplement_brands_tier ON supplement_brands(quality_tier) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_supplement_brands_recommended ON supplement_brands(is_recommended) WHERE is_recommended = true;

-- Auto-update updated_at (reuses function from migration 005)
CREATE TRIGGER supplement_brands_updated_at
  BEFORE UPDATE ON supplement_brands
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- SECTION 1C: MIGRATE 87 SUPPLEMENT ROWS FROM peptide_protocols
-- Uses ON CONFLICT (name) DO NOTHING for idempotent re-runs
-- ============================================================

INSERT INTO supplements (name, slug, category, active_compound, description, evidence_level,
  dose_range_low, dose_range_high, dose_unit, frequency, form, timing_notes, food_interaction,
  key_warnings, adverse_reactions, source_citations, target_sex, is_active)
SELECT
  pp.peptide_name AS name,
  lower(regexp_replace(regexp_replace(pp.peptide_name, '[^a-zA-Z0-9\s-]', '', 'g'), '\s+', '-', 'g')) AS slug,
  pp.category,
  pp.peptide_name AS active_compound,
  pp.description,
  pp.evidence_level,
  pp.dose_range_low,
  pp.dose_range_high,
  'mg' AS dose_unit,
  pp.frequency,
  CASE
    WHEN pp.route = 'oral' THEN 'capsule'
    WHEN pp.route = 'powder' THEN 'powder'
    WHEN pp.route = 'liquid' THEN 'liquid'
    ELSE pp.route
  END AS form,
  pp.timing_notes,
  pp.food_interaction,
  pp.key_warnings,
  pp.adverse_reactions,
  pp.source_citations,
  pp.target_sex,
  pp.is_active
FROM peptide_protocols pp
WHERE pp.type = 'supplement'
ON CONFLICT (name) DO NOTHING;

-- VERIFY: SELECT count(*) FROM supplements; -- Expected: 87

-- ============================================================
-- SECTION 1D: RE-POINT protocol_supplements.supplement_id FK
-- Most critical step: create temp mapping, add new column,
-- populate via mapping, verify no nulls, swap FK
-- ============================================================

-- Create temp mapping table (old peptide_protocols.id -> new supplements.id)
CREATE TEMP TABLE supplement_id_mapping AS
SELECT pp.id AS old_protocol_id, s.id AS new_supplement_id
FROM peptide_protocols pp
JOIN supplements s ON s.name = pp.peptide_name
WHERE pp.type = 'supplement';
-- VERIFY: SELECT count(*) FROM supplement_id_mapping; -- Must be 87

-- Add new column pointing to supplements table
ALTER TABLE protocol_supplements ADD COLUMN supplement_id_new UUID REFERENCES supplements(id) ON DELETE CASCADE;

-- Populate new column via mapping table
UPDATE protocol_supplements ps
SET supplement_id_new = sim.new_supplement_id
FROM supplement_id_mapping sim
WHERE ps.supplement_id = sim.old_protocol_id;
-- VERIFY: SELECT count(*) FROM protocol_supplements WHERE supplement_id_new IS NULL; -- Must be 0

-- Drop old FK constraint, old column, rename new column, add new FK
ALTER TABLE protocol_supplements DROP CONSTRAINT protocol_supplements_supplement_id_fkey;
ALTER TABLE protocol_supplements DROP COLUMN supplement_id;
ALTER TABLE protocol_supplements RENAME COLUMN supplement_id_new TO supplement_id;
ALTER TABLE protocol_supplements ADD CONSTRAINT protocol_supplements_supplement_id_fkey
  FOREIGN KEY (supplement_id) REFERENCES supplements(id) ON DELETE CASCADE;

-- Rebuild unique constraint for (protocol_id, supplement_id)
ALTER TABLE protocol_supplements DROP CONSTRAINT IF EXISTS protocol_supplements_protocol_id_supplement_id_key;
ALTER TABLE protocol_supplements ADD UNIQUE (protocol_id, supplement_id);

-- VERIFY: SELECT count(*) FROM protocol_supplements WHERE supplement_id IS NULL; -- Must be 0
-- VERIFY: SELECT count(*) FROM protocol_supplements ps
--   WHERE NOT EXISTS (SELECT 1 FROM supplements s WHERE s.id = ps.supplement_id); -- Must be 0

-- ============================================================
-- SECTION 1E: SOFT-DELETE SUPPLEMENT ROWS IN peptide_protocols
-- ============================================================

UPDATE peptide_protocols
SET is_active = false, updated_at = now()
WHERE type = 'supplement';

-- VERIFY: SELECT count(*) FROM peptide_protocols WHERE type='supplement' AND is_active = true; -- Must be 0

-- ============================================================
-- SECTION 1F: RLS POLICIES
-- Public SELECT for both tables; admin-only INSERT/UPDATE/DELETE
-- Uses public.user_has_role() from migration 008
-- Policy names prefixed with kb_ for consistency with 018_rls_knowledge_base.sql
-- ============================================================

-- SUPPLEMENTS: public read, admin write
ALTER TABLE supplements ENABLE ROW LEVEL SECURITY;

CREATE POLICY kb_supplements_select ON supplements
  FOR SELECT USING (true);

CREATE POLICY kb_supplements_insert ON supplements
  FOR INSERT WITH CHECK (
    public.user_has_role('admin_super') OR public.user_has_role('admin_manager')
  );

CREATE POLICY kb_supplements_update ON supplements
  FOR UPDATE USING (
    public.user_has_role('admin_super') OR public.user_has_role('admin_manager')
  );

CREATE POLICY kb_supplements_delete ON supplements
  FOR DELETE USING (
    public.user_has_role('admin_super') OR public.user_has_role('admin_manager')
  );

-- SUPPLEMENT_BRANDS: public read, admin write
ALTER TABLE supplement_brands ENABLE ROW LEVEL SECURITY;

CREATE POLICY kb_supplement_brands_select ON supplement_brands
  FOR SELECT USING (true);

CREATE POLICY kb_supplement_brands_insert ON supplement_brands
  FOR INSERT WITH CHECK (
    public.user_has_role('admin_super') OR public.user_has_role('admin_manager')
  );

CREATE POLICY kb_supplement_brands_update ON supplement_brands
  FOR UPDATE USING (
    public.user_has_role('admin_super') OR public.user_has_role('admin_manager')
  );

CREATE POLICY kb_supplement_brands_delete ON supplement_brands
  FOR DELETE USING (
    public.user_has_role('admin_super') OR public.user_has_role('admin_manager')
  );
