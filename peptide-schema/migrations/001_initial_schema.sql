-- PeptideOS Initial Schema Migration
-- Run in Supabase SQL editor or via Supabase CLI

-- Enable extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS vector;

-- ============================================================
-- SYMPTOMS
-- ============================================================

CREATE TABLE symptoms (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name          TEXT NOT NULL UNIQUE,          -- canonical medical name: "Fatigue"
  slug          TEXT NOT NULL UNIQUE,
  description   TEXT,
  body_system   TEXT,                           -- "endocrine" | "neurological" | "musculoskeletal" | etc.
  synonyms      TEXT[] DEFAULT '{}',            -- ["tired", "tiredness", "exhaustion", "always tired"]
  search_vector TSVECTOR,                       -- populated by trigger below
  embedding     vector(1536),                   -- embed(name + synonyms) for semantic search
  severity_scale BOOLEAN DEFAULT true,          -- show 1-10 slider in intake UI
  is_active     BOOLEAN DEFAULT true,
  created_at    TIMESTAMPTZ DEFAULT now()
);

-- Trigger function to keep search_vector in sync (avoids GENERATED ALWAYS immutability issues)
CREATE OR REPLACE FUNCTION symptoms_search_vector_update()
RETURNS TRIGGER AS $$
BEGIN
  NEW.search_vector := to_tsvector(
    'english'::regconfig,
    NEW.name || ' ' || COALESCE(array_to_string(NEW.synonyms, ' '), '')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER symptoms_tsvector_trigger
  BEFORE INSERT OR UPDATE ON symptoms
  FOR EACH ROW EXECUTE FUNCTION symptoms_search_vector_update();

CREATE INDEX idx_symptoms_search   ON symptoms USING GIN(search_vector);
CREATE INDEX idx_symptoms_embed    ON symptoms USING ivfflat (embedding vector_cosine_ops) WITH (lists = 50);
CREATE INDEX idx_symptoms_system   ON symptoms(body_system);

-- Symptom presentation qualifiers (e.g., Color, Timing, Severity, Duration)
CREATE TABLE symptom_qualifiers (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  symptom_id  UUID REFERENCES symptoms(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,                    -- "Color", "Timing", "Severity"
  input_type  TEXT DEFAULT 'select',            -- "select" | "numeric" | "boolean" | "multiselect"
  is_required BOOLEAN DEFAULT false,
  sort_order  INTEGER DEFAULT 0
);

-- Options for each qualifier (e.g., Color → Green, Yellow, Clear)
CREATE TABLE symptom_qualifier_options (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  qualifier_id UUID REFERENCES symptom_qualifiers(id) ON DELETE CASCADE,
  label        TEXT NOT NULL,                   -- "Green", "Morning only"
  value        TEXT NOT NULL,                   -- "green", "morning"
  sort_order   INTEGER DEFAULT 0
);

-- ============================================================
-- CONDITIONS / ILLNESSES
-- ============================================================

CREATE TABLE conditions (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL UNIQUE,
  slug        TEXT UNIQUE,
  description TEXT,
  icd10_code  TEXT,
  category    TEXT,                             -- "hormonal" | "metabolic" | "musculoskeletal" | etc.
  is_active   BOOLEAN DEFAULT true,
  created_at  TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_conditions_category ON conditions(category);
CREATE INDEX idx_conditions_active   ON conditions(is_active);

-- ============================================================
-- SYMPTOM <-> CONDITION RELATIONSHIPS
-- ============================================================

-- Base weights (all default 1.0 per user spec)
CREATE TABLE symptom_conditions (
  symptom_id   UUID REFERENCES symptoms(id)   ON DELETE CASCADE,
  condition_id UUID REFERENCES conditions(id) ON DELETE CASCADE,
  weight       NUMERIC DEFAULT 1.0,            -- base diagnostic weight
  is_primary   BOOLEAN DEFAULT false,          -- defining symptom for this condition
  notes        TEXT,
  PRIMARY KEY (symptom_id, condition_id)
);

CREATE INDEX idx_sc_condition ON symptom_conditions(condition_id);
CREATE INDEX idx_sc_symptom   ON symptom_conditions(symptom_id);

-- Presentation qualifier modifiers on top of base weights
CREATE TABLE symptom_condition_qualifier_weights (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  symptom_id          UUID REFERENCES symptoms(id)                ON DELETE CASCADE,
  condition_id        UUID REFERENCES conditions(id)              ON DELETE CASCADE,
  qualifier_option_id UUID REFERENCES symptom_qualifier_options(id) ON DELETE CASCADE,
  weight_modifier     NUMERIC DEFAULT 1.0,     -- multiply against base weight
  notes               TEXT,
  UNIQUE (symptom_id, condition_id, qualifier_option_id)
);

-- ============================================================
-- CLUSTER ANALYSIS (pre-computed co-occurrence)
-- ============================================================

CREATE TABLE symptom_clusters (
  symptom_id         UUID REFERENCES symptoms(id) ON DELETE CASCADE,
  related_symptom_id UUID REFERENCES symptoms(id) ON DELETE CASCADE,
  cluster_weight     NUMERIC DEFAULT 1.0,      -- co-occurrence count from KB
  PRIMARY KEY (symptom_id, related_symptom_id)
);

CREATE INDEX idx_clusters_symptom ON symptom_clusters(symptom_id);

-- Function to recompute clusters from symptom_conditions co-occurrence
CREATE OR REPLACE FUNCTION recompute_symptom_clusters()
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  DELETE FROM symptom_clusters;
  INSERT INTO symptom_clusters (symptom_id, related_symptom_id, cluster_weight)
  SELECT
    sc1.symptom_id,
    sc2.symptom_id,
    COUNT(*)::NUMERIC AS co_occurrence_count
  FROM symptom_conditions sc1
  JOIN symptom_conditions sc2
    ON sc1.condition_id = sc2.condition_id
    AND sc1.symptom_id  != sc2.symptom_id
  GROUP BY sc1.symptom_id, sc2.symptom_id
  HAVING COUNT(*) >= 3
  ORDER BY co_occurrence_count DESC;
END;
$$;

-- ============================================================
-- RISK FACTORS
-- ============================================================

CREATE TABLE risk_factors (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL UNIQUE,             -- "Age > 50", "Male", "BMI > 30"
  slug        TEXT UNIQUE NOT NULL,
  description TEXT,
  category    TEXT,                             -- "demographic" | "lifestyle" | "medical_history"
  input_type  TEXT DEFAULT 'boolean',           -- "boolean" | "numeric" | "select"
  options     TEXT[],                           -- for select type
  is_active   BOOLEAN DEFAULT true
);

-- Risk factor modifiers per condition
CREATE TABLE condition_risk_factors (
  condition_id    UUID REFERENCES conditions(id)   ON DELETE CASCADE,
  risk_factor_id  UUID REFERENCES risk_factors(id) ON DELETE CASCADE,
  score_modifier  NUMERIC DEFAULT 1.0,           -- multiplier applied to condition score
  is_required     BOOLEAN DEFAULT false,
  notes           TEXT,
  PRIMARY KEY (condition_id, risk_factor_id)
);

-- ============================================================
-- LABS
-- ============================================================

CREATE TABLE labs (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name                 TEXT NOT NULL UNIQUE,     -- "IGF-1", "Testosterone Total"
  full_name            TEXT,
  panel                TEXT,                     -- "hormone" | "metabolic" | "CBC" | etc.
  reference_range_low  NUMERIC,
  reference_range_high NUMERIC,
  reference_unit       TEXT,                     -- "ng/mL", "pg/mL"
  description          TEXT,
  why_relevant         TEXT,                     -- plain-English explanation
  ordering_notes       TEXT,                     -- "fasting required"
  is_active            BOOLEAN DEFAULT true
);

-- How lab values modify condition scores
CREATE TABLE condition_labs (
  condition_id    UUID REFERENCES conditions(id) ON DELETE CASCADE,
  lab_id          UUID REFERENCES labs(id)       ON DELETE CASCADE,
  low_threshold   NUMERIC,                       -- below this → boosts score
  high_threshold  NUMERIC,                       -- above this → boosts score
  score_modifier  NUMERIC DEFAULT 1.5,
  notes           TEXT,
  PRIMARY KEY (condition_id, lab_id)
);

-- ============================================================
-- PEPTIDE PROTOCOLS
-- ============================================================

CREATE TABLE peptide_protocols (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name            TEXT NOT NULL,                -- "BPC-157 Healing Protocol"
  peptide_name    TEXT NOT NULL,                -- "BPC-157" (canonical)
  description     TEXT,
  evidence_level  TEXT,                         -- "emerging" | "moderate" | "well-studied"
  dose_range_low  TEXT,                         -- "200mcg"
  dose_range_high TEXT,                         -- "500mcg"
  frequency       TEXT,                         -- "twice daily"
  route           TEXT,                         -- "subcutaneous" | "oral" | "intranasal"
  cycle_duration  TEXT,                         -- "8-12 weeks"
  key_warnings    TEXT[] DEFAULT '{}',
  adverse_reactions TEXT[] DEFAULT '{}',
  target_sex      TEXT DEFAULT 'both',
  age_range_min   INTEGER,
  age_range_max   INTEGER,
  is_active       BOOLEAN DEFAULT true,
  created_at      TIMESTAMPTZ DEFAULT now(),
  updated_at      TIMESTAMPTZ DEFAULT now()
);

-- Condition → protocol mappings
CREATE TABLE condition_protocols (
  condition_id UUID REFERENCES conditions(id)         ON DELETE CASCADE,
  protocol_id  UUID REFERENCES peptide_protocols(id)  ON DELETE CASCADE,
  priority     INTEGER DEFAULT 1,                -- 1=first-line, 2=adjunct
  rationale    TEXT,
  PRIMARY KEY (condition_id, protocol_id)
);

-- Contraindications per protocol
CREATE TABLE contraindications (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  protocol_id           UUID REFERENCES peptide_protocols(id) ON DELETE CASCADE,
  contraindication_type TEXT NOT NULL,           -- "medication" | "condition" | "lab_value"
  name                  TEXT NOT NULL,           -- "Warfarin", "Active Cancer"
  severity              TEXT NOT NULL,           -- "absolute" | "relative" | "caution"
  description           TEXT,
  action                TEXT                     -- "do not use" | "reduce dose" | "monitor closely"
);

-- Labs required per protocol (baseline, monitoring, follow-up)
CREATE TABLE protocol_labs (
  protocol_id UUID REFERENCES peptide_protocols(id) ON DELETE CASCADE,
  lab_id      UUID REFERENCES labs(id)             ON DELETE CASCADE,
  timing      TEXT NOT NULL,                     -- "baseline" | "monitoring" | "follow-up"
  frequency   TEXT,                              -- "every 6 weeks"
  rationale   TEXT,
  is_required BOOLEAN DEFAULT false,
  PRIMARY KEY (protocol_id, lab_id, timing)
);

-- ============================================================
-- USER INTAKE SESSIONS (anonymous for prototype)
-- ============================================================

CREATE TABLE user_intake_sessions (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at  TIMESTAMPTZ DEFAULT now(),
  updated_at  TIMESTAMPTZ DEFAULT now(),
  status      TEXT DEFAULT 'active',             -- "active" | "protocol_generated"

  -- Rich symptom entries with qualifiers
  -- [{symptom_id, state: "confirmed"|"denied", qualifiers: {option_id: true}, severity: 7, notes: "..."}]
  symptom_entries        JSONB DEFAULT '[]'::jsonb,

  risk_factor_ids        UUID[] DEFAULT '{}',
  lab_entries            JSONB DEFAULT '{}'::jsonb,  -- {lab_id: numeric_value}

  -- Cached scoring output (updated after each score call)
  scored_conditions      JSONB DEFAULT '[]'::jsonb,  -- [{condition_id, name, score, green_pct, yellow_pct, red_pct, rank}]
  accepted_condition_ids UUID[] DEFAULT '{}',

  free_text_notes        TEXT
);

CREATE INDEX idx_sessions_status ON user_intake_sessions(status);
CREATE INDEX idx_sessions_created ON user_intake_sessions(created_at);

-- ============================================================
-- GENERATED PROTOCOLS (output)
-- ============================================================

CREATE TABLE protocols (
  id                     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  intake_session_id      UUID REFERENCES user_intake_sessions(id) ON DELETE SET NULL,
  accepted_condition_ids UUID[] DEFAULT '{}',
  created_at             TIMESTAMPTZ DEFAULT now(),
  title                  TEXT NOT NULL,
  summary                TEXT NOT NULL,
  protocol_json          JSONB NOT NULL,          -- full AI-generated protocol output
  ai_model               TEXT DEFAULT 'gpt-4o-mini',
  prompt_version         TEXT DEFAULT 'v1',
  is_archived            BOOLEAN DEFAULT false
);

-- ============================================================
-- RAG KNOWLEDGE DOCUMENTS
-- ============================================================

CREATE TABLE knowledge_documents (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at  TIMESTAMPTZ DEFAULT now(),
  title       TEXT NOT NULL,
  content     TEXT NOT NULL,
  embedding   vector(1536),
  source_type TEXT,                              -- "pubmed" | "protocol" | "guide" | "safety"
  source_url  TEXT,
  pubmed_id   TEXT,
  peptide_tags TEXT[] DEFAULT '{}',
  topic_tags   TEXT[] DEFAULT '{}',
  is_active   BOOLEAN DEFAULT true
);

CREATE INDEX idx_knowledge_embed ON knowledge_documents
  USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);
CREATE INDEX idx_knowledge_tags  ON knowledge_documents USING GIN(peptide_tags);
