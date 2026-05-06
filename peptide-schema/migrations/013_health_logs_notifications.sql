-- Patient Health Logs & Dosing Notifications Schema
-- Time-series health tracking data and dosing reminder configuration

-- ============================================================
-- PATIENT HEALTH LOGS (time-series)
-- ============================================================

CREATE TABLE patient_health_logs (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id        UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  logged_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  weight_lbs        NUMERIC(5,1),                      -- weight in pounds (e.g. 185.5)
  energy_level      INTEGER CHECK (energy_level BETWEEN 1 AND 10),
  sleep_quality     INTEGER CHECK (sleep_quality BETWEEN 1 AND 10),
  symptom_severity  INTEGER CHECK (symptom_severity BETWEEN 1 AND 10),
  side_effects      TEXT[] DEFAULT '{}',                -- array of reported side effects
  notes             TEXT,
  created_at        TIMESTAMPTZ DEFAULT now(),
  updated_at        TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_health_logs_patient    ON patient_health_logs(patient_id);
CREATE INDEX idx_health_logs_logged_at  ON patient_health_logs(patient_id, logged_at DESC);
CREATE INDEX idx_health_logs_side_fx    ON patient_health_logs USING GIN(side_effects);

-- ============================================================
-- DOSING REMINDERS
-- ============================================================

CREATE TABLE dosing_reminders (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id        UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  prescription_id   UUID REFERENCES prescriptions(id) ON DELETE SET NULL,
  medication_name   TEXT NOT NULL,
  dosage            TEXT,
  frequency         TEXT NOT NULL DEFAULT 'daily',     -- 'daily' | 'twice_daily' | 'three_daily' | 'weekly'
  reminder_times    JSONB NOT NULL DEFAULT '["08:00"]'::jsonb,  -- array of HH:MM strings
  phone_number      TEXT,                              -- E.164 format for SMS
  delivery_method   TEXT NOT NULL DEFAULT 'sms',       -- 'sms' | 'email' | 'push'
  is_active         BOOLEAN DEFAULT true,
  timezone          TEXT DEFAULT 'America/New_York',
  last_sent_at      TIMESTAMPTZ,
  next_send_at      TIMESTAMPTZ,
  created_at        TIMESTAMPTZ DEFAULT now(),
  updated_at        TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_dosing_reminders_patient  ON dosing_reminders(patient_id);
CREATE INDEX idx_dosing_reminders_active   ON dosing_reminders(is_active) WHERE is_active = true;
CREATE INDEX idx_dosing_reminders_next     ON dosing_reminders(next_send_at) WHERE is_active = true;

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE patient_health_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE dosing_reminders ENABLE ROW LEVEL SECURITY;

-- Health logs: patients can manage their own
CREATE POLICY health_logs_select_own ON patient_health_logs
  FOR SELECT USING ((SELECT auth.uid()) = patient_id);

CREATE POLICY health_logs_insert_own ON patient_health_logs
  FOR INSERT WITH CHECK ((SELECT auth.uid()) = patient_id);

CREATE POLICY health_logs_update_own ON patient_health_logs
  FOR UPDATE USING ((SELECT auth.uid()) = patient_id);

CREATE POLICY health_logs_delete_own ON patient_health_logs
  FOR DELETE USING ((SELECT auth.uid()) = patient_id);

-- MDs can view their patients' health logs (via active consultations)
CREATE POLICY health_logs_select_md ON patient_health_logs
  FOR SELECT USING (
    patient_id IN (
      SELECT patient_id FROM consultations
      WHERE md_id = (SELECT auth.uid())
        AND status NOT IN ('cancelled')
    )
  );

-- Dosing reminders: patients can manage their own
CREATE POLICY dosing_reminders_select_own ON dosing_reminders
  FOR SELECT USING ((SELECT auth.uid()) = patient_id);

CREATE POLICY dosing_reminders_insert_own ON dosing_reminders
  FOR INSERT WITH CHECK ((SELECT auth.uid()) = patient_id);

CREATE POLICY dosing_reminders_update_own ON dosing_reminders
  FOR UPDATE USING ((SELECT auth.uid()) = patient_id);

CREATE POLICY dosing_reminders_delete_own ON dosing_reminders
  FOR DELETE USING ((SELECT auth.uid()) = patient_id);

-- ============================================================
-- AUTO-UPDATE TRIGGERS
-- ============================================================

CREATE TRIGGER health_logs_updated_at
  BEFORE UPDATE ON patient_health_logs
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER dosing_reminders_updated_at
  BEFORE UPDATE ON dosing_reminders
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
