-- Comprehensive RLS Policies Migration
-- Replaces basic policies from 005/006/007 with optimized versions
-- Uses (select auth.uid()) subquery form for performance per Supabase best practices
-- See: https://supabase.com/docs/guides/database/postgres/row-level-security#use-security-definer-functions

-- ============================================================
-- HELPER: role-check function (SECURITY DEFINER for performance)
-- ============================================================

CREATE OR REPLACE FUNCTION public.user_has_role(role_name TEXT)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM user_roles ur
    JOIN roles r ON r.id = ur.role_id
    WHERE ur.user_id = (select auth.uid())
      AND r.name = role_name
      AND ur.is_active = true
      AND r.is_active = true
  );
$$;

-- ============================================================
-- DROP EXISTING POLICIES (from migrations 005, 006, 007)
-- ============================================================

-- 005: profiles, user_roles, md_credentials, md_state_licenses
DROP POLICY IF EXISTS profiles_select_own ON profiles;
DROP POLICY IF EXISTS profiles_update_own ON profiles;
DROP POLICY IF EXISTS user_roles_select_own ON user_roles;
DROP POLICY IF EXISTS md_creds_select_own ON md_credentials;
DROP POLICY IF EXISTS md_licenses_select_own ON md_state_licenses;

-- 006: health_history, consultations, consultation_notes, md_availability
DROP POLICY IF EXISTS health_history_select_own ON health_history;
DROP POLICY IF EXISTS health_history_insert_own ON health_history;
DROP POLICY IF EXISTS health_history_update_own ON health_history;
DROP POLICY IF EXISTS consultations_select_own ON consultations;
DROP POLICY IF EXISTS consultations_insert_patient ON consultations;
DROP POLICY IF EXISTS consultations_update_participants ON consultations;
DROP POLICY IF EXISTS consult_notes_select ON consultation_notes;
DROP POLICY IF EXISTS consult_notes_insert_author ON consultation_notes;
DROP POLICY IF EXISTS consult_notes_update_author ON consultation_notes;
DROP POLICY IF EXISTS md_avail_select_all ON md_availability;
DROP POLICY IF EXISTS md_avail_insert_own ON md_availability;
DROP POLICY IF EXISTS md_avail_update_own ON md_availability;
DROP POLICY IF EXISTS md_avail_delete_own ON md_availability;

-- 007: conversations, conversation_participants, messages, payments, subscriptions,
--      md_payouts, prescriptions, pharmacy_orders, consent_records
DROP POLICY IF EXISTS conversations_select_participant ON conversations;
DROP POLICY IF EXISTS conv_participants_select ON conversation_participants;
DROP POLICY IF EXISTS conv_participants_insert ON conversation_participants;
DROP POLICY IF EXISTS messages_select_participant ON messages;
DROP POLICY IF EXISTS messages_insert_sender ON messages;
DROP POLICY IF EXISTS payments_select_own ON payments;
DROP POLICY IF EXISTS subscriptions_select_own ON subscriptions;
DROP POLICY IF EXISTS md_payouts_select_own ON md_payouts;
DROP POLICY IF EXISTS prescriptions_select_own ON prescriptions;
DROP POLICY IF EXISTS prescriptions_insert_prescriber ON prescriptions;
DROP POLICY IF EXISTS prescriptions_update_prescriber ON prescriptions;
DROP POLICY IF EXISTS pharmacy_orders_select_own ON pharmacy_orders;
DROP POLICY IF EXISTS consent_records_select_own ON consent_records;
DROP POLICY IF EXISTS consent_records_insert_own ON consent_records;

-- ============================================================
-- PROFILES: users own their profile, admins can read all
-- ============================================================

CREATE POLICY profiles_select_own ON profiles
  FOR SELECT USING (
    id = (select auth.uid())
    OR public.user_has_role('admin')
  );

CREATE POLICY profiles_update_own ON profiles
  FOR UPDATE USING (id = (select auth.uid()));

CREATE POLICY profiles_insert_own ON profiles
  FOR INSERT WITH CHECK (id = (select auth.uid()));

-- ============================================================
-- USER ROLES: users see their own, admins see all
-- ============================================================

