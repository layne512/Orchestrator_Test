-- Knowledge Base RLS Policies Migration
-- Enables Row Level Security on all 16 knowledge base tables
-- Public SELECT for scoring engine (unauthenticated reads)
-- Admin-only INSERT/UPDATE/DELETE restricted to admin_manager and admin_super roles
-- Uses existing public.user_has_role() from migration 008

-- ============================================================
-- SYMPTOMS: public read, admin-only writes
-- ============================================================

ALTER TABLE symptoms ENABLE ROW LEVEL SECURITY;

CREATE POLICY kb_symptoms_select ON symptoms
  FOR SELECT USING (true);

CREATE POLICY kb_symptoms_insert ON symptoms
  FOR INSERT WITH CHECK (
    public.user_has_role('admin_super') OR public.user_has_role('admin_manager')
  );

CREATE POLICY kb_symptoms_update ON symptoms
  FOR UPDATE USING (
    public.user_has_role('admin_super') OR public.user_has_role('admin_manager')
  );

CREATE POLICY kb_symptoms_delete ON symptoms
  FOR DELETE USING (
    public.user_has_role('admin_super') OR public.user_has_role('admin_manager')
  );

-- ============================================================
-- SYMPTOM QUALIFIERS: public read, admin-only writes
-- ============================================================

ALTER TABLE symptom_qualifiers ENABLE ROW LEVEL SECURITY;

CREATE POLICY kb_symptom_qualifiers_select ON symptom_qualifiers
  FOR SELECT USING (true);

CREATE POLICY kb_symptom_qualifiers_insert ON symptom_qualifiers
  FOR INSERT WITH CHECK (
    public.user_has_role('admin_super') OR public.user_has_role('admin_manager')
  );

CREATE POLICY kb_symptom_qualifiers_update ON symptom_qualifiers
  FOR UPDATE USING (
    public.user_has_role('admin_super') OR public.user_has_role('admin_manager')
  );

CREATE POLICY kb_symptom_qualifiers_delete ON symptom_qualifiers
  FOR DELETE USING (
    public.user_has_role('admin_super') OR public.user_has_role('admin_manager')
  );

-- ============================================================
-- SYMPTOM QUALIFIER OPTIONS: public read, admin-only writes
-- ============================================================

ALTER TABLE symptom_qualifier_options ENABLE ROW LEVEL SECURITY;

CREATE POLICY kb_symptom_qualifier_options_select ON symptom_qualifier_options
  FOR SELECT USING (true);

CREATE POLICY kb_symptom_qualifier_options_insert ON symptom_qualifier_options
  FOR INSERT WITH CHECK (
    public.user_has_role('admin_super') OR public.user_has_role('admin_manager')
  );

CREATE POLICY kb_symptom_qualifier_options_update ON symptom_qualifier_options
  FOR UPDATE USING (
    public.user_has_role('admin_super') OR public.user_has_role('admin_manager')
  );

CREATE POLICY kb_symptom_qualifier_options_delete ON symptom_qualifier_options
  FOR DELETE USING (
    public.user_has_role('admin_super') OR public.user_has_role('admin_manager')
  );

-- ============================================================
-- CONDITIONS: public read, admin-only writes
-- ============================================================

ALTER TABLE conditions ENABLE ROW LEVEL SECURITY;

CREATE POLICY kb_conditions_select ON conditions
  FOR SELECT USING (true);

CREATE POLICY kb_conditions_insert ON conditions
  FOR INSERT WITH CHECK (
    public.user_has_role('admin_super') OR public.user_has_role('admin_manager')
  );

CREATE POLICY kb_conditions_update ON conditions
  FOR UPDATE USING (
    public.user_has_role('admin_super') OR public.user_has_role('admin_manager')
  );

CREATE POLICY kb_conditions_delete ON conditions
  FOR DELETE USING (
    public.user_has_role('admin_super') OR public.user_has_role('admin_manager')
  );

-- ============================================================
-- SYMPTOM CONDITIONS: public read, admin-only writes
-- ============================================================

ALTER TABLE symptom_conditions ENABLE ROW LEVEL SECURITY;

CREATE POLICY kb_symptom_conditions_select ON symptom_conditions
  FOR SELECT USING (true);

CREATE POLICY kb_symptom_conditions_insert ON symptom_conditions
  FOR INSERT WITH CHECK (
    public.user_has_role('admin_super') OR public.user_has_role('admin_manager')
  );

CREATE POLICY kb_symptom_conditions_update ON symptom_conditions
  FOR UPDATE USING (
    public.user_has_role('admin_super') OR public.user_has_role('admin_manager')
  );

CREATE POLICY kb_symptom_conditions_delete ON symptom_conditions
  FOR DELETE USING (
    public.user_has_role('admin_super') OR public.user_has_role('admin_manager')
  );

