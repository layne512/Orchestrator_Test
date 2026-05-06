-- User Management Schema Migration
-- Profiles, roles, MD credentials for telehealth marketplace

-- ============================================================
-- PROFILES (linked to Supabase auth.users)
-- ============================================================

CREATE TABLE profiles (
  id              UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email           TEXT NOT NULL,
  first_name      TEXT,
  last_name       TEXT,
  display_name    TEXT,
  phone           TEXT,
  date_of_birth   DATE,
  sex             TEXT,                           -- "male" | "female" | "other"
  avatar_url      TEXT,
  timezone        TEXT DEFAULT 'America/New_York',
  address_line1   TEXT,
  address_line2   TEXT,
  city            TEXT,
  state           TEXT,                           -- 2-letter state code
  zip_code        TEXT,
  is_active       BOOLEAN DEFAULT true,
  created_at      TIMESTAMPTZ DEFAULT now(),
  updated_at      TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_profiles_email    ON profiles(email);
CREATE INDEX idx_profiles_active   ON profiles(is_active);
CREATE INDEX idx_profiles_state    ON profiles(state);

-- ============================================================
-- ROLES
-- ============================================================

CREATE TABLE roles (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL UNIQUE,              -- "patient" | "md" | "admin"
  subtype     TEXT,                              -- e.g. "endocrinologist", "super_admin"
  description TEXT,
  is_active   BOOLEAN DEFAULT true,
  created_at  TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_roles_name ON roles(name);

-- Seed default roles
INSERT INTO roles (name, subtype, description) VALUES
  ('patient', NULL,            'Patient user'),
  ('md',      NULL,            'Licensed medical provider'),
  ('admin',   NULL,            'Platform administrator'),
  ('admin',   'super_admin',   'Super administrator with full access')
ON CONFLICT (name) DO NOTHING;

-- ============================================================
-- USER_ROLES (junction table)
-- ============================================================

CREATE TABLE user_roles (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  role_id    UUID NOT NULL REFERENCES roles(id)    ON DELETE CASCADE,
  granted_at TIMESTAMPTZ DEFAULT now(),
  granted_by UUID REFERENCES profiles(id),
  is_active  BOOLEAN DEFAULT true,
  UNIQUE (user_id, role_id)
);

CREATE INDEX idx_user_roles_user ON user_roles(user_id);
CREATE INDEX idx_user_roles_role ON user_roles(role_id);

-- ============================================================
-- MD CREDENTIALS
-- ============================================================

CREATE TABLE md_credentials (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id                 UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  npi_number              TEXT UNIQUE,             -- National Provider Identifier
  dea_number              TEXT,                    -- DEA registration number
  medical_school          TEXT,
  graduation_year         INTEGER,
  specialty               TEXT,                    -- "endocrinology" | "internal_medicine" | etc.
  board_certified         BOOLEAN DEFAULT false,
  verification_status     TEXT DEFAULT 'pending',  -- "pending" | "under_review" | "verified" | "rejected" | "expired"
  verified_at             TIMESTAMPTZ,
  verified_by             UUID REFERENCES profiles(id),
  rejection_reason        TEXT,
  malpractice_carrier     TEXT,
  malpractice_policy_num  TEXT,
  malpractice_expiry      DATE,
  created_at              TIMESTAMPTZ DEFAULT now(),
  updated_at              TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_md_creds_user       ON md_credentials(user_id);
CREATE INDEX idx_md_creds_npi        ON md_credentials(npi_number);
CREATE INDEX idx_md_creds_status     ON md_credentials(verification_status);

-- ============================================================
-- MD STATE LICENSES
-- ============================================================

CREATE TABLE md_state_licenses (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  credential_id   UUID NOT NULL REFERENCES md_credentials(id) ON DELETE CASCADE,
  state           TEXT NOT NULL,                  -- 2-letter state code
  license_number  TEXT NOT NULL,
  license_type    TEXT DEFAULT 'MD',              -- "MD" | "DO" | "NP" | "PA"
  issued_date     DATE,
  expiry_date     DATE,
  is_active       BOOLEAN DEFAULT true,
  verified        BOOLEAN DEFAULT false,
  created_at      TIMESTAMPTZ DEFAULT now(),
  UNIQUE (credential_id, state, license_number)
);

CREATE INDEX idx_md_licenses_cred    ON md_state_licenses(credential_id);
CREATE INDEX idx_md_licenses_state   ON md_state_licenses(state);
CREATE INDEX idx_md_licenses_expiry  ON md_state_licenses(expiry_date);

-- ============================================================
-- AUTO-UPDATE updated_at TRIGGER
-- ============================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER md_credentials_updated_at
  BEFORE UPDATE ON md_credentials
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE md_credentials ENABLE ROW LEVEL SECURITY;
ALTER TABLE md_state_licenses ENABLE ROW LEVEL SECURITY;

-- Profiles: users can read/update their own profile
CREATE POLICY profiles_select_own ON profiles
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY profiles_update_own ON profiles
  FOR UPDATE USING (auth.uid() = id);

-- User roles: users can see their own roles
CREATE POLICY user_roles_select_own ON user_roles
  FOR SELECT USING (auth.uid() = user_id);

-- MD credentials: owners can view their own, admins can view all
CREATE POLICY md_creds_select_own ON md_credentials
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY md_licenses_select_own ON md_state_licenses
  FOR SELECT USING (
    credential_id IN (
      SELECT id FROM md_credentials WHERE user_id = auth.uid()
    )
  );