CREATE POLICY user_roles_select_own ON user_roles
  FOR SELECT USING (
    user_id = (select auth.uid())
    OR public.user_has_role('admin')
  );

-- ============================================================
-- MD CREDENTIALS: owner + admins can view
-- ============================================================

CREATE POLICY md_creds_select ON md_credentials
  FOR SELECT USING (
    user_id = (select auth.uid())
    OR public.user_has_role('admin')
  );

CREATE POLICY md_creds_update_own ON md_credentials
  FOR UPDATE USING (user_id = (select auth.uid()));

CREATE POLICY md_creds_insert_own ON md_credentials
  FOR INSERT WITH CHECK (user_id = (select auth.uid()));

-- ============================================================
-- MD STATE LICENSES: owner (via credential) + admins
-- ============================================================

CREATE POLICY md_licenses_select ON md_state_licenses
  FOR SELECT USING (
    credential_id IN (
      SELECT id FROM md_credentials WHERE user_id = (select auth.uid())
    )
    OR public.user_has_role('admin')
  );

CREATE POLICY md_licenses_insert_own ON md_state_licenses
  FOR INSERT WITH CHECK (
    credential_id IN (
      SELECT id FROM md_credentials WHERE user_id = (select auth.uid())
    )
  );

CREATE POLICY md_licenses_update_own ON md_state_licenses
  FOR UPDATE USING (
    credential_id IN (
      SELECT id FROM md_credentials WHERE user_id = (select auth.uid())
    )
  );

-- ============================================================
-- HEALTH HISTORY: patient-only access (PHI)
-- ============================================================

CREATE POLICY health_history_select_own ON health_history
  FOR SELECT USING (
    patient_id = (select auth.uid())
    OR public.user_has_role('admin')
  );

CREATE POLICY health_history_insert_own ON health_history
  FOR INSERT WITH CHECK (patient_id = (select auth.uid()));

CREATE POLICY health_history_update_own ON health_history
  FOR UPDATE USING (patient_id = (select auth.uid()));

-- MDs can read health history for their assigned consultations
CREATE POLICY health_history_select_assigned_md ON health_history
  FOR SELECT USING (
    patient_id IN (
      SELECT patient_id FROM consultations
      WHERE md_id = (select auth.uid())
        AND status NOT IN ('cancelled', 'no_show')
    )
  );

-- ============================================================
-- CONSULTATIONS: patient + assigned MD
-- ============================================================

CREATE POLICY consultations_select_own ON consultations
  FOR SELECT USING (
    patient_id = (select auth.uid())
    OR md_id = (select auth.uid())
    OR public.user_has_role('admin')
  );

CREATE POLICY consultations_insert_patient ON consultations
  FOR INSERT WITH CHECK (patient_id = (select auth.uid()));

CREATE POLICY consultations_update_participants ON consultations
  FOR UPDATE USING (
    patient_id = (select auth.uid())
    OR md_id = (select auth.uid())
  );

-- ============================================================
-- CONSULTATION NOTES: author + consultation participants
-- ============================================================

CREATE POLICY consult_notes_select ON consultation_notes
  FOR SELECT USING (
    author_id = (select auth.uid())
    OR consultation_id IN (
      SELECT id FROM consultations
      WHERE patient_id = (select auth.uid()) OR md_id = (select auth.uid())
    )
    OR public.user_has_role('admin')
  );

CREATE POLICY consult_notes_insert_author ON consultation_notes
  FOR INSERT WITH CHECK (author_id = (select auth.uid()));

CREATE POLICY consult_notes_update_author ON consultation_notes
  FOR UPDATE USING (author_id = (select auth.uid()));

-- ============================================================
-- MD AVAILABILITY: MDs manage own, everyone can read
-- ============================================================

CREATE POLICY md_avail_select_all ON md_availability
  FOR SELECT USING (true);

CREATE POLICY md_avail_insert_own ON md_availability
  FOR INSERT WITH CHECK (md_id = (select auth.uid()));

CREATE POLICY md_avail_update_own ON md_availability
  FOR UPDATE USING (md_id = (select auth.uid()));

CREATE POLICY md_avail_delete_own ON md_availability
  FOR DELETE USING (md_id = (select auth.uid()));

-- ============================================================
-- CONVERSATIONS: participants only
-- ============================================================

