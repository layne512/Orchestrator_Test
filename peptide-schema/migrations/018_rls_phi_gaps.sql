-- RLS Policies for PHI Tables: user_intake_sessions & protocols
-- Fixes HIPAA gap — both tables contain PHI (symptoms, scores, treatment plans)
-- but previously had no RLS, allowing any authenticated user to read all data.
-- Uses cached (select auth.uid()) pattern and public.user_has_role('admin') helper
-- consistent with 008_rls_policies.sql

-- ============================================================
-- ENABLE ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE user_intake_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE protocols ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- USER INTAKE SESSIONS: patient owns, admins can view
-- ============================================================

-- Drop if re-running (idempotent)
DROP POLICY IF EXISTS intake_sessions_select_own ON user_intake_sessions;
DROP POLICY IF EXISTS intake_sessions_insert_own ON user_intake_sessions;
DROP POLICY IF EXISTS intake_sessions_update_own ON user_intake_sessions;

CREATE POLICY intake_sessions_select_own ON user_intake_sessions
  FOR SELECT USING (
    user_id = (select auth.uid())
    OR public.user_has_role('admin')
  );

CREATE POLICY intake_sessions_insert_own ON user_intake_sessions
  FOR INSERT WITH CHECK (user_id = (select auth.uid()));

CREATE POLICY intake_sessions_update_own ON user_intake_sessions
  FOR UPDATE USING (user_id = (select auth.uid()));

-- ============================================================
-- PROTOCOLS: patient owns, admins can view, assigned MDs can view
-- INSERT is service-role only (no permissive policy for authenticated)
-- ============================================================

-- Drop if re-running (idempotent)
DROP POLICY IF EXISTS protocols_select_own ON protocols;
DROP POLICY IF EXISTS protocols_select_assigned_md ON protocols;
DROP POLICY IF EXISTS protocols_update_own ON protocols;

-- Patient + admin SELECT
CREATE POLICY protocols_select_own ON protocols
  FOR SELECT USING (
    user_id = (select auth.uid())
    OR public.user_has_role('admin')
  );

-- Assigned MD can view their patients' protocols (via consultations)
CREATE POLICY protocols_select_assigned_md ON protocols
  FOR SELECT USING (
    user_id IN (
      SELECT patient_id FROM consultations
      WHERE md_id = (select auth.uid())
        AND status NOT IN ('cancelled', 'no_show')
    )
  );

-- No INSERT policy — protocols are created by service role only
-- (service role bypasses RLS)

-- Patient + admin UPDATE
CREATE POLICY protocols_update_own ON protocols
  FOR UPDATE USING (
    user_id = (select auth.uid())
    OR public.user_has_role('admin')
  );
