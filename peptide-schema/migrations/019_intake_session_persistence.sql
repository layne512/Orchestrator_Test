-- ============================================================
-- Intake Session Persistence Migration
-- Adds JSONB columns for chat history, medication entries, and
-- risk factor entries to user_intake_sessions. These columns
-- enable full session state persistence so patients can resume
-- interrupted intake sessions after a page refresh.
-- ============================================================

-- ============================================================
-- 1. USER_INTAKE_SESSIONS: add JSONB columns for session state
-- ============================================================

-- Chat messages (array of {role, content} objects from the AI chatbot)
ALTER TABLE user_intake_sessions
  ADD COLUMN IF NOT EXISTS chat_messages JSONB DEFAULT '[]'::jsonb;

-- Medication entries (array of {medication_id, medication_name} objects)
ALTER TABLE user_intake_sessions
  ADD COLUMN IF NOT EXISTS medication_entries JSONB DEFAULT '[]'::jsonb;

-- Risk factor entries (structured risk factor data for restore)
ALTER TABLE user_intake_sessions
  ADD COLUMN IF NOT EXISTS risk_factor_entries JSONB DEFAULT '[]'::jsonb;

-- ============================================================
-- 2. INDEX: composite index for finding active sessions by user
-- ============================================================

-- Supports the "find resumable session" query:
--   SELECT * FROM user_intake_sessions
--   WHERE user_id = $1 AND status = 'active'
--   ORDER BY updated_at DESC LIMIT 1
CREATE INDEX IF NOT EXISTS idx_sessions_user_status
  ON user_intake_sessions(user_id, status)
  WHERE user_id IS NOT NULL;