CREATE POLICY conversations_select_participant ON conversations
  FOR SELECT USING (
    id IN (
      SELECT conversation_id FROM conversation_participants
      WHERE user_id = (select auth.uid())
    )
    OR public.user_has_role('admin')
  );

CREATE POLICY conversations_update_participant ON conversations
  FOR UPDATE USING (
    id IN (
      SELECT conversation_id FROM conversation_participants
      WHERE user_id = (select auth.uid())
    )
  );

-- ============================================================
-- CONVERSATION PARTICIPANTS: participants of same conversation
-- ============================================================

CREATE POLICY conv_participants_select ON conversation_participants
  FOR SELECT USING (
    conversation_id IN (
      SELECT conversation_id FROM conversation_participants
      WHERE user_id = (select auth.uid())
    )
  );

CREATE POLICY conv_participants_insert ON conversation_participants
  FOR INSERT WITH CHECK (user_id = (select auth.uid()));

-- ============================================================
-- MESSAGES: conversation participants only
-- ============================================================

CREATE POLICY messages_select_participant ON messages
  FOR SELECT USING (
    conversation_id IN (
      SELECT conversation_id FROM conversation_participants
      WHERE user_id = (select auth.uid())
    )
  );

CREATE POLICY messages_insert_sender ON messages
  FOR INSERT WITH CHECK (
    sender_id = (select auth.uid())
    AND conversation_id IN (
      SELECT conversation_id FROM conversation_participants
      WHERE user_id = (select auth.uid())
    )
  );

CREATE POLICY messages_update_sender ON messages
  FOR UPDATE USING (sender_id = (select auth.uid()));

-- ============================================================
-- PAYMENTS: patient owns, admins can view
-- ============================================================

CREATE POLICY payments_select_own ON payments
  FOR SELECT USING (
    patient_id = (select auth.uid())
    OR public.user_has_role('admin')
  );

-- ============================================================
-- SUBSCRIPTIONS: patient owns
-- ============================================================

CREATE POLICY subscriptions_select_own ON subscriptions
  FOR SELECT USING (
    patient_id = (select auth.uid())
    OR public.user_has_role('admin')
  );

-- ============================================================
-- MD PAYOUTS: MD owns, admins can view
-- ============================================================

CREATE POLICY md_payouts_select_own ON md_payouts
  FOR SELECT USING (
    md_id = (select auth.uid())
    OR public.user_has_role('admin')
  );

-- ============================================================
-- PRESCRIPTIONS: patient + prescribing MD
-- ============================================================

CREATE POLICY prescriptions_select_own ON prescriptions
  FOR SELECT USING (
    patient_id = (select auth.uid())
    OR prescriber_id = (select auth.uid())
    OR public.user_has_role('admin')
  );

CREATE POLICY prescriptions_insert_prescriber ON prescriptions
  FOR INSERT WITH CHECK (prescriber_id = (select auth.uid()));

CREATE POLICY prescriptions_update_prescriber ON prescriptions
  FOR UPDATE USING (prescriber_id = (select auth.uid()));

-- ============================================================
-- PHARMACY ORDERS: patient + admins
-- ============================================================

CREATE POLICY pharmacy_orders_select_own ON pharmacy_orders
  FOR SELECT USING (
    patient_id = (select auth.uid())
    OR public.user_has_role('admin')
  );

-- ============================================================
-- CONSENT RECORDS: patient owns
-- ============================================================

CREATE POLICY consent_records_select_own ON consent_records
  FOR SELECT USING (
    patient_id = (select auth.uid())
    OR public.user_has_role('admin')
  );

CREATE POLICY consent_records_insert_own ON consent_records
  FOR INSERT WITH CHECK (patient_id = (select auth.uid()));

-- ============================================================
-- AUDIT LOGS: admin read-only (no direct user access)
-- ============================================================

ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY audit_logs_select_admin ON audit_logs
  FOR SELECT USING (public.user_has_role('admin'));

CREATE POLICY audit_logs_insert_system ON audit_logs
  FOR INSERT WITH CHECK (true);
-- Note: audit log inserts are expected from service role or triggers.
-- The permissive INSERT policy ensures RLS doesn't block audit writes
-- from authenticated users. Sensitive operations should use service role.
