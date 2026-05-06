-- Messaging, Payments, Prescriptions, and Pharmacy Schema Migration
-- Conversations, payments/subscriptions, Rx management, pharmacy orders, consent, audit logs

-- ============================================================
-- CONVERSATIONS (messaging threads)
-- ============================================================

CREATE TABLE conversations (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  consultation_id UUID REFERENCES consultations(id) ON DELETE SET NULL,
  subject         TEXT,
  type            TEXT NOT NULL DEFAULT 'consultation', -- "consultation" | "support" | "system"
  status          TEXT NOT NULL DEFAULT 'open',         -- "open" | "closed" | "archived"
  created_at      TIMESTAMPTZ DEFAULT now(),
  updated_at      TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_conversations_consultation ON conversations(consultation_id) WHERE consultation_id IS NOT NULL;
CREATE INDEX idx_conversations_status       ON conversations(status);

-- ============================================================
-- CONVERSATION PARTICIPANTS
-- ============================================================

CREATE TABLE conversation_participants (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  user_id         UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  role            TEXT NOT NULL DEFAULT 'member',       -- "member" | "owner"
  last_read_at    TIMESTAMPTZ,
  is_muted        BOOLEAN DEFAULT false,
  joined_at       TIMESTAMPTZ DEFAULT now(),
  UNIQUE (conversation_id, user_id)
);

CREATE INDEX idx_conv_participants_user ON conversation_participants(user_id);
CREATE INDEX idx_conv_participants_conv ON conversation_participants(conversation_id);

-- ============================================================
-- MESSAGES (with Supabase Realtime support)
-- ============================================================

CREATE TABLE messages (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  sender_id       UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  body            TEXT NOT NULL,
  message_type    TEXT NOT NULL DEFAULT 'text',         -- "text" | "image" | "file" | "system"
  metadata        JSONB DEFAULT '{}'::jsonb,            -- {file_url, file_name, file_size, mime_type}
  parent_id       UUID REFERENCES messages(id) ON DELETE SET NULL, -- thread replies
  is_edited       BOOLEAN DEFAULT false,
  edited_at       TIMESTAMPTZ,
  is_deleted      BOOLEAN DEFAULT false,
  created_at      TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_messages_conversation  ON messages(conversation_id, created_at);
CREATE INDEX idx_messages_sender        ON messages(sender_id);
CREATE INDEX idx_messages_parent        ON messages(parent_id) WHERE parent_id IS NOT NULL;

-- Enable Supabase Realtime for messages table
ALTER PUBLICATION supabase_realtime ADD TABLE messages;

-- ============================================================
-- PAYMENTS (Stripe references)
-- ============================================================

CREATE TABLE payments (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id          UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  consultation_id     UUID REFERENCES consultations(id) ON DELETE SET NULL,
  stripe_payment_id   TEXT UNIQUE,                      -- Stripe PaymentIntent ID (pi_xxx)
  stripe_charge_id    TEXT,                              -- Stripe Charge ID (ch_xxx)
  amount_cents        INTEGER NOT NULL,                  -- amount in cents
  currency            TEXT NOT NULL DEFAULT 'usd',
  status              TEXT NOT NULL DEFAULT 'pending',   -- "pending" | "processing" | "succeeded" | "failed" | "refunded" | "partially_refunded"
  payment_type        TEXT NOT NULL,                     -- "consultation" | "prescription" | "subscription" | "pharmacy_order"
  description         TEXT,
  failure_reason      TEXT,
  refund_amount_cents INTEGER,
  refunded_at         TIMESTAMPTZ,
  metadata            JSONB DEFAULT '{}'::jsonb,
  created_at          TIMESTAMPTZ DEFAULT now(),
  updated_at          TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_payments_patient       ON payments(patient_id);
CREATE INDEX idx_payments_consultation  ON payments(consultation_id) WHERE consultation_id IS NOT NULL;
CREATE INDEX idx_payments_stripe        ON payments(stripe_payment_id) WHERE stripe_payment_id IS NOT NULL;
CREATE INDEX idx_payments_status        ON payments(status);
CREATE INDEX idx_payments_type          ON payments(payment_type);

-- ============================================================
-- SUBSCRIPTIONS (recurring billing)
-- ============================================================

CREATE TABLE subscriptions (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id              UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  stripe_subscription_id  TEXT UNIQUE,                  -- Stripe Subscription ID (sub_xxx)
  stripe_customer_id      TEXT,                          -- Stripe Customer ID (cus_xxx)
  plan_name               TEXT NOT NULL,                 -- "basic" | "premium" | "peptide_monthly"
  status                  TEXT NOT NULL DEFAULT 'active', -- "active" | "past_due" | "cancelled" | "paused" | "trialing"
  amount_cents            INTEGER NOT NULL,
  currency                TEXT NOT NULL DEFAULT 'usd',
  interval                TEXT NOT NULL DEFAULT 'month', -- "month" | "year"
  current_period_start    TIMESTAMPTZ,
  current_period_end      TIMESTAMPTZ,
  cancel_at_period_end    BOOLEAN DEFAULT false,
  cancelled_at            TIMESTAMPTZ,
  trial_start             TIMESTAMPTZ,
  trial_end               TIMESTAMPTZ,
  metadata                JSONB DEFAULT '{}'::jsonb,
  created_at              TIMESTAMPTZ DEFAULT now(),
  updated_at              TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_subscriptions_patient  ON subscriptions(patient_id);
CREATE INDEX idx_subscriptions_stripe   ON subscriptions(stripe_subscription_id) WHERE stripe_subscription_id IS NOT NULL;
CREATE INDEX idx_subscriptions_status   ON subscriptions(status);

-- ============================================================
-- MD PAYOUTS
-- ============================================================

CREATE TABLE md_payouts (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  md_id                   UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  consultation_id         UUID REFERENCES consultations(id) ON DELETE SET NULL,
  stripe_transfer_id      TEXT UNIQUE,                  -- Stripe Transfer ID (tr_xxx)
  stripe_connect_account  TEXT,                          -- Stripe Connect account ID (acct_xxx)
  amount_cents            INTEGER NOT NULL,
  currency                TEXT NOT NULL DEFAULT 'usd',
  status                  TEXT NOT NULL DEFAULT 'pending', -- "pending" | "processing" | "paid" | "failed"
  payout_period_start     TIMESTAMPTZ,
  payout_period_end       TIMESTAMPTZ,
  failure_reason          TEXT,
  paid_at                 TIMESTAMPTZ,
  metadata                JSONB DEFAULT '{}'::jsonb,
  created_at              TIMESTAMPTZ DEFAULT now(),
  updated_at              TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_md_payouts_md          ON md_payouts(md_id);
CREATE INDEX idx_md_payouts_consultation ON md_payouts(consultation_id) WHERE consultation_id IS NOT NULL;
CREATE INDEX idx_md_payouts_status      ON md_payouts(status);
CREATE INDEX idx_md_payouts_stripe      ON md_payouts(stripe_transfer_id) WHERE stripe_transfer_id IS NOT NULL;

-- ============================================================
-- PRESCRIPTIONS (Rx details, DoseSpot references)
-- ============================================================

CREATE TABLE prescriptions (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  consultation_id     UUID NOT NULL REFERENCES consultations(id) ON DELETE CASCADE,
  patient_id          UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  prescriber_id       UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  dosespot_rx_id      TEXT,                              -- DoseSpot prescription ID
  dosespot_patient_id TEXT,                              -- DoseSpot patient ID
  medication_name     TEXT NOT NULL,                     -- "BPC-157 5mg vial"
  medication_ndc      TEXT,                              -- National Drug Code
  strength            TEXT,                              -- "5mg/mL"
  quantity            NUMERIC NOT NULL,                  -- number of units
  quantity_unit       TEXT DEFAULT 'vial',               -- "vial" | "capsule" | "syringe" | "tablet"
  directions          TEXT NOT NULL,                     -- sig: "Inject 250mcg subcutaneously twice daily"
  refills             INTEGER DEFAULT 0,
  days_supply         INTEGER,
  route               TEXT,                              -- "subcutaneous" | "oral" | "intranasal" | "topical"
  frequency           TEXT,                              -- "twice daily" | "once daily" | "as needed"
  status              TEXT NOT NULL DEFAULT 'draft',     -- "draft" | "pending_review" | "signed" | "sent_to_pharmacy" | "filled" | "cancelled" | "denied"
  prescribed_at       TIMESTAMPTZ,
  signed_at           TIMESTAMPTZ,
  sent_to_pharmacy_at TIMESTAMPTZ,
  pharmacy_type       TEXT,                              -- "503A" | "503B"
  pharmacy_name       TEXT,
  pharmacy_npi        TEXT,
  denial_reason       TEXT,
  notes               TEXT,                              -- prescriber notes
  metadata            JSONB DEFAULT '{}'::jsonb,
  created_at          TIMESTAMPTZ DEFAULT now(),
  updated_at          TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_rx_consultation   ON prescriptions(consultation_id);
CREATE INDEX idx_rx_patient        ON prescriptions(patient_id);
CREATE INDEX idx_rx_prescriber     ON prescriptions(prescriber_id);
CREATE INDEX idx_rx_status         ON prescriptions(status);
CREATE INDEX idx_rx_dosespot       ON prescriptions(dosespot_rx_id) WHERE dosespot_rx_id IS NOT NULL;
CREATE INDEX idx_rx_medication     ON prescriptions(medication_name);

-- ============================================================
-- PHARMACY ORDERS (503A/503B fulfillment)
-- ============================================================

CREATE TABLE pharmacy_orders (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  prescription_id     UUID NOT NULL REFERENCES prescriptions(id) ON DELETE CASCADE,
  patient_id          UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  pharmacy_type       TEXT NOT NULL,                     -- "503A" | "503B"
  pharmacy_name       TEXT NOT NULL,
  pharmacy_npi        TEXT,
  pharmacy_phone      TEXT,
  pharmacy_email      TEXT,
  pharmacy_address    JSONB,                             -- {line1, line2, city, state, zip}
  order_number        TEXT UNIQUE,                       -- pharmacy-assigned order number
  status              TEXT NOT NULL DEFAULT 'pending',   -- "pending" | "received" | "compounding" | "quality_check" | "shipped" | "delivered" | "cancelled" | "returned"
  shipping_carrier    TEXT,                              -- "USPS" | "FedEx" | "UPS"
  tracking_number     TEXT,
  shipped_at          TIMESTAMPTZ,
  delivered_at        TIMESTAMPTZ,
  estimated_delivery  DATE,
  amount_cents        INTEGER,                           -- pharmacy charge in cents
  payment_id          UUID REFERENCES payments(id) ON DELETE SET NULL,
  notes               TEXT,
  metadata            JSONB DEFAULT '{}'::jsonb,
  created_at          TIMESTAMPTZ DEFAULT now(),
  updated_at          TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_pharm_orders_rx       ON pharmacy_orders(prescription_id);
CREATE INDEX idx_pharm_orders_patient  ON pharmacy_orders(patient_id);
CREATE INDEX idx_pharm_orders_status   ON pharmacy_orders(status);
CREATE INDEX idx_pharm_orders_type     ON pharmacy_orders(pharmacy_type);
CREATE INDEX idx_pharm_orders_tracking ON pharmacy_orders(tracking_number) WHERE tracking_number IS NOT NULL;

-- ============================================================
-- CONSENT RECORDS
-- ============================================================

CREATE TABLE consent_records (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id      UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  consent_type    TEXT NOT NULL,                         -- "telehealth" | "treatment" | "hipaa" | "informed_consent" | "pharmacy" | "subscription"
  consent_version TEXT NOT NULL DEFAULT '1.0',           -- version of the consent document
  document_url    TEXT,                                  -- link to signed consent PDF
  consultation_id UUID REFERENCES consultations(id) ON DELETE SET NULL,
  prescription_id UUID REFERENCES prescriptions(id) ON DELETE SET NULL,
  ip_address      INET,
  user_agent      TEXT,
  is_granted      BOOLEAN NOT NULL DEFAULT true,
  granted_at      TIMESTAMPTZ DEFAULT now(),
  revoked_at      TIMESTAMPTZ,
  revocation_reason TEXT,
  metadata        JSONB DEFAULT '{}'::jsonb,
  created_at      TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_consent_patient    ON consent_records(patient_id);
CREATE INDEX idx_consent_type       ON consent_records(consent_type);
CREATE INDEX idx_consent_granted    ON consent_records(patient_id, consent_type, is_granted) WHERE is_granted = true;
CREATE INDEX idx_consent_consult    ON consent_records(consultation_id) WHERE consultation_id IS NOT NULL;

-- ============================================================
-- AUDIT LOGS
-- ============================================================

CREATE TABLE audit_logs (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID REFERENCES profiles(id) ON DELETE SET NULL,
  action      TEXT NOT NULL,                             -- "create" | "update" | "delete" | "login" | "logout" | "consent" | "prescription.sign" | etc.
  entity_type TEXT,                                      -- "consultation" | "prescription" | "payment" | "profile" | etc.
  entity_id   UUID,                                      -- ID of the affected record
  changes     JSONB,                                     -- {field: {old: x, new: y}} for updates
  ip_address  INET,
  user_agent  TEXT,
  metadata    JSONB DEFAULT '{}'::jsonb,
  created_at  TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_audit_user     ON audit_logs(user_id);
CREATE INDEX idx_audit_action   ON audit_logs(action);
CREATE INDEX idx_audit_entity   ON audit_logs(entity_type, entity_id);
CREATE INDEX idx_audit_created  ON audit_logs(created_at);

-- ============================================================
-- AUTO-UPDATE updated_at TRIGGERS
-- ============================================================

CREATE TRIGGER conversations_updated_at
  BEFORE UPDATE ON conversations
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER payments_updated_at
  BEFORE UPDATE ON payments
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER subscriptions_updated_at
  BEFORE UPDATE ON subscriptions
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER md_payouts_updated_at
  BEFORE UPDATE ON md_payouts
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER prescriptions_updated_at
  BEFORE UPDATE ON prescriptions
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER pharmacy_orders_updated_at
  BEFORE UPDATE ON pharmacy_orders
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversation_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE md_payouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE prescriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE pharmacy_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE consent_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- Conversations: participants can view their conversations
CREATE POLICY conversations_select_participant ON conversations
  FOR SELECT USING (
    id IN (SELECT conversation_id FROM conversation_participants WHERE user_id = auth.uid())
  );

-- Conversation participants: can view participants of their conversations
CREATE POLICY conv_participants_select ON conversation_participants
  FOR SELECT USING (
    conversation_id IN (SELECT conversation_id FROM conversation_participants WHERE user_id = auth.uid())
  );

CREATE POLICY conv_participants_insert ON conversation_participants
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Messages: participants can view and send messages in their conversations
CREATE POLICY messages_select_participant ON messages
  FOR SELECT USING (
    conversation_id IN (SELECT conversation_id FROM conversation_participants WHERE user_id = auth.uid())
  );

CREATE POLICY messages_insert_sender ON messages
  FOR INSERT WITH CHECK (
    auth.uid() = sender_id
    AND conversation_id IN (SELECT conversation_id FROM conversation_participants WHERE user_id = auth.uid())
  );

-- Payments: patients can view their own payments
CREATE POLICY payments_select_own ON payments
  FOR SELECT USING (auth.uid() = patient_id);

-- Subscriptions: patients can view their own subscriptions
CREATE POLICY subscriptions_select_own ON subscriptions
  FOR SELECT USING (auth.uid() = patient_id);

-- MD payouts: MDs can view their own payouts
CREATE POLICY md_payouts_select_own ON md_payouts
  FOR SELECT USING (auth.uid() = md_id);

-- Prescriptions: patients and prescribers can view
CREATE POLICY prescriptions_select_own ON prescriptions
  FOR SELECT USING (auth.uid() = patient_id OR auth.uid() = prescriber_id);

CREATE POLICY prescriptions_insert_prescriber ON prescriptions
  FOR INSERT WITH CHECK (auth.uid() = prescriber_id);

CREATE POLICY prescriptions_update_prescriber ON prescriptions
  FOR UPDATE USING (auth.uid() = prescriber_id);

-- Pharmacy orders: patients can view their own orders
CREATE POLICY pharmacy_orders_select_own ON pharmacy_orders
  FOR SELECT USING (auth.uid() = patient_id);

-- Consent records: patients can view their own consent records
CREATE POLICY consent_records_select_own ON consent_records
  FOR SELECT USING (auth.uid() = patient_id);

CREATE POLICY consent_records_insert_own ON consent_records
  FOR INSERT WITH CHECK (auth.uid() = patient_id);

-- Audit logs: only viewable by admins (no direct user policy)
-- Admin access will be handled via service role or custom admin policies
