-- Pharmacies table and prescription schema updates
-- Adds approved pharmacies list (503A/503B), pharmacy_id FK on prescriptions,
-- and makes consultation_id nullable for standalone prescriptions

-- ============================================================
-- PHARMACIES (approved pharmacy list)
-- ============================================================

CREATE TABLE pharmacies (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name            TEXT NOT NULL,
  type            TEXT NOT NULL,                     -- '503A' | '503B'
  npi             TEXT,
  address         TEXT,
  city            TEXT,
  state           TEXT NOT NULL,
  zip             TEXT,
  phone           TEXT,
  fax             TEXT,
  is_active       BOOLEAN DEFAULT true,
  accepted_states TEXT[] DEFAULT '{}',               -- states this pharmacy can ship to
  created_at      TIMESTAMPTZ DEFAULT now(),
  updated_at      TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_pharmacies_type    ON pharmacies(type);
CREATE INDEX idx_pharmacies_state   ON pharmacies(state);
CREATE INDEX idx_pharmacies_active  ON pharmacies(is_active) WHERE is_active = true;

-- ============================================================
-- PRESCRIPTIONS UPDATES
-- ============================================================

-- Add pharmacy_id FK to link prescriptions to approved pharmacies
ALTER TABLE prescriptions ADD COLUMN IF NOT EXISTS pharmacy_id UUID REFERENCES pharmacies(id);

-- Make consultation_id nullable (allows prescriptions without a specific consultation)
ALTER TABLE prescriptions ALTER COLUMN consultation_id DROP NOT NULL;

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE pharmacies ENABLE ROW LEVEL SECURITY;

-- Pharmacies: readable by all authenticated users
CREATE POLICY pharmacies_select_all ON pharmacies
  FOR SELECT USING (true);

-- Only admins can manage pharmacies
CREATE POLICY pharmacies_insert_admin ON pharmacies
  FOR INSERT WITH CHECK (public.user_has_role('admin'));

CREATE POLICY pharmacies_update_admin ON pharmacies
  FOR UPDATE USING (public.user_has_role('admin'));

-- ============================================================
-- AUTO-UPDATE TRIGGER
-- ============================================================

CREATE TRIGGER pharmacies_updated_at
  BEFORE UPDATE ON pharmacies
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- SEED APPROVED PHARMACIES
-- ============================================================

INSERT INTO pharmacies (name, type, state, npi, phone, accepted_states) VALUES
  (
    'Olympia Compounding Pharmacy',
    '503A',
    'FL',
    '1234567890',
    '(407) 555-0100',
    ARRAY['AL','AZ','CA','CO','FL','GA','IL','IN','MA','MD','MI','MN','MO','NC','NJ','NY','OH','OR','PA','SC','TN','TX','VA','WA','WI']
  ),
  (
    'Empower Pharmacy',
    '503A',
    'TX',
    '2345678901',
    '(832) 555-0200',
    ARRAY['AL','AZ','CA','CO','FL','GA','IL','IN','MA','MD','MI','MN','MO','NC','NJ','NY','OH','OR','PA','SC','TN','TX','VA','WA','WI']
  ),
  (
    'Hallandale Pharmacy',
    '503A',
    'FL',
    '3456789012',
    '(954) 555-0300',
    ARRAY['CA','FL','GA','NY','TX']
  ),
  (
    'ReviveRx Outsourcing',
    '503B',
    'NJ',
    '4567890123',
    '(973) 555-0400',
    ARRAY['AL','AZ','CA','CO','FL','GA','IL','IN','MA','MD','MI','MN','MO','NC','NJ','NY','OH','OR','PA','SC','TN','TX','VA','WA','WI']
  ),
  (
    'Precision Peptides Outsourcing',
    '503B',
    'CA',
    '5678901234',
    '(310) 555-0500',
    ARRAY['AZ','CA','CO','FL','NV','OR','TX','WA']
  );