-- ============================================================
-- SYMPTOM CONDITION QUALIFIER WEIGHTS: public read, admin-only writes
-- ============================================================

ALTER TABLE symptom_condition_qualifier_weights ENABLE ROW LEVEL SECURITY;

CREATE POLICY kb_symptom_condition_qualifier_weights_select ON symptom_condition_qualifier_weights
  FOR SELECT USING (true);

CREATE POLICY kb_symptom_condition_qualifier_weights_insert ON symptom_condition_qualifier_weights
  FOR INSERT WITH CHECK (
    public.user_has_role('admin_super') OR public.user_has_role('admin_manager')
  );

CREATE POLICY kb_symptom_condition_qualifier_weights_update ON symptom_condition_qualifier_weights
  FOR UPDATE USING (
    public.user_has_role('admin_super') OR public.user_has_role('admin_manager')
  );

CREATE POLICY kb_symptom_condition_qualifier_weights_delete ON symptom_condition_qualifier_weights
  FOR DELETE USING (
    public.user_has_role('admin_super') OR public.user_has_role('admin_manager')
  );

-- ============================================================
-- SYMPTOM CLUSTERS: public read, admin-only writes
-- ============================================================

ALTER TABLE symptom_clusters ENABLE ROW LEVEL SECURITY;

CREATE POLICY kb_symptom_clusters_select ON symptom_clusters
  FOR SELECT USING (true);

CREATE POLICY kb_symptom_clusters_insert ON symptom_clusters
  FOR INSERT WITH CHECK (
    public.user_has_role('admin_super') OR public.user_has_role('admin_manager')
  );

CREATE POLICY kb_symptom_clusters_update ON symptom_clusters
  FOR UPDATE USING (
    public.user_has_role('admin_super') OR public.user_has_role('admin_manager')
  );

CREATE POLICY kb_symptom_clusters_delete ON symptom_clusters
  FOR DELETE USING (
    public.user_has_role('admin_super') OR public.user_has_role('admin_manager')
  );

-- ============================================================
-- RISK FACTORS: public read, admin-only writes
-- ============================================================

ALTER TABLE risk_factors ENABLE ROW LEVEL SECURITY;

CREATE POLICY kb_risk_factors_select ON risk_factors
  FOR SELECT USING (true);

CREATE POLICY kb_risk_factors_insert ON risk_factors
  FOR INSERT WITH CHECK (
    public.user_has_role('admin_super') OR public.user_has_role('admin_manager')
  );

CREATE POLICY kb_risk_factors_update ON risk_factors
  FOR UPDATE USING (
    public.user_has_role('admin_super') OR public.user_has_role('admin_manager')
  );

CREATE POLICY kb_risk_factors_delete ON risk_factors
  FOR DELETE USING (
    public.user_has_role('admin_super') OR public.user_has_role('admin_manager')
  );

-- ============================================================
-- CONDITION RISK FACTORS: public read, admin-only writes
-- ============================================================

ALTER TABLE condition_risk_factors ENABLE ROW LEVEL SECURITY;

CREATE POLICY kb_condition_risk_factors_select ON condition_risk_factors
  FOR SELECT USING (true);

CREATE POLICY kb_condition_risk_factors_insert ON condition_risk_factors
  FOR INSERT WITH CHECK (
    public.user_has_role('admin_super') OR public.user_has_role('admin_manager')
  );

CREATE POLICY kb_condition_risk_factors_update ON condition_risk_factors
  FOR UPDATE USING (
    public.user_has_role('admin_super') OR public.user_has_role('admin_manager')
  );

CREATE POLICY kb_condition_risk_factors_delete ON condition_risk_factors
  FOR DELETE USING (
    public.user_has_role('admin_super') OR public.user_has_role('admin_manager')
  );

-- ============================================================
-- LABS: public read, admin-only writes
-- ============================================================

ALTER TABLE labs ENABLE ROW LEVEL SECURITY;

CREATE POLICY kb_labs_select ON labs
  FOR SELECT USING (true);

CREATE POLICY kb_labs_insert ON labs
  FOR INSERT WITH CHECK (
    public.user_has_role('admin_super') OR public.user_has_role('admin_manager')
  );

CREATE POLICY kb_labs_update ON labs
  FOR UPDATE USING (
    public.user_has_role('admin_super') OR public.user_has_role('admin_manager')
  );

CREATE POLICY kb_labs_delete ON labs
  FOR DELETE USING (
    public.user_has_role('admin_super') OR public.user_has_role('admin_manager')
  );

-- ============================================================
-- CONDITION LABS: public read, admin-only writes
-- ============================================================

ALTER TABLE condition_labs ENABLE ROW LEVEL SECURITY;

CREATE POLICY kb_condition_labs_select ON condition_labs
  FOR SELECT USING (true);

CREATE POLICY kb_condition_labs_insert ON condition_labs
  FOR INSERT WITH CHECK (
    public.user_has_role('admin_super') OR public.user_has_role('admin_manager')
  );

