-- ============================================================
-- E2E Integration Fixes Migration
-- Aligns database schema with application code written in phases 4-12.
-- Adds missing columns to consultations, user_intake_sessions, and protocols.
-- ============================================================

-- ============================================================
-- 1. USER_INTAKE_SESSIONS: add user_id for linking sessions to accounts
-- ============================================================

ALTER TABLE user_intake_sessions
  ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES profiles(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_sessions_user ON user_intake_sessions(user_id)
  WHERE user_id IS NOT NULL;

-- ============================================================
-- 2. PROTOCOLS: add user_id for linking generated protocols to accounts
-- ============================================================

ALTER TABLE protocols
  ADD COLUMN IF NOT EXISTS user_id    UUID REFERENCES profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

CREATE INDEX IF NOT EXISTS idx_protocols_user ON protocols(user_id)
  WHERE user_id IS NOT NULL;

-- ============================================================
-- 3. CONSULTATIONS: add columns expected by application code
--    Original schema had: md_id, type, reason, status='requested'
--    Application code expects: md_credential_id, consultation_type,
--    patient_message, price_cents, pending_review status, review columns
-- ============================================================

-- Make md_id nullable (code primarily uses md_credential_id)
ALTER TABLE consultations ALTER COLUMN md_id DROP NOT NULL;

-- Add MD credential reference (code's primary way to identify the MD)
ALTER TABLE consultations
  ADD COLUMN IF NOT EXISTS md_credential_id UUID REFERENCES md_credentials(id);

-- Add consultation_type (code uses this instead of the original 'type' column)
ALTER TABLE consultations
  ADD COLUMN IF NOT EXISTS consultation_type TEXT;

-- Add patient_message (code uses this instead of 'reason')
ALTER TABLE consultations
  ADD COLUMN IF NOT EXISTS patient_message TEXT;

-- Add price snapshot at time of booking
ALTER TABLE consultations
  ADD COLUMN IF NOT EXISTS price_cents INTEGER DEFAULT 0;

-- Add review-related columns (used by MD review workflow)
ALTER TABLE consultations
  ADD COLUMN IF NOT EXISTS reviewed_at       TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS md_notes          TEXT,
  ADD COLUMN IF NOT EXISTS rejection_reason  TEXT,
  ADD COLUMN IF NOT EXISTS clinical_notes    JSONB;

-- Sync any existing data: copy 'type' to 'consultation_type', 'reason' to 'patient_message'
UPDATE consultations SET consultation_type = type WHERE consultation_type IS NULL AND type IS NOT NULL;
UPDATE consultations SET patient_message = reason WHERE patient_message IS NULL AND reason IS NOT NULL;

-- Fix protocol_id foreign key: should reference 'protocols' (user-generated), not 'peptide_protocols' (KB)
ALTER TABLE consultations DROP CONSTRAINT IF EXISTS consultations_protocol_id_fkey;
ALTER TABLE consultations
  ADD CONSTRAINT consultations_protocol_id_fkey
  FOREIGN KEY (protocol_id) REFERENCES protocols(id) ON DELETE SET NULL;

-- Create indexes on new columns
CREATE INDEX IF NOT EXISTS idx_consultations_md_cred    ON consultations(md_credential_id);
CREATE INDEX IF NOT EXISTS idx_consultations_ctype      ON consultations(consultation_type);
CREATE INDEX IF NOT EXISTS idx_consultations_price      ON consultations(price_cents);

-- ============================================================
-- 4. RLS POLICIES: update to support md_credential_id access pattern
-- ============================================================

-- Drop old consultation policies that only check md_id
DROP POLICY IF EXISTS consultations_select_participant ON consultations;
DROP POLICY IF EXISTS consultations_update_participant ON consultations;
DROP POLICY IF EXISTS consultations_insert_patient ON consultations;

-- Recreate with support for both md_id and md_credential_id
CREATE POLICY consultations_select_participant ON consultations
  FOR SELECT USING (
    auth.uid() = patient_id
    OR auth.uid() = md_id
    OR md_credential_id IN (SELECT id FROM md_credentials WHERE user_id = auth.uid())
  );

CREATE POLICY consultations_update_participant ON consultations
  FOR UPDATE USING (
    auth.uid() = patient_id
    OR auth.uid() = md_id
    OR md_credential_id IN (SELECT id FROM md_credentials WHERE user_id = auth.uid())
  );

CREATE POLICY consultations_insert_patient ON consultations
  FOR INSERT WITH CHECK (auth.uid() = patient_id);

-- ============================================================
-- 5. PROFILES: add insert policy for sign-up flow
-- ============================================================

-- Allow users to insert their own profile during registration
DROP POLICY IF EXISTS profiles_insert_own ON profiles;
CREATE POLICY profiles_insert_own ON profiles
  FOR INSERT WITH CHECK (auth.uid() = id);
