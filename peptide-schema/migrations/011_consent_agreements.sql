-- Consent & Agreement Management Schema
-- Tracks patient consent for telehealth, HIPAA, and terms of service
-- Supports e-signature capture and document versioning

-- ============================================================
-- CONSENT DOCUMENT TEMPLATES
-- ============================================================

CREATE TABLE consent_documents (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type            TEXT NOT NULL,                    -- "telehealth_informed_consent" | "hipaa_notice" | "terms_of_service"
  title           TEXT NOT NULL,
  version         INTEGER NOT NULL DEFAULT 1,
  content         TEXT NOT NULL,                    -- Full document text (markdown)
  summary         TEXT,                             -- Short plain-language summary
  is_active       BOOLEAN DEFAULT true,
  requires_signature BOOLEAN DEFAULT true,
  created_at      TIMESTAMPTZ DEFAULT now(),
  updated_at      TIMESTAMPTZ DEFAULT now(),
  UNIQUE (type, version)
);

CREATE INDEX idx_consent_docs_type    ON consent_documents(type);
CREATE INDEX idx_consent_docs_active  ON consent_documents(is_active);

-- ============================================================
-- PATIENT CONSENT AGREEMENTS
-- ============================================================

CREATE TABLE patient_consents (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  document_id     UUID NOT NULL REFERENCES consent_documents(id),
  document_type   TEXT NOT NULL,                    -- denormalized for fast lookup
  document_version INTEGER NOT NULL,               -- denormalized for fast lookup
  status          TEXT NOT NULL DEFAULT 'pending',  -- "pending" | "signed" | "declined" | "revoked" | "expired"
  signed_at       TIMESTAMPTZ,
  signature_data  JSONB,                           -- { method, ip_address, user_agent, signature_id }
  ip_address      INET,
  user_agent      TEXT,
  revoked_at      TIMESTAMPTZ,
  revocation_reason TEXT,
  expires_at      TIMESTAMPTZ,
  created_at      TIMESTAMPTZ DEFAULT now(),
  updated_at      TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_patient_consents_user     ON patient_consents(user_id);
CREATE INDEX idx_patient_consents_doc      ON patient_consents(document_id);
CREATE INDEX idx_patient_consents_type     ON patient_consents(document_type);
CREATE INDEX idx_patient_consents_status   ON patient_consents(status);
CREATE INDEX idx_patient_consents_user_type ON patient_consents(user_id, document_type, status);

-- ============================================================
-- E-SIGNATURE REQUESTS (Dropbox Sign / DocuSign tracking)
-- ============================================================

CREATE TABLE esignature_requests (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  consent_id      UUID NOT NULL REFERENCES patient_consents(id) ON DELETE CASCADE,
  provider        TEXT NOT NULL DEFAULT 'internal', -- "internal" | "dropbox_sign" | "docusign"
  external_id     TEXT,                             -- ID from external provider
  status          TEXT NOT NULL DEFAULT 'pending',  -- "pending" | "sent" | "viewed" | "signed" | "declined" | "error"
  request_url     TEXT,                             -- signing URL if applicable
  callback_data   JSONB,                            -- webhook response data
  error_message   TEXT,
  sent_at         TIMESTAMPTZ,
  completed_at    TIMESTAMPTZ,
  created_at      TIMESTAMPTZ DEFAULT now(),
  updated_at      TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_esig_consent    ON esignature_requests(consent_id);
CREATE INDEX idx_esig_external   ON esignature_requests(external_id);
CREATE INDEX idx_esig_status     ON esignature_requests(status);

-- ============================================================
-- AUTO-UPDATE updated_at TRIGGERS
-- ============================================================

CREATE TRIGGER consent_documents_updated_at
  BEFORE UPDATE ON consent_documents
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER patient_consents_updated_at
  BEFORE UPDATE ON patient_consents
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER esignature_requests_updated_at
  BEFORE UPDATE ON esignature_requests
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE consent_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE patient_consents ENABLE ROW LEVEL SECURITY;
ALTER TABLE esignature_requests ENABLE ROW LEVEL SECURITY;

-- Consent documents: anyone authenticated can read active documents
CREATE POLICY consent_docs_select ON consent_documents
  FOR SELECT USING (is_active = true);

-- Patient consents: users can view their own
CREATE POLICY patient_consents_select_own ON patient_consents
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY patient_consents_insert_own ON patient_consents
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY patient_consents_update_own ON patient_consents
  FOR UPDATE USING (auth.uid() = user_id);

-- E-signature requests: users can view their own (via consent relationship)
CREATE POLICY esig_select_own ON esignature_requests
  FOR SELECT USING (
    consent_id IN (
      SELECT id FROM patient_consents WHERE user_id = auth.uid()
    )
  );

-- ============================================================
-- SEED DEFAULT CONSENT DOCUMENTS
-- ============================================================

INSERT INTO consent_documents (type, title, version, content, summary, requires_signature) VALUES
(
  'telehealth_informed_consent',
  'Telehealth Informed Consent',
  1,
  E'# Telehealth Informed Consent\n\n## Purpose\nThis document confirms your informed consent to receive telehealth services through SuperPumped Peptides. Telehealth involves the use of electronic communications to enable healthcare providers to deliver care at a distance.\n\n## Nature of Telehealth Services\nTelehealth services may include, but are not limited to:\n- **Asynchronous consultations** — review of your health information, intake responses, and lab results by a licensed physician\n- **Synchronous video consultations** — real-time video appointments with a licensed physician\n- **Secure messaging** — HIPAA-compliant communication between you and your care team\n- **Prescription services** — electronic prescribing of peptide therapies and related medications\n- **Lab ordering** — ordering of diagnostic lab work through partner laboratories\n\n## Benefits & Risks\n**Benefits** include improved access to medical care, convenience, and reduced travel. **Risks** include the possibility that information transmitted may not be sufficient for appropriate medical decision-making, delays in evaluation or treatment due to technology failures, and the rare possibility of security breaches despite safeguards.\n\n## Your Rights\n- You have the right to withdraw consent at any time without affecting your right to future care.\n- You have the right to request an in-person consultation at any time.\n- You have the right to know who else may be present during a telehealth session.\n- All existing confidentiality protections apply to telehealth services.\n\n## Limitations\n- Telehealth is not appropriate for all medical conditions or emergencies.\n- If you experience a medical emergency, call 911 immediately.\n- Peptide therapy carries inherent risks; your prescribing physician will discuss these with you.\n\n## Consent\nBy signing below, I acknowledge that I have read and understand this Telehealth Informed Consent. I consent to receiving telehealth services as described above.',
  'Consent to receive telehealth medical services including remote consultations, prescriptions, and lab ordering through our platform.',
  true
),
(
  'hipaa_notice',
  'Notice of Privacy Practices (HIPAA)',
  1,
  E'# Notice of Privacy Practices\n\n## Your Information. Your Rights. Our Responsibilities.\n\nThis notice describes how medical information about you may be used and disclosed, and how you can get access to this information. **Please review it carefully.**\n\n## Your Rights\nWhen it comes to your health information, you have certain rights:\n- **Access** — You can ask to see or get an electronic or paper copy of your medical record and other health information.\n- **Correct** — You can ask us to correct health information that you think is incorrect or incomplete.\n- **Request confidential communications** — You can ask us to contact you in a specific way or at a specific address.\n- **Limit sharing** — You can ask us not to use or share certain health information for treatment, payment, or operations.\n- **Accounting of disclosures** — You can ask for a list of times we have shared your health information.\n- **Copy of this notice** — You can ask for a paper copy of this notice at any time.\n- **File a complaint** — You can file a complaint with the U.S. Department of Health and Human Services Office for Civil Rights.\n\n## Our Uses and Disclosures\nWe may use and share your health information for the following purposes:\n- **Treatment** — Providing, coordinating, and managing your healthcare and related services.\n- **Payment** — Processing payments and insurance claims for your healthcare.\n- **Healthcare Operations** — Improving care quality, training staff, and managing our practice.\n\n## Our Responsibilities\n- We are required by law to maintain the privacy and security of your protected health information (PHI).\n- We will let you know promptly if a breach occurs that may have compromised the privacy or security of your PHI.\n- We must follow the duties and privacy practices described in this notice.\n\n## Data Security\nAll health information is encrypted at rest and in transit. Access is restricted to authorized personnel only. We maintain comprehensive audit logs of all access to your health information.\n\n## Contact Information\nIf you have questions about this notice or wish to exercise your rights, contact our Privacy Officer at privacy@superpumpedpeptides.com.\n\n## Acknowledgment\nBy signing below, I acknowledge that I have received and reviewed this Notice of Privacy Practices.',
  'How we protect your health information (PHI), your rights to access and control it, and our legal obligations under HIPAA.',
  true
),
(
  'terms_of_service',
  'Terms of Service',
  1,
  E'# Terms of Service\n\n## Agreement to Terms\nBy accessing or using the SuperPumped Peptides platform, you agree to be bound by these Terms of Service.\n\n## Eligibility\n- You must be at least 18 years of age.\n- You must be located in a state where our services are available.\n- You must provide accurate and complete health information.\n\n## Services\nSuperPumped Peptides provides a telehealth marketplace connecting patients with licensed physicians who may prescribe peptide therapies. We are **not** your healthcare provider — we facilitate the connection between you and independent, licensed physicians.\n\n## Medical Disclaimer\n- All medical decisions are made by licensed physicians, not by the platform.\n- AI-generated protocols are suggestions only and require physician review and approval.\n- Peptide therapy is not appropriate for everyone; your physician will determine suitability.\n- Our platform is not a substitute for emergency medical care.\n\n## User Responsibilities\n- Provide accurate and truthful health information.\n- Follow your physician''s instructions regarding prescribed therapies.\n- Report any adverse effects promptly.\n- Keep your account credentials secure.\n- Do not share prescriptions or medications.\n\n## Payments & Subscriptions\n- Consultation fees, subscription costs, and medication prices are disclosed before purchase.\n- Refund policies are outlined in our Billing Policy.\n- Subscription cancellations take effect at the end of the current billing period.\n\n## Privacy\nYour use of our platform is also governed by our Notice of Privacy Practices (HIPAA) and Privacy Policy.\n\n## Limitation of Liability\nSuperPumped Peptides is a technology platform and is not liable for medical outcomes resulting from treatment prescribed by independent physicians.\n\n## Governing Law\nThese terms are governed by the laws of the State of Delaware.\n\n## Acceptance\nBy signing below, I acknowledge that I have read and agree to these Terms of Service.',
  'Platform usage terms including eligibility, medical disclaimers, user responsibilities, and payment policies.',
  true
);
