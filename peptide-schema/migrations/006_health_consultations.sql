-- Health History & Consultations Schema Migration
-- Patient health records, consultations, notes, and MD availability

-- ============================================================
-- HEALTH HISTORY
-- ============================================================

CREATE TABLE health_history (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id        UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  medications       JSONB DEFAULT '[]'::jsonb,   -- [{name, dose, frequency, start_date, prescriber, is_current}]
  allergies         JSONB DEFAULT '[]'::jsonb,   -- [{allergen, reaction, severity: "mild"|"moderate"|"severe"}]
  medical_history   JSONB DEFAULT '[]'::jsonb,   -- [{condition, diagnosed_date, status: "active"|"resolved", notes}]
  contraindications JSONB DEFAULT '[]'::jsonb,   -- [{type: "medication"|"condition"|"lab_value", name, severity, notes}]
  family_history    JSONB DEFAULT '[]'::jsonb,   -- [{condition, relation, notes}]
  surgical_history  JSONB DEFAULT '[]'::jsonb,   -- [{procedure, date, notes}]
  social_history    JSONB DEFAULT '{}'::jsonb,   -- {smoking, alcohol, exercise, occupation}
  version           INTEGER DEFAULT 1,            -- incremented on each update for audit trail
  is_current        BOOLEAN DEFAULT true,         -- only latest version is current
  created_at        TIMESTAMPTZ DEFAULT now(),
  updated_at        TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_health_history_patient  ON health_history(patient_id);
CREATE INDEX idx_health_history_current  ON health_history(patient_id, is_current) WHERE is_current = true;
CREATE INDEX idx_health_history_meds     ON health_history USING GIN(medications);
CREATE INDEX idx_health_history_allergies ON health_history USING GIN(allergies);

-- ============================================================
-- CONSULTATIONS
-- ============================================================

CREATE TABLE consultations (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id      UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  md_id           UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  type            TEXT NOT NULL,                  -- "async" | "video"
  status          TEXT NOT NULL DEFAULT 'requested', -- "requested" | "scheduled" | "in_progress" | "completed" | "cancelled" | "no_show"
  protocol_id     UUID REFERENCES peptide_protocols(id) ON DELETE SET NULL,
  intake_session_id UUID REFERENCES user_intake_sessions(id) ON DELETE SET NULL,
  reason          TEXT,                           -- chief complaint / reason for visit
  scheduled_at    TIMESTAMPTZ,                   -- for video consultations
  started_at      TIMESTAMPTZ,
  completed_at    TIMESTAMPTZ,
  cancelled_at    TIMESTAMPTZ,
  cancellation_reason TEXT,
  duration_minutes INTEGER,                       -- actual duration
  priority        TEXT DEFAULT 'normal',          -- "normal" | "urgent" | "follow_up"
  is_follow_up    BOOLEAN DEFAULT false,
  parent_consultation_id UUID REFERENCES consultations(id) ON DELETE SET NULL,
  created_at      TIMESTAMPTZ DEFAULT now(),
  updated_at      TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_consultations_patient    ON consultations(patient_id);
CREATE INDEX idx_consultations_md         ON consultations(md_id);
CREATE INDEX idx_consultations_status     ON consultations(status);
CREATE INDEX idx_consultations_type       ON consultations(type);
CREATE INDEX idx_consultations_scheduled  ON consultations(scheduled_at) WHERE scheduled_at IS NOT NULL;
CREATE INDEX idx_consultations_protocol   ON consultations(protocol_id) WHERE protocol_id IS NOT NULL;

-- ============================================================
-- CONSULTATION NOTES (SOAP format)
-- ============================================================

CREATE TABLE consultation_notes (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  consultation_id UUID NOT NULL REFERENCES consultations(id) ON DELETE CASCADE,
  author_id       UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  note_type       TEXT NOT NULL DEFAULT 'soap',   -- "soap" | "addendum" | "follow_up"
  subjective      TEXT,                           -- S: patient's reported symptoms/concerns
  objective       TEXT,                           -- O: clinical findings, vitals, lab results
  assessment      TEXT,                           -- A: diagnosis / clinical impression
  plan            TEXT,                           -- P: treatment plan, prescriptions, follow-up
  internal_notes  TEXT,                           -- private MD notes, not shared with patient
  is_signed       BOOLEAN DEFAULT false,
  signed_at       TIMESTAMPTZ,
  is_amended      BOOLEAN DEFAULT false,
  amendment_reason TEXT,
  created_at      TIMESTAMPTZ DEFAULT now(),
  updated_at      TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_consult_notes_consultation ON consultation_notes(consultation_id);
CREATE INDEX idx_consult_notes_author       ON consultation_notes(author_id);
CREATE INDEX idx_consult_notes_signed       ON consultation_notes(is_signed);

-- ============================================================
-- MD AVAILABILITY
-- ============================================================

CREATE TABLE md_availability (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  md_id           UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  day_of_week     INTEGER NOT NULL,               -- 0=Sunday, 6=Saturday
  start_time      TIME NOT NULL,                  -- slot start (e.g. '09:00')
  end_time        TIME NOT NULL,                  -- slot end (e.g. '09:30')
  slot_duration   INTEGER DEFAULT 30,             -- duration in minutes
  consultation_type TEXT DEFAULT 'both',          -- "async" | "video" | "both"
  is_recurring    BOOLEAN DEFAULT true,           -- weekly recurring slot
  specific_date   DATE,                           -- for one-off availability overrides
  is_available    BOOLEAN DEFAULT true,           -- false = blocked/unavailable
  max_patients    INTEGER DEFAULT 1,              -- max concurrent bookings per slot
  created_at      TIMESTAMPTZ DEFAULT now(),
  updated_at      TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_md_avail_md          ON md_availability(md_id);
CREATE INDEX idx_md_avail_day         ON md_availability(day_of_week);
CREATE INDEX idx_md_avail_available   ON md_availability(md_id, is_available) WHERE is_available = true;
CREATE INDEX idx_md_avail_specific    ON md_availability(specific_date) WHERE specific_date IS NOT NULL;

-- ============================================================
-- AUTO-UPDATE updated_at TRIGGERS
-- ============================================================

CREATE TRIGGER health_history_updated_at
  BEFORE UPDATE ON health_history
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER consultations_updated_at
  BEFORE UPDATE ON consultations
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER consultation_notes_updated_at
  BEFORE UPDATE ON consultation_notes
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER md_availability_updated_at
  BEFORE UPDATE ON md_availability
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE health_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE consultations ENABLE ROW LEVEL SECURITY;
ALTER TABLE consultation_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE md_availability ENABLE ROW LEVEL SECURITY;

-- Health history: patients can read/update their own
CREATE POLICY health_history_select_own ON health_history
  FOR SELECT USING (auth.uid() = patient_id);

CREATE POLICY health_history_insert_own ON health_history
  FOR INSERT WITH CHECK (auth.uid() = patient_id);

CREATE POLICY health_history_update_own ON health_history
  FOR UPDATE USING (auth.uid() = patient_id);

-- Consultations: patients and assigned MDs can view their consultations
CREATE POLICY consultations_select_own ON consultations
  FOR SELECT USING (auth.uid() = patient_id OR auth.uid() = md_id);

CREATE POLICY consultations_insert_patient ON consultations
  FOR INSERT WITH CHECK (auth.uid() = patient_id);

CREATE POLICY consultations_update_participants ON consultations
  FOR UPDATE USING (auth.uid() = patient_id OR auth.uid() = md_id);

-- Consultation notes: author and consultation participants can view
CREATE POLICY consult_notes_select ON consultation_notes
  FOR SELECT USING (
    auth.uid() = author_id
    OR consultation_id IN (
      SELECT id FROM consultations
      WHERE patient_id = auth.uid() OR md_id = auth.uid()
    )
  );

CREATE POLICY consult_notes_insert_author ON consultation_notes
  FOR INSERT WITH CHECK (auth.uid() = author_id);

CREATE POLICY consult_notes_update_author ON consultation_notes
  FOR UPDATE USING (auth.uid() = author_id);

-- MD availability: MDs can manage their own, everyone can read
CREATE POLICY md_avail_select_all ON md_availability
  FOR SELECT USING (true);

CREATE POLICY md_avail_insert_own ON md_availability
  FOR INSERT WITH CHECK (auth.uid() = md_id);

CREATE POLICY md_avail_update_own ON md_availability
  FOR UPDATE USING (auth.uid() = md_id);

CREATE POLICY md_avail_delete_own ON md_availability
  FOR DELETE USING (auth.uid() = md_id);
