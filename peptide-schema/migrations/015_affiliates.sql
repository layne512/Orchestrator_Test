-- Affiliate Program Schema Migration
-- Affiliate registration, tracking links, and commission tracking

-- ============================================================
-- AFFILIATES
-- ============================================================

CREATE TABLE affiliates (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  code              TEXT NOT NULL UNIQUE,                    -- unique tracking code
  status            TEXT DEFAULT 'active',                   -- 'active' | 'suspended' | 'deactivated'
  commission_rate   INTEGER DEFAULT 1000,                    -- basis points (1000 = 10%)
  total_clicks      INTEGER DEFAULT 0,
  payout_method     TEXT,                                    -- 'stripe_connect' | 'paypal' | 'check'
  payout_details    JSONB DEFAULT '{}',                      -- payout-specific info (encrypted at rest)
  created_at        TIMESTAMPTZ DEFAULT now(),
  updated_at        TIMESTAMPTZ DEFAULT now()
);

CREATE UNIQUE INDEX idx_affiliates_user     ON affiliates(user_id);
CREATE UNIQUE INDEX idx_affiliates_code     ON affiliates(code);
CREATE INDEX idx_affiliates_status          ON affiliates(status);

-- ============================================================
-- AFFILIATE REFERRALS
-- ============================================================

CREATE TABLE affiliate_referrals (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  affiliate_id        UUID NOT NULL REFERENCES affiliates(id) ON DELETE CASCADE,
  referred_email      TEXT NOT NULL,
  referred_user_id    UUID REFERENCES profiles(id) ON DELETE SET NULL,
  status              TEXT DEFAULT 'pending',                -- 'pending' | 'converted' | 'paid' | 'rejected'
  commission_amount   INTEGER DEFAULT 0,                     -- amount in cents
  order_amount        INTEGER DEFAULT 0,                     -- referred order amount in cents
  paid_at             TIMESTAMPTZ,
  created_at          TIMESTAMPTZ DEFAULT now(),
  updated_at          TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_referrals_affiliate   ON affiliate_referrals(affiliate_id);
CREATE INDEX idx_referrals_status      ON affiliate_referrals(status);
CREATE INDEX idx_referrals_email       ON affiliate_referrals(referred_email);

-- ============================================================
-- AUTO-UPDATE updated_at TRIGGERS
-- ============================================================

CREATE TRIGGER affiliates_updated_at
  BEFORE UPDATE ON affiliates
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER affiliate_referrals_updated_at
  BEFORE UPDATE ON affiliate_referrals
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE affiliates ENABLE ROW LEVEL SECURITY;
ALTER TABLE affiliate_referrals ENABLE ROW LEVEL SECURITY;

-- Affiliates: users can read/update their own record
CREATE POLICY affiliates_select_own ON affiliates
  FOR SELECT USING ((select auth.uid()) = user_id);

CREATE POLICY affiliates_insert_own ON affiliates
  FOR INSERT WITH CHECK ((select auth.uid()) = user_id);

CREATE POLICY affiliates_update_own ON affiliates
  FOR UPDATE USING ((select auth.uid()) = user_id);

-- Affiliate referrals: affiliates can see their own referrals
CREATE POLICY referrals_select_own ON affiliate_referrals
  FOR SELECT USING (
    affiliate_id IN (
      SELECT id FROM affiliates WHERE user_id = (select auth.uid())
    )
  );