CREATE POLICY kb_condition_labs_update ON condition_labs
  FOR UPDATE USING (
    public.user_has_role('admin_super') OR public.user_has_role('admin_manager')
  );

CREATE POLICY kb_condition_labs_delete ON condition_labs
  FOR DELETE USING (
    public.user_has_role('admin_super') OR public.user_has_role('admin_manager')
  );

-- ============================================================
-- PEPTIDE PROTOCOLS: public read, admin-only writes
-- ============================================================

ALTER TABLE peptide_protocols ENABLE ROW LEVEL SECURITY;

CREATE POLICY kb_peptide_protocols_select ON peptide_protocols
  FOR SELECT USING (true);

CREATE POLICY kb_peptide_protocols_insert ON peptide_protocols
  FOR INSERT WITH CHECK (
    public.user_has_role('admin_super') OR public.user_has_role('admin_manager')
  );

CREATE POLICY kb_peptide_protocols_update ON peptide_protocols
  FOR UPDATE USING (
    public.user_has_role('admin_super') OR public.user_has_role('admin_manager')
  );

CREATE POLICY kb_peptide_protocols_delete ON peptide_protocols
  FOR DELETE USING (
    public.user_has_role('admin_super') OR public.user_has_role('admin_manager')
  );

-- ============================================================
-- CONDITION PROTOCOLS: public read, admin-only writes
-- ============================================================

ALTER TABLE condition_protocols ENABLE ROW LEVEL SECURITY;

CREATE POLICY kb_condition_protocols_select ON condition_protocols
  FOR SELECT USING (true);

CREATE POLICY kb_condition_protocols_insert ON condition_protocols
  FOR INSERT WITH CHECK (
    public.user_has_role('admin_super') OR public.user_has_role('admin_manager')
  );

CREATE POLICY kb_condition_protocols_update ON condition_protocols
  FOR UPDATE USING (
    public.user_has_role('admin_super') OR public.user_has_role('admin_manager')
  );

CREATE POLICY kb_condition_protocols_delete ON condition_protocols
  FOR DELETE USING (
    public.user_has_role('admin_super') OR public.user_has_role('admin_manager')
  );

-- ============================================================
-- CONTRAINDICATIONS: public read, admin-only writes
-- ============================================================

ALTER TABLE contraindications ENABLE ROW LEVEL SECURITY;

CREATE POLICY kb_contraindications_select ON contraindications
  FOR SELECT USING (true);

CREATE POLICY kb_contraindications_insert ON contraindications
  FOR INSERT WITH CHECK (
    public.user_has_role('admin_super') OR public.user_has_role('admin_manager')
  );

CREATE POLICY kb_contraindications_update ON contraindications
  FOR UPDATE USING (
    public.user_has_role('admin_super') OR public.user_has_role('admin_manager')
  );

CREATE POLICY kb_contraindications_delete ON contraindications
  FOR DELETE USING (
    public.user_has_role('admin_super') OR public.user_has_role('admin_manager')
  );

-- ============================================================
-- PROTOCOL LABS: public read, admin-only writes
-- ============================================================

ALTER TABLE protocol_labs ENABLE ROW LEVEL SECURITY;

CREATE POLICY kb_protocol_labs_select ON protocol_labs
  FOR SELECT USING (true);

CREATE POLICY kb_protocol_labs_insert ON protocol_labs
  FOR INSERT WITH CHECK (
    public.user_has_role('admin_super') OR public.user_has_role('admin_manager')
  );

CREATE POLICY kb_protocol_labs_update ON protocol_labs
  FOR UPDATE USING (
    public.user_has_role('admin_super') OR public.user_has_role('admin_manager')
  );

CREATE POLICY kb_protocol_labs_delete ON protocol_labs
  FOR DELETE USING (
    public.user_has_role('admin_super') OR public.user_has_role('admin_manager')
  );

-- ============================================================
-- KNOWLEDGE DOCUMENTS: public read, admin-only writes
-- ============================================================

ALTER TABLE knowledge_documents ENABLE ROW LEVEL SECURITY;

CREATE POLICY kb_knowledge_documents_select ON knowledge_documents
  FOR SELECT USING (true);

CREATE POLICY kb_knowledge_documents_insert ON knowledge_documents
  FOR INSERT WITH CHECK (
    public.user_has_role('admin_super') OR public.user_has_role('admin_manager')
  );

CREATE POLICY kb_knowledge_documents_update ON knowledge_documents
  FOR UPDATE USING (
    public.user_has_role('admin_super') OR public.user_has_role('admin_manager')
  );

CREATE POLICY kb_knowledge_documents_delete ON knowledge_documents
  FOR DELETE USING (
    public.user_has_role('admin_super') OR public.user_has_role('admin_manager')
  );
