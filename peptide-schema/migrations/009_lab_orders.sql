-- Lab Orders and Results Schema Migration
-- Supports lab ordering via Quest, Labcorp, or other lab partners.

-- ============================================================
-- LAB ORDERS
-- ============================================================

CREATE TABLE lab_orders (
  id                        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  consultation_id           UUID REFERENCES consultations(id) ON DELETE SET NULL,
  patient_id                UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  ordering_provider_id      UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  lab_provider              TEXT NOT NULL DEFAULT 'quest',         -- "quest" | "labcorp" | custom key
  external_order_id         TEXT,                                  -- vendor-assigned order ID
  external_requisition_id   TEXT,                                  -- vendor requisition reference
  panels                    JSONB NOT NULL DEFAULT '[]'::jsonb,    -- [{code, name, loinc_code}]
  diagnosis_codes           TEXT[] NOT NULL DEFAULT '{}',          -- ICD-10 codes
  priority                  TEXT NOT NULL DEFAULT 'routine',       -- "routine" | "urgent" | "stat"
  status                    TEXT NOT NULL DEFAULT 'draft',         -- "draft" | "pending_review" | "approved" | "requisition_sent" | "specimen_collected" | "processing" | "completed" | "cancelled" | "rejected"
  fasting_required          BOOLEAN DEFAULT false,
  special_instructions      TEXT,
  location_id               TEXT,                                  -- lab draw site ID
  scheduled_at              TIMESTAMPTZ,                           -- preferred draw date
  collected_at              TIMESTAMPTZ,                           -- actual specimen collection
  resulted_at               TIMESTAMPTZ,                           -- when results available
  notes                     TEXT,                                  -- provider notes
  metadata                  JSONB DEFAULT '{}'::jsonb,
  created_at                TIMESTAMPTZ DEFAULT now(),
  updated_at                TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_lab_orders_patient       ON lab_orders(patient_id);
CREATE INDEX idx_lab_orders_provider      ON lab_orders(ordering_provider_id);
CREATE INDEX idx_lab_orders_consultation  ON lab_orders(consultation_id) WHERE consultation_id IS NOT NULL;
CREATE INDEX idx_lab_orders_status        ON lab_orders(status);
CREATE INDEX idx_lab_orders_lab_provider  ON lab_orders(lab_provider);
CREATE INDEX idx_lab_orders_external      ON lab_orders(external_order_id) WHERE external_order_id IS NOT NULL;

-- ============================================================
-- LAB RESULTS
-- ============================================================

CREATE TABLE lab_results (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lab_order_id        UUID NOT NULL REFERENCES lab_orders(id) ON DELETE CASCADE,
  patient_id          UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  external_result_id  TEXT,                                    -- vendor result ID
  panel_code          TEXT NOT NULL,                            -- "CMP", "CBC", etc.
  panel_name          TEXT NOT NULL,                            -- "Comprehensive Metabolic Panel"
  status              TEXT NOT NULL DEFAULT 'pending',          -- "pending" | "preliminary" | "final" | "corrected" | "cancelled"
  result_items        JSONB NOT NULL DEFAULT '[]'::jsonb,      -- [{code, name, value, unit, reference_range, flag, loinc_code, notes}]
  performing_lab      TEXT,                                     -- lab that ran the test
  collected_at        TIMESTAMPTZ,
  resulted_at         TIMESTAMPTZ,
  reviewed_by         UUID REFERENCES profiles(id) ON DELETE SET NULL,
  reviewed_at         TIMESTAMPTZ,
  review_notes        TEXT,
  is_abnormal         BOOLEAN DEFAULT false,
  pdf_url             TEXT,                                     -- link to PDF report
  metadata            JSONB DEFAULT '{}'::jsonb,
  created_at          TIMESTAMPTZ DEFAULT now(),
  updated_at          TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_lab_results_order      ON lab_results(lab_order_id);
CREATE INDEX idx_lab_results_patient    ON lab_results(patient_id);
CREATE INDEX idx_lab_results_status     ON lab_results(status);
CREATE INDEX idx_lab_results_panel      ON lab_results(panel_code);
CREATE INDEX idx_lab_results_abnormal   ON lab_results(patient_id, is_abnormal) WHERE is_abnormal = true;
CREATE INDEX idx_lab_results_external   ON lab_results(external_result_id) WHERE external_result_id IS NOT NULL;

-- ============================================================
-- AUTO-UPDATE updated_at TRIGGERS
-- ============================================================

CREATE TRIGGER lab_orders_updated_at
  BEFORE UPDATE ON lab_orders
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER lab_results_updated_at
  BEFORE UPDATE ON lab_results
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE lab_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE lab_results ENABLE ROW LEVEL SECURITY;

-- Lab orders: patients can view their own, ordering providers can view theirs
CREATE POLICY lab_orders_select_own ON lab_orders
  FOR SELECT USING (auth.uid() = patient_id OR auth.uid() = ordering_provider_id);

CREATE POLICY lab_orders_insert_provider ON lab_orders
  FOR INSERT WITH CHECK (auth.uid() = ordering_provider_id);

CREATE POLICY lab_orders_update_provider ON lab_orders
  FOR UPDATE USING (auth.uid() = ordering_provider_id);

-- Lab results: patients can view their own, reviewing provider can view
CREATE POLICY lab_results_select_own ON lab_results
  FOR SELECT USING (
    auth.uid() = patient_id
    OR auth.uid() IN (SELECT ordering_provider_id FROM lab_orders WHERE id = lab_order_id)
  );
