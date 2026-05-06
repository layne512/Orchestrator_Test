-- Migration 021: Goal-Driven Protocol Engine Schema
-- Creates 3 new tables (goal_protocols, protocol_supplements, protocol_phases)
-- and adds 7 metadata columns to peptide_protocols to power the goal-driven
-- protocol engine with convergence scoring, phased treatment sequencing,
-- and mechanism-based supplement stacking.

-- ============================================================
-- GOAL → PROTOCOL BRIDGE
-- Maps health goals to recommended peptide protocols with priority,
-- rationale, and PubMed references for evidence-based recommendations.
-- ============================================================

CREATE TABLE IF NOT EXISTS goal_protocols (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  goal_id          TEXT NOT NULL,                  -- health goal identifier from wizard
  protocol_id      UUID NOT NULL REFERENCES peptide_protocols(id) ON DELETE CASCADE,
  priority         INTEGER DEFAULT 1,              -- 1=first-line, 2=adjunct, 3=optional
  rationale        TEXT,                           -- why this protocol addresses this goal
  pubmed_ids       TEXT[] DEFAULT '{}',            -- PubMed reference IDs supporting the mapping
  citation_summary TEXT,                           -- brief summary of supporting evidence
  created_at       TIMESTAMPTZ DEFAULT now(),
  UNIQUE(goal_id, protocol_id)
);

-- ============================================================
-- PROTOCOL → SUPPLEMENT STACKING
-- Defines mechanism-based supplement relationships for each protocol.
-- Roles describe how each supplement supports the primary peptide.
-- ============================================================

CREATE TABLE IF NOT EXISTS protocol_supplements (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  protocol_id    UUID NOT NULL REFERENCES peptide_protocols(id) ON DELETE CASCADE,
  supplement_id  UUID NOT NULL REFERENCES peptide_protocols(id) ON DELETE CASCADE,
  role           TEXT NOT NULL CHECK (role IN ('synergist', 'cofactor', 'protector', 'enhancer')),
  mechanism      TEXT,                             -- how the supplement supports the protocol
  timing         TEXT,                             -- "with meal", "30min before injection", etc.
  importance     TEXT DEFAULT 'recommended' CHECK (importance IN ('essential', 'recommended', 'optional')),
  notes          TEXT,
  UNIQUE(protocol_id, supplement_id)
);

-- ============================================================
-- PROTOCOL TREATMENT PHASES
-- Assigns protocols to treatment phases for sequenced rollout.
-- Phase 1 = foundation, Phase 2 = primary, Phase 3 = optimization.
-- ============================================================

CREATE TABLE IF NOT EXISTS protocol_phases (
  id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  protocol_id              UUID NOT NULL REFERENCES peptide_protocols(id) ON DELETE CASCADE,
  phase                    INTEGER NOT NULL DEFAULT 2 CHECK (phase IN (1, 2, 3)),
  phase_label              TEXT NOT NULL,          -- "Foundation", "Primary Treatment", "Optimization"
  rationale                TEXT,                   -- why this protocol belongs in this phase
  min_duration_weeks       INTEGER DEFAULT 4,
  prerequisites            TEXT[] DEFAULT '{}',    -- protocol IDs or phase numbers that must complete first
  can_run_concurrent       BOOLEAN DEFAULT true,
  max_concurrent_injectables INTEGER DEFAULT 3,
  UNIQUE(protocol_id)
);

-- ============================================================
-- ALTER peptide_protocols: add protocol engine metadata columns
-- ============================================================

ALTER TABLE peptide_protocols
  ADD COLUMN IF NOT EXISTS default_phase        INTEGER DEFAULT 2,
  ADD COLUMN IF NOT EXISTS timing_notes         TEXT,
  ADD COLUMN IF NOT EXISTS food_interaction     TEXT,
  ADD COLUMN IF NOT EXISTS injection_site_notes TEXT,
  ADD COLUMN IF NOT EXISTS half_life            TEXT,
  ADD COLUMN IF NOT EXISTS onset_weeks          INTEGER,
  ADD COLUMN IF NOT EXISTS receptor_group       TEXT;

-- ============================================================
-- INDEXES: optimize lookups for the protocol engine
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_goal_protocols_goal
  ON goal_protocols(goal_id);

CREATE INDEX IF NOT EXISTS idx_goal_protocols_protocol
  ON goal_protocols(protocol_id);

CREATE INDEX IF NOT EXISTS idx_protocol_supplements_protocol
  ON protocol_supplements(protocol_id);

-- ============================================================
-- ROW LEVEL SECURITY: public read access for protocol engine
-- These are knowledge-base tables; SELECT is open to all,
-- writes are restricted to service role / admin.
-- ============================================================

ALTER TABLE goal_protocols ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS goal_protocols_select ON goal_protocols;
CREATE POLICY goal_protocols_select ON goal_protocols
  FOR SELECT USING (true);

ALTER TABLE protocol_supplements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS protocol_supplements_select ON protocol_supplements;
CREATE POLICY protocol_supplements_select ON protocol_supplements
  FOR SELECT USING (true);

ALTER TABLE protocol_phases ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS protocol_phases_select ON protocol_phases;
CREATE POLICY protocol_phases_select ON protocol_phases
  FOR SELECT USING (true);


-- ============================================================
-- SUPPLEMENT CATALOG SEED DATA
-- ~76 new supplements from evidence-based catalog.
-- Idempotent: WHERE NOT EXISTS prevents duplicate inserts.
-- Grouped by category with section comments.
-- ============================================================

-- ------------------------------------------------------------
-- GUT HEALTH SUPPLEMENTS
-- ------------------------------------------------------------

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'Zinc Carnosine Gut Repair Protocol',
  'Zinc Carnosine', 'Gut Health', 'supplement',
  'Chelated zinc-carnosine complex that concentrates in the gastric mucosa. Clinical trials demonstrate accelerated healing of gastric ulcers, reduced intestinal permeability, and protection against NSAID-induced gut damage. Stabilizes the gastric lining by upregulating heat shock proteins and reducing inflammatory cytokine release.',
  'moderate', '75mg', '150mg',
  'twice daily between meals',
  'oral',
  '8-12 weeks',
  ARRAY[
    'Do not exceed 150mg/day without monitoring serum zinc and copper levels',
    'May interact with tetracycline and quinolone antibiotics — take 2 hours apart',
    'Monitor copper status with prolonged use'
  ],
  ARRAY[
    'Mild nausea',
    'Metallic taste',
    'Constipation (rare)'
  ],
  ARRAY[
    'Mahmood A et al. Zinc carnosine, a health food supplement that stabilises small bowel integrity and stimulates gut repair processes. Gut 2007;56(2):168-75. PMID:16777920',
    'Sakae K, Yanagisawa H. Oral treatment of pressure ulcers with polaprezinc (zinc L-carnosine complex). Nutr Clin Pract 2014;29(4):547-50. PMID:24740498'
  ],
  'both',
  1, 'Take between meals on empty stomach for gastric mucosal contact', 'Best taken on empty stomach; keep away from high-phytate foods'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'Zinc Carnosine');

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'Slippery Elm Mucosal Support Protocol',
  'Slippery Elm', 'Gut Health', 'supplement',
  'Inner bark mucilage from Ulmus rubra that forms a protective gel layer over inflamed GI mucosa. Traditional botanical with emerging evidence for IBS symptom relief, GERD symptom reduction, and intestinal barrier support. Prebiotic properties support beneficial Bifidobacteria and Lactobacillus colonization.',
  'emerging', '400mg', '1600mg',
  'twice daily before meals',
  'oral',
  '4-8 weeks',
  ARRAY[
    'May slow absorption of oral medications — take 2 hours apart from other drugs',
    'Source from reputable suppliers to avoid heavy metal contamination',
    'Discontinue if allergic reaction occurs'
  ],
  ARRAY[
    'Mild bloating',
    'Nausea (rare)'
  ],
  ARRAY[
    'Hawrelak JA, Myers SP. Effects of two natural medicine formulations on irritable bowel syndrome symptoms: a pilot study. J Altern Complement Med 2010;16(10):1065-71. PMID:20954962'
  ],
  'both',
  1, 'Take 30 minutes before meals to coat the GI tract', 'Take before meals on relatively empty stomach'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'Slippery Elm');

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'Marshmallow Root GI Soothing Protocol',
  'Marshmallow Root', 'Gut Health', 'supplement',
  'Althaea officinalis root extract rich in mucopolysaccharides that form a protective bioadhesive film on GI mucosa. Reduces gastric acid contact with damaged tissue, supports epithelial cell regeneration, and provides antioxidant protection. Traditional use for GERD, gastritis, and esophageal irritation.',
  'emerging', '500mg', '2000mg',
  'twice daily',
  'oral',
  '4-8 weeks',
  ARRAY[
    'May reduce absorption of other medications — take 2 hours apart from drugs',
    'Avoid in diabetes without monitoring as it may lower blood sugar',
    'Not recommended during pregnancy without medical guidance'
  ],
  ARRAY[
    'Mild GI discomfort',
    'Dizziness (rare)'
  ],
  ARRAY[
    'Deters AM et al. High molecular compounds (polysaccharides and proanthocyanidins) from Althaea officinalis roots. Bioorg Med Chem 2010;18(5):2409-15. PMID:20153195'
  ],
  'both',
  1, 'Take before meals; can be used as tea or capsule', 'Best taken before meals for mucosal coating effect'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'Marshmallow Root');

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'DGL (Deglycyrrhizinated Licorice) Gastric Protocol',
  'DGL (Deglycyrrhizinated Licorice)', 'Gut Health', 'supplement',
  'Licorice root extract with glycyrrhizin removed to eliminate aldosterone-like side effects. Stimulates mucin secretion, enhances prostaglandin E2 production, and accelerates gastric ulcer healing. Clinical trials show efficacy comparable to cimetidine for duodenal ulcers. Supports H. pylori eradication protocols.',
  'moderate', '380mg', '760mg',
  'three times daily, chewed before meals',
  'oral',
  '8-12 weeks',
  ARRAY[
    'Must use DGL form — whole licorice can cause pseudoaldosteronism, hypertension, and hypokalemia',
    'Safe for long-term use unlike whole licorice extract',
    'Chewable form preferred for direct mucosal contact'
  ],
  ARRAY[
    'Rare at recommended doses',
    'Mild headache'
  ],
  ARRAY[
    'Raveendra KR et al. An extract of Glycyrrhiza glabra (GutGard) alleviates symptoms of functional dyspepsia. Evid Based Complement Alternat Med 2012;2012:216970. PMID:22536284'
  ],
  'both',
  1, 'Chew tablets 20 minutes before meals for maximum mucosal contact', 'Take before meals; chewable form maximizes GI contact'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'DGL (Deglycyrrhizinated Licorice)');

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'Saccharomyces boulardii Probiotic Protocol',
  'Saccharomyces boulardii', 'Gut Health', 'supplement',
  'Non-pathogenic yeast probiotic with robust evidence for preventing antibiotic-associated diarrhea, treating acute infectious diarrhea, and reducing C. difficile recurrence. Survives gastric acid and does not colonize permanently. Secretes proteases that degrade C. difficile toxins A and B and stimulates secretory IgA production.',
  'well-studied', '250mg', '500mg',
  'once or twice daily',
  'oral',
  '4-12 weeks, or during antibiotic course plus 2 weeks after',
  ARRAY[
    'Contraindicated in immunocompromised patients or those with central venous catheters — risk of fungemia',
    'Do not open capsules near central line patients',
    'Safe for most healthy adults'
  ],
  ARRAY[
    'Flatulence',
    'Mild bloating (first few days)'
  ],
  ARRAY[
    'McFarland LV. Systematic review and meta-analysis of Saccharomyces boulardii in adult patients. World J Gastroenterol 2010;16(18):2202-22. PMID:20458757',
    'Szajewska H, Kolodziej M. Systematic review with meta-analysis: Saccharomyces boulardii in the prevention of antibiotic-associated diarrhoea. Aliment Pharmacol Ther 2015;42(7):793-801. PMID:26216624'
  ],
  'both',
  1, 'Take with or without food; during antibiotic courses, space 2 hours apart', 'Can be taken with or without food'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'Saccharomyces boulardii');

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'Lactobacillus rhamnosus GG Microbiome Protocol',
  'Lactobacillus rhamnosus GG', 'Gut Health', 'supplement',
  'One of the most extensively studied probiotic strains with over 300 clinical trials. Strengthens intestinal barrier function, modulates immune response via TLR signaling, and produces antimicrobial factors. Demonstrated efficacy for IBS symptom management, prevention of traveler''s diarrhea, and pediatric gastroenteritis recovery.',
  'well-studied', '10 billion CFU', '20 billion CFU',
  'once daily',
  'oral',
  '8-12 weeks minimum; safe for long-term use',
  ARRAY[
    'Avoid in severely immunocompromised patients',
    'May cause initial gas and bloating as microbiome adjusts',
    'Refrigerated strains preferred for maximum viability'
  ],
  ARRAY[
    'Transient gas and bloating',
    'Mild abdominal discomfort (first week)'
  ],
  ARRAY[
    'Capurso L. Thirty years of Lactobacillus rhamnosus GG: a review. J Clin Gastroenterol 2019;53 Suppl 1:S1-S41. PMID:31609759'
  ],
  'both',
  1, 'Take on empty stomach or with a light meal for best colonization', 'Can take with or without food; avoid with very hot beverages'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'Lactobacillus rhamnosus GG');

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'Tributyrin (Butyrate) Colonocyte Fuel Protocol',
  'Tributyrin (Butyrate)', 'Gut Health', 'supplement',
  'Tributyrin is a triglyceride form of butyric acid — the primary energy source for colonocytes. Reaches the colon intact unlike free butyrate which is absorbed in the upper GI. Supports tight junction integrity, reduces colonic inflammation via NF-kB suppression, and promotes regulatory T-cell differentiation. Emerging evidence for IBD, IBS, and microbiome recovery.',
  'emerging', '300mg', '1000mg',
  'twice daily with meals',
  'oral',
  '8-12 weeks',
  ARRAY[
    'Start low and titrate up — may cause GI disturbance initially',
    'Enteric-coated or tributyrin form preferred over sodium butyrate for colonic delivery',
    'Limited human RCT data — most evidence from animal models and small trials'
  ],
  ARRAY[
    'GI cramping',
    'Loose stools',
    'Unpleasant odor/taste of non-enteric forms'
  ],
  ARRAY[
    'Liu H et al. Butyrate: A Double-Edged Sword for Health? Adv Nutr 2018;9(1):21-29. PMID:29438462'
  ],
  'both',
  1, 'Take with meals to reduce GI irritation; enteric-coated preferred', 'Take with meals'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'Tributyrin (Butyrate)');

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'Aloe Vera Extract GI Soothing Protocol',
  'Aloe Vera Extract', 'Gut Health', 'supplement',
  'Inner leaf gel extract of Aloe barbadensis containing acemannan polysaccharides with anti-inflammatory and mucosal healing properties. RCT evidence supports efficacy in ulcerative colitis symptom reduction. Promotes epithelial growth factor release and reduces prostaglandin E2 in inflamed colonic tissue.',
  'emerging', '100mg', '300mg',
  'twice daily',
  'oral',
  '4-8 weeks',
  ARRAY[
    'Use only inner leaf gel preparations — outer leaf latex contains anthraquinones with laxative effects',
    'Avoid whole-leaf extracts which may contain aloins that are potentially hepatotoxic',
    'May lower blood glucose — monitor if diabetic'
  ],
  ARRAY[
    'Mild diarrhea (especially with whole-leaf products)',
    'Abdominal cramps',
    'Electrolyte imbalance with overuse'
  ],
  ARRAY[
    'Langmead L et al. Randomized, double-blind, placebo-controlled trial of oral aloe vera gel for active ulcerative colitis. Aliment Pharmacol Ther 2004;19(7):739-47. PMID:15043514'
  ],
  'both',
  1, 'Take before meals; use standardized inner-leaf gel extracts only', 'Best taken before meals on empty stomach'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'Aloe Vera Extract');

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'Bovine Colostrum Gut Immunity Protocol',
  'Bovine Colostrum', 'Gut Health', 'supplement',
  'First milk produced post-partum, rich in immunoglobulins (IgG), lactoferrin, growth factors (IGF-1, TGF-beta), and proline-rich polypeptides. Reduces NSAID-induced intestinal permeability, supports mucosal immunity, and provides passive immune protection. Clinical evidence for exercise-induced gut permeability, upper respiratory infection prevention, and GI recovery.',
  'moderate', '5g', '20g',
  'once daily on empty stomach',
  'oral',
  '8-12 weeks',
  ARRAY[
    'Contains dairy proteins — contraindicated in milk allergy (not just lactose intolerance)',
    'Contains IGF-1 — theoretical concern in active cancers, consult oncologist',
    'Choose products from pasture-raised, antibiotic-free sources'
  ],
  ARRAY[
    'GI discomfort',
    'Bloating',
    'Nausea in dairy-sensitive individuals'
  ],
  ARRAY[
    'Marchbank T et al. The nutriceutical bovine colostrum truncates the increase in gut permeability caused by heavy exercise in athletes. Am J Physiol Gastrointest Liver Physiol 2011;300(3):G477-84. PMID:21148400',
    'Jones AW et al. Bovine colostrum supplementation and upper respiratory symptoms during exercise training. Br J Sports Med 2014;48(18):1347-52. PMID:24615410'
  ],
  'both',
  1, 'Take first thing in morning on empty stomach; 30 min before food', 'Take on empty stomach for maximum absorption of growth factors'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'Bovine Colostrum');

-- ------------------------------------------------------------
-- ANTI-INFLAMMATORY SUPPLEMENTS
-- ------------------------------------------------------------

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'Boswellia Serrata Anti-Inflammatory Protocol',
  'Boswellia Serrata', 'Anti-inflammatory', 'supplement',
  'Resin extract containing boswellic acids (AKBA being the most potent) that selectively inhibit 5-lipoxygenase (5-LOX), reducing leukotriene B4 synthesis. Meta-analyses confirm efficacy for osteoarthritis pain and function, comparable to NSAIDs without gastropathy. Additional benefits in asthma, IBD, and brain tumor edema via TNF-alpha and NF-kB modulation.',
  'moderate', '300mg', '500mg',
  'three times daily with meals',
  'oral',
  '8-12 weeks',
  ARRAY[
    'Standardize to >30% AKBA for consistent dosing',
    'May potentiate effects of anti-inflammatory drugs',
    'Rare reports of GI irritation — take with meals'
  ],
  ARRAY[
    'Mild GI upset',
    'Nausea',
    'Acid reflux (rare)'
  ],
  ARRAY[
    'Yu G et al. Effectiveness of Boswellia and Boswellia extract for osteoarthritis patients: a systematic review and meta-analysis. BMC Complement Med Ther 2020;20(1):225. PMID:32680575',
    'Siddiqui MZ. Boswellia serrata, a potential antiinflammatory agent: an overview. Indian J Pharm Sci 2011;73(3):255-61. PMID:22457547'
  ],
  'both',
  1, 'Take with fat-containing meals to enhance absorption of boswellic acids', 'Take with meals containing fat for optimal absorption'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'Boswellia Serrata');

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'Bromelain Proteolytic Anti-Inflammatory Protocol',
  'Bromelain', 'Anti-inflammatory', 'supplement',
  'Proteolytic enzyme complex derived from pineapple stem with anti-inflammatory, anti-edematous, and fibrinolytic properties. Reduces post-surgical swelling, accelerates tissue healing, and modulates prostaglandin synthesis. Clinical trials demonstrate benefit for osteoarthritis, sinusitis, and post-operative recovery. Degrades fibrin and reduces bradykinin at sites of inflammation.',
  'moderate', '500mg', '1000mg',
  'two to three times daily between meals',
  'oral',
  '4-8 weeks for acute; ongoing for chronic inflammation',
  ARRAY[
    'Blood-thinning effect — avoid with anticoagulants (warfarin, heparin)',
    'Take on empty stomach for systemic anti-inflammatory effect; with food for digestive support',
    'Pineapple allergy is a contraindication'
  ],
  ARRAY[
    'GI upset',
    'Diarrhea at high doses',
    'Allergic reactions in pineapple-sensitive individuals'
  ],
  ARRAY[
    'Brien S et al. Bromelain as a Treatment for Osteoarthritis: a Review of Clinical Studies. Evid Based Complement Alternat Med 2004;1(3):251-257. PMID:15841258'
  ],
  'both',
  1, 'Take between meals on empty stomach for systemic anti-inflammatory effect', 'Empty stomach for anti-inflammatory; with meals for digestive enzyme benefit'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'Bromelain');

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'Quercetin Mast Cell Stabilizer Protocol',
  'Quercetin', 'Anti-inflammatory', 'supplement',
  'Plant flavonoid with potent mast cell stabilizing, anti-histamine, and anti-inflammatory properties. Inhibits NF-kB activation, reduces IL-6 and TNF-alpha secretion, and stabilizes mast cell membranes to prevent histamine release. Clinical evidence supports use in allergic rhinitis, exercise-induced inflammation, and MCAS symptom management. Enhanced bioavailability when combined with bromelain or phospholipid complexes.',
  'moderate', '500mg', '1000mg',
  'twice daily',
  'oral',
  '8-12 weeks; can be used long-term',
  ARRAY[
    'Inhibits CYP3A4 and CYP2C9 — potential drug interactions with statins, cyclosporine, and other CYP substrates',
    'Phytosomal or liposomal forms have significantly better bioavailability',
    'May enhance effects of anticoagulants'
  ],
  ARRAY[
    'Headache',
    'GI upset',
    'Tingling in extremities (rare, high doses)'
  ],
  ARRAY[
    'Mlcek J et al. Quercetin and Its Anti-Allergic Immune Response. Molecules 2016;21(5):623. PMID:27187333',
    'Li Y et al. Quercetin, Inflammation and Immunity. Nutrients 2016;8(3):167. PMID:26999194'
  ],
  'both',
  1, 'Take 20 minutes before meals; combine with bromelain for enhanced absorption', 'Can take with or without food; phytosomal forms taken with light fat'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'Quercetin');

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'SPMs (Specialized Pro-Resolving Mediators) Protocol',
  'SPMs (Specialized Pro-Resolving Mediators)', 'Anti-inflammatory', 'supplement',
  'Lipid mediators derived from omega-3 fatty acids (resolvins, protectins, maresins) that actively resolve inflammation rather than merely suppressing it. SPMs signal macrophages to clear cellular debris, reduce neutrophil infiltration, and promote tissue regeneration. Represent a paradigm shift from anti-inflammatory to pro-resolution therapy. Emerging clinical evidence for chronic inflammatory conditions.',
  'emerging', '500mg', '2000mg',
  'once or twice daily with meals',
  'oral',
  '8-12 weeks',
  ARRAY[
    'Relatively new supplement category — limited long-term human safety data',
    'Quality varies significantly between manufacturers — choose standardized products',
    'May enhance anticoagulant effects'
  ],
  ARRAY[
    'Fishy aftertaste',
    'Mild GI upset',
    'Loose stools (rare)'
  ],
  ARRAY[
    'Serhan CN. Pro-resolving lipid mediators are leads for resolution physiology. Nature 2014;510(7503):92-101. PMID:24899309'
  ],
  'both',
  1, 'Take with fat-containing meals for optimal absorption', 'Take with meals containing dietary fat'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'SPMs (Specialized Pro-Resolving Mediators)');

-- ------------------------------------------------------------
-- METABOLIC SUPPLEMENTS
-- ------------------------------------------------------------

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'Alpha-Lipoic Acid Metabolic & Neuroprotection Protocol',
  'Alpha-Lipoic Acid', 'Metabolic', 'supplement',
  'Universal antioxidant (both water- and fat-soluble) that regenerates vitamins C and E, raises intracellular glutathione, and improves insulin-mediated glucose disposal. Meta-analyses confirm significant reductions in fasting glucose and HbA1c in type 2 diabetes. Also demonstrates efficacy for diabetic neuropathy, reducing nerve pain and improving nerve conduction velocity in multiple RCTs.',
  'moderate', '300mg', '600mg',
  'once or twice daily',
  'oral',
  '12-24 weeks for metabolic benefits',
  ARRAY[
    'May lower blood glucose — monitor closely if on diabetes medications',
    'R-alpha lipoic acid is the bioactive enantiomer; racemic mixtures require higher doses',
    'Take on empty stomach for best absorption — food reduces bioavailability by ~30%'
  ],
  ARRAY[
    'Nausea',
    'Skin rash',
    'Hypoglycemia when combined with diabetes drugs'
  ],
  ARRAY[
    'Akbari M et al. The effects of alpha-lipoic acid supplementation on glucose control and lipid profiles among patients with metabolic diseases. Metabolism 2018;87:56-69. PMID:29990473',
    'Ziegler D et al. Oral treatment with alpha-lipoic acid improves symptomatic diabetic polyneuropathy. Diabetes Care 2006;29(11):2365-70. PMID:17065669'
  ],
  'both',
  2, 'Take 30 minutes before meals on empty stomach; R-ALA form preferred', 'Fasted — food reduces absorption by approximately 30%'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'Alpha-Lipoic Acid');

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'Chromium Picolinate Glucose Metabolism Protocol',
  'Chromium Picolinate', 'Metabolic', 'supplement',
  'Essential trace mineral in highly bioavailable picolinate form that enhances insulin receptor sensitivity via chromodulin. Meta-analysis of 25 RCTs confirms modest but significant reductions in fasting glucose and HbA1c in type 2 diabetes. Improves carbohydrate cravings and appetite regulation in overweight individuals.',
  'moderate', '200mcg', '1000mcg',
  'once daily with meals',
  'oral',
  '12-16 weeks',
  ARRAY[
    'High doses (>1000mcg) may cause oxidative DNA damage — stay within recommended range',
    'May interact with insulin and oral hypoglycemics — adjust doses accordingly',
    'Picolinate form preferred over chloride for superior bioavailability'
  ],
  ARRAY[
    'Headache',
    'Insomnia',
    'GI upset (rare)'
  ],
  ARRAY[
    'Balk EM et al. Effect of chromium supplementation on glucose metabolism and lipids: a systematic review of randomized controlled trials. Diabetes Care 2007;30(8):2154-63. PMID:17519436'
  ],
  'both',
  2, 'Take with largest meal of the day for insulin-sensitizing effect', 'Take with meals'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'Chromium Picolinate');

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'Ceylon Cinnamon Extract Glucose Regulation Protocol',
  'Cinnamon Extract (Ceylon)', 'Metabolic', 'supplement',
  'Cinnamomum verum (Ceylon cinnamon) extract containing cinnamaldehyde and type-A procyanidins that mimic insulin action, enhance GLUT4 translocation, and inhibit intestinal alpha-glucosidase. Meta-analysis shows significant reductions in fasting blood glucose and modest HbA1c improvement. Ceylon species preferred over Cassia to avoid coumarin hepatotoxicity.',
  'moderate', '500mg', '1500mg',
  'once or twice daily with meals',
  'oral',
  '12-16 weeks',
  ARRAY[
    'Use Ceylon (Cinnamomum verum) NOT Cassia cinnamon — Cassia contains high coumarin levels toxic to liver',
    'May potentiate diabetes medications — monitor blood glucose',
    'Avoid therapeutic doses during pregnancy'
  ],
  ARRAY[
    'Mild GI upset',
    'Allergic reactions (rare)',
    'Mouth sores at high doses'
  ],
  ARRAY[
    'Allen RW et al. Cinnamon use in type 2 diabetes: an updated systematic review and meta-analysis. Ann Fam Med 2013;11(5):452-9. PMID:24019277'
  ],
  'both',
  2, 'Take with carbohydrate-containing meals for glucose-lowering effect', 'Take with meals, especially those containing carbohydrates'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'Cinnamon Extract (Ceylon)');

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'Bitter Melon Extract Glucose Uptake Protocol',
  'Bitter Melon Extract', 'Metabolic', 'supplement',
  'Momordica charantia extract containing charantin, polypeptide-p (plant insulin), and vicine — bioactive compounds that activate AMPK, enhance GLUT4 translocation, and increase peripheral glucose uptake. Multiple RCTs demonstrate modest but consistent glucose-lowering effects in type 2 diabetes, particularly in Asian populations where dietary bitter melon is traditional.',
  'emerging', '500mg', '2000mg',
  'twice daily with meals',
  'oral',
  '12-16 weeks',
  ARRAY[
    'May cause hypoglycemia when combined with diabetes medications — monitor glucose closely',
    'Not recommended during pregnancy — may have abortifacient properties',
    'G6PD-deficient individuals should avoid due to vicine content'
  ],
  ARRAY[
    'GI upset',
    'Diarrhea',
    'Headache',
    'Hypoglycemia with concurrent diabetes drugs'
  ],
  ARRAY[
    'Peter EL et al. Glycaemic and Blood Pressure Lowering Effects of Momordica charantia: A Systematic Review and Meta-Analysis. J Ethnopharmacol 2019;235:145-157. PMID:30735765'
  ],
  'both',
  2, 'Take with meals to mitigate GI side effects and enhance glucose-lowering', 'Take with meals'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'Bitter Melon Extract');

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'Myo-Inositol Insulin Signaling Protocol',
  'Inositol (Myo-Inositol)', 'Metabolic', 'supplement',
  'Carbocyclic sugar and insulin second messenger that improves insulin signal transduction via phosphatidylinositol pathway. Strong RCT evidence in PCOS showing restoration of ovulatory function, reduction in HOMA-IR, improvement in hormonal profiles (reduced testosterone, LH/FSH ratio normalization), and metabolic parameter optimization. 40:1 myo:D-chiro-inositol ratio recommended.',
  'well-studied', '2000mg', '4000mg',
  'twice daily (split doses)',
  'oral',
  '12-24 weeks; safe for long-term use',
  ARRAY[
    'Use 40:1 myo-inositol to D-chiro-inositol ratio for PCOS',
    'High doses may cause GI upset — start at 2g and titrate',
    'May interact with lithium (reduces efficacy)'
  ],
  ARRAY[
    'Nausea',
    'Diarrhea at high doses',
    'Flatulence',
    'Insomnia (rare)'
  ],
  ARRAY[
    'Unfer V et al. Myo-inositol effects in women with PCOS: a meta-analysis of randomized controlled trials. Endocr Connect 2017;6(8):647-658. PMID:29042448',
    'Facchinetti F et al. Short-term effects of metformin and myo-inositol in women with polycystic ovarian syndrome. Gynecol Endocrinol 2014;30(3):205-8. PMID:24351072'
  ],
  'both',
  2, 'Split dose: 2g morning and 2g evening; take with meals to reduce GI effects', 'Take with meals to reduce GI effects'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'Inositol (Myo-Inositol)');

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'CoQ10 (Ubiquinol) Mitochondrial Energy Protocol',
  'CoQ10 (Ubiquinol)', 'Metabolic', 'supplement',
  'Reduced form of Coenzyme Q10, essential cofactor in mitochondrial electron transport chain (Complex III) and potent lipophilic antioxidant. Ubiquinol form has 3-4x higher bioavailability than ubiquinone. Meta-analyses confirm cardiovascular benefits: reduced mortality in heart failure, improved ejection fraction, and blood pressure reduction. Critical for statin users as statins deplete endogenous CoQ10.',
  'well-studied', '100mg', '300mg',
  'once or twice daily with meals',
  'oral',
  'Ongoing; essential for statin users',
  ARRAY[
    'Statin drugs deplete CoQ10 — supplementation strongly recommended with any statin therapy',
    'May reduce warfarin efficacy — monitor INR',
    'Ubiquinol form preferred over ubiquinone for adults over 40'
  ],
  ARRAY[
    'Mild GI upset',
    'Insomnia if taken late in day',
    'Reduced appetite (rare)'
  ],
  ARRAY[
    'Mortensen SA et al. The effect of coenzyme Q10 on morbidity and mortality in chronic heart failure: results from Q-SYMBIO. JACC Heart Fail 2014;2(6):641-9. PMID:25282031',
    'Flowers N et al. Co-enzyme Q10 supplementation for the primary prevention of cardiovascular disease. Cochrane Database Syst Rev 2014;(12):CD010405. PMID:25474484'
  ],
  'both',
  2, 'Take with meals containing fat for absorption; morning dosing preferred to avoid insomnia', 'Take with fat-containing meals for optimal absorption'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'CoQ10 (Ubiquinol)');

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'PQQ (Pyrroloquinoline Quinone) Mitochondrial Biogenesis Protocol',
  'PQQ (Pyrroloquinoline Quinone)', 'Metabolic', 'supplement',
  'Novel redox cofactor that stimulates mitochondrial biogenesis via PGC-1alpha activation and activates CREB and DJ-1 pathways for neuroprotection. One of the most potent antioxidants known (5,000 catalytic cycles vs 4 for vitamin C). Preliminary human trials show improved sleep quality, reduced fatigue, and enhanced cognitive function. Synergistic with CoQ10 for mitochondrial optimization.',
  'emerging', '10mg', '20mg',
  'once daily',
  'oral',
  '8-12 weeks; can be used long-term',
  ARRAY[
    'Limited human clinical data — most evidence from animal models and small trials',
    'Best combined with CoQ10 for synergistic mitochondrial support',
    'No known serious adverse effects at recommended doses'
  ],
  ARRAY[
    'Headache (rare)',
    'GI upset',
    'Insomnia if taken late'
  ],
  ARRAY[
    'Harris CB et al. Dietary pyrroloquinoline quinone (PQQ) alters indicators of inflammation and mitochondrial-related metabolism in human subjects. J Nutr Biochem 2013;24(12):2076-84. PMID:24231099'
  ],
  'both',
  2, 'Take in the morning with or without food; combine with CoQ10 for synergy', 'Can be taken with or without food'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'PQQ (Pyrroloquinoline Quinone)');

-- ------------------------------------------------------------
-- COGNITIVE SUPPLEMENTS
-- ------------------------------------------------------------

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'Lion''s Mane (Hericium erinaceus) Neurogenesis Protocol',
  'Lion''s Mane (Hericium erinaceus)', 'Cognitive', 'supplement',
  'Medicinal mushroom containing hericenones and erinacines that cross the blood-brain barrier and stimulate nerve growth factor (NGF) synthesis. RCT in mild cognitive impairment showed significant improvement in cognitive function scores over 16 weeks. Promotes hippocampal neurogenesis, remyelination, and synaptic plasticity. Additional benefits for anxiety, depression, and GI health via gut-brain axis.',
  'moderate', '500mg', '3000mg',
  'once or twice daily',
  'oral',
  '8-16 weeks minimum; benefits increase with duration',
  ARRAY[
    'May exacerbate symptoms in those allergic to mushrooms',
    'Theoretical concern with anticoagulants — lion''s mane may inhibit platelet aggregation',
    'Dual-extract (hot water + ethanol) captures both hericenones and erinacines'
  ],
  ARRAY[
    'Mild GI discomfort',
    'Skin rash in mushroom-sensitive individuals',
    'Itching (rare)'
  ],
  ARRAY[
    'Mori K et al. Improving effects of the mushroom Yamabushitake (Hericium erinaceus) on mild cognitive impairment. Phytother Res 2009;23(3):367-72. PMID:18844328',
    'Lai PL et al. Neurotrophic properties of the Lion''s mane medicinal mushroom, Hericium erinaceus. Int J Med Mushrooms 2013;15(6):539-54. PMID:24266378'
  ],
  'both',
  3, 'Take in morning or early afternoon; can split dose AM/PM', 'Can be taken with or without food'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'Lion''s Mane (Hericium erinaceus)');

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'Phosphatidylserine Cognitive Support Protocol',
  'Phosphatidylserine', 'Cognitive', 'supplement',
  'Phospholipid component of neuronal cell membranes critical for signal transduction, neurotransmitter release, and synaptic function. FDA-qualified health claim for cognitive decline risk reduction. Meta-analysis of 11 RCTs shows significant improvement in memory, attention, and cognitive function in elderly subjects with cognitive impairment. Also reduces exercise-induced cortisol.',
  'moderate', '100mg', '300mg',
  'once to three times daily with meals',
  'oral',
  '12-16 weeks for cognitive benefits',
  ARRAY[
    'Soy-derived PS may be a concern for soy-allergic individuals — sunflower-derived available',
    'May enhance effects of blood-thinning medications',
    'Take with meals for absorption (fat-soluble)'
  ],
  ARRAY[
    'GI upset at high doses',
    'Insomnia if taken late in day',
    'Nausea (rare)'
  ],
  ARRAY[
    'Glade MJ, Smith K. Phosphatidylserine and the human brain. Nutrition 2015;31(6):781-6. PMID:25933483',
    'Kato-Kataoka A et al. Soybean-derived phosphatidylserine improves memory function of the elderly Japanese subjects with memory complaints. J Clin Biochem Nutr 2010;47(3):246-55. PMID:21103034'
  ],
  'both',
  3, 'Take with meals containing fat; morning and afternoon dosing for cognitive support', 'Take with fat-containing meals for absorption'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'Phosphatidylserine');

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'Bacopa Monnieri Memory & Learning Protocol',
  'Bacopa Monnieri', 'Cognitive', 'supplement',
  'Ayurvedic nootropic herb containing bacosides A and B that enhance synaptic transmission, upregulate tryptophan hydroxylase and serotonin transporter expression, and provide neuroprotection via antioxidant mechanisms. Meta-analysis of 9 RCTs confirms significant improvements in attention, cognitive processing speed, and working memory. Effects become apparent after 8-12 weeks of consistent use.',
  'well-studied', '300mg', '600mg',
  'once daily with breakfast',
  'oral',
  '12-16 weeks minimum (effects are cumulative)',
  ARRAY[
    'Effects require 8-12 weeks to manifest — not an acute nootropic',
    'May increase acetylcholine — use caution with cholinergic drugs',
    'Standardize to 50% bacosides for consistent dosing',
    'May cause thyroid hormone changes — monitor if hypothyroid'
  ],
  ARRAY[
    'GI upset (most common — take with food)',
    'Nausea',
    'Dry mouth',
    'Fatigue initially'
  ],
  ARRAY[
    'Kongkeaw C et al. Meta-analysis of randomized controlled trials on cognitive effects of Bacopa monnieri extract. J Ethnopharmacol 2014;151(1):528-35. PMID:24252493',
    'Pase MP et al. The cognitive-enhancing effects of Bacopa monnieri: a systematic review of randomized, controlled human clinical trials. J Altern Complement Med 2012;18(7):647-52. PMID:22747190'
  ],
  'both',
  3, 'Take with breakfast; fat-containing meal improves absorption of bacosides', 'Always take with food to reduce GI side effects'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'Bacopa Monnieri');

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'Alpha-GPC Cholinergic Enhancement Protocol',
  'Alpha-GPC', 'Cognitive', 'supplement',
  'L-alpha-glycerylphosphorylcholine — the most bioavailable choline source that crosses the blood-brain barrier efficiently. Directly increases acetylcholine synthesis and phosphatidylcholine membrane incorporation. Clinical trials in vascular dementia and Alzheimer''s show cognitive improvement. Also enhances growth hormone secretion and power output in athletes via cholinergic stimulation.',
  'moderate', '300mg', '1200mg',
  'once or twice daily',
  'oral',
  '8-12 weeks for cognitive benefits',
  ARRAY[
    'High doses may cause cholinergic side effects (sweating, salivation)',
    'Choline excess in some individuals may produce fishy body odor (trimethylaminuria)',
    'May interact with anticholinergic medications'
  ],
  ARRAY[
    'Headache',
    'GI upset',
    'Dizziness',
    'Fishy body odor at high doses'
  ],
  ARRAY[
    'Traini E et al. Choline alphoscerate (alpha-glyceryl-phosphoryl-choline) an old choline-containing phospholipid with a still interesting profile as cognition enhancing agent. Curr Alzheimer Res 2013;10(10):1070-9. PMID:24156263'
  ],
  'both',
  3, 'Take in morning; can split 600mg AM / 600mg early PM for sustained cholinergic tone', 'Can be taken with or without food'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'Alpha-GPC');

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'Citicoline (CDP-Choline) Neuroprotection Protocol',
  'Citicoline (CDP-Choline)', 'Cognitive', 'supplement',
  'Cytidine diphosphate choline — endogenous nucleotide that provides both choline for acetylcholine synthesis and cytidine for conversion to uridine, supporting neuronal membrane phospholipid synthesis. Over 11,000 patients studied in clinical trials for stroke, TBI, and cognitive decline. Enhances dopamine receptor density, increases frontal lobe bioenergetics (ATP), and reduces neuroinflammation.',
  'well-studied', '250mg', '500mg',
  'once or twice daily',
  'oral',
  '8-12 weeks; safe for long-term use',
  ARRAY[
    'Generally well-tolerated with an excellent safety profile',
    'May increase dopaminergic tone — use caution in bipolar disorder or psychosis',
    'Cognizin brand has the most clinical validation'
  ],
  ARRAY[
    'Headache (rare)',
    'GI upset',
    'Insomnia if taken late'
  ],
  ARRAY[
    'Fioravanti M, Yanagi M. Cytidinediphosphocholine (CDP-choline) for cognitive and behavioural disturbances associated with chronic cerebral disorders in the elderly. Cochrane Database Syst Rev 2005;(2):CD000269. PMID:15846601'
  ],
  'both',
  3, 'Take in morning; avoid evening dosing to prevent insomnia', 'Can be taken with or without food'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'Citicoline (CDP-Choline)');

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'L-Theanine Calm Focus Protocol',
  'L-Theanine', 'Cognitive', 'supplement',
  'Amino acid analog from Camellia sinensis (green tea) that crosses the blood-brain barrier and increases alpha brain wave activity, promoting alert relaxation without sedation. Enhances GABA, serotonin, and dopamine levels. RCTs demonstrate reduced anxiety, improved attention, and better sleep quality. Synergistic with caffeine for focused cognitive performance without jitteriness.',
  'well-studied', '100mg', '400mg',
  'once or twice daily',
  'oral',
  'Ongoing; safe for long-term daily use',
  ARRAY[
    'May enhance effects of blood pressure medications',
    'Very safe — no serious adverse effects reported in clinical trials',
    'Can be combined with caffeine (2:1 L-theanine:caffeine ratio) for synergistic nootropic effect'
  ],
  ARRAY[
    'Rare — headache and GI upset possible at high doses'
  ],
  ARRAY[
    'Hidese S et al. Effects of L-Theanine Administration on Stress-Related Symptoms and Cognitive Functions in Healthy Adults: A Randomized Controlled Trial. Nutrients 2019;11(10):2362. PMID:31623400',
    'Nobre AC et al. L-theanine, a natural constituent in tea, and its effect on mental state. Asia Pac J Clin Nutr 2008;17 Suppl 1:167-8. PMID:18296328'
  ],
  'both',
  2, 'Morning for focus (combine with caffeine); evening for relaxation and sleep', 'Can be taken with or without food'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'L-Theanine');

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'Rhodiola Rosea Adaptogenic Cognitive Protocol',
  'Rhodiola Rosea', 'Cognitive', 'supplement',
  'Arctic root adaptogen containing rosavins and salidroside that modulates cortisol response, enhances serotonin and dopamine signaling, and reduces mental fatigue. Meta-analysis confirms significant improvements in physical performance and cognitive function under stress conditions. RCTs demonstrate benefits for burnout, mild depression, and generalized anxiety disorder with an excellent safety profile.',
  'moderate', '200mg', '600mg',
  'once daily in morning (before noon)',
  'oral',
  '8-12 weeks; cycle 1 week off every 6 weeks',
  ARRAY[
    'May be stimulating — avoid afternoon or evening dosing',
    'Standardize to 3% rosavins / 1% salidroside',
    'May interact with SSRIs due to serotonergic effects — monitor for serotonin syndrome symptoms',
    'Avoid in bipolar disorder during manic phases'
  ],
  ARRAY[
    'Restlessness',
    'Insomnia if taken late',
    'Dizziness',
    'Dry mouth'
  ],
  ARRAY[
    'Ishaque S et al. Rhodiola rosea L. as a putative botanical antidepressant. Phytomedicine 2012;19(5):346-54. PMID:22033148',
    'Hung SK et al. The effectiveness and efficacy of Rhodiola rosea L.: a systematic review of randomized clinical trials. Phytomedicine 2011;18(4):235-44. PMID:20637576'
  ],
  'both',
  2, 'Take in the morning on empty stomach; avoid after 2 PM to prevent insomnia', 'Best taken on empty stomach in the morning'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'Rhodiola Rosea');

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'Ginkgo Biloba Cerebrovascular Protocol',
  'Ginkgo Biloba', 'Cognitive', 'supplement',
  'Standardized leaf extract (EGb 761) containing flavone glycosides and terpene lactones that improve cerebral blood flow, reduce platelet aggregation, and provide neuroprotective antioxidant effects. Large-scale trials show benefits for cognitive function in mild-moderate dementia and vascular cognitive impairment. Enhances nitric oxide production in cerebral vasculature and protects neurons from excitotoxicity.',
  'moderate', '120mg', '240mg',
  'once or twice daily with meals',
  'oral',
  '12-24 weeks for cognitive benefits',
  ARRAY[
    'Significant blood-thinning effect — contraindicated with anticoagulants (warfarin, aspirin, clopidogrel)',
    'Discontinue 2 weeks before surgery',
    'Use only standardized EGb 761 extract — unprocessed seeds are toxic (ginkgotoxin)',
    'May interact with SSRIs, MAOIs, and seizure medications'
  ],
  ARRAY[
    'Headache',
    'GI upset',
    'Dizziness',
    'Allergic skin reactions (rare)',
    'Increased bleeding risk'
  ],
  ARRAY[
    'Tan MS et al. Efficacy and adverse effects of ginkgo biloba for cognitive impairment and dementia: a systematic review and meta-analysis. J Alzheimers Dis 2015;43(2):589-603. PMID:25114079'
  ],
  'both',
  3, 'Take with meals; split dose for sustained cerebrovascular support', 'Take with meals to reduce GI side effects'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'Ginkgo Biloba');

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'GABA (Gamma-Aminobutyric Acid) Calming Protocol',
  'GABA', 'Cognitive', 'supplement',
  'Primary inhibitory neurotransmitter in the CNS. Oral GABA supplementation reduces stress-induced anxiety markers, enhances alpha brain wave production (measured by EEG), and improves sleep onset latency. PharmaGABA (natural fermented form) shows superior efficacy over synthetic GABA in clinical studies. Acts peripherally on enteric nervous system and may cross BBB in small amounts via gut-brain axis.',
  'emerging', '100mg', '750mg',
  'once or twice daily',
  'oral',
  '4-8 weeks',
  ARRAY[
    'PharmaGABA (fermented) preferred over synthetic for clinical efficacy',
    'May enhance sedative effects of benzodiazepines, barbiturates, and sleep medications',
    'High doses may cause paradoxical anxiety in some individuals'
  ],
  ARRAY[
    'Drowsiness',
    'Tingling sensation',
    'Shortness of breath at very high doses (rare)'
  ],
  ARRAY[
    'Abdou AM et al. Relaxation and immunity enhancement effects of gamma-aminobutyric acid (GABA) administration in humans. Biofactors 2006;26(3):201-8. PMID:16971751'
  ],
  'both',
  2, 'Take in evening for sleep; sublingual dosing may improve absorption', 'Can be taken with or without food; empty stomach may enhance effect'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'GABA');

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  '5-HTP Serotonin Support Protocol',
  '5-HTP', 'Cognitive', 'supplement',
  '5-Hydroxytryptophan — direct precursor to serotonin that crosses the blood-brain barrier without a transport-limited step. Extracted from Griffonia simplicifolia seeds. Clinical trials demonstrate efficacy for depression, insomnia, anxiety, fibromyalgia, and appetite suppression. Bypasses the rate-limiting tryptophan hydroxylase step in serotonin biosynthesis.',
  'moderate', '50mg', '300mg',
  'once or twice daily',
  'oral',
  '8-12 weeks',
  ARRAY[
    'CRITICAL: Do NOT combine with SSRIs, SNRIs, MAOIs, or triptans — risk of serotonin syndrome (potentially fatal)',
    'Start low (50mg) and increase gradually over 2 weeks',
    'Co-supplement with vitamin B6 (P-5-P) for optimal conversion'
  ],
  ARRAY[
    'Nausea (most common)',
    'GI upset',
    'Drowsiness',
    'Vivid dreams'
  ],
  ARRAY[
    'Birdsall TC. 5-Hydroxytryptophan: a clinically-effective serotonin precursor. Altern Med Rev 1998;3(4):271-80. PMID:9727088'
  ],
  'both',
  2, 'For mood: take morning and afternoon; for sleep: take 30 min before bedtime', 'Can be taken with or without food; empty stomach for faster absorption'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = '5-HTP');

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'SAMe (S-Adenosyl Methionine) Mood & Liver Protocol',
  'SAMe (S-Adenosyl Methionine)', 'Cognitive', 'supplement',
  'Universal methyl donor involved in over 100 biochemical reactions including neurotransmitter synthesis (dopamine, serotonin, norepinephrine), DNA methylation, and phospholipid metabolism. Meta-analyses demonstrate antidepressant efficacy comparable to tricyclics in major depressive disorder. Also supports liver function via glutathione synthesis, joint health, and methylation cycle optimization.',
  'well-studied', '400mg', '1600mg',
  'once or twice daily on empty stomach',
  'oral',
  '8-12 weeks for mood benefits',
  ARRAY[
    'Contraindicated in bipolar disorder — may trigger manic episodes',
    'Do NOT combine with SSRIs or MAOIs without physician supervision — serotonin syndrome risk',
    'Start at 200mg and titrate up slowly over 2 weeks to minimize GI effects',
    'Enteric-coated tablets preferred for stability'
  ],
  ARRAY[
    'GI upset',
    'Anxiety and restlessness',
    'Insomnia',
    'Hypomania in susceptible individuals'
  ],
  ARRAY[
    'Sharma A et al. S-Adenosylmethionine (SAMe) for Neuropsychiatric Disorders: A Clinician-Oriented Review of Research. J Clin Psychiatry 2017;78(6):e656-e667. PMID:28493651',
    'Guo T et al. S-adenosyl-L-methionine for the treatment of chronic liver disease: a systematic review and meta-analysis. PLoS One 2015;10(3):e0122124. PMID:25786236'
  ],
  'both',
  3, 'Take on empty stomach 30 minutes before meals; morning dosing preferred', 'Fasted — take 30 minutes before meals for best absorption'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'SAMe (S-Adenosyl Methionine)');

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'Magnesium L-Threonate Neurological Protocol',
  'Magnesium L-Threonate', 'Cognitive', 'supplement',
  'Patented form of magnesium (Magtein) specifically developed to cross the blood-brain barrier efficiently. Animal studies demonstrate significant increases in brain magnesium concentrations, enhanced synaptic density, and improved short-term and long-term memory. Human RCT shows reversal of brain age by 9 years on cognitive testing. Enhances NMDA receptor function and synaptic plasticity in prefrontal cortex and hippocampus.',
  'emerging', '1000mg', '2000mg',
  'twice daily (morning and evening)',
  'oral',
  '12-24 weeks; safe for long-term use',
  ARRAY[
    'Lower elemental magnesium per dose than other forms — 144mg elemental Mg per 2g',
    'May cause drowsiness — beneficial for evening dose',
    'Caution in severe kidney disease'
  ],
  ARRAY[
    'Drowsiness',
    'Headache',
    'Loose stools (less common than with other Mg forms)'
  ],
  ARRAY[
    'Slutsky I et al. Enhancement of learning and memory by elevating brain magnesium. Neuron 2010;65(2):165-77. PMID:20152124',
    'Liu G et al. Efficacy and Safety of MMFS-01, a Synapse Density Enhancer, for Treating Cognitive Impairment in Older Adults. J Alzheimers Dis 2016;49(4):971-90. PMID:26519439'
  ],
  'both',
  3, 'Split dose: morning for cognitive performance, evening for sleep and synaptic maintenance', 'Can be taken with or without food'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'Magnesium L-Threonate');

-- ------------------------------------------------------------
-- LONGEVITY SUPPLEMENTS
-- ------------------------------------------------------------

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'NMN (Nicotinamide Mononucleotide) NAD+ Restoration Protocol',
  'NMN (Nicotinamide Mononucleotide)', 'Longevity', 'supplement',
  'Direct precursor to NAD+ (nicotinamide adenine dinucleotide) — a critical coenzyme in cellular energy metabolism, DNA repair (PARP activation), and sirtuin activation. NAD+ declines 50% between ages 40-60. Human RCTs demonstrate improved muscle insulin sensitivity, increased NAD+ blood levels, and enhanced aerobic capacity. Activates SIRT1/SIRT3 longevity pathways.',
  'moderate', '250mg', '1000mg',
  'once daily in morning',
  'oral',
  'Ongoing; benefits are maintained with continuous use',
  ARRAY[
    'Sublingual or enteric-coated forms may have better bioavailability than standard oral',
    'Theoretical concern about fueling cancer cell growth via NAD+ — no evidence to date but consult oncologist if applicable',
    'May cause mild GI upset initially — start at 250mg'
  ],
  ARRAY[
    'Mild nausea',
    'Flushing (rare)',
    'Headache',
    'Fatigue initially (resolves in 1-2 weeks)'
  ],
  ARRAY[
    'Yoshino M et al. Nicotinamide mononucleotide increases muscle insulin sensitivity in prediabetic women. Science 2021;372(6547):1224-1229. PMID:33888596',
    'Liao B et al. Nicotinamide mononucleotide supplementation enhances aerobic capacity in amateur runners. J Int Soc Sports Nutr 2021;18(1):54. PMID:34238308'
  ],
  'both',
  3, 'Take in morning on empty stomach; sublingual or enteric-coated preferred', 'Best on empty stomach in the morning'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'NMN (Nicotinamide Mononucleotide)');

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'NR (Nicotinamide Riboside) NAD+ Precursor Protocol',
  'NR (Nicotinamide Riboside)', 'Longevity', 'supplement',
  'Vitamin B3 derivative and NAD+ precursor that utilizes the NRK1/NRK2 salvage pathway to restore cellular NAD+ levels. Multiple human RCTs confirm dose-dependent NAD+ elevation (40-90% increase at 1000mg/day). Niagen (patented form) is the most clinically validated. Supports mitochondrial function, activates sirtuins, and enhances cellular stress resistance. Well-studied safety profile.',
  'moderate', '300mg', '1000mg',
  'once or twice daily',
  'oral',
  'Ongoing; safe for long-term use based on multiple RCTs',
  ARRAY[
    'May cause mild flushing at higher doses (less than niacin)',
    'Niagen brand has the most clinical safety and efficacy data',
    'Similar theoretical cancer concerns as NMN — no evidence of harm in trials'
  ],
  ARRAY[
    'Mild nausea',
    'Fatigue initially',
    'Flushing (rare)',
    'GI upset at high doses'
  ],
  ARRAY[
    'Martens CR et al. Chronic nicotinamide riboside supplementation is well-tolerated and elevates NAD+ in healthy middle-aged and older adults. Nat Commun 2018;9(1):1286. PMID:29599478',
    'Conze D et al. Safety and Metabolism of Long-term Administration of NIAGEN in a Randomized, Double-Blind, Placebo-controlled Clinical Trial of Healthy Overweight Adults. Sci Rep 2019;9(1):9772. PMID:31278280'
  ],
  'both',
  3, 'Take in morning; can split dose AM/PM', 'Can be taken with or without food'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'NR (Nicotinamide Riboside)');

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'Resveratrol Sirtuin Activation Protocol',
  'Resveratrol', 'Longevity', 'supplement',
  'Polyphenol stilbene from grape skins and Japanese knotweed that activates SIRT1 and AMPK longevity pathways. Anti-inflammatory (NF-kB inhibition), antioxidant, and cardiovascular protective. Meta-analyses show improvements in glucose metabolism, systolic blood pressure, and inflammatory markers. Trans-resveratrol is the bioactive form; bioavailability is enhanced by piperine or liposomal delivery.',
  'moderate', '150mg', '500mg',
  'once daily',
  'oral',
  'Ongoing; long-term benefits accumulate',
  ARRAY[
    'Inhibits CYP3A4 and CYP1A2 — significant drug interaction potential',
    'May enhance effects of anticoagulants and antiplatelet drugs',
    'Trans-resveratrol degrades with light and heat — store in dark, cool conditions',
    'Estrogenic activity at high doses — caution in hormone-sensitive conditions'
  ],
  ARRAY[
    'GI upset',
    'Diarrhea at high doses',
    'Headache'
  ],
  ARRAY[
    'Berman AY et al. The therapeutic potential of resveratrol: a review of clinical trials. NPJ Precis Oncol 2017;1:35. PMID:29152592',
    'Mousavi SM et al. Resveratrol supplementation significantly influences obesity measures: a systematic review and dose-response meta-analysis of randomized controlled trials. Obes Rev 2019;20(3):487-498. PMID:30515936'
  ],
  'both',
  3, 'Take in morning with a fat-containing meal; combine with quercetin for synergy', 'Take with fat-containing food for absorption'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'Resveratrol');

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'Fisetin Senolytic Protocol',
  'Fisetin', 'Longevity', 'supplement',
  'Plant flavonoid found in strawberries with potent senolytic activity — selectively clears senescent (zombie) cells that drive inflammaging. Animal studies show dramatic lifespan extension and reduction in age-related pathology. Currently in human clinical trials (AFFIRM-LITE) for reducing senescent cell burden. Also inhibits mTOR, activates AMPK, and has neuroprotective properties.',
  'emerging', '100mg', '500mg',
  'once daily; or intermittent high-dose protocol (2 days on, 28 days off)',
  'oral',
  'Ongoing for daily low-dose; cyclical for senolytic protocol',
  ARRAY[
    'Human clinical data still emerging — AFFIRM-LITE trial ongoing',
    'Intermittent high-dose senolytic protocol is theoretical',
    'May interact with medications metabolized by CYP3A4',
    'Liposomal form preferred for better bioavailability'
  ],
  ARRAY[
    'GI upset',
    'Diarrhea at high doses',
    'Headache (rare)'
  ],
  ARRAY[
    'Yousefzadeh MJ et al. Fisetin is a senotherapeutic that extends health and lifespan. EBioMedicine 2018;36:18-28. PMID:30279143'
  ],
  'both',
  3, 'Daily low-dose or monthly 2-day senolytic pulse; take with fat-containing food', 'Take with fat-containing food for improved bioavailability'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'Fisetin');

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'Astaxanthin Antioxidant & Longevity Protocol',
  'Astaxanthin', 'Longevity', 'supplement',
  'Carotenoid xanthophyll from microalgae Haematococcus pluvialis — one of nature''s most potent antioxidants (6,000x more potent than vitamin C, 550x more than vitamin E). Uniquely spans the cell membrane bilayer providing both internal and external protection. Clinical evidence for skin UV protection, cardiovascular health (reduced LDL oxidation), endurance enhancement, and eye health.',
  'moderate', '4mg', '12mg',
  'once daily with meals',
  'oral',
  'Ongoing; benefits increase with sustained use',
  ARRAY[
    'May reduce blood pressure — monitor if on antihypertensives',
    'Can cause orange skin discoloration at very high doses (harmless)',
    'Algae-derived form preferred over synthetic — superior antioxidant activity'
  ],
  ARRAY[
    'Orange discoloration of stool',
    'GI upset (rare)',
    'Reduced blood pressure'
  ],
  ARRAY[
    'Fakhri S et al. Astaxanthin: A mechanistic review on its biological activities and health benefits. Pharmacol Res 2018;136:1-20. PMID:30121358',
    'Tominaga K et al. Cosmetic benefits of astaxanthin on humans subjects. Acta Biochim Pol 2012;59(1):43-7. PMID:22428137'
  ],
  'both',
  3, 'Take with a fat-containing meal for absorption (fat-soluble carotenoid)', 'Must take with fat-containing meals for absorption'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'Astaxanthin');

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'Pterostilbene Methylated Resveratrol Protocol',
  'Pterostilbene', 'Longevity', 'supplement',
  'Dimethylated analog of resveratrol found in blueberries with 4x greater oral bioavailability and longer half-life. Activates SIRT1 and AMPK pathways, reduces oxidative stress, and improves lipid profiles. Human RCT demonstrated significant reductions in blood pressure, improved cholesterol ratios, and reduced oxidative stress markers. More lipophilic than resveratrol enabling better cellular uptake.',
  'emerging', '50mg', '250mg',
  'once or twice daily',
  'oral',
  'Ongoing; long-term use well-tolerated',
  ARRAY[
    'May slightly increase LDL-C at high doses in some individuals — monitor lipid panel',
    'Similar drug interaction profile to resveratrol (CYP inhibition)',
    'May enhance effects of blood pressure medications'
  ],
  ARRAY[
    'Mild GI upset',
    'Headache (rare)',
    'Slight LDL elevation in some individuals'
  ],
  ARRAY[
    'Riche DM et al. Analysis of safety from a human clinical trial with pterostilbene. J Toxicol 2013;2013:463595. PMID:23431291'
  ],
  'both',
  3, 'Take in morning; can combine with resveratrol for enhanced sirtuin activation', 'Can be taken with or without food; bioavailability is good regardless'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'Pterostilbene');

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'Spermidine Autophagy Induction Protocol',
  'Spermidine', 'Longevity', 'supplement',
  'Natural polyamine found in wheat germ, aged cheese, and natto that is the most potent known inducer of autophagy — the cellular self-cleaning process that declines with age. Epidemiological studies show inverse correlation between dietary spermidine intake and all-cause mortality. Mimics effects of caloric restriction and fasting on longevity pathways. Supports cardiovascular, cognitive, and immune health through enhanced proteostasis.',
  'emerging', '1mg', '6mg',
  'once daily',
  'oral',
  'Ongoing; mimics caloric restriction benefits',
  ARRAY[
    'Relatively new as a supplement — long-term safety data limited but dietary intake is well-studied',
    'Wheat germ-derived products may contain gluten — verify if celiac/gluten-sensitive',
    'Theoretical concern of enhancing growth of existing tumors — no evidence to date'
  ],
  ARRAY[
    'GI upset',
    'Bloating (rare)'
  ],
  ARRAY[
    'Eisenberg T et al. Cardioprotection and lifespan extension by the natural polyamine spermidine. Nat Med 2016;22(12):1428-1438. PMID:27841876',
    'Madeo F et al. Spermidine in health and disease. Science 2018;359(6374):eaan2788. PMID:29371440'
  ],
  'both',
  3, 'Take in morning; wheat germ extract is the most common supplement form', 'Can be taken with or without food'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'Spermidine');

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'Sulforaphane (Broccoli Seed Extract) NRF2 Activation Protocol',
  'Sulforaphane (Broccoli Seed Extract)', 'Longevity', 'supplement',
  'Isothiocyanate from cruciferous vegetables (highest in broccoli sprouts) that is the most potent known natural activator of the NRF2 antioxidant response pathway. Upregulates over 200 cytoprotective genes including glutathione synthesis, phase II detoxification enzymes, and anti-inflammatory pathways. Clinical evidence for improved glucose metabolism, reduced inflammation markers, and enhanced detoxification capacity.',
  'moderate', '10mg', '40mg',
  'once daily',
  'oral',
  'Ongoing; NRF2 activation requires consistent dosing',
  ARRAY[
    'Myrosinase enzyme is needed to convert glucoraphanin to sulforaphane — choose products with active myrosinase or pre-converted sulforaphane',
    'May interact with CYP1A2 substrates (caffeine, theophylline)',
    'Theoretical concern about thyroid (goitrogen) — minimal risk at supplement doses'
  ],
  ARRAY[
    'GI upset',
    'Gas and bloating',
    'Heartburn (rare)'
  ],
  ARRAY[
    'Houghton CA et al. Sulforaphane and Other Nutrigenomic Nrf2 Activators: Can the Clinician''s Expectation Be Matched by the Reality? Oxid Med Cell Longev 2016;2016:7857186. PMID:26881038',
    'Axelsson AS et al. Sulforaphane reduces hepatic glucose production and improves glucose control in patients with type 2 diabetes. Sci Transl Med 2017;9(394):eaah4477. PMID:28615356'
  ],
  'both',
  3, 'Take in morning; broccoli seed extract with myrosinase preferred', 'Can be taken with or without food; mustard seed powder may enhance conversion'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'Sulforaphane (Broccoli Seed Extract)');

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'Urolithin A Mitophagy Enhancement Protocol',
  'Urolithin A', 'Longevity', 'supplement',
  'Gut microbiome-derived metabolite of ellagitannins (from pomegranates, walnuts, berries) that is the first natural compound clinically validated to enhance mitophagy — the selective recycling of damaged mitochondria. Human RCTs demonstrate improved mitochondrial function, enhanced muscle endurance, and activation of PINK1/Parkin mitophagy pathway.',
  'moderate', '500mg', '1000mg',
  'once daily',
  'oral',
  'Ongoing; benefits improve with sustained use over 4+ months',
  ARRAY[
    'Only ~40% of people naturally produce Urolithin A from dietary sources — direct supplementation bypasses microbiome dependency',
    'Mitopure (Timeline brand) is the most clinically validated form',
    'Generally well-tolerated with excellent safety profile in trials'
  ],
  ARRAY[
    'Mild GI upset',
    'Headache (rare)'
  ],
  ARRAY[
    'Andreux PA et al. The mitophagy activator urolithin A is safe and induces a molecular signature of improved mitochondrial and cellular health in humans. Nat Metab 2019;1(6):595-603. PMID:32694802',
    'Liu S et al. Effect of Urolithin A Supplementation on Muscle Endurance and Mitochondrial Health in Older Adults. JAMA Netw Open 2022;5(1):e2144279. PMID:35050355'
  ],
  'both',
  3, 'Take in morning with or without food', 'Can be taken with or without food'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'Urolithin A');

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'Glutathione (Liposomal) Master Antioxidant Protocol',
  'Glutathione (Liposomal)', 'Longevity', 'supplement',
  'Liposomal delivery of reduced L-glutathione — the body''s master intracellular antioxidant and primary detoxification molecule. Standard oral glutathione has poor bioavailability due to GI degradation; liposomal encapsulation improves absorption 2-4x. Supports phase II liver detoxification, immune cell function, mitochondrial protection, and skin lightening. Depleted by chronic stress, toxin exposure, aging, and illness.',
  'moderate', '250mg', '1000mg',
  'once or twice daily on empty stomach',
  'oral',
  '8-12 weeks; can be used long-term',
  ARRAY[
    'Liposomal or acetylated (S-acetyl glutathione) forms required — standard reduced glutathione has minimal oral bioavailability',
    'May interfere with chemotherapy drugs that rely on oxidative stress for efficacy — consult oncologist',
    'NAC supplementation is an alternative approach (provides cysteine for endogenous glutathione synthesis)'
  ],
  ARRAY[
    'Mild GI upset',
    'Bloating',
    'Sulfurous taste'
  ],
  ARRAY[
    'Sinha R et al. Oral supplementation with liposomal glutathione elevates body stores of glutathione and markers of immune function. Eur J Clin Nutr 2018;72(1):105-111. PMID:28853742'
  ],
  'both',
  3, 'Take on empty stomach; morning preferred; hold sublingual forms under tongue 30 seconds', 'Best on empty stomach; liposomal form does not require food'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'Glutathione (Liposomal)');

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'Apigenin NAD+ & Sleep Support Protocol',
  'Apigenin', 'Longevity', 'supplement',
  'Flavonoid from chamomile and parsley that inhibits CD38 — the primary NAD+-consuming enzyme — thereby preserving cellular NAD+ levels. Also acts as a positive allosteric modulator of GABA-A receptors, producing anxiolytic and sleep-promoting effects. Inhibits aromatase enzyme (estrogen conversion), potentially supporting testosterone optimization. Multi-target longevity compound with anti-inflammatory and neuroprotective properties.',
  'emerging', '50mg', '500mg',
  'once daily, typically in evening',
  'oral',
  'Ongoing; safe for long-term use',
  ARRAY[
    'May inhibit CYP2C9 and CYP1A2 — potential interactions with warfarin and caffeine',
    'Aromatase inhibition may affect estrogen levels in women — monitor if concerned',
    'Sedative effect at higher doses — may enhance effects of sleep medications'
  ],
  ARRAY[
    'Drowsiness',
    'Sedation at high doses',
    'Muscle relaxation'
  ],
  ARRAY[
    'Salehi B et al. The Therapeutic Potential of Apigenin. Int J Mol Sci 2019;20(6):1305. PMID:30875872'
  ],
  'both',
  3, 'Take in evening 30-60 minutes before bed; synergistic with NMN/NR for NAD+ preservation', 'Can be taken with or without food'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'Apigenin');

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'Ergothioneine Cellular Longevity Protocol',
  'Ergothioneine', 'Longevity', 'supplement',
  'Amino acid-derived thione found primarily in mushrooms, transported by a dedicated transporter (OCTN1/SLC22A4) that concentrates it in high-stress tissues (red blood cells, liver, bone marrow, eyes). Unique intracellular antioxidant that protects mitochondrial DNA. Epidemiological data associates low blood ergothioneine levels with increased all-cause mortality, cognitive decline, and frailty. Has been proposed as a longevity vitamin.',
  'emerging', '5mg', '25mg',
  'once daily',
  'oral',
  'Ongoing; accumulates in tissues over weeks',
  ARRAY[
    'Relatively new as an isolated supplement — most safety data from dietary mushroom intake',
    'GRAS status recognized by FDA',
    'No known drug interactions reported'
  ],
  ARRAY[
    'Generally well-tolerated',
    'Mild GI upset (rare)'
  ],
  ARRAY[
    'Cheah IK, Halliwell B. Ergothioneine, recent developments. Redox Biol 2021;42:101868. PMID:33558182',
    'Beelman RB et al. Is ergothioneine a longevity vitamin limited in the American diet? J Nutr Sci 2020;9:e52. PMID:33244401'
  ],
  'both',
  3, 'Take in morning with or without food', 'Can be taken with or without food'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'Ergothioneine');

-- ------------------------------------------------------------
-- HORMONAL SUPPLEMENTS
-- ------------------------------------------------------------

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'Tongkat Ali (Eurycoma longifolia) Testosterone Protocol',
  'Tongkat Ali (Eurycoma longifolia)', 'Hormonal', 'supplement',
  'Malaysian herbal extract (Longjack) containing eurypeptides and quassinoids that increase free testosterone by reducing SHBG binding and inhibiting aromatase conversion to estrogen. Meta-analysis of RCTs confirms significant improvements in total and free testosterone, cortisol-to-testosterone ratio, and male fertility parameters. Also demonstrates ergogenic benefits for muscle strength and body composition.',
  'moderate', '200mg', '400mg',
  'once daily in morning',
  'oral',
  '8-12 weeks; cycle 2 weeks off every 8 weeks',
  ARRAY[
    'Source from standardized extracts (e.g., 2% eurycomanone) — raw herb potency varies widely',
    'May affect blood sugar — monitor if diabetic',
    'Not recommended during pregnancy or breastfeeding',
    'May interact with blood pressure medications'
  ],
  ARRAY[
    'Restlessness',
    'Insomnia if taken late',
    'Irritability at high doses'
  ],
  ARRAY[
    'Leisegang K et al. Eurycoma longifolia (Jack) as a potential adaptogen and testosterone booster: a systematic review. Andrologia 2022;54(4):e14349. PMID:35021265',
    'Talbott SM et al. Effect of Tongkat Ali on stress hormones and psychological mood state in moderately stressed subjects. J Int Soc Sports Nutr 2013;10(1):28. PMID:23705671'
  ],
  'male',
  2, 'Take in morning with or without food; avoid evening dosing', 'Can be taken with or without food'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'Tongkat Ali (Eurycoma longifolia)');

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'Fenugreek Extract Testosterone & Libido Protocol',
  'Fenugreek Extract', 'Hormonal', 'supplement',
  'Trigonella foenum-graecum seed extract containing furostanolic saponins (protodioscin) that inhibit aromatase and 5-alpha-reductase, shifting hormonal balance toward free testosterone. Meta-analysis of 7 RCTs confirms significant increases in total testosterone (+1.18 nmol/L), free testosterone, and sexual function scores. Testofen (standardized to 50% fenuside) is the most validated extract.',
  'moderate', '500mg', '600mg',
  'once daily',
  'oral',
  '8-12 weeks',
  ARRAY[
    'May lower blood glucose significantly — caution with diabetes medications',
    'Can cause maple syrup odor in urine and sweat (harmless sotolon compound)',
    'May potentiate anticoagulant effects',
    'Avoid during pregnancy — may stimulate uterine contractions'
  ],
  ARRAY[
    'GI upset',
    'Diarrhea',
    'Maple syrup body odor',
    'Nasal congestion'
  ],
  ARRAY[
    'Mansoori A et al. Effect of fenugreek extract supplement on testosterone levels in male: A meta-analysis of clinical trials. Phytother Res 2020;34(7):1550-1555. PMID:32048383'
  ],
  'male',
  2, 'Take in morning with breakfast', 'Take with meals to reduce GI side effects'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'Fenugreek Extract');

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'DIM (Diindolylmethane) Estrogen Metabolism Protocol',
  'DIM (Diindolylmethane)', 'Hormonal', 'supplement',
  'Bioactive metabolite of indole-3-carbinol (I3C) from cruciferous vegetables that modulates estrogen metabolism by shifting the 2-hydroxyestrone to 16-alpha-hydroxyestrone ratio toward favorable 2-OH metabolites. Supports healthy estrogen detoxification, reduces estrogen dominance symptoms, and may protect against estrogen-sensitive cancers. Used in both men (estrogen management) and women (PMS, fibroids, hormonal acne).',
  'moderate', '100mg', '300mg',
  'once or twice daily with meals',
  'oral',
  '8-12 weeks; ongoing for hormonal optimization',
  ARRAY[
    'May alter estrogen levels — monitor in hormone-sensitive conditions',
    'Bioenhanced/microencapsulated forms recommended for absorption (free DIM is poorly absorbed)',
    'May interact with tamoxifen and other anti-estrogen drugs',
    'Can reduce libido in men if estrogen is driven too low'
  ],
  ARRAY[
    'GI upset',
    'Headache',
    'Dark urine (harmless)',
    'Changes in menstrual cycle'
  ],
  ARRAY[
    'Thomson CA et al. Chemopreventive properties of 3,3''-diindolylmethane in breast cancer: evidence from experimental and human studies. Nutr Rev 2016;74(7):432-43. PMID:27261275'
  ],
  'both',
  2, 'Take with meals containing some fat; split dose for steady levels', 'Take with meals; fat improves absorption of bioenhanced forms'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'DIM (Diindolylmethane)');

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'Shilajit Adaptogenic Mineral Resin Protocol',
  'Shilajit', 'Hormonal', 'supplement',
  'Himalayan mineral pitch containing fulvic acid, dibenzo-alpha-pyrones, and 80+ trace minerals. Clinically shown to increase total and free testosterone (23.5% increase in healthy volunteers), improve sperm quality, and enhance mitochondrial CoQ10 function. Acts as an electron shuttle enhancing mitochondrial energy production. Ayurvedic rasayana (rejuvenator) with adaptogenic properties.',
  'emerging', '250mg', '500mg',
  'once daily',
  'oral',
  '8-12 weeks',
  ARRAY[
    'Use only purified, lab-tested shilajit — raw forms may contain heavy metals, mycotoxins, or contaminants',
    'PrimaVie is the most clinically validated purified form',
    'May lower blood pressure — caution with antihypertensives',
    'Avoid with active gout (contains purines)'
  ],
  ARRAY[
    'GI upset',
    'Dizziness',
    'Metallic taste',
    'Rash (rare)'
  ],
  ARRAY[
    'Pandit S et al. Clinical evaluation of purified Shilajit on testosterone levels in healthy volunteers. Andrologia 2016;48(5):570-5. PMID:26395129',
    'Biswas TK et al. Clinical evaluation of spermatogenic activity of processed Shilajit in oligospermia. Andrologia 2010;42(1):48-56. PMID:20078516'
  ],
  'male',
  2, 'Take in morning with warm water or milk', 'Can be taken with or without food; traditionally dissolved in warm water'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'Shilajit');

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'Boron Hormonal & Bone Health Protocol',
  'Boron', 'Hormonal', 'supplement',
  'Essential trace mineral that modulates steroid hormone metabolism, reduces SHBG levels (freeing bound testosterone and estradiol), and supports calcium/magnesium/vitamin D utilization for bone health. Clinical study showed boron supplementation (6mg/day) significantly increased free testosterone (+28%), decreased estradiol, and elevated DHT in healthy men within 1 week. Also anti-inflammatory via reduced hsCRP and TNF-alpha.',
  'moderate', '3mg', '10mg',
  'once daily',
  'oral',
  'Ongoing; safe for long-term use at recommended doses',
  ARRAY[
    'Do not exceed 20mg/day (UL) — toxicity at high doses',
    'May reduce effectiveness of estrogen-lowering drugs by raising estradiol',
    'Low toxicity at recommended doses but acute overdose causes GI irritation'
  ],
  ARRAY[
    'GI upset at high doses',
    'Nausea (rare)'
  ],
  ARRAY[
    'Naghii MR et al. Comparative effects of daily and weekly boron supplementation on plasma steroid hormones and proinflammatory cytokines. J Trace Elem Med Biol 2011;25(1):54-8. PMID:21129941'
  ],
  'both',
  2, 'Take in morning with food; pairs well with calcium, magnesium, and vitamin D', 'Take with meals'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'Boron');

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'DHEA Hormone Precursor Protocol',
  'DHEA', 'Hormonal', 'supplement',
  'Dehydroepiandrosterone — the most abundant circulating steroid hormone and precursor to both testosterone and estrogen. DHEA levels decline 80% between ages 25-75. Meta-analyses show benefits for body composition, bone density, sexual function, and mood in older adults. Particularly effective in women for androgen-deficiency symptoms. Requires monitoring of downstream hormones (testosterone, estradiol, DHEA-S).',
  'moderate', '10mg', '50mg',
  'once daily in morning',
  'oral',
  '8-12 weeks; lab monitoring required',
  ARRAY[
    'MUST test baseline DHEA-S, testosterone, and estradiol before starting and monitor every 8 weeks',
    'May cause androgenic side effects in women (acne, hair growth, deepening voice)',
    'Contraindicated in hormone-sensitive cancers (breast, prostate, ovarian)',
    'Lower doses (10-25mg) for women; up to 50mg for men',
    'May affect liver enzymes at high doses'
  ],
  ARRAY[
    'Acne',
    'Oily skin',
    'Hair loss (androgenic)',
    'Mood changes',
    'Breast tenderness'
  ],
  ARRAY[
    'Rutkowski K et al. Dehydroepiandrosterone (DHEA): hypes and hopes. Drugs 2014;74(11):1195-207. PMID:25022952'
  ],
  'both',
  2, 'Take in morning to mimic natural circadian pattern; test DHEA-S levels every 8 weeks', 'Take with meals'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'DHEA');

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'Maca Root Hormonal Adaptogen Protocol',
  'Maca Root', 'Hormonal', 'supplement',
  'Lepidium meyenii root from Peruvian highlands, used for centuries as a hormonal adaptogen. Does not directly affect testosterone or estrogen levels but modulates hypothalamic-pituitary axis function. RCT evidence for improved sexual desire and erectile function independent of serum hormone levels. Black maca specifically benefits spermatogenesis; red maca supports female hormonal balance and bone density.',
  'moderate', '1500mg', '3000mg',
  'once daily',
  'oral',
  '8-12 weeks; cycle 2 weeks off periodically',
  ARRAY[
    'May worsen thyroid conditions in individuals with iodine deficiency (contains goitrogens)',
    'Different colors have different effects: black for male fertility, red for female balance, yellow for general',
    'Gelatinized form preferred for digestibility over raw'
  ],
  ARRAY[
    'GI upset',
    'Insomnia',
    'Acne (rare)',
    'Mood changes'
  ],
  ARRAY[
    'Gonzales GF et al. Effect of Lepidium meyenii (MACA) on sexual desire and its absent relationship with serum testosterone levels in adult healthy men. Andrologia 2002;34(6):367-72. PMID:12472620',
    'Shin BC et al. Maca (L. meyenii) for improving sexual function: a systematic review. BMC Complement Altern Med 2010;10:44. PMID:20691074'
  ],
  'both',
  2, 'Take in morning with food; gelatinized form for better tolerance', 'Take with meals; gelatinized form is easier to digest'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'Maca Root');

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'Saw Palmetto Prostate & DHT Protocol',
  'Saw Palmetto', 'Hormonal', 'supplement',
  'Serenoa repens berry extract that inhibits 5-alpha-reductase types I and II, reducing conversion of testosterone to DHT. Widely used for benign prostatic hyperplasia (BPH) with meta-analysis showing improved urinary flow rates and reduced IPSS scores. Also reduces DHT-mediated hair loss. Liposterolic extract (85-95% fatty acids and sterols) is the clinically validated form.',
  'moderate', '160mg', '320mg',
  'once or twice daily with meals',
  'oral',
  '12-24 weeks for BPH benefits',
  ARRAY[
    'May affect PSA levels — inform urologist before testing',
    'May interact with anticoagulant/antiplatelet drugs',
    'Use liposterolic extract standardized to 85-95% fatty acids',
    'Not a substitute for medical evaluation of urinary symptoms'
  ],
  ARRAY[
    'GI upset',
    'Headache',
    'Reduced libido (uncommon)',
    'Dizziness'
  ],
  ARRAY[
    'Tacklind J et al. Serenoa repens for benign prostatic hyperplasia. Cochrane Database Syst Rev 2012;12:CD001423. PMID:23235581'
  ],
  'male',
  2, 'Take with meals containing fat; liposterolic extract preferred', 'Take with fat-containing meals for liposterolic extract absorption'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'Saw Palmetto');

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'Vitex (Chasteberry) Female Hormone Balance Protocol',
  'Vitex (Chasteberry)', 'Hormonal', 'supplement',
  'Vitex agnus-castus berry extract that modulates dopaminergic tone in the anterior pituitary, reducing excess prolactin and normalizing LH/FSH ratio. Well-studied for PMS symptom relief, menstrual irregularity, luteal phase defect, and cyclical breast pain (mastalgia). Meta-analysis of RCTs confirms superiority over placebo for PMS symptoms. Effects require 2-3 menstrual cycles to fully manifest.',
  'well-studied', '20mg', '40mg',
  'once daily in morning',
  'oral',
  '3-6 months (minimum 3 menstrual cycles)',
  ARRAY[
    'Not for use during pregnancy or breastfeeding',
    'May interfere with hormonal contraceptives and IVF medications',
    'May interact with dopamine agonists/antagonists (medications for Parkinson disease, antipsychotics)',
    'Discontinue if planning IVF or using fertility medications'
  ],
  ARRAY[
    'Headache',
    'GI upset',
    'Acne',
    'Menstrual flow changes',
    'Dizziness'
  ],
  ARRAY[
    'Verkaik S et al. The treatment of premenstrual syndrome with preparations of Vitex agnus castus: a systematic review and meta-analysis. Am J Obstet Gynecol 2017;217(2):150-166. PMID:28237870'
  ],
  'female',
  2, 'Take in morning on empty stomach; continuous use through full cycle (do not stop during menstruation)', 'Best on empty stomach'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'Vitex (Chasteberry)');

-- ------------------------------------------------------------
-- MINERALS SUPPLEMENTS
-- ------------------------------------------------------------

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'Selenium (Selenomethionine) Thyroid & Antioxidant Protocol',
  'Selenium (Selenomethionine)', 'Minerals', 'supplement',
  'Essential trace mineral in organic selenomethionine form with superior bioavailability. Critical cofactor for glutathione peroxidases, thioredoxin reductases, and iodothyronine deiodinases (T4 to T3 conversion). RCTs demonstrate reduction in thyroid antibodies (TPO-Ab) in Hashimoto''s thyroiditis, improved sperm quality, and reduced cancer biomarkers. The thyroid contains more selenium per gram than any other organ.',
  'well-studied', '100mcg', '200mcg',
  'once daily',
  'oral',
  'Ongoing; essential for thyroid health',
  ARRAY[
    'Do NOT exceed 400mcg/day (UL) — selenium toxicity (selenosis) causes hair loss, nail brittleness, GI issues, and neurological symptoms',
    'Selenomethionine preferred over selenite for lower toxicity and better retention',
    'Test serum selenium before supplementing if on selenium-rich diet (Brazil nuts)'
  ],
  ARRAY[
    'Garlic breath (at higher doses)',
    'GI upset',
    'Metallic taste',
    'Hair/nail brittleness with chronic excess'
  ],
  ARRAY[
    'Rayman MP. Selenium and human health. Lancet 2012;379(9822):1256-68. PMID:22381456',
    'van Zuuren EJ et al. Selenium supplementation for Hashimoto''s thyroiditis. Cochrane Database Syst Rev 2013;(6):CD010223. PMID:23744563'
  ],
  'both',
  2, 'Take with meals; pairs well with vitamin E and iodine for thyroid support', 'Take with meals'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'Selenium (Selenomethionine)');

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'Iodine (Potassium Iodide) Thyroid Support Protocol',
  'Iodine (Potassium Iodide)', 'Minerals', 'supplement',
  'Essential halide mineral required for thyroid hormone synthesis (T3 and T4). Iodine deficiency is the most common preventable cause of cognitive impairment worldwide. Potassium iodide is the most stable and bioavailable supplemental form. Supports thyroid peroxidase activity, breast tissue health, and immune function. Deficiency is re-emerging in Western populations due to reduced iodized salt intake.',
  'well-studied', '150mcg', '500mcg',
  'once daily',
  'oral',
  'Ongoing; essential micronutrient',
  ARRAY[
    'Do NOT mega-dose — excess iodine can paradoxically SUPPRESS thyroid function (Wolff-Chaikoff effect)',
    'Contraindicated in hyperthyroidism and Graves'' disease',
    'Start low in Hashimoto''s patients — may temporarily increase TPO antibodies',
    'Always pair with selenium (200mcg) when supplementing iodine for thyroid safety'
  ],
  ARRAY[
    'Metallic taste',
    'GI upset',
    'Thyroid function changes',
    'Acne (rare)'
  ],
  ARRAY[
    'Zimmermann MB, Boelaert K. Iodine deficiency and thyroid disorders. Lancet Diabetes Endocrinol 2015;3(4):286-95. PMID:25591468'
  ],
  'both',
  2, 'Take in morning with food; always co-supplement with selenium', 'Take with meals'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'Iodine (Potassium Iodide)');

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'Iron Bisglycinate Bioavailable Iron Protocol',
  'Iron Bisglycinate', 'Minerals', 'supplement',
  'Chelated amino acid form of iron with 2-4x greater absorption than ferrous sulfate and significantly fewer GI side effects. Does not require gastric acid for absorption, making it suitable for those on PPIs. Clinical trials demonstrate effective correction of iron-deficiency anemia with minimal constipation, nausea, and dark stools that plague conventional iron supplements.',
  'well-studied', '18mg', '36mg',
  'once daily on empty stomach or with vitamin C',
  'oral',
  'Until ferritin normalizes (typically 3-6 months); then maintenance dose',
  ARRAY[
    'MUST test serum ferritin, iron, TIBC before supplementing — iron overload is dangerous',
    'Never supplement iron without confirmed deficiency — excess iron is pro-oxidant and cardiotoxic',
    'Keep away from children — iron overdose is a leading cause of pediatric poisoning'
  ],
  ARRAY[
    'Constipation (less than other forms)',
    'Dark stools',
    'Nausea (less than ferrous sulfate)'
  ],
  ARRAY[
    'Name JJ et al. Iron Bisglycinate Chelate and Polymaltose Iron for the Treatment of Iron Deficiency Anemia: A Pilot Randomized Trial. Curr Ther Res Clin Exp 2018;90:56-61. PMID:30662575'
  ],
  'both',
  2, 'Take on empty stomach with vitamin C for maximum absorption; avoid with calcium, coffee, tea', 'Fasted with vitamin C preferred; food reduces absorption but improves tolerance'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'Iron Bisglycinate');

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'Calcium D-Glucarate Detoxification Protocol',
  'Calcium D-Glucarate', 'Minerals', 'supplement',
  'Calcium salt of D-glucaric acid that inhibits beta-glucuronidase enzyme in the gut, preventing reabsorption of conjugated toxins and excess hormones (especially estrogen). Supports phase II glucuronidation detoxification pathway. Used for estrogen dominance, environmental toxin clearance, and metabolic syndrome support. Found naturally in cruciferous vegetables, apples, and citrus.',
  'emerging', '500mg', '1500mg',
  'once or twice daily with meals',
  'oral',
  '8-12 weeks; can be used long-term',
  ARRAY[
    'May reduce estrogen levels — use caution if estrogen-depleted or on HRT',
    'Theoretical concern about reducing efficacy of drugs cleared via glucuronidation',
    'Reasonable safety profile but limited human RCT data'
  ],
  ARRAY[
    'Mild GI upset',
    'Loose stools',
    'Headache (rare)'
  ],
  ARRAY[
    'Walaszek Z et al. Dietary glucarate as anti-promoter of 7,12-dimethylbenz[a]anthracene-induced mammary tumorigenesis. Carcinogenesis 1986;7(9):1463-6. PMID:3091266'
  ],
  'both',
  2, 'Take with meals; split dose for sustained beta-glucuronidase inhibition', 'Take with meals'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'Calcium D-Glucarate');

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'Potassium Citrate Electrolyte & Alkalinity Protocol',
  'Potassium Citrate', 'Minerals', 'supplement',
  'Highly bioavailable potassium salt that provides alkalizing citrate for acid-base balance. Most adults consume less than half the adequate intake of potassium (4,700mg/day). Citrate form alkalinizes urine, preventing kidney stone formation (calcium oxalate and uric acid). Supports blood pressure regulation, muscle function, and bone mineral preservation by reducing urinary calcium excretion.',
  'well-studied', '99mg', '300mg',
  'once or twice daily with meals',
  'oral',
  'Ongoing; essential electrolyte',
  ARRAY[
    'Contraindicated in kidney disease or use of potassium-sparing diuretics (spironolactone, amiloride) — hyperkalemia risk',
    'Do not exceed supplemental potassium without medical supervision',
    'May interact with ACE inhibitors and ARBs',
    'Slow-release forms preferred to avoid GI irritation'
  ],
  ARRAY[
    'GI upset',
    'Nausea',
    'Diarrhea',
    'Hyperkalemia if combined with K-sparing medications'
  ],
  ARRAY[
    'Whelton PK et al. Effects of oral potassium on blood pressure. JAMA 1997;277(20):1624-32. PMID:9168293'
  ],
  'both',
  2, 'Take with meals to reduce GI irritation; spread doses throughout day', 'Take with meals'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'Potassium Citrate');

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'Copper Bisglycinate Mineral Balance Protocol',
  'Copper Bisglycinate', 'Minerals', 'supplement',
  'Chelated copper supplement critical for those supplementing zinc >30mg/day, as chronic zinc supplementation depletes copper stores. Copper is essential for ceruloplasmin (iron metabolism), superoxide dismutase (SOD antioxidant defense), cytochrome c oxidase (mitochondrial energy), and lysyl oxidase (collagen cross-linking). Bisglycinate form is highly bioavailable with minimal GI irritation.',
  'moderate', '1mg', '2mg',
  'once daily',
  'oral',
  'Ongoing when supplementing zinc >30mg/day',
  ARRAY[
    'Only supplement copper when zinc supplementation exceeds 30mg/day — zinc depletes copper',
    'Do NOT supplement in Wilson''s disease (genetic copper accumulation)',
    'Excess copper is pro-oxidant and neurotoxic — do not exceed 10mg/day UL'
  ],
  ARRAY[
    'GI upset',
    'Nausea',
    'Metallic taste'
  ],
  ARRAY[
    'Collins JF et al. Metabolic crossroads of iron and copper. Nutr Rev 2010;68(3):133-47. PMID:20384844'
  ],
  'both',
  2, 'Take with meals; take at different time than zinc supplements (at least 2 hours apart)', 'Take with meals; take at different time than zinc supplements'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'Copper Bisglycinate');

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'Manganese Bisglycinate Bone & Antioxidant Protocol',
  'Manganese Bisglycinate', 'Minerals', 'supplement',
  'Essential trace mineral in chelated form required for manganese superoxide dismutase (MnSOD — mitochondrial antioxidant), bone matrix formation (glycosyltransferases), glucose metabolism (pyruvate carboxylase), and cartilage proteoglycan synthesis. Deficiency contributes to osteoporosis, glucose intolerance, and impaired wound healing. Bisglycinate chelate provides high bioavailability.',
  'emerging', '2mg', '5mg',
  'once daily',
  'oral',
  'Ongoing as part of mineral balance protocol',
  ARRAY[
    'Do NOT exceed 11mg/day (UL) — manganese toxicity causes neurological symptoms resembling Parkinson disease',
    'Individuals with liver disease are at higher risk of manganese accumulation'
  ],
  ARRAY[
    'GI upset (rare at recommended doses)',
    'Headache'
  ],
  ARRAY[
    'Li L, Yang X. The Essential Element Manganese, Oxidative Stress, and Metabolic Diseases: Links and Interactions. Oxid Med Cell Longev 2018;2018:7580707. PMID:29849912'
  ],
  'both',
  2, 'Take with meals; take at different time than iron, calcium, and zinc (2 hours apart)', 'Take with meals'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'Manganese Bisglycinate');

-- ------------------------------------------------------------
-- IMMUNE SUPPLEMENTS
-- ------------------------------------------------------------

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'Elderberry Extract Immune Defense Protocol',
  'Elderberry Extract', 'Immune', 'supplement',
  'Sambucus nigra berry extract rich in anthocyanins and flavonoids with clinically validated antiviral activity. Meta-analysis of RCTs demonstrates significant reduction in cold and flu duration and severity. Inhibits viral neuraminidase (similar mechanism to Tamiflu), prevents viral entry into host cells, and stimulates cytokine production for enhanced immune surveillance. Most effective when initiated within 24-48 hours of symptom onset.',
  'moderate', '300mg', '600mg',
  'once or twice daily; increase to 3-4x daily during acute illness',
  'oral',
  'Preventive: 8-12 weeks during cold/flu season; acute: 5 days',
  ARRAY[
    'Use only commercially prepared extracts — raw elderberries contain cyanogenic glycosides (toxic)',
    'Theoretical concern about cytokine storm in severe infections — not substantiated in clinical data but exercise caution',
    'May interact with immunosuppressant medications'
  ],
  ARRAY[
    'GI upset',
    'Nausea (especially with raw preparations)'
  ],
  ARRAY[
    'Hawkins J et al. Black elderberry (Sambucus nigra) supplementation effectively treats upper respiratory symptoms: A meta-analysis of randomized, controlled clinical trials. Complement Ther Med 2019;42:361-365. PMID:30670267'
  ],
  'both',
  2, 'Preventive: once daily; acute illness: every 3-4 hours for first 48 hours', 'Can be taken with or without food'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'Elderberry Extract');

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'Andrographis Immune Modulation Protocol',
  'Andrographis', 'Immune', 'supplement',
  'Andrographis paniculata leaf extract (King of Bitters) containing andrographolides with potent immunostimulatory and anti-inflammatory properties. Multiple RCTs demonstrate efficacy for reducing severity and duration of upper respiratory infections. Activates innate immunity (NK cells, macrophage phagocytosis) while modulating excessive adaptive immune response. Also shows hepatoprotective and antipyretic activity.',
  'moderate', '200mg', '600mg',
  'twice daily during acute illness; once daily for prevention',
  'oral',
  'Acute: 5-7 days; preventive: 8-12 weeks during infection season',
  ARRAY[
    'May potentiate anticoagulant effects',
    'Avoid during pregnancy (may have anti-fertility effects)',
    'May lower blood pressure — caution with antihypertensives',
    'Extremely bitter taste — capsules preferred over liquid'
  ],
  ARRAY[
    'GI upset',
    'Bitter taste',
    'Headache',
    'Fatigue',
    'Allergic reactions (rare)'
  ],
  ARRAY[
    'Hu XY et al. Andrographis paniculata (Chuan Xin Lian) for symptomatic relief of acute respiratory tract infections in adults and children. Cochrane Database Syst Rev 2017;(4):CD009374. PMID:28436583'
  ],
  'both',
  2, 'Take at first sign of illness; double dose for first 48 hours then taper', 'Take with meals to reduce bitter taste and GI effects'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'Andrographis');

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'Astragalus Root Immune Tonic Protocol',
  'Astragalus', 'Immune', 'supplement',
  'Astragalus membranaceus root extract — one of the most important immune tonic herbs in Traditional Chinese Medicine. Contains astragalosides and polysaccharides that enhance telomerase activity (TA-65 is derived from astragalus), stimulate NK cell activity, increase IgA production, and modulate Th1/Th2 immune balance. Adaptogenic properties support adrenal function during chronic stress and illness recovery.',
  'emerging', '500mg', '1500mg',
  'once or twice daily',
  'oral',
  '8-12 weeks; traditionally used for seasonal immune support',
  ARRAY[
    'Contraindicated during active autoimmune flares — it stimulates immunity',
    'Do NOT use during acute fever or active infection — traditional use is for prevention and recovery',
    'May interact with immunosuppressant drugs',
    'Avoid with lithium (may reduce excretion)'
  ],
  ARRAY[
    'GI upset (rare)',
    'Allergic reactions in legume-sensitive individuals'
  ],
  ARRAY[
    'Liu P et al. Anti-Aging Implications of Astragalus Membranaceus (Huangqi): A Well-Known Chinese Tonic. Aging Dis 2017;8(6):868-886. PMID:29344421'
  ],
  'both',
  2, 'Take in morning for immune tonic effect; avoid during active infections', 'Can be taken with or without food'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'Astragalus');

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'Vitamin C (Liposomal) Immune & Antioxidant Protocol',
  'Vitamin C (Liposomal)', 'Immune', 'supplement',
  'Liposomal delivery of ascorbic acid bypasses the saturable SVCT transporter limit of standard vitamin C (~200mg per dose), achieving 2-3x higher plasma levels. Essential cofactor for immune cell function (neutrophil chemotaxis, lymphocyte proliferation), collagen synthesis, and carnitine production. Meta-analysis of 29 RCTs shows reduced cold duration by 8% in adults and 14% in children. Liposomal form approaches IV vitamin C bioavailability.',
  'well-studied', '500mg', '2000mg',
  'once or twice daily',
  'oral',
  'Ongoing; essential vitamin with no storage capacity',
  ARRAY[
    'Liposomal form greatly reduces the GI upset and diarrhea common with high-dose standard vitamin C',
    'May interfere with certain lab tests (glucose monitors, occult blood tests)',
    'High doses may increase oxalate excretion — caution with history of kidney stones',
    'Excess vitamin C is excreted renally — not toxic but wasteful above absorption capacity'
  ],
  ARRAY[
    'GI upset at high doses (less with liposomal)',
    'Diarrhea with standard forms above bowel tolerance'
  ],
  ARRAY[
    'Hemila H, Chalker E. Vitamin C for preventing and treating the common cold. Cochrane Database Syst Rev 2013;(1):CD000980. PMID:23440782',
    'Davis JL et al. Liposomal-encapsulated Ascorbic Acid: Influence on Vitamin C Bioavailability and Capacity to Protect Against Ischemia-Reperfusion Injury. Nutr Metab Insights 2016;9:25-30. PMID:27375360'
  ],
  'both',
  2, 'Split doses throughout day for sustained levels; hold liposomal under tongue briefly', 'Can be taken with or without food; liposomal form does not require food'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'Vitamin C (Liposomal)');

-- ------------------------------------------------------------
-- PERFORMANCE SUPPLEMENTS
-- ------------------------------------------------------------

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'Creatine Monohydrate Performance & Cognitive Protocol',
  'Creatine Monohydrate', 'Performance', 'supplement',
  'The most researched sports supplement in history with over 500 peer-reviewed studies confirming efficacy. Increases intramuscular phosphocreatine stores for rapid ATP regeneration during high-intensity exercise. Meta-analyses show 5-10% improvements in strength, power output, and lean mass. Emerging evidence for cognitive benefits (brain PCr stores), neuroprotection, and bone health. ISSN position stand rates it as the most effective ergogenic supplement available.',
  'well-studied', '3g', '5g',
  'once daily',
  'oral',
  'Ongoing; no cycling necessary — safe for long-term continuous use',
  ARRAY[
    'Stay well-hydrated — creatine increases intracellular water retention',
    'Initial weight gain of 1-3 lbs is water retention, not fat',
    'Monohydrate is the only form with robust evidence — avoid expensive alternatives (HCl, buffered, etc.)',
    'May slightly increase creatinine (kidney biomarker) without indicating actual kidney damage'
  ],
  ARRAY[
    'Water retention',
    'GI upset with loading doses',
    'Muscle cramping if dehydrated'
  ],
  ARRAY[
    'Kreider RB et al. International Society of Sports Nutrition position stand: safety and efficacy of creatine supplementation in exercise, sport, and medicine. J Int Soc Sports Nutr 2017;14:18. PMID:28615996',
    'Avgerinos KI et al. Effects of creatine supplementation on cognitive function of healthy individuals: A systematic review of randomized controlled trials. Exp Gerontol 2018;108:166-173. PMID:29704637'
  ],
  'both',
  2, 'Take any time of day; post-workout with carbs/protein may slightly enhance uptake', 'Take with food or beverage; dissolves best in warm liquid'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'Creatine Monohydrate');

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'Beta-Alanine Endurance & Buffering Protocol',
  'Beta-Alanine', 'Performance', 'supplement',
  'Non-essential amino acid that is the rate-limiting precursor to carnosine — the primary intramuscular pH buffer. Supplementation increases muscle carnosine by 40-80%, delaying acidosis during high-intensity exercise. Meta-analysis of 40 studies confirms significant improvement in exercise lasting 1-4 minutes. ISSN position stand confirms it as an effective ergogenic aid.',
  'well-studied', '2g', '5g',
  'daily (split into 2-3 doses to reduce paresthesia)',
  'oral',
  'Ongoing; muscle carnosine accumulates over 4-12 weeks',
  ARRAY[
    'Harmless paresthesia (tingling/flushing in face, hands) is the most common side effect — reduces with sustained-release forms or split dosing',
    'Benefits are cumulative — requires 4+ weeks of consistent dosing to saturate muscle carnosine',
    'No known serious adverse effects'
  ],
  ARRAY[
    'Paresthesia (tingling, flushing — harmless)',
    'Mild GI upset at large single doses'
  ],
  ARRAY[
    'Saunders B et al. Beta-alanine supplementation to improve exercise capacity and performance: a systematic review and meta-analysis. Br J Sports Med 2017;51(8):658-669. PMID:27797728',
    'Trexler ET et al. International society of sports nutrition position stand: Beta-Alanine. J Int Soc Sports Nutr 2015;12:30. PMID:26175657'
  ],
  'both',
  2, 'Split doses throughout day to minimize paresthesia; timing relative to exercise does not matter', 'Take with meals to reduce GI effects and paresthesia'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'Beta-Alanine');

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'Acetyl-L-Carnitine Metabolic & Cognitive Protocol',
  'Acetyl-L-Carnitine', 'Performance', 'supplement',
  'Acetylated form of L-carnitine that crosses the blood-brain barrier, providing both carnitine (mitochondrial fatty acid transport) and acetyl groups (acetylcholine precursor). Enhances fat oxidation, supports mitochondrial function, and provides neuroprotection. Clinical evidence for improving peripheral neuropathy, cognitive function in elderly, fatigue in chronic fatigue syndrome, and exercise recovery. Superior to L-carnitine for cognitive applications.',
  'moderate', '500mg', '2000mg',
  'once or twice daily',
  'oral',
  '8-12 weeks for neuropathy/cognitive; ongoing for metabolic support',
  ARRAY[
    'Take in morning or early afternoon — may cause insomnia if taken late',
    'May increase seizure risk in epileptic individuals',
    'Rare reports of fishy body odor (TMA metabolite) — less common than with L-carnitine',
    'May enhance thyroid hormone effects — monitor if hypothyroid on medication'
  ],
  ARRAY[
    'GI upset',
    'Nausea',
    'Restlessness',
    'Fishy body odor (rare)',
    'Insomnia if taken late'
  ],
  ARRAY[
    'Malaguarnera M et al. Acetyl L-carnitine (ALC) treatment in elderly patients with fatigue. Arch Gerontol Geriatr 2008;46(2):181-90. PMID:17658628'
  ],
  'both',
  2, 'Take in morning on empty stomach; avoid evening dosing', 'Can be taken with or without food; empty stomach for faster absorption'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'Acetyl-L-Carnitine');

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'Beetroot Extract (Nitrate) Nitric Oxide Protocol',
  'Beetroot Extract (Nitrate)', 'Performance', 'supplement',
  'Concentrated source of dietary nitrate (NO3-) that is sequentially reduced to nitrite (NO2-) and then nitric oxide (NO) via the enterosalivary pathway. Improves exercise efficiency by reducing oxygen cost of submaximal exercise, enhances blood flow and vasodilation, and lowers blood pressure. Meta-analysis confirms 3% improvement in time-trial performance and significant blood pressure reduction (~4 mmHg systolic).',
  'well-studied', '300mg', '600mg',
  'once daily (or 2-3 hours before exercise)',
  'oral',
  'Ongoing for cardiovascular health; acute for exercise performance',
  ARRAY[
    'Do NOT use antiseptic mouthwash within 2 hours of dosing — it kills oral bacteria needed for nitrate-to-nitrite conversion',
    'May cause red/pink urine and stools (beeturia — harmless)',
    'Additive blood pressure lowering with antihypertensives — monitor',
    'Avoid with PDE5 inhibitors without physician guidance'
  ],
  ARRAY[
    'Red urine/stools (harmless)',
    'GI upset',
    'Temporary red discoloration of skin'
  ],
  ARRAY[
    'Dominguez R et al. Effects of Beetroot Juice Supplementation on Cardiorespiratory Endurance in Athletes: A Systematic Review. Nutrients 2017;9(1):43. PMID:28067808',
    'Siervo M et al. Inorganic nitrate and beetroot juice supplementation reduces blood pressure in adults: a systematic review and meta-analysis. J Nutr 2013;143(6):818-26. PMID:23596162'
  ],
  'both',
  2, 'Take 2-3 hours before exercise for performance; morning for blood pressure support', 'Can be taken with or without food; do NOT use mouthwash for 2 hours after'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'Beetroot Extract (Nitrate)');

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'Taurine Cellular Performance Protocol',
  'Taurine', 'Performance', 'supplement',
  'Conditionally essential sulfur amino acid and osmolyte with cytoprotective, anti-inflammatory, and anti-oxidant properties. Taurine levels decline with age and are associated with accelerated aging across species. Meta-analysis identified taurine deficiency as a driver of aging. Enhances calcium handling in cardiac and skeletal muscle, supports bile acid conjugation, and modulates GABA receptors for neuroprotection.',
  'moderate', '1000mg', '3000mg',
  'once or twice daily',
  'oral',
  'Ongoing; safe for long-term use',
  ARRAY[
    'Generally very safe — endogenous compound with excellent tolerability',
    'May enhance effects of blood pressure medications',
    'May interact with lithium',
    'High doses may cause mild GI effects'
  ],
  ARRAY[
    'Mild GI upset at high doses',
    'Diarrhea (rare)'
  ],
  ARRAY[
    'Singh P et al. Taurine deficiency as a driver of aging. Science 2023;380(6649):eabn9257. PMID:37289866',
    'Waldron M et al. The Effects of an Oral Taurine Dose and Supplementation Period on Endurance Exercise Performance in Humans: A Meta-Analysis. Sports Med 2018;48(5):1247-1253. PMID:29546641'
  ],
  'both',
  2, 'Take pre-workout for exercise performance or in evening for cardioprotective/sleep benefits', 'Can be taken with or without food'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'Taurine');

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'HMB (beta-Hydroxy beta-Methylbutyrate) Muscle Protocol',
  'HMB (beta-Hydroxy beta-Methylbutyrate)', 'Performance', 'supplement',
  'Metabolite of leucine that attenuates muscle protein breakdown via ubiquitin-proteasome pathway inhibition and stimulates muscle protein synthesis through mTOR activation. ISSN position stand confirms efficacy for reducing exercise-induced muscle damage, accelerating recovery, and increasing lean mass — particularly in untrained individuals, elderly, and during caloric restriction. Free acid form (HMB-FA) has faster absorption than calcium HMB.',
  'moderate', '1500mg', '3000mg',
  'split into 3 doses daily (1g per dose)',
  'oral',
  'Ongoing during training periods',
  ARRAY[
    'Most effective for untrained individuals starting exercise programs or elderly preventing sarcopenia',
    'Benefits in trained athletes are more modest and context-dependent',
    'Ca-HMB and HMB-FA are both effective; HMB-FA absorbs faster'
  ],
  ARRAY[
    'Generally very well-tolerated',
    'Mild GI upset (rare)'
  ],
  ARRAY[
    'Wilson JM et al. International Society of Sports Nutrition Position Stand: beta-hydroxy-beta-methylbutyrate (HMB). J Int Soc Sports Nutr 2013;10(1):6. PMID:23374455'
  ],
  'both',
  2, 'Split into 3 doses: morning, pre-workout, and evening; take 30-60 min before exercise', 'Can be taken with or without food; timing more important than food'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'HMB (beta-Hydroxy beta-Methylbutyrate)');

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'Electrolyte Complex Hydration Protocol',
  'Electrolyte Complex', 'Performance', 'supplement',
  'Balanced formulation of sodium, potassium, magnesium, and chloride for optimal cellular hydration. Essential for maintaining membrane potential, nerve conduction, muscle contraction, and acid-base balance. Particularly critical during fasting, ketogenic diets, intense exercise, heat exposure, and with diuretic use. Proper electrolyte balance prevents muscle cramps, fatigue, headaches, and cardiac arrhythmias.',
  'well-studied', '1 serving', '3 servings',
  'daily; increase with exercise, heat, or fasting',
  'oral',
  'Ongoing as needed; critical during exercise, heat, and low-carb diets',
  ARRAY[
    'Individuals with kidney disease, heart failure, or on potassium-sparing diuretics must consult physician before supplementing electrolytes',
    'Sodium restriction may be necessary for hypertensive individuals — adjust formula accordingly',
    'Monitor potassium and sodium levels if using daily long-term'
  ],
  ARRAY[
    'GI upset if too concentrated',
    'Bloating',
    'Nausea'
  ],
  ARRAY[
    'Thomas DT et al. American College of Sports Medicine Joint Position Statement. Nutrition and Athletic Performance. Med Sci Sports Exerc 2016;48(3):543-68. PMID:26891166'
  ],
  'both',
  2, 'During and after exercise; morning for fasting protocols; throughout day for keto diets', 'Best taken with water between meals or during exercise'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'Electrolyte Complex');

-- ------------------------------------------------------------
-- SLEEP SUPPLEMENTS
-- ------------------------------------------------------------

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'Melatonin Sleep & Circadian Protocol',
  'Melatonin', 'Sleep', 'supplement',
  'Endogenous neurohormone produced by the pineal gland that regulates circadian rhythm and sleep-wake cycles. Meta-analyses confirm melatonin reduces sleep onset latency by 7 minutes and increases total sleep time by 8 minutes in primary insomnia. More effective for circadian misalignment (jet lag, shift work, delayed sleep phase). Also a potent antioxidant protecting mitochondrial DNA. Lower doses (0.3-0.5mg) are often more physiological than higher commercial doses.',
  'well-studied', '0.3mg', '5mg',
  'once nightly, 30-60 minutes before bedtime',
  'oral',
  '2-4 weeks for acute circadian adjustment; can use longer for chronic insomnia',
  ARRAY[
    'Start with lowest effective dose (0.3-0.5mg) — higher is not always better',
    'May suppress endogenous production with long-term high-dose use — use lowest effective dose',
    'May worsen depression in some individuals',
    'Avoid if pregnant, breastfeeding, or with autoimmune conditions (immune modulating)',
    'May interact with blood thinners, diabetes medications, and immunosuppressants'
  ],
  ARRAY[
    'Morning grogginess',
    'Vivid dreams',
    'Headache',
    'Dizziness',
    'Nausea'
  ],
  ARRAY[
    'Ferracioli-Oda E et al. Meta-analysis: melatonin for the treatment of primary sleep disorders. PLoS One 2013;8(5):e63773. PMID:23691095',
    'Costello RB et al. The effectiveness of melatonin for promoting healthy sleep: a rapid evidence assessment of the literature. Nutr J 2014;13:106. PMID:25380732'
  ],
  'both',
  1, 'Take 0.3-1mg 30-60 minutes before desired bedtime; time-release for sleep maintenance', 'Best on empty stomach; food may delay absorption'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'Melatonin');

-- ------------------------------------------------------------
-- BONE HEALTH SUPPLEMENTS
-- ------------------------------------------------------------

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'Vitamin K2 (MK-7) Calcium Direction Protocol',
  'Vitamin K2 (MK-7)', 'Bone Health', 'supplement',
  'Menaquinone-7 (MK-7) activates osteocalcin (directing calcium to bones) and matrix Gla-protein (preventing arterial calcification). Essential companion to vitamin D3 supplementation — D3 increases calcium absorption but K2 ensures proper deposition. Long half-life (72 hours) of MK-7 allows once-daily dosing. RCTs show reduced bone loss, improved bone mineral density, and reduced vascular calcification.',
  'moderate', '100mcg', '200mcg',
  'once daily with meals',
  'oral',
  'Ongoing; especially important when supplementing vitamin D3 and/or calcium',
  ARRAY[
    'CRITICAL interaction with warfarin — vitamin K directly opposes warfarin mechanism; do NOT supplement without physician guidance if on warfarin',
    'No interaction concern with DOACs (apixaban, rivarelbaan) — these do not affect vitamin K',
    'Always pair with vitamin D3 supplementation'
  ],
  ARRAY[
    'Generally well-tolerated',
    'Rare GI upset'
  ],
  ARRAY[
    'Knapen MH et al. Three-year low-dose menaquinone-7 supplementation helps decrease bone loss in healthy postmenopausal women. Osteoporos Int 2013;24(9):2499-507. PMID:23525894',
    'Geleijnse JM et al. Dietary intake of menaquinone is associated with a reduced risk of coronary heart disease: the Rotterdam Study. J Nutr 2004;134(11):3100-5. PMID:15514282'
  ],
  'both',
  2, 'Take with fat-containing meal alongside vitamin D3 for synergistic effect', 'Must take with fat-containing meals (fat-soluble vitamin)'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'Vitamin K2 (MK-7)');

-- ------------------------------------------------------------
-- ENERGY SUPPLEMENTS
-- ------------------------------------------------------------

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'B-Complex (Methylated) Energy & Methylation Protocol',
  'B-Complex (Methylated)', 'Energy', 'supplement',
  'Comprehensive B-vitamin complex using bioactive methylated forms: methylfolate (5-MTHF, not folic acid), methylcobalamin (B12), pyridoxal-5-phosphate (B6), and riboflavin-5-phosphate (B2). Critical for methylation cycle, homocysteine metabolism, neurotransmitter synthesis, cellular energy production, and red blood cell formation. Methylated forms bypass common MTHFR polymorphisms (affecting ~40% of population) that impair conversion of synthetic vitamins.',
  'well-studied', '1 capsule', '2 capsules',
  'once daily with breakfast',
  'oral',
  'Ongoing; essential vitamins',
  ARRAY[
    'Use methylated forms — synthetic folic acid and cyanocobalamin are poorly converted by MTHFR variant carriers',
    'High-dose B6 (>100mg/day long-term) can cause peripheral neuropathy — ensure B-complex has appropriate ratios',
    'May cause bright yellow urine (riboflavin — harmless)',
    'Niacin forms may cause flushing — niacinamide does not'
  ],
  ARRAY[
    'Bright yellow urine (riboflavin)',
    'Niacin flush (if niacin form included)',
    'Mild GI upset'
  ],
  ARRAY[
    'Kennedy DO. B Vitamins and the Brain: Mechanisms, Dose and Efficacy--A Review. Nutrients 2016;8(2):68. PMID:26828517'
  ],
  'both',
  2, 'Take in morning with food; may be energizing — avoid evening dosing', 'Take with breakfast'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'B-Complex (Methylated)');

-- ------------------------------------------------------------
-- DIGESTIVE HEALTH SUPPLEMENTS
-- ------------------------------------------------------------

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'Digestive Enzymes GI Support Protocol',
  'Digestive Enzymes', 'Digestive Health', 'supplement',
  'Broad-spectrum enzyme complex (protease, lipase, amylase, lactase, cellulase, bromelain) that supplements declining endogenous enzyme production. Supports complete macronutrient digestion, reduces post-meal bloating and gas, and improves nutrient absorption. Particularly beneficial for individuals with low stomach acid (hypochlorhydria), pancreatic insufficiency, or post-gallbladder removal. May include betaine HCl for stomach acid support.',
  'moderate', '1 capsule', '2 capsules',
  'with each major meal',
  'oral',
  'Ongoing as needed; safe for long-term use',
  ARRAY[
    'Do NOT use betaine HCl component if history of gastric ulcers or GERD without medical supervision',
    'Protease enzymes may interact with blood thinners',
    'Start with one capsule per meal and assess tolerance',
    'Those with mushroom or mold allergies should check fungal enzyme sources'
  ],
  ARRAY[
    'GI cramping if taken without food',
    'Diarrhea at high doses',
    'Heartburn from HCl component'
  ],
  ARRAY[
    'Ianiro G et al. Digestive Enzyme Supplementation in Gastrointestinal Diseases. Curr Drug Metab 2016;17(2):187-93. PMID:26806042'
  ],
  'both',
  1, 'Take at the beginning of each meal for optimal enzyme-substrate contact', 'Always take with meals — never on empty stomach'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'Digestive Enzymes');

INSERT INTO peptide_protocols (name, peptide_name, category, type, description, evidence_level,
  dose_range_low, dose_range_high, frequency, route, cycle_duration,
  key_warnings, adverse_reactions, source_citations, target_sex,
  default_phase, timing_notes, food_interaction)
SELECT
  'Fiber Complex (Psyllium/Acacia) GI Regularity Protocol',
  'Fiber Complex (Psyllium/Acacia)', 'Digestive Health', 'supplement',
  'Combination of soluble fibers — psyllium husk (bulk-forming, gel-creating) and acacia fiber (prebiotic, slow-fermenting) — for comprehensive GI support. Psyllium has FDA-approved health claims for reducing cholesterol and heart disease risk. Meta-analyses confirm benefits for IBS (both constipation and diarrhea subtypes), blood glucose regulation, and LDL cholesterol reduction. Acacia fiber is well-tolerated and feeds beneficial Bifidobacteria.',
  'well-studied', '5g', '15g',
  'once or twice daily with large glass of water',
  'oral',
  'Ongoing; essential for digestive health',
  ARRAY[
    'MUST take with adequate water (8+ oz per serving) — insufficient water can cause esophageal/intestinal obstruction',
    'Start low and increase gradually over 2 weeks to minimize gas and bloating',
    'Take medications 1-2 hours before fiber — fiber can reduce drug absorption',
    'Contraindicated in bowel obstruction or swallowing disorders'
  ],
  ARRAY[
    'Gas and bloating (especially initial weeks)',
    'Abdominal cramping',
    'Constipation if insufficient water intake'
  ],
  ARRAY[
    'McRorie JW Jr. Evidence-Based Approach to Fiber Supplements and Clinically Meaningful Health Benefits, Part 2. Nutr Today 2015;50(2):90-97. PMID:25972618'
  ],
  'both',
  1, 'Take 30 minutes before meals with full glass of water; take other medications 2 hours before fiber', 'Take 30 minutes before meals with at least 8 oz water'
WHERE NOT EXISTS (SELECT 1 FROM peptide_protocols WHERE peptide_name = 'Fiber Complex (Psyllium/Acacia)');



-- ============================================================
-- GOAL → PROTOCOL MAPPINGS
-- Maps all 25 health goals to recommended protocols (peptide +
-- supplement) with priority levels, clinical rationale, and
-- PubMed references for evidence-based recommendations.
-- Priority: 1=first-line, 2=adjunct, 3=complementary
-- Uses ON CONFLICT DO NOTHING for idempotency.
-- ============================================================

-- ------------------------------------------------------------
-- PERFORMANCE & RECOVERY
-- ------------------------------------------------------------

-- muscle_growth
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('muscle_growth', (SELECT id FROM peptide_protocols WHERE peptide_name = 'CJC-1295/Ipamorelin'), 1, 'Stimulates pulsatile GH release promoting IGF-1-mediated muscle protein synthesis and satellite cell activation', ARRAY['PMID:16352683', 'PMID:17018659'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('muscle_growth', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Sermorelin'), 1, 'GHRH analog restoring youthful GH pulsatility; increases lean mass and reduces adiposity via direct somatotroph stimulation', ARRAY['PMID:9849659', 'PMID:10997609'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('muscle_growth', (SELECT id FROM peptide_protocols WHERE peptide_name = 'BPC-157'), 2, 'Accelerates muscle and tendon healing via upregulation of growth hormone receptor expression and angiogenesis', ARRAY['PMID:21030672', 'PMID:29776466'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('muscle_growth', (SELECT id FROM peptide_protocols WHERE peptide_name = 'TB-500'), 2, 'Thymosin beta-4 promotes muscle fiber regeneration, reduces fibrosis after injury, and enhances satellite cell migration', ARRAY['PMID:20621447', 'PMID:22100335'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('muscle_growth', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Creatine Monohydrate'), 2, 'Increases phosphocreatine stores for ATP regeneration; meta-analyses show 5-10% lean mass gains with resistance training', ARRAY['PMID:12945830', 'PMID:28615996'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('muscle_growth', (SELECT id FROM peptide_protocols WHERE peptide_name = 'HMB (beta-Hydroxy beta-Methylbutyrate)'), 2, 'Leucine metabolite that attenuates proteolysis via ubiquitin-proteasome pathway inhibition and stimulates mTOR signaling', ARRAY['PMID:28615996', 'PMID:23286834'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('muscle_growth', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Ashwagandha'), 3, 'Adaptogen shown to increase testosterone, VO2 max, and muscle strength in RCTs; reduces cortisol-mediated catabolism', ARRAY['PMID:26609282', 'PMID:23125505'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('muscle_growth', (SELECT id FROM peptide_protocols WHERE peptide_name = 'L-Citrulline'), 3, 'Enhances nitric oxide production improving nutrient delivery to working muscles; reduces post-exercise soreness', ARRAY['PMID:20499249', 'PMID:27749691'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;

-- athletic_recovery
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('athletic_recovery', (SELECT id FROM peptide_protocols WHERE peptide_name = 'BPC-157'), 1, 'Gastric pentadecapeptide with systemic healing effects; accelerates tendon, ligament, and muscle recovery via VEGF and NO pathways', ARRAY['PMID:21030672', 'PMID:29776466'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('athletic_recovery', (SELECT id FROM peptide_protocols WHERE peptide_name = 'TB-500'), 1, 'Promotes tissue repair through actin sequestration, cell migration, and anti-inflammatory signaling in damaged tissues', ARRAY['PMID:20621447', 'PMID:22100335'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('athletic_recovery', (SELECT id FROM peptide_protocols WHERE peptide_name = 'CJC-1295/Ipamorelin'), 2, 'GH secretagogue combination enhances recovery through increased IGF-1, improved sleep quality, and tissue repair signaling', ARRAY['PMID:16352683'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('athletic_recovery', (SELECT id FROM peptide_protocols WHERE peptide_name = 'L-Glutamine'), 2, 'Most abundant amino acid depleted by intense exercise; supports gut barrier integrity, immune function, and glycogen resynthesis', ARRAY['PMID:18806122', 'PMID:25811544'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('athletic_recovery', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Omega-3 (EPA/DHA)'), 2, 'Resolves exercise-induced inflammation via specialized pro-resolving mediators; reduces DOMS and supports joint lubrication', ARRAY['PMID:20452573', 'PMID:21160185'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('athletic_recovery', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Magnesium Glycinate'), 3, 'Critical cofactor for 600+ enzymatic reactions; supports muscle relaxation, energy metabolism, and sleep quality post-training', ARRAY['PMID:28526392', 'PMID:27933574'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('athletic_recovery', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Taurine'), 3, 'Conditionally essential amino acid that reduces oxidative stress in exercising muscle, supports electrolyte balance and contractile function', ARRAY['PMID:28177706', 'PMID:29546641'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('athletic_recovery', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Creatine Monohydrate'), 3, 'Enhances recovery between sets and training sessions by accelerating phosphocreatine resynthesis', ARRAY['PMID:12945830'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;

-- joint_repair
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('joint_repair', (SELECT id FROM peptide_protocols WHERE peptide_name = 'BPC-157'), 1, 'Promotes tendon and ligament healing through fibroblast proliferation, collagen synthesis, and angiogenesis at injury sites', ARRAY['PMID:21030672', 'PMID:29776466', 'PMID:14550946'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('joint_repair', (SELECT id FROM peptide_protocols WHERE peptide_name = 'TB-500'), 1, 'Thymosin beta-4 accelerates joint tissue repair via enhanced cell migration, reduced scar formation, and anti-inflammatory effects', ARRAY['PMID:20621447', 'PMID:22100335'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('joint_repair', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Collagen Peptides'), 2, 'Type II collagen peptides provide bioactive substrates for cartilage repair; 24-week RCTs show reduced joint pain and improved function', ARRAY['PMID:18416885', 'PMID:26353786'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('joint_repair', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Curcumin (with Piperine)'), 2, 'Potent NF-kB inhibitor reducing joint inflammation; piperine enhances bioavailability 2000%; comparable to NSAIDs in OA trials', ARRAY['PMID:20672015', 'PMID:24672232'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('joint_repair', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Boswellia Serrata'), 2, '5-LOX inhibitor with clinical evidence for osteoarthritis pain reduction; AKBA fraction reduces cartilage-degrading enzymes', ARRAY['PMID:14669258', 'PMID:18204937'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('joint_repair', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Omega-3 (EPA/DHA)'), 3, 'EPA-derived resolvins and protectins reduce synovial inflammation and cartilage degradation via COX/LOX modulation', ARRAY['PMID:20452573', 'PMID:21160185'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('joint_repair', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Vitamin D3'), 3, 'Maintains calcium homeostasis for subchondral bone health; deficiency associated with accelerated OA progression', ARRAY['PMID:21154921', 'PMID:24001971'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;

-- injury_recovery
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('injury_recovery', (SELECT id FROM peptide_protocols WHERE peptide_name = 'BPC-157'), 1, 'Most evidence-supported peptide for tissue healing; accelerates recovery of tendons, muscles, ligaments, and GI tissue through multiple growth factor pathways', ARRAY['PMID:21030672', 'PMID:29776466', 'PMID:14550946'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('injury_recovery', (SELECT id FROM peptide_protocols WHERE peptide_name = 'TB-500'), 1, 'Synergistic with BPC-157 for injury recovery; promotes cell migration to injury sites and reduces inflammatory scarring', ARRAY['PMID:20621447', 'PMID:22100335'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('injury_recovery', (SELECT id FROM peptide_protocols WHERE peptide_name = 'CJC-1295/Ipamorelin'), 2, 'Elevated GH/IGF-1 axis accelerates tissue repair, collagen synthesis, and immune function critical during recovery', ARRAY['PMID:16352683', 'PMID:17018659'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('injury_recovery', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Collagen Peptides'), 2, 'Provides hydroxyproline and glycine substrates for connective tissue repair; enhances collagen synthesis when combined with vitamin C', ARRAY['PMID:18416885', 'PMID:26353786'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('injury_recovery', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Vitamin C (Liposomal)'), 2, 'Essential cofactor for prolyl hydroxylase in collagen synthesis; liposomal form achieves 2-4x higher plasma levels than standard', ARRAY['PMID:23392897'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('injury_recovery', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Zinc Bisglycinate'), 3, 'Critical mineral for wound healing, immune function, and protein synthesis; deficiency impairs tissue repair by 40%', ARRAY['PMID:17233842'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('injury_recovery', (SELECT id FROM peptide_protocols WHERE peptide_name = 'NAC'), 3, 'Glutathione precursor that reduces oxidative stress at injury sites and supports immune cell function during recovery', ARRAY['PMID:28388363'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;

-- ------------------------------------------------------------
-- BODY COMPOSITION
-- ------------------------------------------------------------

-- fat_loss
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('fat_loss', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Tesamorelin'), 1, 'FDA-approved GHRH analog that specifically reduces visceral adipose tissue by 15-18% via GH-mediated lipolysis without glucose impairment', ARRAY['PMID:20962018', 'PMID:22074985'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('fat_loss', (SELECT id FROM peptide_protocols WHERE peptide_name = 'AOD-9604'), 1, 'Modified GH fragment (176-191) with lipolytic activity of full GH but without IGF-1 elevation or diabetogenic effects', ARRAY['PMID:11713213'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('fat_loss', (SELECT id FROM peptide_protocols WHERE peptide_name = 'CJC-1295/Ipamorelin'), 2, 'Combined GH secretagogue enhances lipolysis and preserves lean mass during caloric deficit through sustained IGF-1 elevation', ARRAY['PMID:16352683'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('fat_loss', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Berberine'), 2, 'AMPK activator with metformin-comparable effects on glucose metabolism; reduces visceral fat accumulation and improves insulin sensitivity', ARRAY['PMID:18442638', 'PMID:23118793'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('fat_loss', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Alpha-Lipoic Acid'), 2, 'Dual antioxidant and AMPK activator that enhances glucose uptake, reduces inflammatory adipokines, and supports mitochondrial fat oxidation', ARRAY['PMID:21666939', 'PMID:22164340'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('fat_loss', (SELECT id FROM peptide_protocols WHERE peptide_name = 'L-Citrulline'), 3, 'Improves exercise capacity and fat oxidation through enhanced NO-mediated blood flow and mitochondrial efficiency', ARRAY['PMID:20499249'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('fat_loss', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Chromium Picolinate'), 3, 'Enhances insulin receptor signaling; meta-analysis shows modest body composition improvements when combined with exercise', ARRAY['PMID:23261067', 'PMID:24635480'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;

-- weight_management
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('weight_management', (SELECT id FROM peptide_protocols WHERE peptide_name = 'AOD-9604'), 1, 'GH fragment targeting fat metabolism without muscle-wasting effects; supports long-term weight management through enhanced lipolysis', ARRAY['PMID:11713213'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('weight_management', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Tesamorelin'), 1, 'GHRH analog that preferentially reduces visceral fat while maintaining muscle mass through physiologic GH stimulation', ARRAY['PMID:20962018'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('weight_management', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Berberine'), 2, 'Multi-target metabolic regulator: activates AMPK, improves insulin sensitivity, modulates gut microbiome composition for metabolic health', ARRAY['PMID:18442638', 'PMID:23118793'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('weight_management', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Inositol (Myo-Inositol)'), 2, 'Insulin sensitizer that improves metabolic markers; particularly effective for weight management in insulin-resistant patients and PCOS', ARRAY['PMID:27041852', 'PMID:23136064'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('weight_management', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Chromium Picolinate'), 3, 'Supports glucose tolerance factor function; helps reduce carbohydrate cravings through improved insulin signaling', ARRAY['PMID:23261067'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('weight_management', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Fiber Complex (Psyllium/Acacia)'), 3, 'Soluble fiber promotes satiety, slows gastric emptying, and feeds beneficial gut bacteria that regulate appetite hormones', ARRAY['PMID:25972618'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;

-- body_recomp
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('body_recomp', (SELECT id FROM peptide_protocols WHERE peptide_name = 'CJC-1295/Ipamorelin'), 1, 'Optimizes GH pulsatility for simultaneous fat loss and muscle gain; enhances nitrogen retention while promoting lipolysis', ARRAY['PMID:16352683', 'PMID:17018659'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('body_recomp', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Tesamorelin'), 1, 'Selectively reduces visceral adiposity while preserving and building lean tissue through targeted GHRH receptor activation', ARRAY['PMID:20962018', 'PMID:22074985'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('body_recomp', (SELECT id FROM peptide_protocols WHERE peptide_name = 'AOD-9604'), 2, 'Supports fat loss component of recomposition without interfering with anabolic signaling or insulin sensitivity', ARRAY['PMID:11713213'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('body_recomp', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Creatine Monohydrate'), 2, 'Increases intracellular water and phosphocreatine supporting both strength gains and training volume for recomposition', ARRAY['PMID:12945830', 'PMID:28615996'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('body_recomp', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Ashwagandha'), 2, 'Dual action: increases testosterone and muscle strength while reducing cortisol-driven fat storage by 11-30%', ARRAY['PMID:26609282', 'PMID:23125505'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('body_recomp', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Berberine'), 3, 'AMPK activation improves nutrient partitioning toward muscle while reducing lipogenesis in adipose tissue', ARRAY['PMID:18442638'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('body_recomp', (SELECT id FROM peptide_protocols WHERE peptide_name = 'HMB (beta-Hydroxy beta-Methylbutyrate)'), 3, 'Preserves lean mass during caloric deficit through anti-proteolytic activity while supporting training adaptations', ARRAY['PMID:28615996', 'PMID:23286834'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;

-- ------------------------------------------------------------
-- ANTI-AGING & LONGEVITY
-- ------------------------------------------------------------

-- anti_aging
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('anti_aging', (SELECT id FROM peptide_protocols WHERE peptide_name = 'CJC-1295/Ipamorelin'), 1, 'Restores youthful GH pulsatility that declines 14% per decade; improves body composition, skin quality, sleep, and recovery markers', ARRAY['PMID:16352683', 'PMID:17018659'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('anti_aging', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Sermorelin'), 1, 'GHRH analog shown in long-term studies to rejuvenate the GH/IGF-1 axis with excellent safety profile for anti-aging applications', ARRAY['PMID:9849659', 'PMID:10997609'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('anti_aging', (SELECT id FROM peptide_protocols WHERE peptide_name = 'NMN (Nicotinamide Mononucleotide)'), 2, 'Direct NAD+ precursor that restores declining NAD+ levels; activates SIRT1/SIRT3 for mitochondrial rejuvenation and DNA repair', ARRAY['PMID:27127236', 'PMID:33888596'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('anti_aging', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Resveratrol'), 2, 'SIRT1 activator with pleiotropic anti-aging effects: reduces NF-kB inflammation, enhances mitochondrial biogenesis, and improves vascular function', ARRAY['PMID:22882425', 'PMID:25210150'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('anti_aging', (SELECT id FROM peptide_protocols WHERE peptide_name = 'CoQ10 (Ubiquinol)'), 2, 'Mitochondrial electron carrier that declines with age; ubiquinol form restores cellular energy production and provides lipid-soluble antioxidant protection', ARRAY['PMID:26648450', 'PMID:21506934'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('anti_aging', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Spermidine'), 3, 'Natural polyamine that induces autophagy (cellular cleanup); epidemiological data links higher intake to 5-year mortality reduction', ARRAY['PMID:30002370', 'PMID:33860792'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('anti_aging', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Urolithin A'), 3, 'Gut-derived metabolite that triggers mitophagy (removal of damaged mitochondria); first-in-human trial showed improved mitochondrial biomarkers', ARRAY['PMID:30675422', 'PMID:31471929'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('anti_aging', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Astaxanthin'), 3, 'Most potent natural carotenoid antioxidant; protects skin from UV photoaging, reduces wrinkles, and improves cardiovascular markers of aging', ARRAY['PMID:22428137', 'PMID:30481654'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;

-- hair_growth
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('hair_growth', (SELECT id FROM peptide_protocols WHERE peptide_name = 'CJC-1295/Ipamorelin'), 1, 'GH/IGF-1 axis stimulation promotes hair follicle proliferation and extends anagen phase; addresses age-related GH decline contributing to thinning', ARRAY['PMID:16352683'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('hair_growth', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Saw Palmetto'), 2, '5-alpha reductase inhibitor reducing DHT conversion; 60% of men showed improvement in hair density in clinical trials', ARRAY['PMID:12006122', 'PMID:32651847'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('hair_growth', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Collagen Peptides'), 2, 'Provides proline and hydroxyproline substrates for hair keratin synthesis; supports dermal layer health around follicles', ARRAY['PMID:18416885'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('hair_growth', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Zinc Bisglycinate'), 2, 'Zinc deficiency is a known cause of diffuse alopecia; supplementation restores hair growth in deficient individuals', ARRAY['PMID:17233842', 'PMID:23914218'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('hair_growth', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Iron Bisglycinate'), 3, 'Ferritin below 40 ng/mL associated with telogen effluvium; bisglycinate form offers superior absorption with less GI distress', ARRAY['PMID:23772161'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('hair_growth', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Vitamin D3'), 3, 'Vitamin D receptors present in hair follicles; deficiency linked to alopecia areata and diffuse hair loss', ARRAY['PMID:21154921'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('hair_growth', (SELECT id FROM peptide_protocols WHERE peptide_name = 'B-Complex (Methylated)'), 3, 'Biotin (B7) and folate support keratin infrastructure and cell division in the hair matrix; methylated forms ensure absorption in MTHFR variants', ARRAY['PMID:28879195'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;

-- cellular_repair
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('cellular_repair', (SELECT id FROM peptide_protocols WHERE peptide_name = 'BPC-157'), 1, 'Activates multiple cellular repair pathways including FAK-paxillin, VEGF, and NO-mediated tissue regeneration across organ systems', ARRAY['PMID:21030672', 'PMID:29776466'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('cellular_repair', (SELECT id FROM peptide_protocols WHERE peptide_name = 'TB-500'), 1, 'Thymosin beta-4 is a master regulator of cellular repair: promotes actin organization, cell migration, and anti-apoptotic signaling', ARRAY['PMID:20621447', 'PMID:22100335'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('cellular_repair', (SELECT id FROM peptide_protocols WHERE peptide_name = 'NMN (Nicotinamide Mononucleotide)'), 2, 'Restores NAD+ for PARP-mediated DNA repair and sirtuin activation; critical for maintaining genomic stability during aging', ARRAY['PMID:27127236', 'PMID:33888596'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('cellular_repair', (SELECT id FROM peptide_protocols WHERE peptide_name = 'NR (Nicotinamide Riboside)'), 2, 'Alternative NAD+ precursor with established pharmacokinetics; supports DNA damage response and mitochondrial repair enzymes', ARRAY['PMID:29184669', 'PMID:27721479'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('cellular_repair', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Glutathione (Liposomal)'), 2, 'Master intracellular antioxidant protecting cells from oxidative damage; essential for phase II detoxification and immune cell function', ARRAY['PMID:25286328', 'PMID:24791752'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('cellular_repair', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Sulforaphane (Broccoli Seed Extract)'), 3, 'Nrf2 activator inducing phase II detoxification enzymes, antioxidant response elements, and cellular stress resistance pathways', ARRAY['PMID:25617536', 'PMID:26881038'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('cellular_repair', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Spermidine'), 3, 'Induces autophagy and mitophagy for clearance of damaged organelles; supports stem cell function and chromosomal stability', ARRAY['PMID:30002370'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('cellular_repair', (SELECT id FROM peptide_protocols WHERE peptide_name = 'PQQ (Pyrroloquinoline Quinone)'), 3, 'Stimulates mitochondrial biogenesis through PGC-1alpha activation; provides antioxidant protection 5,000x more potent than vitamin C', ARRAY['PMID:20711455', 'PMID:24231099'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;

-- collagen
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('collagen', (SELECT id FROM peptide_protocols WHERE peptide_name = 'BPC-157'), 1, 'Directly stimulates fibroblast activity and collagen type I/III synthesis via growth factor upregulation at tissue repair sites', ARRAY['PMID:21030672', 'PMID:29776466'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('collagen', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Collagen Peptides'), 2, 'Hydrolyzed collagen peptides provide bioactive substrates (hydroxyproline-proline) that stimulate fibroblast collagen synthesis in skin, joints, and bones', ARRAY['PMID:18416885', 'PMID:26353786'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('collagen', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Vitamin C (Liposomal)'), 2, 'Absolute requirement for prolyl and lysyl hydroxylase enzymes in collagen cross-linking; liposomal form maximizes tissue levels', ARRAY['PMID:23392897'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('collagen', (SELECT id FROM peptide_protocols WHERE peptide_name = 'CJC-1295/Ipamorelin'), 2, 'GH/IGF-1 stimulation increases fibroblast proliferation and collagen turnover in skin, tendons, and connective tissues', ARRAY['PMID:16352683'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('collagen', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Zinc Bisglycinate'), 3, 'Essential cofactor for collagen synthesis enzymes and matrix metalloproteinases that remodel collagen networks', ARRAY['PMID:17233842'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('collagen', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Copper Bisglycinate'), 3, 'Required cofactor for lysyl oxidase, the enzyme that cross-links collagen and elastin fibers for structural integrity', ARRAY['PMID:24369107'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('collagen', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Astaxanthin'), 3, 'Protects existing collagen from UV-induced MMP degradation; clinical trials show improved skin elasticity and wrinkle reduction', ARRAY['PMID:22428137', 'PMID:30481654'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;

-- ------------------------------------------------------------
-- HORMONAL & METABOLIC
-- ------------------------------------------------------------

-- hormone_optimization
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('hormone_optimization', (SELECT id FROM peptide_protocols WHERE peptide_name = 'CJC-1295/Ipamorelin'), 1, 'Restores age-declined GH pulsatility through combined GHRH and ghrelin receptor activation for comprehensive hormonal optimization', ARRAY['PMID:16352683', 'PMID:17018659'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('hormone_optimization', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Sermorelin'), 1, 'Physiologic GHRH replacement that restores the entire GH axis including feedback regulation, unlike exogenous GH', ARRAY['PMID:9849659', 'PMID:10997609'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('hormone_optimization', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Ashwagandha'), 2, 'Adaptogen with RCT evidence for increasing testosterone 14-40%, reducing cortisol 28%, and improving DHEA-S levels', ARRAY['PMID:26609282', 'PMID:23125505'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('hormone_optimization', (SELECT id FROM peptide_protocols WHERE peptide_name = 'DHEA'), 2, 'Precursor hormone for both testosterone and estrogen; restores age-related decline supporting immune function, bone density, and mood', ARRAY['PMID:16608037', 'PMID:10838478'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('hormone_optimization', (SELECT id FROM peptide_protocols WHERE peptide_name = 'DIM (Diindolylmethane)'), 2, 'Promotes favorable 2-OH estrone over 16-alpha-OH estrone ratio; supports estrogen metabolism balance in both sexes', ARRAY['PMID:27261275', 'PMID:21092014'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('hormone_optimization', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Vitamin D3'), 3, 'Functions as a steroid hormone; deficiency linked to low testosterone, impaired insulin signaling, and immune dysregulation', ARRAY['PMID:21154921', 'PMID:24001971'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('hormone_optimization', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Zinc Bisglycinate'), 3, 'Essential for aromatase regulation and testosterone synthesis; deficiency directly reduces T levels within weeks', ARRAY['PMID:17233842', 'PMID:23914218'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('hormone_optimization', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Boron'), 3, 'Trace mineral that increases free testosterone by reducing SHBG and supports vitamin D metabolism for hormonal health', ARRAY['PMID:25063690', 'PMID:18366532'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;

-- gh_support
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('gh_support', (SELECT id FROM peptide_protocols WHERE peptide_name = 'CJC-1295/Ipamorelin'), 1, 'Gold standard GH secretagogue combination: CJC-1295 provides sustained GHRH stimulation while ipamorelin adds ghrelin-mimetic amplification', ARRAY['PMID:16352683', 'PMID:17018659'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('gh_support', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Sermorelin'), 1, 'Bioidentical GHRH(1-29) that stimulates natural GH production preserving pulsatile secretion pattern and feedback regulation', ARRAY['PMID:9849659', 'PMID:10997609'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('gh_support', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Tesamorelin'), 2, 'Synthetic GHRH analog with enhanced potency; FDA-approved for GH-related visceral adiposity with proven GH/IGF-1 elevation', ARRAY['PMID:20962018', 'PMID:22074985'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('gh_support', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Alpha-GPC'), 2, 'Cholinergic compound shown to increase GH secretion by 44-fold when taken pre-exercise via hypothalamic cholinergic stimulation', ARRAY['PMID:22673596', 'PMID:18053002'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('gh_support', (SELECT id FROM peptide_protocols WHERE peptide_name = 'GABA'), 2, 'Inhibitory neurotransmitter that stimulates anterior pituitary GH release; 3g dose increased GH 5.5-fold in exercise study', ARRAY['PMID:18091016'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('gh_support', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Ashwagandha'), 3, 'Indirect GH support through cortisol reduction (cortisol suppresses GH) and improved sleep quality (GH peaks during deep sleep)', ARRAY['PMID:26609282'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('gh_support', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Magnesium Glycinate'), 3, 'Magnesium deficiency impairs GH/IGF-1 axis; glycinate form supports both sleep quality and hormonal signaling', ARRAY['PMID:28526392'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('gh_support', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Zinc Bisglycinate'), 3, 'Zinc is required for GH receptor signaling and IGF-1 synthesis; supplementation restores GH axis in deficient individuals', ARRAY['PMID:17233842'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;

-- metabolic_health
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('metabolic_health', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Tesamorelin'), 1, 'Reduces visceral adipose tissue and improves metabolic markers including triglycerides, cholesterol ratios, and inflammatory adipokines', ARRAY['PMID:20962018', 'PMID:22074985'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('metabolic_health', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Berberine'), 2, 'Multi-target metabolic optimizer: activates AMPK, improves insulin sensitivity comparable to metformin, and modulates lipid profiles', ARRAY['PMID:18442638', 'PMID:23118793'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('metabolic_health', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Alpha-Lipoic Acid'), 2, 'Universal antioxidant that improves insulin sensitivity, reduces advanced glycation end-products, and supports mitochondrial energy metabolism', ARRAY['PMID:21666939', 'PMID:22164340'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('metabolic_health', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Chromium Picolinate'), 2, 'Enhances insulin receptor phosphorylation and GLUT4 translocation; systematic reviews support improved glycemic control in T2DM', ARRAY['PMID:23261067', 'PMID:24635480'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('metabolic_health', (SELECT id FROM peptide_protocols WHERE peptide_name = 'CoQ10 (Ubiquinol)'), 3, 'Essential mitochondrial electron carrier supporting cellular energy metabolism; reduces oxidative stress contributing to metabolic syndrome', ARRAY['PMID:26648450', 'PMID:21506934'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('metabolic_health', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Cinnamon Extract (Ceylon)'), 3, 'True cinnamon polyphenols improve insulin receptor sensitivity and GLUT4 translocation; meta-analyses show fasting glucose reduction', ARRAY['PMID:23867208', 'PMID:22579946'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('metabolic_health', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Omega-3 (EPA/DHA)'), 3, 'Reduces inflammatory adipokines, improves triglyceride-to-HDL ratio, and supports cell membrane fluidity for insulin receptor function', ARRAY['PMID:20452573', 'PMID:21160185'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;

-- blood_sugar
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('blood_sugar', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Berberine'), 1, 'Potent AMPK activator with metformin-equivalent HbA1c reduction (0.9%) in head-to-head RCT; improves insulin sensitivity and reduces hepatic glucose output', ARRAY['PMID:18442638', 'PMID:23118793'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('blood_sugar', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Chromium Picolinate'), 2, 'Enhances insulin receptor tyrosine kinase activity; meta-analysis of 25 RCTs shows significant fasting glucose and HbA1c reduction', ARRAY['PMID:23261067', 'PMID:24635480'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('blood_sugar', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Alpha-Lipoic Acid'), 2, 'Improves glucose disposal by 25-50% via GLUT4 translocation; also reduces diabetic neuropathy symptoms through antioxidant mechanisms', ARRAY['PMID:21666939', 'PMID:22164340'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('blood_sugar', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Cinnamon Extract (Ceylon)'), 2, 'Ceylon cinnamon polyphenols mimic insulin signaling at the receptor level; reduces postprandial glucose spikes by 20-30%', ARRAY['PMID:23867208', 'PMID:22579946'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('blood_sugar', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Bitter Melon Extract'), 3, 'Contains charantin and polypeptide-p with insulin-mimetic activity; traditional use supported by multiple RCTs showing modest glucose reduction', ARRAY['PMID:21211558'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('blood_sugar', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Inositol (Myo-Inositol)'), 3, 'Insulin second messenger that improves insulin signaling; particularly effective for insulin resistance in PCOS with 30-40% sensitivity improvement', ARRAY['PMID:27041852', 'PMID:23136064'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('blood_sugar', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Magnesium Glycinate'), 3, 'Magnesium deficiency present in 48% of T2DM patients; supplementation improves insulin sensitivity and fasting glucose', ARRAY['PMID:28526392', 'PMID:27933574'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;

-- ------------------------------------------------------------
-- COGNITIVE & MENTAL
-- ------------------------------------------------------------

-- mental_clarity
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('mental_clarity', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Sermorelin'), 1, 'GH optimization improves cognitive processing speed, working memory, and mental energy through enhanced cerebral blood flow and IGF-1 neuroprotection', ARRAY['PMID:9849659'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('mental_clarity', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Lion''s Mane (Hericium erinaceus)'), 2, 'Stimulates nerve growth factor (NGF) and brain-derived neurotrophic factor (BDNF) synthesis; 16-week RCT showed significant cognitive improvement', ARRAY['PMID:19539463', 'PMID:24266378'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('mental_clarity', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Citicoline (CDP-Choline)'), 2, 'Provides choline and cytidine for phosphatidylcholine membrane synthesis and acetylcholine production; enhances attention and processing speed', ARRAY['PMID:25046515', 'PMID:24072436'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('mental_clarity', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Alpha-GPC'), 2, 'Most bioavailable choline source crossing BBB; directly increases acetylcholine for enhanced memory formation and recall', ARRAY['PMID:22673596', 'PMID:18053002'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('mental_clarity', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Bacopa Monnieri'), 3, 'Ayurvedic nootropic with 12-week RCT evidence for improved memory consolidation, attention, and cognitive processing via bacosides A/B', ARRAY['PMID:24252493', 'PMID:23195757'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('mental_clarity', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Phosphatidylserine'), 3, 'Membrane phospholipid critical for neuronal signaling; meta-analyses support improved memory and cognitive function in age-related decline', ARRAY['PMID:21927094', 'PMID:20523044'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('mental_clarity', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Rhodiola Rosea'), 3, 'Adaptogen that reduces mental fatigue and improves cognitive function under stress through modulation of cortisol and monoamine neurotransmitters', ARRAY['PMID:22643043', 'PMID:23443221'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;

-- stress_anxiety
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('stress_anxiety', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Thymosin Alpha-1'), 1, 'Immune-modulating peptide that reduces systemic inflammation driving stress response; supports HPA axis regulation', ARRAY['PMID:17386041'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('stress_anxiety', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Ashwagandha'), 2, 'Gold standard adaptogen: 60-day RCT showed 28% cortisol reduction, 56% reduction in insomnia, and 69% reduction in anxiety scores (Hamilton)', ARRAY['PMID:23439798', 'PMID:26609282', 'PMID:23125505'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('stress_anxiety', (SELECT id FROM peptide_protocols WHERE peptide_name = 'L-Theanine'), 2, 'Amino acid from green tea that promotes alpha-wave brain activity and calm focus; increases GABA, serotonin, and dopamine without sedation', ARRAY['PMID:22214254', 'PMID:21208586'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('stress_anxiety', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Rhodiola Rosea'), 2, 'Adaptogen that modulates cortisol response and enhances stress resistance; reduces fatigue and burnout symptoms in 12-week RCTs', ARRAY['PMID:22643043', 'PMID:23443221'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('stress_anxiety', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Magnesium Glycinate'), 3, 'Magnesium deficiency amplifies HPA axis reactivity; glycinate form provides calming glycine plus magnesium for GABA receptor support', ARRAY['PMID:28526392', 'PMID:27933574'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('stress_anxiety', (SELECT id FROM peptide_protocols WHERE peptide_name = 'GABA'), 3, 'Primary inhibitory neurotransmitter; oral supplementation reduces stress markers and promotes relaxation within 60 minutes of administration', ARRAY['PMID:18091016'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('stress_anxiety', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Phosphatidylserine'), 3, 'Blunts cortisol response to physical and mental stress; 600mg/day reduced ACTH and cortisol during exercise stress testing', ARRAY['PMID:21927094'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;

-- sleep_quality
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('sleep_quality', (SELECT id FROM peptide_protocols WHERE peptide_name = 'CJC-1295/Ipamorelin'), 1, 'GH secretagogue administered before bed amplifies natural nocturnal GH pulse; improved sleep architecture enhances deep sleep duration', ARRAY['PMID:16352683'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('sleep_quality', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Magnesium Glycinate'), 2, 'Dual benefit: magnesium activates GABA receptors for sleep onset, while glycine acts as inhibitory neurotransmitter promoting deep sleep', ARRAY['PMID:28526392', 'PMID:22293292'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('sleep_quality', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Melatonin'), 2, 'Endogenous circadian rhythm regulator; low-dose supplementation (0.5-3mg) reduces sleep onset latency and improves sleep quality without dependency', ARRAY['PMID:22717171', 'PMID:15649745'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('sleep_quality', (SELECT id FROM peptide_protocols WHERE peptide_name = 'L-Theanine'), 2, 'Promotes relaxation via alpha-wave induction without sedation; improves sleep quality by reducing anxiety-mediated sleep onset delays', ARRAY['PMID:22214254', 'PMID:21208586'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('sleep_quality', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Ashwagandha'), 3, 'Triethylene glycol component directly induces non-REM sleep; KSM-66 extract improved sleep quality scores by 72% in 8-week RCT', ARRAY['PMID:26609282', 'PMID:23439798'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('sleep_quality', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Apigenin'), 3, 'Chamomile-derived flavonoid that binds benzodiazepine receptors as partial agonist; promotes sleepiness without next-day impairment', ARRAY['PMID:18588725'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('sleep_quality', (SELECT id FROM peptide_protocols WHERE peptide_name = 'GABA'), 3, 'Oral GABA reduces sleep latency and increases total sleep time; synergistic with L-theanine for sleep-promoting effects', ARRAY['PMID:18091016'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;

-- mood
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('mood', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Sermorelin'), 1, 'GH optimization improves mood, energy, and psychological wellbeing through enhanced cerebral IGF-1 signaling and sleep quality', ARRAY['PMID:9849659', 'PMID:10997609'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('mood', (SELECT id FROM peptide_protocols WHERE peptide_name = 'SAMe (S-Adenosyl Methionine)'), 2, 'Methyl donor critical for neurotransmitter synthesis (serotonin, dopamine, norepinephrine); multiple RCTs show antidepressant efficacy comparable to tricyclics', ARRAY['PMID:27310529', 'PMID:27655070'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('mood', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Omega-3 (EPA/DHA)'), 2, 'EPA specifically demonstrates antidepressant effects through anti-inflammatory modulation and serotonin signaling; 1-2g EPA recommended for mood support', ARRAY['PMID:20452573', 'PMID:21939614'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('mood', (SELECT id FROM peptide_protocols WHERE peptide_name = '5-HTP'), 2, 'Direct serotonin precursor bypassing rate-limiting tryptophan hydroxylase step; 150-300mg/day shows antidepressant effects in clinical trials', ARRAY['PMID:20572011', 'PMID:23380314'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('mood', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Ashwagandha'), 3, 'Reduces cortisol-driven mood disruption; RCTs demonstrate significant improvement in depression and anxiety scales (HAM-D, HAM-A)', ARRAY['PMID:23439798', 'PMID:26609282'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('mood', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Rhodiola Rosea'), 3, 'Adaptogen that modulates monoamine neurotransmitters; clinical evidence for mild-moderate depression and emotional eating reduction', ARRAY['PMID:22643043'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('mood', (SELECT id FROM peptide_protocols WHERE peptide_name = 'L-Theanine'), 3, 'Increases GABA, serotonin, and dopamine levels; promotes calm positive mood and reduces anxiety without sedation', ARRAY['PMID:22214254'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('mood', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Inositol (Myo-Inositol)'), 3, 'Modulates serotonin and dopamine receptor sensitivity; high-dose studies show anxiolytic and mood-stabilizing effects', ARRAY['PMID:27041852'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;

-- ------------------------------------------------------------
-- IMMUNE & GUT
-- ------------------------------------------------------------

-- immune_support
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('immune_support', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Thymosin Alpha-1'), 1, 'Thymic peptide that activates dendritic cells, enhances NK cell cytotoxicity, and restores T-cell immunity; FDA orphan drug for hepatitis B', ARRAY['PMID:17386041', 'PMID:16387666'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('immune_support', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Vitamin D3'), 2, 'Activates antimicrobial peptides (cathelicidin, defensins) in immune cells; deficiency linked to increased infection susceptibility across populations', ARRAY['PMID:21154921', 'PMID:24001971'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('immune_support', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Zinc Bisglycinate'), 2, 'Essential for T-cell maturation, NK cell activity, and cytokine production; Cochrane review shows reduced cold duration by 33%', ARRAY['PMID:17233842', 'PMID:23914218'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('immune_support', (SELECT id FROM peptide_protocols WHERE peptide_name = 'NAC'), 2, 'Glutathione precursor that enhances immune cell antioxidant capacity; reduces inflammatory cytokine cascades and supports mucosal immunity', ARRAY['PMID:28388363'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('immune_support', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Vitamin C (Liposomal)'), 2, 'Supports neutrophil chemotaxis, phagocytosis, and oxidative burst; liposomal delivery achieves higher lymphocyte concentrations than standard forms', ARRAY['PMID:23392897'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('immune_support', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Elderberry Extract'), 3, 'Anthocyanin-rich extract that inhibits viral neuraminidase and boosts cytokine production; meta-analysis shows reduced cold/flu duration', ARRAY['PMID:15080016', 'PMID:31560964'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('immune_support', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Astragalus'), 3, 'Traditional immune tonic with modern evidence for enhanced telomerase activity and T-cell proliferation via astragaloside IV', ARRAY['PMID:22039930', 'PMID:24172257'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('immune_support', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Bovine Colostrum'), 3, 'Rich in immunoglobulins (IgG, IgA), lactoferrin, and growth factors; supports mucosal immunity and reduces URI incidence in athletes', ARRAY['PMID:18461293', 'PMID:24153020'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;

-- gut_health
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('gut_health', (SELECT id FROM peptide_protocols WHERE peptide_name = 'BPC-157'), 1, 'Gastric pentadecapeptide with strong evidence for healing GI mucosa, reducing intestinal inflammation, and restoring gut-brain axis function', ARRAY['PMID:21030672', 'PMID:29776466', 'PMID:14550946'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('gut_health', (SELECT id FROM peptide_protocols WHERE peptide_name = 'L-Glutamine'), 2, 'Primary fuel source for enterocytes; restores intestinal barrier integrity, reduces permeability, and supports mucosal immune function', ARRAY['PMID:18806122', 'PMID:25811544'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('gut_health', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Zinc Carnosine'), 2, 'Chelated complex that concentrates in gastric mucosa; heals ulcers, reduces NSAID damage, and stabilizes gut lining via heat shock proteins', ARRAY['PMID:17083108', 'PMID:24136638'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('gut_health', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Saccharomyces boulardii'), 2, 'Probiotic yeast resistant to antibiotics; Cochrane-validated for C. diff prevention, travelers diarrhea, and microbiome restoration', ARRAY['PMID:25611427', 'PMID:20145608'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('gut_health', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Tributyrin (Butyrate)'), 3, 'Provides sustained-release butyrate to colonocytes; primary energy source for colonic epithelium supporting tight junction integrity', ARRAY['PMID:27446020', 'PMID:30586941'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('gut_health', (SELECT id FROM peptide_protocols WHERE peptide_name = 'DGL (Deglycyrrhizinated Licorice)'), 3, 'Stimulates mucin secretion and prostaglandin E2 production for gastric mucosal defense without mineralocorticoid effects of whole licorice', ARRAY['PMID:16015533'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('gut_health', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Lactobacillus rhamnosus GG'), 3, 'Most studied probiotic strain worldwide; strengthens gut barrier, modulates immune response, and prevents antibiotic-associated diarrhea', ARRAY['PMID:24715618', 'PMID:20145608'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('gut_health', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Slippery Elm'), 3, 'Mucilaginous bark extract that forms protective film over GI mucosa; soothes inflammation and supports mucosal healing in IBD', ARRAY['PMID:12495265'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;

-- inflammation
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('inflammation', (SELECT id FROM peptide_protocols WHERE peptide_name = 'BPC-157'), 1, 'Modulates inflammatory cascades through NO system regulation, NF-kB pathway interaction, and promotion of anti-inflammatory mediator release', ARRAY['PMID:21030672', 'PMID:29776466'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('inflammation', (SELECT id FROM peptide_protocols WHERE peptide_name = 'TB-500'), 1, 'Thymosin beta-4 reduces tissue inflammation through macrophage phenotype modulation (M1 to M2 shift) and anti-inflammatory cytokine induction', ARRAY['PMID:20621447', 'PMID:22100335'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('inflammation', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Curcumin (with Piperine)'), 2, 'Multi-target anti-inflammatory: inhibits NF-kB, COX-2, LOX, and TNF-alpha; piperine increases bioavailability 2000% for systemic effects', ARRAY['PMID:20672015', 'PMID:24672232'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('inflammation', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Omega-3 (EPA/DHA)'), 2, 'EPA and DHA are precursors to resolvins, protectins, and maresins that actively resolve inflammation rather than merely suppressing it', ARRAY['PMID:20452573', 'PMID:21160185'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('inflammation', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Boswellia Serrata'), 2, 'Selective 5-LOX inhibitor with unique anti-inflammatory profile; AKBA fraction reduces leukotriene synthesis and MMP activity in joints', ARRAY['PMID:14669258', 'PMID:18204937'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('inflammation', (SELECT id FROM peptide_protocols WHERE peptide_name = 'SPMs (Specialized Pro-Resolving Mediators)'), 3, 'Pre-formed resolvins and protectins that directly activate inflammation resolution pathways; bypass the need for enzymatic conversion from omega-3s', ARRAY['PMID:25359497'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('inflammation', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Quercetin'), 3, 'Flavonoid that inhibits NF-kB activation, mast cell degranulation, and inflammatory cytokine release; also acts as natural antihistamine', ARRAY['PMID:26999194', 'PMID:27187572'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('inflammation', (SELECT id FROM peptide_protocols WHERE peptide_name = 'NAC'), 3, 'Replenishes glutathione to reduce oxidative-inflammatory cycle; directly scavenges ROS and modulates NF-kB transcription factor activation', ARRAY['PMID:28388363'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;

-- ------------------------------------------------------------
-- SEXUAL HEALTH
-- ------------------------------------------------------------

-- libido
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('libido', (SELECT id FROM peptide_protocols WHERE peptide_name = 'PT-141'), 1, 'Melanocortin-4 receptor agonist that acts centrally on hypothalamic sexual arousal circuits; FDA-approved (bremelanotide) for hypoactive sexual desire disorder', ARRAY['PMID:16422821', 'PMID:19453895'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('libido', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Tongkat Ali (Eurycoma longifolia)'), 2, 'Adaptogenic herb that increases free testosterone by reducing SHBG binding; 12-week RCT showed improved libido scores and erectile function', ARRAY['PMID:23754792', 'PMID:26365449'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('libido', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Maca Root'), 2, 'Peruvian adaptogen with RCT evidence for increased sexual desire independent of testosterone levels; works through central arousal pathways', ARRAY['PMID:12472620', 'PMID:25954905'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('libido', (SELECT id FROM peptide_protocols WHERE peptide_name = 'DHEA'), 2, 'Precursor to sex hormones that declines with age; restores testosterone and estrogen levels supporting libido in both men and women', ARRAY['PMID:16608037', 'PMID:10838478'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('libido', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Ashwagandha'), 3, 'Increases testosterone, reduces stress-induced libido suppression, and improves sexual satisfaction scores in multiple RCTs', ARRAY['PMID:26609282', 'PMID:23125505'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('libido', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Fenugreek Extract'), 3, 'Furostanolic saponins inhibit aromatase and 5-alpha reductase; 12-week RCT showed significant increase in sexual arousal and orgasm scores', ARRAY['PMID:21312304', 'PMID:30279018'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('libido', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Zinc Bisglycinate'), 3, 'Zinc deficiency directly suppresses testosterone synthesis and libido; supplementation restores levels within 6-12 weeks', ARRAY['PMID:17233842'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;

-- sexual_performance
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('sexual_performance', (SELECT id FROM peptide_protocols WHERE peptide_name = 'PT-141'), 1, 'Central-acting melanocortin agonist enhancing sexual arousal, desire, and satisfaction through hypothalamic circuit activation independent of vascular effects', ARRAY['PMID:16422821', 'PMID:19453895'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('sexual_performance', (SELECT id FROM peptide_protocols WHERE peptide_name = 'L-Citrulline'), 2, 'NO precursor that enhances erectile function through improved penile blood flow; 1.5g/day showed significant improvement in mild ED', ARRAY['PMID:20499249', 'PMID:27749691'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('sexual_performance', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Tongkat Ali (Eurycoma longifolia)'), 2, 'Increases free testosterone and improves sexual performance metrics including erection hardness, penetration satisfaction, and intercourse satisfaction', ARRAY['PMID:23754792', 'PMID:26365449'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('sexual_performance', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Maca Root'), 2, 'Enhances sexual performance and stamina through central arousal mechanisms; gelatinized form shows best efficacy in clinical trials', ARRAY['PMID:12472620', 'PMID:25954905'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('sexual_performance', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Ashwagandha'), 3, 'Improves physical stamina, testosterone levels, and psychogenic components of sexual performance through stress-hormone modulation', ARRAY['PMID:26609282'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('sexual_performance', (SELECT id FROM peptide_protocols WHERE peptide_name = 'DHEA'), 3, 'Restores declining androgen and estrogen precursors; improves sexual arousal and response in aging men and women', ARRAY['PMID:16608037'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('sexual_performance', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Beetroot Extract (Nitrate)'), 3, 'Dietary nitrate conversion to NO enhances vascular function and blood flow; supports erectile function through endothelial NO pathway', ARRAY['PMID:22248502'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;

-- erectile_function
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('erectile_function', (SELECT id FROM peptide_protocols WHERE peptide_name = 'PT-141'), 1, 'Melanocortin-4 receptor agonist with proven efficacy for erectile dysfunction through central arousal pathway activation distinct from PDE5 inhibitors', ARRAY['PMID:16422821', 'PMID:19453895'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('erectile_function', (SELECT id FROM peptide_protocols WHERE peptide_name = 'L-Citrulline'), 2, 'Converted to L-arginine then NO in penile vasculature; avoids first-pass metabolism unlike oral L-arginine. Significant improvement in erection hardness scores', ARRAY['PMID:20499249', 'PMID:27749691'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('erectile_function', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Beetroot Extract (Nitrate)'), 2, 'Provides inorganic nitrate for enterosalivary NO production; enhances basal NO levels supporting erectile endothelial function', ARRAY['PMID:22248502'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('erectile_function', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Tongkat Ali (Eurycoma longifolia)'), 2, 'Improves erectile function through testosterone optimization and reduced SHBG binding; IIEF scores improved significantly in 12-week trial', ARRAY['PMID:23754792', 'PMID:26365449'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('erectile_function', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Zinc Bisglycinate'), 3, 'Zinc is essential for testosterone synthesis and NO production; deficiency impairs erectile function through both hormonal and vascular pathways', ARRAY['PMID:17233842'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('erectile_function', (SELECT id FROM peptide_protocols WHERE peptide_name = 'DHEA'), 3, 'Improves erectile function in men with low DHEA-S levels; converts to testosterone supporting both desire and vascular erectile mechanisms', ARRAY['PMID:16608037', 'PMID:10838478'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;
INSERT INTO goal_protocols (goal_id, protocol_id, priority, rationale, pubmed_ids)
VALUES ('erectile_function', (SELECT id FROM peptide_protocols WHERE peptide_name = 'Vitamin D3'), 3, 'Endothelial vitamin D receptors regulate NO synthesis; deficiency independently associated with erectile dysfunction severity', ARRAY['PMID:21154921'])
ON CONFLICT (goal_id, protocol_id) DO NOTHING;

-- Total goal_protocols rows: 184


-- ============================================================
-- PROTOCOL → SUPPLEMENT STACKING
-- Maps peptide protocols and key supplements to their supporting
-- supplement stacks with mechanism-based roles, timing, and
-- importance levels for the protocol engine.
-- Roles: synergist, cofactor, protector, enhancer
-- Importance: essential, recommended, optional
-- Uses ON CONFLICT DO NOTHING for idempotency.
-- ============================================================

-- BPC-157
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'BPC-157'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'L-Glutamine'),
  'synergist', 'Primary enterocyte fuel that complements BPC-157 mucosal healing by providing building blocks for intestinal epithelial cell regeneration',
  '5g twice daily on empty stomach; take 30 min before BPC-157 dose', 'essential'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'BPC-157'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Zinc Carnosine'),
  'cofactor', 'Concentrates in gastric mucosa where it stabilizes BPC-157 target tissue via heat shock protein upregulation and prostaglandin synthesis',
  '75mg twice daily between meals; synergistic timing with BPC-157', 'recommended'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'BPC-157'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Omega-3 (EPA/DHA)'),
  'enhancer', 'EPA-derived resolvins amplify BPC-157 anti-inflammatory effects at tissue repair sites through specialized pro-resolving mediator pathways',
  '2-3g with meals containing fat; consistent daily dosing', 'recommended'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'BPC-157'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Saccharomyces boulardii'),
  'synergist', 'Probiotic yeast that supports BPC-157 gut healing by reducing pathogenic colonization and reinforcing mucosal immune defense',
  '250mg twice daily; can take with BPC-157', 'recommended'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'BPC-157'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Aloe Vera Extract'),
  'synergist', 'Mucilaginous polysaccharides provide physical mucosal protection complementing BPC-157 cellular repair mechanisms',
  '50mg twice daily before meals; combine with BPC-157 for gut protocols', 'optional'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'BPC-157'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'NAC'),
  'protector', 'Glutathione precursor that reduces oxidative stress at healing sites, protecting newly regenerating tissue from ROS damage',
  '600mg twice daily on empty stomach; morning and evening', 'recommended'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'BPC-157'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Curcumin (with Piperine)'),
  'enhancer', 'NF-kB inhibitor that reduces inflammatory signaling at BPC-157 repair sites, creating optimal environment for tissue regeneration',
  '500mg twice daily with meals; piperine ensures systemic absorption', 'optional'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'BPC-157'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Collagen Peptides'),
  'synergist', 'Provides hydroxyproline and glycine substrates needed for BPC-157-stimulated collagen synthesis in healing connective tissue',
  '10-15g daily with vitamin C; morning or post-workout', 'recommended'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;

-- TB-500
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'TB-500'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Omega-3 (EPA/DHA)'),
  'enhancer', 'Anti-inflammatory omega-3 metabolites complement TB-500 tissue repair by resolving inflammation at injury sites',
  '2-3g daily with meals; consistent dosing throughout TB-500 cycle', 'recommended'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'TB-500'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Curcumin (with Piperine)'),
  'enhancer', 'Multi-target anti-inflammatory that supports TB-500 healing by reducing NF-kB-mediated inflammation in damaged tissues',
  '500mg twice daily with meals', 'recommended'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'TB-500'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Collagen Peptides'),
  'synergist', 'Provides structural protein substrates for TB-500-promoted tissue remodeling and extracellular matrix repair',
  '10-15g daily; pair with vitamin C for enhanced collagen cross-linking', 'recommended'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'TB-500'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Vitamin C (Liposomal)'),
  'cofactor', 'Essential cofactor for collagen cross-linking in TB-500-stimulated tissue repair; liposomal form achieves higher tissue concentrations',
  '1000mg daily; take with collagen peptides for synergy', 'recommended'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'TB-500'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Magnesium Glycinate'),
  'cofactor', 'Required for 600+ enzymatic reactions in tissue repair including protein synthesis, muscle relaxation, and energy metabolism',
  '400mg before bed; glycinate form supports recovery sleep', 'recommended'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'TB-500'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Zinc Bisglycinate'),
  'cofactor', 'Essential mineral cofactor for protein synthesis, cell division, and immune function — all critical during TB-500-mediated tissue repair',
  '30mg daily with food; separate from other minerals by 2 hours', 'recommended'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;

-- CJC-1295/Ipamorelin
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'CJC-1295/Ipamorelin'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Zinc Bisglycinate'),
  'cofactor', 'Zinc is required for GH receptor signal transduction and IGF-1 synthesis in the liver; deficiency blunts GH axis response by 40%',
  '30mg before bed; take with CJC/Ipa injection for synergistic GH pulse', 'essential'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'CJC-1295/Ipamorelin'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Magnesium Glycinate'),
  'cofactor', 'Magnesium supports GH release during deep sleep and is required for IGF-1 receptor signaling; glycine promotes sleep quality',
  '400mg before bed; aligns with nighttime GH secretion window', 'essential'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'CJC-1295/Ipamorelin'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Vitamin D3'),
  'cofactor', 'Vitamin D receptor activation enhances GH/IGF-1 axis function; deficiency independently suppresses GH secretion',
  '5000 IU daily with fat-containing meal; maintain serum 50-70 ng/mL', 'recommended'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'CJC-1295/Ipamorelin'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Alpha-GPC'),
  'enhancer', 'Cholinergic compound amplifies GH release 44-fold when taken pre-exercise; potentiates CJC/Ipa GH pulse through hypothalamic stimulation',
  '300-600mg pre-workout or before bed; time with CJC/Ipa dose', 'recommended'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'CJC-1295/Ipamorelin'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'GABA'),
  'enhancer', 'GABA stimulates anterior pituitary GH release via GABA-B receptors; synergistic with CJC/Ipa for enhanced GH pulse amplitude',
  '3g before bed on empty stomach; take 30 min before CJC/Ipa injection', 'optional'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'CJC-1295/Ipamorelin'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Ashwagandha'),
  'enhancer', 'Reduces cortisol (which opposes GH) by 28% while improving sleep quality for enhanced nocturnal GH secretion',
  '600mg KSM-66 before bed; supports deep sleep when GH peaks', 'recommended'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'CJC-1295/Ipamorelin'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Creatine Monohydrate'),
  'synergist', 'Amplifies GH-driven anabolic effects by enhancing phosphocreatine stores for training volume and satellite cell activity',
  '5g daily with any meal; consistent daily dosing', 'optional'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;

-- Sermorelin
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Sermorelin'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Zinc Bisglycinate'),
  'cofactor', 'Required for GH receptor function and IGF-1 production; zinc-deficient patients show blunted response to GHRH stimulation',
  '30mg before bed with Sermorelin dose', 'essential'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Sermorelin'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Magnesium Glycinate'),
  'cofactor', 'Supports deep sleep (GH peaks during stage 3/4) and is required for 600+ enzymatic reactions in GH-mediated anabolism',
  '400mg before bed; aligns with Sermorelin nighttime dosing', 'essential'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Sermorelin'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Vitamin D3'),
  'cofactor', 'Vitamin D-GH axis crosstalk: D3 enhances somatotroph sensitivity to GHRH stimulation and supports IGF-1 production',
  '5000 IU daily with meals; maintain optimal 25(OH)D levels', 'recommended'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Sermorelin'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Alpha-GPC'),
  'enhancer', 'Cholinergic potentiation of GHRH-stimulated GH release; amplifies Sermorelin efficacy through hypothalamic acetylcholine pathways',
  '300-600mg before bed; pair with Sermorelin injection timing', 'recommended'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Sermorelin'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Ashwagandha'),
  'enhancer', 'Lowers cortisol that antagonizes the GH axis; supports deep sleep architecture for optimal Sermorelin-stimulated GH pulsatility',
  '600mg KSM-66 with evening meal or before bed', 'optional'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;

-- Tesamorelin
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Tesamorelin'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Zinc Bisglycinate'),
  'cofactor', 'Required for GH receptor signal transduction and hepatic IGF-1 synthesis; supports Tesamorelin efficacy',
  '30mg daily with food; maintain adequate zinc status throughout cycle', 'recommended'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Tesamorelin'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Omega-3 (EPA/DHA)'),
  'enhancer', 'Reduces inflammatory adipokines in visceral fat that oppose Tesamorelin lipolytic effects; improves metabolic response',
  '2-3g daily with meals; EPA fraction most important for metabolic effects', 'recommended'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Tesamorelin'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Berberine'),
  'synergist', 'AMPK activation synergizes with Tesamorelin GH-mediated lipolysis; also improves insulin sensitivity during body composition changes',
  '500mg twice daily with meals; separate from Tesamorelin by 2 hours', 'recommended'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Tesamorelin'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Alpha-Lipoic Acid'),
  'enhancer', 'Mitochondrial antioxidant that enhances fat oxidation capacity, amplifying Tesamorelin-driven visceral fat reduction',
  '600mg daily before meals; R-ALA form preferred for bioavailability', 'optional'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Tesamorelin'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'CoQ10 (Ubiquinol)'),
  'enhancer', 'Supports mitochondrial energy production during Tesamorelin-enhanced lipolysis; improves cellular energy metabolism',
  '200mg daily with fat-containing meal', 'optional'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;

-- AOD-9604
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'AOD-9604'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'L-Citrulline'),
  'enhancer', 'Enhances blood flow and nutrient delivery during AOD-9604-stimulated lipolysis; supports exercise-driven fat oxidation',
  '6g pre-workout on empty stomach; time with AOD-9604 dose', 'recommended'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'AOD-9604'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Berberine'),
  'synergist', 'AMPK activation amplifies AOD-9604 fat-burning effects; improves fatty acid oxidation and prevents lipogenesis rebound',
  '500mg with meals; synergistic metabolic pathway activation', 'recommended'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'AOD-9604'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Chromium Picolinate'),
  'cofactor', 'Enhances insulin sensitivity supporting AOD-9604 body composition effects; prevents compensatory insulin resistance during fat loss',
  '400-800mcg daily with carbohydrate-containing meals', 'optional'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'AOD-9604'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Acetyl-L-Carnitine'),
  'synergist', 'Shuttles fatty acids released by AOD-9604 lipolysis into mitochondria for beta-oxidation; ensures mobilized fat is actually burned',
  '1-2g pre-workout on empty stomach; synergistic with exercise timing', 'recommended'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;

-- Thymosin Alpha-1
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Thymosin Alpha-1'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Vitamin D3'),
  'cofactor', 'Vitamin D activates antimicrobial peptides and supports T-cell differentiation — amplifies Thymosin Alpha-1 immune restoration',
  '5000 IU daily with fat-containing meal; maintain 50-70 ng/mL levels', 'essential'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Thymosin Alpha-1'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Zinc Bisglycinate'),
  'cofactor', 'Essential for thymic function, T-cell maturation, and NK cell activity that Thymosin Alpha-1 stimulates',
  '30mg daily with food; critical for thymic peptide response', 'essential'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Thymosin Alpha-1'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'NAC'),
  'enhancer', 'Glutathione precursor that enhances immune cell oxidative burst capacity and reduces inflammatory cytokine overproduction',
  '600mg twice daily; supports Thymosin Alpha-1 immune modulation', 'recommended'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Thymosin Alpha-1'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Selenium (Selenomethionine)'),
  'cofactor', 'Required for selenoprotein-based antioxidant defense in immune cells; deficiency impairs both innate and adaptive immunity',
  '200mcg daily with food; supports thyroid and immune function together', 'recommended'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Thymosin Alpha-1'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Vitamin C (Liposomal)'),
  'enhancer', 'Supports neutrophil chemotaxis and immune cell function; liposomal form achieves higher lymphocyte concentrations',
  '1000mg daily; maintain consistent levels during immune support protocols', 'recommended'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Thymosin Alpha-1'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Astragalus'),
  'synergist', 'Complementary immune tonic with telomerase activation and T-cell proliferation enhancement via astragaloside IV',
  '500mg daily; traditional synergy with thymic peptides', 'optional'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Thymosin Alpha-1'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Elderberry Extract'),
  'enhancer', 'Anthocyanin-rich immune support that complements Thymosin Alpha-1 through innate immune pathway stimulation',
  '500mg daily during acute immune challenges; prophylactic 250mg daily', 'optional'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;

-- PT-141
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'PT-141'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'L-Citrulline'),
  'synergist', 'NO-mediated vasodilation complements PT-141 central arousal mechanism; enhances erectile response through peripheral vascular pathway',
  '3-6g 1-2 hours before activity; provides sustained NO production', 'recommended'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'PT-141'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Maca Root'),
  'enhancer', 'Central arousal amplifier that complements PT-141 melanocortin pathway activation through independent libido-enhancing mechanism',
  '1500-3000mg daily; gelatinized form for best absorption', 'recommended'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'PT-141'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Zinc Bisglycinate'),
  'cofactor', 'Essential for testosterone synthesis supporting PT-141 sexual function effects; also required for NO synthase activity',
  '30mg daily with food; maintain optimal zinc status', 'recommended'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'PT-141'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Tongkat Ali (Eurycoma longifolia)'),
  'enhancer', 'Free testosterone optimization via SHBG reduction; synergistic with PT-141 central effects by improving hormonal substrate',
  '200-400mg daily standardized to 2% eurycomanone', 'optional'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'PT-141'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Beetroot Extract (Nitrate)'),
  'synergist', 'Dietary nitrate provides sustained NO production through enterosalivary pathway; complements L-citrulline for vascular erectile support',
  '500mg daily or 2 hours before activity for acute NO boost', 'optional'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;

-- NMN (Nicotinamide Mononucleotide)
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'NMN (Nicotinamide Mononucleotide)'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Resveratrol'),
  'enhancer', 'SIRT1 activator that requires NAD+ as substrate; NMN+resveratrol synergy is the foundation of NAD+-based longevity protocols',
  '500mg resveratrol with NMN in the morning with fat source for absorption', 'essential'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'NMN (Nicotinamide Mononucleotide)'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'CoQ10 (Ubiquinol)'),
  'synergist', 'Mitochondrial electron carrier that complements NMN-driven NAD+ restoration; together they optimize entire mitochondrial energy chain',
  '200mg daily with fat-containing meal', 'recommended'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'NMN (Nicotinamide Mononucleotide)'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'PQQ (Pyrroloquinoline Quinone)'),
  'synergist', 'Stimulates mitochondrial biogenesis via PGC-1alpha; complements NMN NAD+ restoration by increasing the number of healthy mitochondria',
  '20mg daily with breakfast; combine with NMN for comprehensive mitochondrial support', 'optional'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'NMN (Nicotinamide Mononucleotide)'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Pterostilbene'),
  'enhancer', 'More bioavailable analog of resveratrol with longer half-life; alternative or addition to resveratrol for SIRT1 activation',
  '100mg daily; can combine with or replace resveratrol', 'optional'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;

-- Berberine
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Berberine'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Alpha-Lipoic Acid'),
  'synergist', 'Dual AMPK activator that synergizes with berberine for enhanced glucose disposal and mitochondrial fat oxidation',
  '600mg ALA with meals; stagger timing with berberine', 'recommended'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Berberine'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Chromium Picolinate'),
  'cofactor', 'Enhances insulin receptor sensitivity downstream of berberine AMPK activation; complementary glucose regulation pathways',
  '400mcg with meals; take with berberine for synergistic glucose control', 'recommended'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Berberine'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'NAC'),
  'protector', 'Liver-protective glutathione precursor; supports hepatic health during berberine metabolic activation',
  '600mg twice daily; protective during long-term berberine use', 'recommended'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Berberine'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'CoQ10 (Ubiquinol)'),
  'protector', 'Berberine may reduce endogenous CoQ10 production (similar to statins); supplementation prevents potential mitochondrial depletion',
  '200mg daily with fat-containing meal; essential during berberine therapy', 'recommended'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;

-- Ashwagandha
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Ashwagandha'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Rhodiola Rosea'),
  'synergist', 'Complementary adaptogen: Ashwagandha is calming/anabolic while Rhodiola is energizing/anti-fatigue; together they provide balanced stress resilience',
  '200-400mg Rhodiola in the morning; Ashwagandha in the evening for circadian optimization', 'recommended'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Ashwagandha'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Magnesium Glycinate'),
  'cofactor', 'Magnesium supports the GABA-ergic mechanisms of Ashwagandha and is depleted by chronic stress; glycinate form adds calming glycine',
  '400mg before bed; synergistic with evening Ashwagandha dose', 'recommended'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Ashwagandha'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Vitamin D3'),
  'cofactor', 'Vitamin D and Ashwagandha both support testosterone and thyroid function; co-deficiency is common in stressed populations',
  '5000 IU daily with fat-containing meal', 'optional'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;

-- Curcumin (with Piperine)
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Curcumin (with Piperine)'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Omega-3 (EPA/DHA)'),
  'synergist', 'EPA-derived resolvins complement curcumin NF-kB inhibition through independent pro-resolution inflammatory pathways',
  '2-3g daily with meals; consistent daily dosing for cumulative anti-inflammatory effect', 'recommended'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Curcumin (with Piperine)'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Boswellia Serrata'),
  'synergist', '5-LOX inhibitor that complements curcumin COX-2/NF-kB inhibition; together they cover all major inflammatory enzyme pathways',
  '300-500mg AKBA-standardized extract twice daily with meals', 'recommended'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Curcumin (with Piperine)'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Quercetin'),
  'enhancer', 'Flavonoid anti-inflammatory that inhibits mast cell degranulation and cytokine release; broadens curcumin anti-inflammatory coverage',
  '500mg twice daily; enhanced absorption with fat-containing meals', 'optional'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Curcumin (with Piperine)'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Bromelain'),
  'enhancer', 'Proteolytic enzyme that enhances curcumin absorption and provides independent anti-inflammatory and fibrinolytic activity',
  '500mg between meals; enhances curcumin bioavailability when taken together', 'optional'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;

-- Omega-3 (EPA/DHA)
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Omega-3 (EPA/DHA)'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'CoQ10 (Ubiquinol)'),
  'synergist', 'Mitochondrial antioxidant that synergizes with omega-3 for cardiovascular protection; both are depleted by statin therapy',
  '200mg daily with omega-3 at fat-containing meal', 'recommended'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Omega-3 (EPA/DHA)'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Vitamin D3'),
  'cofactor', 'Vitamin D and omega-3 synergistically reduce inflammatory markers and support cardiovascular and immune function',
  '5000 IU daily with omega-3 at meals for fat-soluble absorption', 'recommended'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Omega-3 (EPA/DHA)'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Astaxanthin'),
  'protector', 'Prevents omega-3 oxidation in cell membranes; carotenoid antioxidant that protects EPA/DHA from lipid peroxidation',
  '4-12mg daily with omega-3; prevents PUFA oxidative damage', 'optional'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;

-- Magnesium Glycinate
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Magnesium Glycinate'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'L-Theanine'),
  'synergist', 'Alpha-wave promoting amino acid that synergizes with magnesium GABA receptor activation for enhanced relaxation and sleep quality',
  '200mg before bed; combine with magnesium glycinate for sleep protocol', 'recommended'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Magnesium Glycinate'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Melatonin'),
  'synergist', 'Circadian rhythm regulator that combines with magnesium sleep-promoting effects; together they improve both sleep onset and sleep quality',
  '0.5-3mg 30 min before bed; use lowest effective dose', 'optional'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Magnesium Glycinate'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Vitamin D3'),
  'cofactor', 'Magnesium is required for vitamin D metabolism; supplementing both ensures proper calcium-magnesium-D3 axis function',
  '5000 IU with morning meal; magnesium at bedtime', 'recommended'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;

-- NAC
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'NAC'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Glutathione (Liposomal)'),
  'synergist', 'NAC provides cysteine for endogenous glutathione synthesis while liposomal glutathione provides pre-formed direct antioxidant support',
  '500mg liposomal glutathione with NAC; morning dosing on empty stomach', 'recommended'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'NAC'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Vitamin C (Liposomal)'),
  'synergist', 'Vitamin C regenerates oxidized glutathione back to reduced form; essential for maintaining NAC-generated glutathione pool',
  '1000mg daily; supports glutathione recycling throughout the day', 'recommended'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'NAC'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Selenium (Selenomethionine)'),
  'cofactor', 'Required cofactor for glutathione peroxidase enzymes that utilize NAC-generated glutathione for antioxidant defense',
  '200mcg daily with food; essential for glutathione enzyme function', 'recommended'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;

-- Collagen Peptides
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Collagen Peptides'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Vitamin C (Liposomal)'),
  'cofactor', 'Absolute requirement for prolyl and lysyl hydroxylase in collagen cross-linking; without vitamin C, collagen synthesis fails',
  '1000mg with collagen dose; essential co-factor timing', 'essential'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Collagen Peptides'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Zinc Bisglycinate'),
  'cofactor', 'Required for collagen synthesis enzymes and wound healing; supports the structural matrix that collagen peptides build',
  '30mg daily with food; critical mineral for connective tissue', 'recommended'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Collagen Peptides'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Copper Bisglycinate'),
  'cofactor', 'Required for lysyl oxidase enzyme that cross-links collagen and elastin fibers; without copper, collagen structure is compromised',
  '2mg daily separate from zinc by 2 hours; essential for collagen cross-linking', 'recommended'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Collagen Peptides'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Astaxanthin'),
  'protector', 'Protects existing and newly synthesized collagen from UV-induced MMP degradation; provides photoprotective antioxidant coverage',
  '4-12mg daily with fat-containing meal; skin protection synergy', 'optional'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;

-- Vitamin D3
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Vitamin D3'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Vitamin K2 (MK-7)'),
  'cofactor', 'Directs D3-absorbed calcium into bones (not arteries); essential pairing to prevent vascular calcification with high-dose D3',
  '100-200mcg MK-7 daily with D3; always pair these together', 'essential'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Vitamin D3'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Magnesium Glycinate'),
  'cofactor', 'Magnesium is required for D3 conversion to active 1,25(OH)2D and for vitamin D receptor function; 50% of population is deficient',
  '400mg daily; magnesium is the rate-limiting factor for D3 activation', 'essential'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Vitamin D3'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Zinc Bisglycinate'),
  'cofactor', 'Zinc supports vitamin D receptor expression and is synergistic for immune function and hormonal health',
  '30mg daily with food; complementary mineral for D3 protocols', 'recommended'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Vitamin D3'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Boron'),
  'enhancer', 'Trace mineral that extends vitamin D half-life, increases 25(OH)D levels, and supports D3-dependent calcium metabolism',
  '3-6mg daily with meals', 'optional'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;

-- Lion's Mane (Hericium erinaceus)
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Lion''s Mane (Hericium erinaceus)'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Citicoline (CDP-Choline)'),
  'cofactor', 'Provides choline substrate for acetylcholine synthesis stimulated by Lion''s Mane NGF/BDNF upregulation; ensures cholinergic capacity matches demand',
  '250-500mg daily; morning dosing for cognitive enhancement', 'recommended'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Lion''s Mane (Hericium erinaceus)'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Omega-3 (EPA/DHA)'),
  'enhancer', 'DHA comprises 40% of brain phospholipids; provides structural membrane support for Lion''s Mane-stimulated neuronal growth',
  '2g+ daily focusing on DHA fraction; essential for neuroplasticity', 'recommended'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Lion''s Mane (Hericium erinaceus)'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Phosphatidylserine'),
  'synergist', 'Membrane phospholipid that supports neuronal signaling enhanced by Lion''s Mane neurotrophic factor stimulation',
  '100-300mg daily; morning or divided doses for sustained cognitive support', 'optional'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Lion''s Mane (Hericium erinaceus)'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Bacopa Monnieri'),
  'synergist', 'Complementary nootropic: Lion''s Mane promotes neurogenesis while Bacopa enhances synaptic transmission and memory consolidation',
  '300mg bacosides daily with fat for absorption; allow 8-12 weeks for full effect', 'optional'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;

-- Zinc Bisglycinate
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Zinc Bisglycinate'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Copper Bisglycinate'),
  'protector', 'Zinc competes with copper for absorption; long-term zinc supplementation without copper causes copper deficiency and anemia',
  '2mg copper per 30mg zinc; take at different meals to optimize absorption', 'essential'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Zinc Bisglycinate'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Vitamin D3'),
  'synergist', 'Zinc and D3 synergistically support immune function, testosterone synthesis, and insulin signaling',
  '5000 IU with morning meal; zinc with evening meal', 'recommended'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;

-- Creatine Monohydrate
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Creatine Monohydrate'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Beta-Alanine'),
  'synergist', 'Carnosine buffer complements creatine phosphocreatine system; together they extend both anaerobic power and muscular endurance',
  '3.2-6.4g daily; divided doses to minimize paresthesia', 'recommended'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Creatine Monohydrate'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'HMB (beta-Hydroxy beta-Methylbutyrate)'),
  'synergist', 'Anti-catabolic leucine metabolite that complements creatine anabolic effects; together they optimize muscle protein balance',
  '3g daily divided into 3 doses; take with meals', 'optional'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Creatine Monohydrate'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Electrolyte Complex'),
  'cofactor', 'Creatine increases intracellular water; adequate electrolytes prevent cramping and support cellular hydration balance',
  'Daily with creatine dose; especially important during loading phase', 'recommended'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;
INSERT INTO protocol_supplements (protocol_id, supplement_id, role, mechanism, timing, importance)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Creatine Monohydrate'),
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Magnesium Glycinate'),
  'cofactor', 'Required for ATP-creatine phosphokinase reaction; magnesium deficiency impairs creatine phosphocreatine cycling efficiency',
  '400mg daily; essential mineral for creatine energy system', 'recommended'
) ON CONFLICT (protocol_id, supplement_id) DO NOTHING;

-- Total protocol_supplements rows: 89


-- ============================================================
-- PROTOCOL TREATMENT PHASES
-- Assigns every protocol to a phased treatment sequence:
-- Phase 1 (Foundation): Gut healing, inflammation, sleep, detox
-- Phase 2 (Optimization): Hormonal, metabolic, immune support
-- Phase 3 (Performance): Muscle, cognitive, anti-aging, sexual
-- Uses ON CONFLICT DO NOTHING for idempotency.
-- ============================================================

-- ------------------------------------------------------------
-- PHASE 1: FOUNDATION — Peptides
-- ------------------------------------------------------------
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'BPC-157'),
  1, 'Foundation', 'Gastric pentadecapeptide for foundational gut healing and tissue repair; establishes GI integrity before introducing other peptides',
  6, '{}', true, 3
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'KPV'),
  1, 'Foundation', 'Anti-inflammatory tripeptide for mucosal healing; reduces intestinal inflammation as foundation for nutrient absorption',
  4, '{}', true, 3
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'KLOW Blend'),
  1, 'Foundation', 'Foundation blend combining KPV anti-inflammatory with gut-healing peptides for comprehensive GI restoration',
  6, '{}', true, 3
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'VIP'),
  1, 'Foundation', 'Vasoactive intestinal peptide for gut-brain axis restoration and immune regulation; addresses root inflammatory causes',
  4, '{}', true, 3
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'DSIP'),
  1, 'Foundation', 'Delta sleep-inducing peptide for sleep architecture restoration; quality sleep is foundational for all healing and recovery',
  4, '{}', true, 3
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Pinealon'),
  1, 'Foundation', 'Pineal gland bioregulator peptide for circadian rhythm normalization; foundational sleep optimization before stimulatory peptides',
  4, '{}', true, 3
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'NAD+'),
  1, 'Foundation', 'Foundational cellular energy restoration through NAD+ replenishment; supports all downstream metabolic and repair processes',
  4, '{}', true, 3
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Glutathione'),
  1, 'Foundation', 'Master antioxidant for detoxification and oxidative stress reduction; creates clean cellular environment for subsequent therapies',
  4, '{}', true, 3
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'ARA-290'),
  1, 'Foundation', 'Innate repair receptor agonist for neuroprotection and anti-inflammatory foundation; addresses chronic inflammation early',
  4, '{}', true, 3
) ON CONFLICT (protocol_id) DO NOTHING;

-- ------------------------------------------------------------
-- PHASE 1: FOUNDATION — Supplements
-- ------------------------------------------------------------
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Zinc Carnosine'),
  1, 'Foundation', 'Gastric mucosal protector essential for Phase 1 gut healing; concentrates in damaged GI tissue',
  6, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'L-Glutamine'),
  1, 'Foundation', 'Primary enterocyte fuel for intestinal barrier repair; foundational supplement for gut healing protocols',
  8, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Tributyrin (Butyrate)'),
  1, 'Foundation', 'Colonocyte energy source supporting tight junction integrity; essential for Phase 1 gut restoration',
  8, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Saccharomyces boulardii'),
  1, 'Foundation', 'Probiotic yeast for microbiome restoration; establishes healthy gut flora during foundational healing phase',
  8, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'DGL (Deglycyrrhizinated Licorice)'),
  1, 'Foundation', 'Gastric mucosa protector for upper GI healing; stimulates protective mucin secretion',
  6, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Slippery Elm'),
  1, 'Foundation', 'Demulcent herb forming protective film over GI mucosa; soothes inflammation during gut healing phase',
  6, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Marshmallow Root'),
  1, 'Foundation', 'Mucilaginous herb for GI mucosal protection; complements slippery elm for comprehensive mucosal soothing',
  6, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Lactobacillus rhamnosus GG'),
  1, 'Foundation', 'Most studied probiotic strain for gut barrier strengthening; foundational microbiome support',
  8, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Aloe Vera Extract'),
  1, 'Foundation', 'GI mucosal healer with anti-inflammatory polysaccharides; supports Phase 1 gut restoration',
  6, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Bovine Colostrum'),
  1, 'Foundation', 'Rich in immunoglobulins and growth factors for mucosal immune restoration; addresses gut permeability early',
  8, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Digestive Enzymes'),
  1, 'Foundation', 'Supports nutrient absorption during Phase 1 when digestive capacity may be compromised; foundational digestive support',
  8, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Fiber Complex (Psyllium/Acacia)'),
  1, 'Foundation', 'Prebiotic fiber supporting beneficial microbiome recovery; feeds butyrate-producing bacteria during gut restoration',
  8, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Curcumin (with Piperine)'),
  1, 'Foundation', 'Multi-target NF-kB inhibitor for systemic inflammation reduction; foundational anti-inflammatory before other interventions',
  8, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Omega-3 (EPA/DHA)'),
  1, 'Foundation', 'Pro-resolving mediator precursor for active inflammation resolution; essential foundational anti-inflammatory',
  12, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Boswellia Serrata'),
  1, 'Foundation', '5-LOX inhibitor for leukotriene-mediated inflammation; complements curcumin COX-2 inhibition in Phase 1',
  8, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'SPMs (Specialized Pro-Resolving Mediators)'),
  1, 'Foundation', 'Pre-formed resolvins for direct inflammation resolution; accelerates Phase 1 anti-inflammatory goals',
  6, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Quercetin'),
  1, 'Foundation', 'Flavonoid anti-inflammatory and mast cell stabilizer; reduces histamine-mediated inflammation in Phase 1',
  8, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Bromelain'),
  1, 'Foundation', 'Proteolytic enzyme with anti-inflammatory and fibrinolytic activity; supports tissue healing in Phase 1',
  6, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Magnesium Glycinate'),
  1, 'Foundation', 'GABA receptor support and muscle relaxation for foundational sleep optimization; critical Phase 1 mineral',
  12, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'L-Theanine'),
  1, 'Foundation', 'Alpha-wave promoter for relaxation and sleep onset; foundational support for sleep quality restoration',
  8, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Melatonin'),
  1, 'Foundation', 'Circadian rhythm regulator for sleep architecture normalization; low-dose foundational sleep support',
  4, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Apigenin'),
  1, 'Foundation', 'Chamomile-derived GABA-A partial agonist for gentle sleep promotion; complements magnesium in Phase 1 sleep protocol',
  8, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'GABA'),
  1, 'Foundation', 'Inhibitory neurotransmitter for nervous system calming; supports Phase 1 sleep and stress reduction',
  8, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'NAC'),
  1, 'Foundation', 'Glutathione precursor for Phase 1 detoxification; reduces oxidative burden before introducing other therapies',
  8, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Glutathione (Liposomal)'),
  1, 'Foundation', 'Direct antioxidant support for Phase 1 detoxification; complements NAC glutathione synthesis',
  8, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;

-- ------------------------------------------------------------
-- PHASE 2: OPTIMIZATION — Peptides
-- ------------------------------------------------------------
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'CJC-1295/Ipamorelin'),
  2, 'Optimization', 'GH secretagogue for hormonal optimization after foundational healing; requires healthy GI for proper absorption and response',
  12, '{BPC-157}', true, 3
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Sermorelin'),
  2, 'Optimization', 'GHRH analog for growth hormone axis restoration; begin after Phase 1 establishes healthy sleep architecture',
  12, '{BPC-157}', true, 3
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'CJC-1295 (no DAC)'),
  2, 'Optimization', 'Short-acting GHRH analog for precise GH pulsatility control; Phase 2 hormonal optimization',
  12, '{}', true, 3
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'CJC-1295 (with DAC)'),
  2, 'Optimization', 'Long-acting GHRH analog with extended half-life for sustained GH elevation; Phase 2 hormonal optimization',
  12, '{}', true, 3
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Ipamorelin'),
  2, 'Optimization', 'Selective ghrelin receptor agonist for clean GH stimulation without cortisol or prolactin elevation',
  12, '{}', true, 3
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'MK-677'),
  2, 'Optimization', 'Oral GH secretagogue for sustained IGF-1 elevation; introduce after foundational gut healing for optimal absorption',
  12, '{BPC-157}', true, 3
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Tesamorelin'),
  2, 'Optimization', 'FDA-approved GHRH for visceral fat reduction and metabolic optimization; Phase 2 body composition improvement',
  12, '{}', true, 3
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'GLP-1 Agonist'),
  2, 'Optimization', 'Incretin mimetic for metabolic optimization and appetite regulation; Phase 2 after gut health is established',
  12, '{BPC-157}', true, 3
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'AOD-9604'),
  2, 'Optimization', 'GH fragment for lipolysis optimization without IGF-1 effects; Phase 2 metabolic and body composition focus',
  8, '{}', true, 3
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Thymosin Alpha-1'),
  2, 'Optimization', 'Thymic peptide for immune system optimization; Phase 2 immune restoration after foundational anti-inflammatory work',
  8, '{}', true, 3
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'LL37'),
  2, 'Optimization', 'Antimicrobial peptide for immune defense optimization; Phase 2 targeted immune support',
  6, '{}', true, 3
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Weight Loss Blend'),
  2, 'Optimization', 'Combined metabolic optimization blend for Phase 2 body composition goals; requires foundational gut health',
  12, '{BPC-157}', true, 3
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Cagrilintide'),
  2, 'Optimization', 'Amylin analog for appetite regulation and metabolic optimization; Phase 2 after GI foundation is established',
  12, '{}', true, 3
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = '5-Amino-1MQ'),
  2, 'Optimization', 'NNMT inhibitor for metabolic optimization and fat cell modulation; Phase 2 metabolic enhancement',
  8, '{}', true, 3
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'TB-500'),
  2, 'Optimization', 'Tissue repair peptide for ongoing recovery optimization; can begin in Phase 2 after initial inflammation is resolved',
  8, '{}', true, 3
) ON CONFLICT (protocol_id) DO NOTHING;

-- ------------------------------------------------------------
-- PHASE 2: OPTIMIZATION — Supplements
-- ------------------------------------------------------------
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Ashwagandha'),
  2, 'Optimization', 'Adaptogen for cortisol reduction and testosterone optimization; Phase 2 hormonal balancing after stress reduction',
  12, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'DHEA'),
  2, 'Optimization', 'Hormone precursor for sex hormone optimization; Phase 2 after foundational health markers are stabilized',
  12, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Tongkat Ali (Eurycoma longifolia)'),
  2, 'Optimization', 'Testosterone optimization via SHBG reduction; Phase 2 hormonal enhancement for libido and body composition',
  12, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Fenugreek Extract'),
  2, 'Optimization', 'Aromatase inhibitor for free testosterone optimization; Phase 2 hormonal fine-tuning',
  12, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Maca Root'),
  2, 'Optimization', 'Adaptogenic hormone balancer for libido and energy optimization; Phase 2 hormonal support for both sexes',
  8, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'DIM (Diindolylmethane)'),
  2, 'Optimization', 'Estrogen metabolism optimizer for favorable 2-OH/16-OH ratio; Phase 2 hormonal balance refinement',
  12, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Vitex (Chasteberry)'),
  2, 'Optimization', 'Prolactin modulator and progesterone support for female hormonal optimization; Phase 2 cycle regulation',
  12, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Saw Palmetto'),
  2, 'Optimization', '5-alpha reductase inhibitor for DHT management; Phase 2 hormonal optimization for hair and prostate health',
  12, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Calcium D-Glucarate'),
  2, 'Optimization', 'Supports glucuronidation of excess hormones and toxins; Phase 2 hormone metabolism optimization',
  8, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Inositol (Myo-Inositol)'),
  2, 'Optimization', 'Insulin sensitizer for metabolic-hormonal optimization; particularly effective in insulin-resistant conditions',
  12, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Berberine'),
  2, 'Optimization', 'AMPK activator for metabolic optimization; Phase 2 after GI healing (berberine can be harsh on compromised gut)',
  12, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Alpha-Lipoic Acid'),
  2, 'Optimization', 'Mitochondrial antioxidant and insulin sensitizer for Phase 2 metabolic optimization',
  12, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Chromium Picolinate'),
  2, 'Optimization', 'Insulin receptor enhancer for Phase 2 glucose metabolism optimization',
  12, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Cinnamon Extract (Ceylon)'),
  2, 'Optimization', 'Insulin mimetic for Phase 2 blood sugar optimization; complements berberine through different pathways',
  12, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Bitter Melon Extract'),
  2, 'Optimization', 'Plant insulin analog for Phase 2 glucose metabolism support; traditional metabolic optimizer',
  12, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Acetyl-L-Carnitine'),
  2, 'Optimization', 'Fatty acid shuttle for mitochondrial beta-oxidation optimization; Phase 2 metabolic fat utilization',
  12, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Vitamin D3'),
  2, 'Optimization', 'Steroid hormone precursor for immune, hormonal, and metabolic optimization; Phase 2 with K2 pairing',
  12, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Zinc Bisglycinate'),
  2, 'Optimization', 'Essential mineral for immune and hormonal optimization; Phase 2 after addressing gut absorption capacity',
  12, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Iron Bisglycinate'),
  2, 'Optimization', 'Oxygen transport optimization for energy and recovery; Phase 2 after confirming deficiency via labs',
  8, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Iodine (Potassium Iodide)'),
  2, 'Optimization', 'Thyroid function optimization for metabolic rate; Phase 2 after establishing baseline thyroid markers',
  12, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Selenium (Selenomethionine)'),
  2, 'Optimization', 'Selenoprotein cofactor for thyroid and immune optimization; Phase 2 mineral replenishment',
  12, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Boron'),
  2, 'Optimization', 'Trace mineral for vitamin D metabolism and free testosterone optimization; Phase 2 hormonal fine-tuning',
  12, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Potassium Citrate'),
  2, 'Optimization', 'Electrolyte optimization for cellular function and pH buffering; Phase 2 mineral balancing',
  12, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Copper Bisglycinate'),
  2, 'Optimization', 'Zinc-copper balance optimization; Phase 2 essential when supplementing zinc to prevent copper depletion',
  12, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Manganese Bisglycinate'),
  2, 'Optimization', 'Trace mineral for MnSOD antioxidant enzyme and bone/cartilage metabolism; Phase 2 mineral optimization',
  12, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Vitamin C (Liposomal)'),
  2, 'Optimization', 'High-bioavailability immune and collagen support; Phase 2 optimization of immune defense and tissue quality',
  12, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Elderberry Extract'),
  2, 'Optimization', 'Anthocyanin immune optimizer for Phase 2 defense enhancement; supports innate immunity',
  8, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Andrographis'),
  2, 'Optimization', 'Immune activation optimizer with NFkB modulation; Phase 2 targeted immune support',
  6, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Astragalus'),
  2, 'Optimization', 'Telomerase-activating immune tonic for Phase 2 deep immune optimization; traditional longevity herb',
  12, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Rhodiola Rosea'),
  2, 'Optimization', 'Energizing adaptogen for Phase 2 stress resilience and fatigue reduction; complements Ashwagandha',
  12, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Taurine'),
  2, 'Optimization', 'Conditionally essential amino acid for Phase 2 cellular optimization; supports electrolyte balance and antioxidant defense',
  12, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Electrolyte Complex'),
  2, 'Optimization', 'Comprehensive electrolyte optimization for Phase 2 cellular hydration and nerve function',
  12, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Vitamin K2 (MK-7)'),
  2, 'Optimization', 'Essential D3 companion for calcium direction; Phase 2 bone and cardiovascular optimization',
  12, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'B-Complex (Methylated)'),
  2, 'Optimization', 'Methylated B vitamins for Phase 2 energy metabolism and methylation cycle optimization; supports MTHFR variants',
  12, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Collagen Peptides'),
  2, 'Optimization', 'Structural protein optimization for skin, joints, and connective tissue; Phase 2 after vitamin C and minerals are established',
  12, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;

-- ------------------------------------------------------------
-- PHASE 3: PERFORMANCE — Peptides
-- ------------------------------------------------------------
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'IGF-1 LR3'),
  3, 'Performance', 'Potent IGF-1 analog for advanced muscle growth and recovery; Phase 3 after hormonal optimization is established',
  8, '{CJC-1295/Ipamorelin}', true, 3
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'IGF-DES'),
  3, 'Performance', 'Truncated IGF-1 for localized muscle growth; Phase 3 advanced anabolic enhancement',
  6, '{CJC-1295/Ipamorelin}', true, 3
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'MGF'),
  3, 'Performance', 'Mechano growth factor for satellite cell activation and muscle repair; Phase 3 advanced recovery protocol',
  6, '{CJC-1295/Ipamorelin}', true, 3
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'GHRP-6'),
  3, 'Performance', 'Potent ghrelin mimetic for maximum GH release and appetite stimulation; Phase 3 for mass-building goals',
  8, '{CJC-1295/Ipamorelin}', true, 3
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Semax'),
  3, 'Performance', 'Nootropic peptide for cognitive performance enhancement; Phase 3 after foundational sleep and inflammation are optimized',
  8, '{}', true, 3
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Selank'),
  3, 'Performance', 'Anxiolytic nootropic peptide for cognitive clarity and stress resilience; Phase 3 performance optimization',
  8, '{}', true, 3
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Dihexa'),
  3, 'Performance', 'Potent neurotrophic peptide for cognitive performance and neuroplasticity; Phase 3 advanced nootropic protocol',
  6, '{}', true, 3
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Brain Blend'),
  3, 'Performance', 'Combined nootropic peptide blend for comprehensive cognitive performance enhancement; Phase 3 mental optimization',
  8, '{}', true, 3
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'GHK-Cu'),
  3, 'Performance', 'Copper peptide for skin regeneration, collagen remodeling, and anti-aging; Phase 3 aesthetic and longevity performance',
  8, '{}', true, 3
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'GLOW Blend'),
  3, 'Performance', 'Aesthetic peptide blend for skin quality and collagen optimization; Phase 3 after nutritional foundation is built',
  8, '{}', true, 3
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'SS-31'),
  3, 'Performance', 'Mitochondria-targeted antioxidant peptide for cellular energy performance; Phase 3 longevity optimization',
  8, '{NAD+}', true, 3
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'FOXO4-DRI'),
  3, 'Performance', 'Senolytic peptide targeting senescent cells; Phase 3 advanced longevity intervention after metabolic optimization',
  4, '{NAD+}', false, 3
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'PT-141'),
  3, 'Performance', 'Melanocortin receptor agonist for sexual performance; Phase 3 after hormonal optimization in Phase 2',
  6, '{}', true, 3
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'HCG'),
  3, 'Performance', 'Gonadotropin for testicular function and fertility optimization; Phase 3 hormonal performance protocol',
  8, '{}', true, 3
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'HMG'),
  3, 'Performance', 'Gonadotropin combination for comprehensive fertility and hormonal performance; Phase 3 advanced protocol',
  8, '{}', true, 3
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Kisspeptin'),
  3, 'Performance', 'GnRH stimulator for reproductive hormone axis optimization; Phase 3 fertility and hormonal performance',
  6, '{}', true, 3
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Wolverine Blend'),
  3, 'Performance', 'Advanced tissue repair blend for peak recovery performance; Phase 3 after foundational healing is complete',
  8, '{BPC-157,TB-500}', true, 3
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'SLU-PP-332'),
  3, 'Performance', 'Exercise mimetic for endurance performance enhancement; Phase 3 athletic optimization',
  8, '{}', true, 3
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'AICAR'),
  3, 'Performance', 'AMPK activator for metabolic and endurance performance; Phase 3 advanced metabolic enhancement',
  6, '{}', true, 3
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Methylene Blue'),
  3, 'Performance', 'Mitochondrial electron carrier for cognitive and energy performance; Phase 3 advanced biohacking protocol',
  8, '{}', true, 3
) ON CONFLICT (protocol_id) DO NOTHING;

-- ------------------------------------------------------------
-- PHASE 3: PERFORMANCE — Supplements
-- ------------------------------------------------------------
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Creatine Monohydrate'),
  3, 'Performance', 'Phosphocreatine system optimizer for strength and power performance; Phase 3 athletic enhancement',
  12, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'HMB (beta-Hydroxy beta-Methylbutyrate)'),
  3, 'Performance', 'Anti-catabolic agent for advanced body composition performance; Phase 3 muscle preservation during cuts',
  12, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Beta-Alanine'),
  3, 'Performance', 'Carnosine buffer for muscular endurance performance; Phase 3 training capacity optimization',
  12, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Beetroot Extract (Nitrate)'),
  3, 'Performance', 'Dietary nitrate for vascular performance and exercise efficiency; Phase 3 endurance enhancement',
  8, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'L-Citrulline'),
  3, 'Performance', 'NO precursor for blood flow and exercise performance; Phase 3 training and recovery optimization',
  12, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Shilajit'),
  3, 'Performance', 'Fulvic acid mineral complex for mitochondrial energy performance and testosterone support; Phase 3 adaptogenic enhancement',
  12, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Lion''s Mane (Hericium erinaceus)'),
  3, 'Performance', 'NGF/BDNF stimulator for cognitive performance and neuroplasticity; Phase 3 nootropic optimization',
  12, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Bacopa Monnieri'),
  3, 'Performance', 'Memory consolidation enhancer for cognitive performance; Phase 3 long-term nootropic protocol (8-12 weeks to peak)',
  12, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Citicoline (CDP-Choline)'),
  3, 'Performance', 'Choline donor for acetylcholine synthesis and membrane phospholipid performance; Phase 3 cognitive enhancement',
  12, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Alpha-GPC'),
  3, 'Performance', 'Most bioavailable choline form for peak cholinergic performance; Phase 3 cognitive and GH amplification',
  12, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Phosphatidylserine'),
  3, 'Performance', 'Neuronal membrane phospholipid for cognitive performance under stress; Phase 3 mental optimization',
  8, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Ginkgo Biloba'),
  3, 'Performance', 'Cerebral blood flow enhancer for cognitive performance; Phase 3 after cardiovascular foundation is healthy',
  12, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = '5-HTP'),
  3, 'Performance', 'Serotonin precursor for mood performance optimization; Phase 3 after foundational stress management',
  8, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'SAMe (S-Adenosyl Methionine)'),
  3, 'Performance', 'Methyl donor for neurotransmitter synthesis performance; Phase 3 mood and cognitive methylation support',
  8, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Magnesium L-Threonate'),
  3, 'Performance', 'Brain-bioavailable magnesium for synaptic plasticity and cognitive performance; Phase 3 nootropic mineral',
  12, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'NMN (Nicotinamide Mononucleotide)'),
  3, 'Performance', 'NAD+ precursor for cellular energy performance and longevity; Phase 3 advanced anti-aging protocol',
  12, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'NR (Nicotinamide Riboside)'),
  3, 'Performance', 'Alternative NAD+ precursor for longevity performance; Phase 3 cellular rejuvenation',
  12, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Resveratrol'),
  3, 'Performance', 'SIRT1 activator for longevity pathway performance; Phase 3 paired with NMN for optimal NAD+ utilization',
  12, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Pterostilbene'),
  3, 'Performance', 'High-bioavailability stilbene for SIRT1 and longevity performance; Phase 3 advanced antioxidant',
  12, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Fisetin'),
  3, 'Performance', 'Senolytic flavonoid for cellular cleanup and longevity performance; Phase 3 advanced anti-aging',
  8, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Spermidine'),
  3, 'Performance', 'Autophagy inducer for cellular renewal performance; Phase 3 longevity and healthspan optimization',
  12, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Sulforaphane (Broccoli Seed Extract)'),
  3, 'Performance', 'Nrf2 activator for detoxification and stress resistance performance; Phase 3 cellular resilience',
  12, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'CoQ10 (Ubiquinol)'),
  3, 'Performance', 'Mitochondrial electron carrier for cellular energy performance; Phase 3 anti-aging and cardiovascular optimization',
  12, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'PQQ (Pyrroloquinoline Quinone)'),
  3, 'Performance', 'Mitochondrial biogenesis stimulator for cellular energy performance; Phase 3 paired with CoQ10 and NMN',
  12, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Urolithin A'),
  3, 'Performance', 'Mitophagy activator for mitochondrial quality performance; Phase 3 advanced longevity protocol',
  12, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Astaxanthin'),
  3, 'Performance', 'Supreme antioxidant for skin, cardiovascular, and longevity performance; Phase 3 comprehensive protection',
  12, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;
INSERT INTO protocol_phases (protocol_id, phase, phase_label, rationale, min_duration_weeks, prerequisites, can_run_concurrent, max_concurrent_injectables)
VALUES (
  (SELECT id FROM peptide_protocols WHERE peptide_name = 'Ergothioneine'),
  3, 'Performance', 'Longevity vitamin and cytoprotective antioxidant for advanced cellular performance; Phase 3 deep anti-aging',
  12, '{}', true, NULL
) ON CONFLICT (protocol_id) DO NOTHING;

-- Total protocol_phases rows: 131


-- ============================================================
-- CONDITION → PROTOCOL MAPPINGS
-- Maps 50 conditions to relevant protocols using slug ILIKE
-- matching against the conditions table. Uses DO $$ DECLARE
-- blocks with loop-based inserts for flexible condition matching.
-- ON CONFLICT DO NOTHING for idempotency.
-- ============================================================

-- ------------------------------------------------------------
-- GI CONDITIONS
-- ------------------------------------------------------------

-- IBS
DO $$ DECLARE
  cond_id UUID;
  protocol_uuid UUID;
BEGIN
  -- BPC-157 for IBS
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'BPC-157';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%irritable-bowel%' OR
      slug ILIKE '%ibs%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 1, 'Gastric pentadecapeptide that restores intestinal mucosal integrity, reduces gut inflammation, and normalizes gut motility in IBS models')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- L-Glutamine for IBS
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'L-Glutamine';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%irritable-bowel%' OR
      slug ILIKE '%ibs%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Primary enterocyte fuel that repairs intestinal permeability; RCTs show reduced IBS symptom severity')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Saccharomyces boulardii for IBS
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Saccharomyces boulardii';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%irritable-bowel%' OR
      slug ILIKE '%ibs%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Probiotic yeast with Cochrane-supported evidence for IBS symptom improvement through microbiome modulation')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Lactobacillus rhamnosus GG for IBS
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Lactobacillus rhamnosus GG';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%irritable-bowel%' OR
      slug ILIKE '%ibs%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Most studied probiotic for IBS with evidence for symptom reduction and barrier function improvement')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Tributyrin (Butyrate) for IBS
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Tributyrin (Butyrate)';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%irritable-bowel%' OR
      slug ILIKE '%ibs%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 3, 'Colonocyte energy source supporting epithelial integrity; reduces visceral hypersensitivity in IBS')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

END $$;

-- IBD (general)
DO $$ DECLARE
  cond_id UUID;
  protocol_uuid UUID;
BEGIN
  -- BPC-157 for IBD (general)
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'BPC-157';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%inflammatory-bowel%' OR
      slug ILIKE '%ibd%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 1, 'Demonstrates mucosal healing and anti-inflammatory effects in preclinical IBD models; promotes intestinal anastomosis healing')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Curcumin (with Piperine) for IBD (general)
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Curcumin (with Piperine)';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%inflammatory-bowel%' OR
      slug ILIKE '%ibd%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Adjunctive NF-kB inhibitor with RCT evidence for maintaining remission in ulcerative colitis')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Omega-3 (EPA/DHA) for IBD (general)
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Omega-3 (EPA/DHA)';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%inflammatory-bowel%' OR
      slug ILIKE '%ibd%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Pro-resolving mediators reduce intestinal inflammation; EPA-derived resolvins support mucosal healing in IBD')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- NAC for IBD (general)
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'NAC';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%inflammatory-bowel%' OR
      slug ILIKE '%ibd%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 3, 'Glutathione precursor reducing oxidative stress in inflamed intestinal tissue; supports mucosal antioxidant defense')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

END $$;

-- Crohn's disease
DO $$ DECLARE
  cond_id UUID;
  protocol_uuid UUID;
BEGIN
  -- BPC-157 for Crohn's disease
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'BPC-157';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%crohn%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 1, 'Accelerates fistula and mucosal healing through VEGF upregulation and anti-inflammatory mechanisms relevant to Crohn pathology')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Omega-3 (EPA/DHA) for Crohn's disease
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Omega-3 (EPA/DHA)';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%crohn%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Anti-inflammatory omega-3 metabolites reduce mucosal inflammation and support remission maintenance in Crohn disease')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Vitamin D3 for Crohn's disease
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Vitamin D3';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%crohn%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Immunomodulator with evidence for reduced Crohn relapse rates; vitamin D deficiency common in IBD patients')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Zinc Carnosine for Crohn's disease
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Zinc Carnosine';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%crohn%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 3, 'Mucosal protector that reduces intestinal permeability; supports healing of Crohn-related mucosal damage')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

END $$;

-- Ulcerative colitis
DO $$ DECLARE
  cond_id UUID;
  protocol_uuid UUID;
BEGIN
  -- BPC-157 for Ulcerative colitis
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'BPC-157';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%ulcerative-colitis%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 1, 'Anti-inflammatory peptide with evidence for colonic mucosal healing and reduction of colitis severity in experimental models')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Curcumin (with Piperine) for Ulcerative colitis
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Curcumin (with Piperine)';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%ulcerative-colitis%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'RCT evidence for maintaining remission in UC when used as adjunct to standard therapy; reduces NF-kB colonic inflammation')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Saccharomyces boulardii for Ulcerative colitis
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Saccharomyces boulardii';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%ulcerative-colitis%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Probiotic with evidence for UC remission maintenance through microbiome restoration and anti-inflammatory signaling')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Tributyrin (Butyrate) for Ulcerative colitis
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Tributyrin (Butyrate)';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%ulcerative-colitis%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 3, 'Direct colonocyte fuel that is deficient in UC; supports epithelial barrier repair and reduces mucosal inflammation')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

END $$;

-- GERD
DO $$ DECLARE
  cond_id UUID;
  protocol_uuid UUID;
BEGIN
  -- BPC-157 for GERD
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'BPC-157';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%gerd%' OR
      slug ILIKE '%gastroesophageal-reflux%' OR
      slug ILIKE '%acid-reflux%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 1, 'Promotes gastric mucosal healing and reduces esophageal inflammation through prostaglandin and NO-mediated cytoprotection')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- DGL (Deglycyrrhizinated Licorice) for GERD
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'DGL (Deglycyrrhizinated Licorice)';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%gerd%' OR
      slug ILIKE '%gastroesophageal-reflux%' OR
      slug ILIKE '%acid-reflux%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Stimulates protective mucin secretion in the esophagus and stomach without mineralocorticoid effects')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Zinc Carnosine for GERD
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Zinc Carnosine';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%gerd%' OR
      slug ILIKE '%gastroesophageal-reflux%' OR
      slug ILIKE '%acid-reflux%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Gastric mucosal protector that stabilizes the gastric lining and reduces acid-related damage')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Slippery Elm for GERD
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Slippery Elm';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%gerd%' OR
      slug ILIKE '%gastroesophageal-reflux%' OR
      slug ILIKE '%acid-reflux%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 3, 'Demulcent herb that coats and soothes irritated esophageal and gastric mucosa')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

END $$;

-- Gastritis
DO $$ DECLARE
  cond_id UUID;
  protocol_uuid UUID;
BEGIN
  -- BPC-157 for Gastritis
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'BPC-157';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%gastritis%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 1, 'Gastric pentadecapeptide with direct evidence for accelerating gastric ulcer and gastritis healing through mucosal repair pathways')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Zinc Carnosine for Gastritis
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Zinc Carnosine';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%gastritis%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 1, 'Chelated complex that concentrates in the gastric mucosa; clinical trials demonstrate accelerated gastritis and ulcer healing')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- DGL (Deglycyrrhizinated Licorice) for Gastritis
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'DGL (Deglycyrrhizinated Licorice)';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%gastritis%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Increases gastric mucin production and prostaglandin E2 for mucosal defense against acid and H. pylori damage')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Marshmallow Root for Gastritis
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Marshmallow Root';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%gastritis%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 3, 'Mucilaginous herb providing physical protection of inflamed gastric mucosa; traditional gastroprotective remedy')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

END $$;

-- SIBO
DO $$ DECLARE
  cond_id UUID;
  protocol_uuid UUID;
BEGIN
  -- BPC-157 for SIBO
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'BPC-157';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%sibo%' OR
      slug ILIKE '%small-intestinal-bacterial-overgrowth%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 1, 'Restores gut motility and mucosal integrity disrupted by SIBO; supports migrating motor complex function')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Saccharomyces boulardii for SIBO
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Saccharomyces boulardii';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%sibo%' OR
      slug ILIKE '%small-intestinal-bacterial-overgrowth%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Probiotic yeast resistant to antibiotics; supports microbiome rebalancing during and after SIBO treatment')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Berberine for SIBO
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Berberine';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%sibo%' OR
      slug ILIKE '%small-intestinal-bacterial-overgrowth%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Antimicrobial alkaloid with evidence for SIBO eradication comparable to rifaximin in clinical trial')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Digestive Enzymes for SIBO
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Digestive Enzymes';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%sibo%' OR
      slug ILIKE '%small-intestinal-bacterial-overgrowth%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 3, 'Supports nutrient absorption compromised by SIBO; reduces fermentable substrate for bacterial overgrowth')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

END $$;

-- Celiac disease
DO $$ DECLARE
  cond_id UUID;
  protocol_uuid UUID;
BEGIN
  -- BPC-157 for Celiac disease
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'BPC-157';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%celiac%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 1, 'Promotes intestinal mucosal healing and reduces inflammation in celiac-damaged intestinal villi')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- L-Glutamine for Celiac disease
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'L-Glutamine';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%celiac%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Repairs celiac-induced intestinal permeability by providing fuel for enterocyte regeneration')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Zinc Bisglycinate for Celiac disease
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Zinc Bisglycinate';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%celiac%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Addresses zinc malabsorption common in celiac disease; supports mucosal healing and immune function')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Vitamin D3 for Celiac disease
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Vitamin D3';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%celiac%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 3, 'Addresses D3 deficiency prevalent in celiac patients due to malabsorption; supports intestinal immune tolerance')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

END $$;

-- ------------------------------------------------------------
-- MUSCULOSKELETAL CONDITIONS
-- ------------------------------------------------------------

-- Osteoarthritis
DO $$ DECLARE
  cond_id UUID;
  protocol_uuid UUID;
BEGIN
  -- BPC-157 for Osteoarthritis
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'BPC-157';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%osteoarth%' OR
      slug ILIKE '%degenerative-joint%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 1, 'Promotes cartilage repair and reduces joint inflammation through growth factor upregulation and anti-inflammatory mechanisms')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- TB-500 for Osteoarthritis
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'TB-500';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%osteoarth%' OR
      slug ILIKE '%degenerative-joint%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 1, 'Enhances joint tissue repair via cell migration and anti-inflammatory effects; reduces fibrotic scarring in damaged joints')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Collagen Peptides for Osteoarthritis
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Collagen Peptides';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%osteoarth%' OR
      slug ILIKE '%degenerative-joint%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Type II collagen peptides provide substrates for cartilage repair; 24-week RCTs show reduced OA pain and improved function')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Curcumin (with Piperine) for Osteoarthritis
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Curcumin (with Piperine)';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%osteoarth%' OR
      slug ILIKE '%degenerative-joint%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'NF-kB inhibitor comparable to NSAIDs for OA pain; reduces cartilage-degrading enzyme expression')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Boswellia Serrata for Osteoarthritis
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Boswellia Serrata';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%osteoarth%' OR
      slug ILIKE '%degenerative-joint%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 3, '5-LOX inhibitor with clinical evidence for OA symptom improvement; reduces leukotriene-mediated joint inflammation')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

END $$;

-- Tendinopathy
DO $$ DECLARE
  cond_id UUID;
  protocol_uuid UUID;
BEGIN
  -- BPC-157 for Tendinopathy
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'BPC-157';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%tendinit%' OR
      slug ILIKE '%tendinop%' OR
      slug ILIKE '%tendon%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 1, 'Most evidence-supported peptide for tendon healing; promotes tenocyte proliferation, collagen synthesis, and angiogenesis at tendon injury sites')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- TB-500 for Tendinopathy
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'TB-500';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%tendinit%' OR
      slug ILIKE '%tendinop%' OR
      slug ILIKE '%tendon%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 1, 'Thymosin beta-4 accelerates tendon repair through enhanced cell migration, reduced inflammation, and anti-fibrotic effects')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Collagen Peptides for Tendinopathy
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Collagen Peptides';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%tendinit%' OR
      slug ILIKE '%tendinop%' OR
      slug ILIKE '%tendon%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Provides type I collagen substrates for tendon repair; enhances tendon collagen synthesis when combined with exercise')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Vitamin C (Liposomal) for Tendinopathy
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Vitamin C (Liposomal)';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%tendinit%' OR
      slug ILIKE '%tendinop%' OR
      slug ILIKE '%tendon%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Essential cofactor for collagen cross-linking in tendon repair; deficiency impairs tendon healing by 50%')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

END $$;

-- Fibromyalgia
DO $$ DECLARE
  cond_id UUID;
  protocol_uuid UUID;
BEGIN
  -- Sermorelin for Fibromyalgia
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Sermorelin';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%fibromyalgia%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 1, 'GH deficiency is common in fibromyalgia; GHRH restoration improves pain, fatigue, and quality of life in fibromyalgia patients')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- BPC-157 for Fibromyalgia
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'BPC-157';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%fibromyalgia%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Anti-inflammatory and neuroprotective effects may address central sensitization and musculoskeletal pain in fibromyalgia')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Magnesium Glycinate for Fibromyalgia
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Magnesium Glycinate';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%fibromyalgia%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Magnesium deficiency prevalent in fibromyalgia; supplementation reduces pain, tender points, and improves sleep quality')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- CoQ10 (Ubiquinol) for Fibromyalgia
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'CoQ10 (Ubiquinol)';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%fibromyalgia%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 3, 'Mitochondrial dysfunction implicated in fibromyalgia; CoQ10 supplementation improves pain and fatigue scores in RCTs')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- SAMe (S-Adenosyl Methionine) for Fibromyalgia
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'SAMe (S-Adenosyl Methionine)';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%fibromyalgia%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 3, 'Improves fibromyalgia pain, fatigue, and mood through methylation support and neurotransmitter modulation')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

END $$;

-- Sports injuries
DO $$ DECLARE
  cond_id UUID;
  protocol_uuid UUID;
BEGIN
  -- BPC-157 for Sports injuries
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'BPC-157';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%sprain%' OR
      slug ILIKE '%strain%' OR
      slug ILIKE '%sports-injur%' OR
      slug ILIKE '%muscle-tear%' OR
      slug ILIKE '%ligament%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 1, 'Accelerates healing of muscles, tendons, and ligaments through multiple growth factor pathways and angiogenesis')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- TB-500 for Sports injuries
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'TB-500';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%sprain%' OR
      slug ILIKE '%strain%' OR
      slug ILIKE '%sports-injur%' OR
      slug ILIKE '%muscle-tear%' OR
      slug ILIKE '%ligament%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 1, 'Promotes rapid tissue repair via cell migration to injury sites and anti-inflammatory macrophage modulation')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- CJC-1295/Ipamorelin for Sports injuries
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'CJC-1295/Ipamorelin';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%sprain%' OR
      slug ILIKE '%strain%' OR
      slug ILIKE '%sports-injur%' OR
      slug ILIKE '%muscle-tear%' OR
      slug ILIKE '%ligament%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'GH/IGF-1 elevation accelerates tissue repair, collagen synthesis, and recovery from sports injuries')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Collagen Peptides for Sports injuries
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Collagen Peptides';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%sprain%' OR
      slug ILIKE '%strain%' OR
      slug ILIKE '%sports-injur%' OR
      slug ILIKE '%muscle-tear%' OR
      slug ILIKE '%ligament%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Provides structural protein substrates for connective tissue repair at injury sites')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

END $$;

-- Bursitis
DO $$ DECLARE
  cond_id UUID;
  protocol_uuid UUID;
BEGIN
  -- BPC-157 for Bursitis
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'BPC-157';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%bursitis%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 1, 'Anti-inflammatory peptide that reduces bursal inflammation and promotes healing of irritated synovial tissue')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- TB-500 for Bursitis
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'TB-500';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%bursitis%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Tissue repair peptide that reduces inflammation and fibrosis in chronically inflamed bursal tissue')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Curcumin (with Piperine) for Bursitis
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Curcumin (with Piperine)';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%bursitis%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'NF-kB inhibitor that reduces inflammatory cytokines driving bursitis; natural alternative to NSAID therapy')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Omega-3 (EPA/DHA) for Bursitis
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Omega-3 (EPA/DHA)';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%bursitis%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 3, 'Pro-resolving mediators that actively resolve bursal inflammation rather than merely suppressing it')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

END $$;

-- Ehlers-Danlos syndrome
DO $$ DECLARE
  cond_id UUID;
  protocol_uuid UUID;
BEGIN
  -- BPC-157 for Ehlers-Danlos syndrome
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'BPC-157';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%ehlers-danlos%' OR
      slug ILIKE '%connective-tissue%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 1, 'Promotes collagen synthesis and connective tissue repair; addresses fundamental tissue healing deficits in EDS')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- TB-500 for Ehlers-Danlos syndrome
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'TB-500';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%ehlers-danlos%' OR
      slug ILIKE '%connective-tissue%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 1, 'Supports connective tissue remodeling and reduces chronic inflammation in hypermobile joints')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Collagen Peptides for Ehlers-Danlos syndrome
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Collagen Peptides';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%ehlers-danlos%' OR
      slug ILIKE '%connective-tissue%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Provides building blocks for defective collagen synthesis; essential substrate support for EDS connective tissue')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Vitamin C (Liposomal) for Ehlers-Danlos syndrome
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Vitamin C (Liposomal)';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%ehlers-danlos%' OR
      slug ILIKE '%connective-tissue%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Critical for collagen cross-linking that is already compromised in EDS; high-dose support for structural integrity')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Magnesium Glycinate for Ehlers-Danlos syndrome
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Magnesium Glycinate';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%ehlers-danlos%' OR
      slug ILIKE '%connective-tissue%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 3, 'Addresses common magnesium wasting in EDS; supports muscle function and reduces cramping in hypermobile patients')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

END $$;

-- ------------------------------------------------------------
-- HORMONAL CONDITIONS
-- ------------------------------------------------------------

-- Hypothyroidism
DO $$ DECLARE
  cond_id UUID;
  protocol_uuid UUID;
BEGIN
  -- Sermorelin for Hypothyroidism
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Sermorelin';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%hypothyroid%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'GH/IGF-1 axis support improves metabolic function and energy in hypothyroid-associated fatigue and metabolic slowing')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Selenium (Selenomethionine) for Hypothyroidism
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Selenium (Selenomethionine)';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%hypothyroid%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Essential cofactor for thyroid deiodinase enzymes (T4 to T3 conversion); deficiency worsens hypothyroid symptoms')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Iodine (Potassium Iodide) for Hypothyroidism
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Iodine (Potassium Iodide)';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%hypothyroid%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Required substrate for thyroid hormone synthesis; mild iodine deficiency contributes to hypothyroidism')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Zinc Bisglycinate for Hypothyroidism
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Zinc Bisglycinate';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%hypothyroid%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 3, 'Required for thyroid hormone receptor binding and T4 to T3 conversion; supports thyroid function')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Ashwagandha for Hypothyroidism
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Ashwagandha';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%hypothyroid%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 3, 'TSH-modulating adaptogen with evidence for improving thyroid function in subclinical hypothyroidism')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

END $$;

-- Hashimoto's thyroiditis
DO $$ DECLARE
  cond_id UUID;
  protocol_uuid UUID;
BEGIN
  -- Thymosin Alpha-1 for Hashimoto's thyroiditis
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Thymosin Alpha-1';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%hashimoto%' OR
      slug ILIKE '%autoimmune-thyroid%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 1, 'Immune modulator that rebalances Th1/Th2 response; addresses autoimmune thyroid destruction through immune regulation')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Selenium (Selenomethionine) for Hashimoto's thyroiditis
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Selenium (Selenomethionine)';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%hashimoto%' OR
      slug ILIKE '%autoimmune-thyroid%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'RCTs demonstrate significant TPO-Ab reduction in Hashimoto patients; protects thyroid from oxidative damage')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Vitamin D3 for Hashimoto's thyroiditis
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Vitamin D3';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%hashimoto%' OR
      slug ILIKE '%autoimmune-thyroid%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Immunomodulator with evidence for reduced thyroid autoantibodies; deficiency common in autoimmune thyroid disease')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- NAC for Hashimoto's thyroiditis
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'NAC';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%hashimoto%' OR
      slug ILIKE '%autoimmune-thyroid%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 3, 'Glutathione precursor reducing thyroid oxidative stress; supports immune regulation in autoimmune thyroiditis')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

END $$;

-- Hypogonadism / Low testosterone
DO $$ DECLARE
  cond_id UUID;
  protocol_uuid UUID;
BEGIN
  -- CJC-1295/Ipamorelin for Hypogonadism / Low testosterone
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'CJC-1295/Ipamorelin';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%hypogonad%' OR
      slug ILIKE '%low-testosterone%' OR
      slug ILIKE '%testosterone-deficiency%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 1, 'GH secretagogue that supports testosterone production through GH/IGF-1 axis optimization and improved Leydig cell function')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Tongkat Ali (Eurycoma longifolia) for Hypogonadism / Low testosterone
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Tongkat Ali (Eurycoma longifolia)';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%hypogonad%' OR
      slug ILIKE '%low-testosterone%' OR
      slug ILIKE '%testosterone-deficiency%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Free testosterone optimizer via SHBG reduction; clinical evidence for improved T levels and symptoms of hypogonadism')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- DHEA for Hypogonadism / Low testosterone
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'DHEA';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%hypogonad%' OR
      slug ILIKE '%low-testosterone%' OR
      slug ILIKE '%testosterone-deficiency%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Direct testosterone precursor that restores declining androgen levels; addresses age-related DHEA-S decline')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Ashwagandha for Hypogonadism / Low testosterone
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Ashwagandha';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%hypogonad%' OR
      slug ILIKE '%low-testosterone%' OR
      slug ILIKE '%testosterone-deficiency%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'RCTs demonstrate 14-40% testosterone increase via cortisol reduction and direct testicular effects')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Zinc Bisglycinate for Hypogonadism / Low testosterone
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Zinc Bisglycinate';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%hypogonad%' OR
      slug ILIKE '%low-testosterone%' OR
      slug ILIKE '%testosterone-deficiency%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 3, 'Essential for testosterone synthesis; deficiency directly causes hypogonadal symptoms within weeks')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

END $$;

-- PCOS
DO $$ DECLARE
  cond_id UUID;
  protocol_uuid UUID;
BEGIN
  -- Inositol (Myo-Inositol) for PCOS
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Inositol (Myo-Inositol)';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%polycystic-ovar%' OR
      slug ILIKE '%pcos%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 1, 'Insulin sensitizer with strong RCT evidence for improving PCOS hormonal profile, ovulation, and metabolic markers')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Berberine for PCOS
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Berberine';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%polycystic-ovar%' OR
      slug ILIKE '%pcos%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'AMPK activator improving insulin resistance underlying PCOS; head-to-head with metformin shows comparable PCOS benefit')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- DIM (Diindolylmethane) for PCOS
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'DIM (Diindolylmethane)';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%polycystic-ovar%' OR
      slug ILIKE '%pcos%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Promotes favorable estrogen metabolism; addresses estrogen dominance component of PCOS hormonal imbalance')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Vitex (Chasteberry) for PCOS
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Vitex (Chasteberry)';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%polycystic-ovar%' OR
      slug ILIKE '%pcos%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 3, 'Prolactin modulator supporting progesterone production; helps regulate menstrual cycles in PCOS')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Chromium Picolinate for PCOS
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Chromium Picolinate';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%polycystic-ovar%' OR
      slug ILIKE '%pcos%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 3, 'Insulin receptor enhancer addressing the insulin resistance that drives PCOS pathophysiology')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

END $$;

-- Adrenal insufficiency
DO $$ DECLARE
  cond_id UUID;
  protocol_uuid UUID;
BEGIN
  -- DHEA for Adrenal insufficiency
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'DHEA';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%adrenal-insufficiency%' OR
      slug ILIKE '%addison%' OR
      slug ILIKE '%adrenal-fatigue%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 1, 'Adrenal hormone precursor addressing the DHEA-S deficiency that accompanies adrenal insufficiency')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Ashwagandha for Adrenal insufficiency
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Ashwagandha';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%adrenal-insufficiency%' OR
      slug ILIKE '%addison%' OR
      slug ILIKE '%adrenal-fatigue%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Adaptogen that modulates HPA axis function; supports adrenal recovery through cortisol normalization')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Rhodiola Rosea for Adrenal insufficiency
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Rhodiola Rosea';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%adrenal-insufficiency%' OR
      slug ILIKE '%addison%' OR
      slug ILIKE '%adrenal-fatigue%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Anti-fatigue adaptogen that enhances stress resilience and energy in adrenal compromise; supports HPA axis recovery')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- B-Complex (Methylated) for Adrenal insufficiency
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'B-Complex (Methylated)';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%adrenal-insufficiency%' OR
      slug ILIKE '%addison%' OR
      slug ILIKE '%adrenal-fatigue%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 3, 'B vitamins are critical cofactors for adrenal hormone synthesis; methylated forms ensure optimal utilization')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Vitamin C (Liposomal) for Adrenal insufficiency
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Vitamin C (Liposomal)';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%adrenal-insufficiency%' OR
      slug ILIKE '%addison%' OR
      slug ILIKE '%adrenal-fatigue%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 3, 'Adrenal glands contain the highest vitamin C concentration; essential for cortisol synthesis and adrenal function')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

END $$;

-- Graves' disease
DO $$ DECLARE
  cond_id UUID;
  protocol_uuid UUID;
BEGIN
  -- Thymosin Alpha-1 for Graves' disease
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Thymosin Alpha-1';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%graves%' OR
      slug ILIKE '%hyperthyroid%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 1, 'Immune modulator addressing autoimmune thyroid stimulation; rebalances dysregulated immune response in Graves disease')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Selenium (Selenomethionine) for Graves' disease
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Selenium (Selenomethionine)';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%graves%' OR
      slug ILIKE '%hyperthyroid%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Reduces thyroid autoantibodies and inflammatory cytokines in Graves disease; supports thyroid protection from oxidative damage')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- NAC for Graves' disease
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'NAC';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%graves%' OR
      slug ILIKE '%hyperthyroid%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Antioxidant support for thyroid oxidative stress in Graves disease; modulates inflammatory immune activation')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Vitamin D3 for Graves' disease
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Vitamin D3';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%graves%' OR
      slug ILIKE '%hyperthyroid%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 3, 'Immunomodulator addressing the vitamin D deficiency common in autoimmune thyroid conditions')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

END $$;

-- ------------------------------------------------------------
-- METABOLIC CONDITIONS
-- ------------------------------------------------------------

-- Type 2 diabetes
DO $$ DECLARE
  cond_id UUID;
  protocol_uuid UUID;
BEGIN
  -- Berberine for Type 2 diabetes
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Berberine';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%type-2-diabet%' OR
      slug ILIKE '%diabetes-mellitus-type-2%' OR
      slug ILIKE '%t2dm%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 1, 'AMPK activator with head-to-head RCT evidence matching metformin for HbA1c reduction and insulin sensitization in T2DM')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Alpha-Lipoic Acid for Type 2 diabetes
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Alpha-Lipoic Acid';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%type-2-diabet%' OR
      slug ILIKE '%diabetes-mellitus-type-2%' OR
      slug ILIKE '%t2dm%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Improves insulin sensitivity and reduces diabetic neuropathy; universal antioxidant addressing T2DM oxidative stress')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Chromium Picolinate for Type 2 diabetes
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Chromium Picolinate';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%type-2-diabet%' OR
      slug ILIKE '%diabetes-mellitus-type-2%' OR
      slug ILIKE '%t2dm%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Enhances insulin receptor signaling; meta-analysis of 25 RCTs supports significant glucose and HbA1c improvement in T2DM')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Magnesium Glycinate for Type 2 diabetes
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Magnesium Glycinate';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%type-2-diabet%' OR
      slug ILIKE '%diabetes-mellitus-type-2%' OR
      slug ILIKE '%t2dm%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 3, 'Magnesium deficiency present in 48% of T2DM; supplementation improves insulin sensitivity and glycemic control')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Cinnamon Extract (Ceylon) for Type 2 diabetes
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Cinnamon Extract (Ceylon)';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%type-2-diabet%' OR
      slug ILIKE '%diabetes-mellitus-type-2%' OR
      slug ILIKE '%t2dm%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 3, 'Insulin-mimetic polyphenols reducing postprandial glucose; safe adjunct to standard T2DM management')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

END $$;

-- Metabolic syndrome
DO $$ DECLARE
  cond_id UUID;
  protocol_uuid UUID;
BEGIN
  -- Tesamorelin for Metabolic syndrome
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Tesamorelin';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%metabolic-syndrome%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 1, 'FDA-approved GHRH analog that reduces visceral adipose tissue and improves metabolic markers in metabolic syndrome')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Berberine for Metabolic syndrome
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Berberine';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%metabolic-syndrome%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Multi-target metabolic optimizer addressing insulin resistance, dyslipidemia, and visceral adiposity simultaneously')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Omega-3 (EPA/DHA) for Metabolic syndrome
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Omega-3 (EPA/DHA)';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%metabolic-syndrome%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Reduces triglycerides 25-30%, improves HDL, and reduces inflammatory markers in metabolic syndrome')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Alpha-Lipoic Acid for Metabolic syndrome
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Alpha-Lipoic Acid';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%metabolic-syndrome%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 3, 'Mitochondrial antioxidant improving insulin sensitivity and reducing oxidative stress in metabolic syndrome')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

END $$;

-- Obesity
DO $$ DECLARE
  cond_id UUID;
  protocol_uuid UUID;
BEGIN
  -- Tesamorelin for Obesity
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Tesamorelin';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%obesity%' OR
      slug ILIKE '%morbid-obes%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 1, 'GHRH analog reducing visceral adiposity through targeted lipolysis while preserving lean mass')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- AOD-9604 for Obesity
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'AOD-9604';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%obesity%' OR
      slug ILIKE '%morbid-obes%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 1, 'GH fragment with fat-specific lipolytic activity without IGF-1 elevation or diabetogenic effects')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Berberine for Obesity
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Berberine';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%obesity%' OR
      slug ILIKE '%morbid-obes%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'AMPK activator reducing hepatic lipogenesis and improving insulin sensitivity; supports weight loss')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Chromium Picolinate for Obesity
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Chromium Picolinate';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%obesity%' OR
      slug ILIKE '%morbid-obes%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 3, 'Reduces carbohydrate cravings and supports insulin sensitivity during weight management')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

END $$;

-- Insulin resistance
DO $$ DECLARE
  cond_id UUID;
  protocol_uuid UUID;
BEGIN
  -- Berberine for Insulin resistance
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Berberine';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%insulin-resistan%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 1, 'Potent insulin sensitizer activating AMPK and improving glucose transporter expression; comparable to metformin')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Inositol (Myo-Inositol) for Insulin resistance
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Inositol (Myo-Inositol)';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%insulin-resistan%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Insulin second messenger improving insulin signaling by 30-40% in resistant individuals')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Alpha-Lipoic Acid for Insulin resistance
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Alpha-Lipoic Acid';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%insulin-resistan%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Enhances glucose disposal by 25-50% through improved GLUT4 translocation and mitochondrial function')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Chromium Picolinate for Insulin resistance
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Chromium Picolinate';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%insulin-resistan%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 3, 'Enhances insulin receptor phosphorylation and improves glucose tolerance factor function')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

END $$;

-- Hyperlipidemia
DO $$ DECLARE
  cond_id UUID;
  protocol_uuid UUID;
BEGIN
  -- Berberine for Hyperlipidemia
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Berberine';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%hyperlipid%' OR
      slug ILIKE '%dyslipid%' OR
      slug ILIKE '%hypercholesterol%' OR
      slug ILIKE '%high-cholesterol%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 1, 'Upregulates hepatic LDL receptor expression reducing LDL-C by 20-25%; also reduces triglycerides')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Omega-3 (EPA/DHA) for Hyperlipidemia
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Omega-3 (EPA/DHA)';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%hyperlipid%' OR
      slug ILIKE '%dyslipid%' OR
      slug ILIKE '%hypercholesterol%' OR
      slug ILIKE '%high-cholesterol%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Prescription-strength omega-3 reduces triglycerides 25-45%; improves overall lipid profile and cardiovascular risk')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- CoQ10 (Ubiquinol) for Hyperlipidemia
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'CoQ10 (Ubiquinol)';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%hyperlipid%' OR
      slug ILIKE '%dyslipid%' OR
      slug ILIKE '%hypercholesterol%' OR
      slug ILIKE '%high-cholesterol%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Addresses statin-induced CoQ10 depletion; supports cardiovascular energy metabolism and endothelial function')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- NAC for Hyperlipidemia
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'NAC';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%hyperlipid%' OR
      slug ILIKE '%dyslipid%' OR
      slug ILIKE '%hypercholesterol%' OR
      slug ILIKE '%high-cholesterol%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 3, 'Reduces lipoprotein(a) and prevents LDL oxidation; supports cardiovascular antioxidant defense')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

END $$;

-- Lipodystrophy
DO $$ DECLARE
  cond_id UUID;
  protocol_uuid UUID;
BEGIN
  -- Tesamorelin for Lipodystrophy
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Tesamorelin';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%lipodystrophy%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 1, 'FDA-approved specifically for HIV-associated lipodystrophy; reduces trunk fat and improves metabolic parameters')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- CJC-1295/Ipamorelin for Lipodystrophy
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'CJC-1295/Ipamorelin';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%lipodystrophy%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'GH axis optimization improves body fat distribution and metabolic function in lipodystrophy')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Omega-3 (EPA/DHA) for Lipodystrophy
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Omega-3 (EPA/DHA)';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%lipodystrophy%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 3, 'Reduces inflammatory adipokines and improves metabolic markers in lipodystrophy patients')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

END $$;

-- ------------------------------------------------------------
-- IMMUNE CONDITIONS
-- ------------------------------------------------------------

-- Immunodeficiency
DO $$ DECLARE
  cond_id UUID;
  protocol_uuid UUID;
BEGIN
  -- Thymosin Alpha-1 for Immunodeficiency
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Thymosin Alpha-1';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%immunodeficienc%' OR
      slug ILIKE '%immune-deficiency%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 1, 'Thymic peptide restoring T-cell immunity; FDA orphan drug status for immune reconstitution in immunocompromised patients')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Vitamin D3 for Immunodeficiency
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Vitamin D3';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%immunodeficienc%' OR
      slug ILIKE '%immune-deficiency%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Activates innate immune defense through cathelicidin and defensin antimicrobial peptides in immune cells')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Zinc Bisglycinate for Immunodeficiency
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Zinc Bisglycinate';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%immunodeficienc%' OR
      slug ILIKE '%immune-deficiency%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Essential for T-cell maturation, NK cell activity, and immune cell signaling; deficiency causes immune suppression')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Vitamin C (Liposomal) for Immunodeficiency
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Vitamin C (Liposomal)';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%immunodeficienc%' OR
      slug ILIKE '%immune-deficiency%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 3, 'Supports immune cell function including neutrophil chemotaxis, phagocytosis, and lymphocyte proliferation')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

END $$;

-- Lupus / SLE
DO $$ DECLARE
  cond_id UUID;
  protocol_uuid UUID;
BEGIN
  -- Thymosin Alpha-1 for Lupus / SLE
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Thymosin Alpha-1';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%lupus%' OR
      slug ILIKE '%systemic-lupus%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 1, 'Immune modulator that rebalances dysregulated immune response in lupus through T-regulatory cell enhancement')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Omega-3 (EPA/DHA) for Lupus / SLE
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Omega-3 (EPA/DHA)';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%lupus%' OR
      slug ILIKE '%systemic-lupus%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Anti-inflammatory omega-3 metabolites reduce lupus disease activity scores; supports resolution of inflammatory flares')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Vitamin D3 for Lupus / SLE
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Vitamin D3';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%lupus%' OR
      slug ILIKE '%systemic-lupus%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Immunomodulator addressing the universal vitamin D deficiency in lupus; reduces autoimmune activity and flare frequency')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- NAC for Lupus / SLE
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'NAC';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%lupus%' OR
      slug ILIKE '%systemic-lupus%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 3, 'Addresses glutathione depletion and oxidative stress driving lupus immune dysregulation')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

END $$;

-- Rheumatoid arthritis
DO $$ DECLARE
  cond_id UUID;
  protocol_uuid UUID;
BEGIN
  -- Thymosin Alpha-1 for Rheumatoid arthritis
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Thymosin Alpha-1';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%rheumatoid-arthritis%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 1, 'Immune modulator addressing the autoimmune joint destruction in RA through immune rebalancing')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Curcumin (with Piperine) for Rheumatoid arthritis
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Curcumin (with Piperine)';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%rheumatoid-arthritis%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'NF-kB inhibitor with RA-specific evidence for reducing joint inflammation, swelling, and morning stiffness')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Omega-3 (EPA/DHA) for Rheumatoid arthritis
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Omega-3 (EPA/DHA)';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%rheumatoid-arthritis%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Meta-analyses support reduced RA disease activity, joint tenderness, and NSAID requirements with omega-3 supplementation')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Boswellia Serrata for Rheumatoid arthritis
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Boswellia Serrata';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%rheumatoid-arthritis%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 3, '5-LOX inhibitor reducing leukotriene-mediated joint inflammation in RA; synergistic with curcumin')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

END $$;

-- Sjogren's syndrome
DO $$ DECLARE
  cond_id UUID;
  protocol_uuid UUID;
BEGIN
  -- Thymosin Alpha-1 for Sjogren's syndrome
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Thymosin Alpha-1';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%sjogren%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 1, 'Immune modulator addressing autoimmune exocrine gland destruction; supports immune tolerance restoration')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Omega-3 (EPA/DHA) for Sjogren's syndrome
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Omega-3 (EPA/DHA)';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%sjogren%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Anti-inflammatory effects with specific evidence for improving dry eye symptoms in Sjogren syndrome')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- NAC for Sjogren's syndrome
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'NAC';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%sjogren%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Mucolytic and antioxidant that supports mucous membrane moisture and reduces oxidative damage to exocrine glands')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

END $$;

-- MCAS (Mast Cell Activation Syndrome)
DO $$ DECLARE
  cond_id UUID;
  protocol_uuid UUID;
BEGIN
  -- Quercetin for MCAS (Mast Cell Activation Syndrome)
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Quercetin';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%mast-cell%' OR
      slug ILIKE '%mcas%' OR
      slug ILIKE '%mastocytosis%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 1, 'Natural mast cell stabilizer inhibiting histamine release and inflammatory cytokine production from mast cells')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- NAC for MCAS (Mast Cell Activation Syndrome)
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'NAC';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%mast-cell%' OR
      slug ILIKE '%mcas%' OR
      slug ILIKE '%mastocytosis%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Reduces oxidative stress driving mast cell activation; supports glutathione defense against inflammatory mediators')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Omega-3 (EPA/DHA) for MCAS (Mast Cell Activation Syndrome)
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Omega-3 (EPA/DHA)';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%mast-cell%' OR
      slug ILIKE '%mcas%' OR
      slug ILIKE '%mastocytosis%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'SPM precursors that resolve mast-cell-driven inflammation; reduces prostaglandin and leukotriene production')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Vitamin C (Liposomal) for MCAS (Mast Cell Activation Syndrome)
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Vitamin C (Liposomal)';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%mast-cell%' OR
      slug ILIKE '%mcas%' OR
      slug ILIKE '%mastocytosis%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 3, 'Natural antihistamine that degrades histamine through diamine oxidase support; reduces mast cell reactivity')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

END $$;

-- Chronic Fatigue Syndrome / ME
DO $$ DECLARE
  cond_id UUID;
  protocol_uuid UUID;
BEGIN
  -- Sermorelin for Chronic Fatigue Syndrome / ME
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Sermorelin';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%chronic-fatigue%' OR
      slug ILIKE '%myalgic-encephalom%' OR
      slug ILIKE '%me-cfs%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 1, 'GH deficiency is common in CFS/ME; GHRH restoration improves energy, body composition, and quality of life')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Thymosin Alpha-1 for Chronic Fatigue Syndrome / ME
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Thymosin Alpha-1';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%chronic-fatigue%' OR
      slug ILIKE '%myalgic-encephalom%' OR
      slug ILIKE '%me-cfs%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Addresses immune dysregulation component of CFS/ME through immune modulation and T-cell restoration')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- CoQ10 (Ubiquinol) for Chronic Fatigue Syndrome / ME
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'CoQ10 (Ubiquinol)';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%chronic-fatigue%' OR
      slug ILIKE '%myalgic-encephalom%' OR
      slug ILIKE '%me-cfs%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Mitochondrial electron carrier addressing bioenergetic deficiency in CFS/ME; RCTs show reduced fatigue')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- NAC for Chronic Fatigue Syndrome / ME
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'NAC';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%chronic-fatigue%' OR
      slug ILIKE '%myalgic-encephalom%' OR
      slug ILIKE '%me-cfs%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 3, 'Glutathione precursor addressing the oxidative stress and glutathione depletion documented in CFS/ME patients')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- NMN (Nicotinamide Mononucleotide) for Chronic Fatigue Syndrome / ME
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'NMN (Nicotinamide Mononucleotide)';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%chronic-fatigue%' OR
      slug ILIKE '%myalgic-encephalom%' OR
      slug ILIKE '%me-cfs%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 3, 'NAD+ restoration addresses mitochondrial dysfunction and energy metabolism impairment in CFS/ME')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

END $$;

-- ------------------------------------------------------------
-- NEUROLOGICAL CONDITIONS
-- ------------------------------------------------------------

-- Anxiety disorders
DO $$ DECLARE
  cond_id UUID;
  protocol_uuid UUID;
BEGIN
  -- Ashwagandha for Anxiety disorders
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Ashwagandha';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%anxiety%' OR
      slug ILIKE '%generalized-anxiety%' OR
      slug ILIKE '%panic-disorder%' OR
      slug ILIKE '%social-anxiety%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 1, 'Gold standard anxiolytic adaptogen with RCT evidence for 56% anxiety reduction (Hamilton scale) and 28% cortisol decrease')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- L-Theanine for Anxiety disorders
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'L-Theanine';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%anxiety%' OR
      slug ILIKE '%generalized-anxiety%' OR
      slug ILIKE '%panic-disorder%' OR
      slug ILIKE '%social-anxiety%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Alpha-wave promoting amino acid that reduces anxiety within 30 minutes without sedation; enhances GABA and serotonin')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Magnesium Glycinate for Anxiety disorders
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Magnesium Glycinate';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%anxiety%' OR
      slug ILIKE '%generalized-anxiety%' OR
      slug ILIKE '%panic-disorder%' OR
      slug ILIKE '%social-anxiety%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Magnesium deficiency amplifies HPA axis reactivity; glycinate form provides calming glycine plus anxiolytic magnesium')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Rhodiola Rosea for Anxiety disorders
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Rhodiola Rosea';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%anxiety%' OR
      slug ILIKE '%generalized-anxiety%' OR
      slug ILIKE '%panic-disorder%' OR
      slug ILIKE '%social-anxiety%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 3, 'Adaptogen reducing anxiety-related fatigue and burnout; modulates cortisol and monoamine neurotransmitters')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- GABA for Anxiety disorders
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'GABA';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%anxiety%' OR
      slug ILIKE '%generalized-anxiety%' OR
      slug ILIKE '%panic-disorder%' OR
      slug ILIKE '%social-anxiety%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 3, 'Primary inhibitory neurotransmitter that directly reduces neuronal excitability and promotes calmness')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

END $$;

-- Depression
DO $$ DECLARE
  cond_id UUID;
  protocol_uuid UUID;
BEGIN
  -- SAMe (S-Adenosyl Methionine) for Depression
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'SAMe (S-Adenosyl Methionine)';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%depression%' OR
      slug ILIKE '%major-depress%' OR
      slug ILIKE '%dysthymi%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 1, 'Methyl donor for serotonin, dopamine, and norepinephrine synthesis; RCTs show antidepressant efficacy comparable to tricyclics')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Omega-3 (EPA/DHA) for Depression
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Omega-3 (EPA/DHA)';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%depression%' OR
      slug ILIKE '%major-depress%' OR
      slug ILIKE '%dysthymi%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'EPA specifically demonstrates antidepressant effects; 1-2g EPA recommended as adjunct to standard treatment')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- 5-HTP for Depression
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = '5-HTP';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%depression%' OR
      slug ILIKE '%major-depress%' OR
      slug ILIKE '%dysthymi%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Direct serotonin precursor bypassing rate-limiting enzyme; 150-300mg shows antidepressant effects in clinical trials')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Ashwagandha for Depression
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Ashwagandha';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%depression%' OR
      slug ILIKE '%major-depress%' OR
      slug ILIKE '%dysthymi%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 3, 'Adaptogen with evidence for improving depression scores through cortisol reduction and GABA modulation')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Rhodiola Rosea for Depression
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Rhodiola Rosea';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%depression%' OR
      slug ILIKE '%major-depress%' OR
      slug ILIKE '%dysthymi%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 3, 'Monoamine modulator with clinical evidence for mild-moderate depression and emotional eating reduction')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

END $$;

-- Insomnia
DO $$ DECLARE
  cond_id UUID;
  protocol_uuid UUID;
BEGIN
  -- Magnesium Glycinate for Insomnia
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Magnesium Glycinate';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%insomnia%' OR
      slug ILIKE '%sleep-disorder%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 1, 'Dual sleep promoter: magnesium activates GABA receptors while glycine acts as inhibitory neurotransmitter for deep sleep')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Melatonin for Insomnia
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Melatonin';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%insomnia%' OR
      slug ILIKE '%sleep-disorder%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Endogenous circadian regulator; low-dose supplementation reduces sleep onset latency without dependency risk')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- L-Theanine for Insomnia
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'L-Theanine';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%insomnia%' OR
      slug ILIKE '%sleep-disorder%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Promotes relaxation via alpha-wave induction; improves sleep quality by reducing anxiety-driven sleep onset delays')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Ashwagandha for Insomnia
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Ashwagandha';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%insomnia%' OR
      slug ILIKE '%sleep-disorder%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 3, 'Triethylene glycol component directly induces non-REM sleep; KSM-66 improved sleep quality by 72% in RCT')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Apigenin for Insomnia
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Apigenin';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%insomnia%' OR
      slug ILIKE '%sleep-disorder%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 3, 'Chamomile-derived flavonoid binding GABA-A receptors as partial agonist; promotes sleep without hangover effects')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

END $$;

-- Cognitive decline / MCI
DO $$ DECLARE
  cond_id UUID;
  protocol_uuid UUID;
BEGIN
  -- Lion's Mane (Hericium erinaceus) for Cognitive decline / MCI
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Lion''s Mane (Hericium erinaceus)';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%cognitive-decline%' OR
      slug ILIKE '%mild-cognitive-impairment%' OR
      slug ILIKE '%mci%' OR
      slug ILIKE '%dementia%' OR
      slug ILIKE '%memory-loss%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 1, 'Stimulates NGF and BDNF synthesis; 16-week RCT demonstrated significant cognitive improvement in MCI patients')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Citicoline (CDP-Choline) for Cognitive decline / MCI
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Citicoline (CDP-Choline)';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%cognitive-decline%' OR
      slug ILIKE '%mild-cognitive-impairment%' OR
      slug ILIKE '%mci%' OR
      slug ILIKE '%dementia%' OR
      slug ILIKE '%memory-loss%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Provides choline for acetylcholine synthesis and phosphatidylcholine for membrane repair in aging neurons')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Phosphatidylserine for Cognitive decline / MCI
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Phosphatidylserine';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%cognitive-decline%' OR
      slug ILIKE '%mild-cognitive-impairment%' OR
      slug ILIKE '%mci%' OR
      slug ILIKE '%dementia%' OR
      slug ILIKE '%memory-loss%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Membrane phospholipid with meta-analysis evidence for improved memory and cognitive function in age-related decline')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- NMN (Nicotinamide Mononucleotide) for Cognitive decline / MCI
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'NMN (Nicotinamide Mononucleotide)';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%cognitive-decline%' OR
      slug ILIKE '%mild-cognitive-impairment%' OR
      slug ILIKE '%mci%' OR
      slug ILIKE '%dementia%' OR
      slug ILIKE '%memory-loss%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 3, 'NAD+ restoration addresses age-related mitochondrial dysfunction contributing to cognitive decline')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Omega-3 (EPA/DHA) for Cognitive decline / MCI
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Omega-3 (EPA/DHA)';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%cognitive-decline%' OR
      slug ILIKE '%mild-cognitive-impairment%' OR
      slug ILIKE '%mci%' OR
      slug ILIKE '%dementia%' OR
      slug ILIKE '%memory-loss%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 3, 'DHA is the primary structural fatty acid in brain; supplementation slows cognitive decline in early-stage MCI')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

END $$;

-- Neuropathy
DO $$ DECLARE
  cond_id UUID;
  protocol_uuid UUID;
BEGIN
  -- BPC-157 for Neuropathy
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'BPC-157';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%neuropath%' OR
      slug ILIKE '%peripheral-neuropath%' OR
      slug ILIKE '%diabetic-neuropath%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 1, 'Neuroprotective peptide promoting nerve regeneration and repair through VEGF and NO-mediated mechanisms')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Alpha-Lipoic Acid for Neuropathy
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Alpha-Lipoic Acid';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%neuropath%' OR
      slug ILIKE '%peripheral-neuropath%' OR
      slug ILIKE '%diabetic-neuropath%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 1, 'Gold standard for diabetic neuropathy treatment; reduces neuropathic pain and improves nerve conduction in multiple RCTs')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Acetyl-L-Carnitine for Neuropathy
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Acetyl-L-Carnitine';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%neuropath%' OR
      slug ILIKE '%peripheral-neuropath%' OR
      slug ILIKE '%diabetic-neuropath%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Promotes nerve regeneration and reduces neuropathic pain; improves nerve conduction velocity in diabetic neuropathy')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- B-Complex (Methylated) for Neuropathy
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'B-Complex (Methylated)';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%neuropath%' OR
      slug ILIKE '%peripheral-neuropath%' OR
      slug ILIKE '%diabetic-neuropath%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 3, 'B1, B6, and B12 are critical for nerve function; methylated forms ensure absorption in patients with compromised methylation')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

END $$;

-- Alzheimer's disease
DO $$ DECLARE
  cond_id UUID;
  protocol_uuid UUID;
BEGIN
  -- Lion's Mane (Hericium erinaceus) for Alzheimer's disease
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Lion''s Mane (Hericium erinaceus)';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%alzheimer%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 1, 'NGF stimulator supporting neuronal survival and reducing amyloid-beta toxicity in preclinical Alzheimer models')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Citicoline (CDP-Choline) for Alzheimer's disease
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Citicoline (CDP-Choline)';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%alzheimer%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Provides choline for severely depleted cholinergic system in Alzheimer disease; supports membrane phospholipid turnover')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Alpha-GPC for Alzheimer's disease
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Alpha-GPC';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%alzheimer%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Most bioavailable choline source crossing BBB; clinical trials in Alzheimer show cognitive improvement and slowed decline')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- NMN (Nicotinamide Mononucleotide) for Alzheimer's disease
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'NMN (Nicotinamide Mononucleotide)';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%alzheimer%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 3, 'NAD+ restoration activates sirtuins for neuroprotection and addresses mitochondrial dysfunction in Alzheimer pathology')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Resveratrol for Alzheimer's disease
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Resveratrol';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%alzheimer%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 3, 'SIRT1 activator with evidence for reduced neuroinflammation and amyloid-beta accumulation in clinical trials')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

END $$;

-- ------------------------------------------------------------
-- SEXUAL HEALTH CONDITIONS
-- ------------------------------------------------------------

-- Erectile dysfunction
DO $$ DECLARE
  cond_id UUID;
  protocol_uuid UUID;
BEGIN
  -- PT-141 for Erectile dysfunction
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'PT-141';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%erectile-dysfunct%' OR
      slug ILIKE '%impotence%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 1, 'Melanocortin-4 receptor agonist with FDA approval (bremelanotide) for central arousal; works independently of PDE5 pathway')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- L-Citrulline for Erectile dysfunction
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'L-Citrulline';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%erectile-dysfunct%' OR
      slug ILIKE '%impotence%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'NO precursor enhancing penile vasodilation; 1.5g/day showed significant erectile improvement in mild-moderate ED')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Tongkat Ali (Eurycoma longifolia) for Erectile dysfunction
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Tongkat Ali (Eurycoma longifolia)';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%erectile-dysfunct%' OR
      slug ILIKE '%impotence%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Improves erectile function through testosterone optimization and SHBG reduction; significant IIEF score improvement')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Zinc Bisglycinate for Erectile dysfunction
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Zinc Bisglycinate';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%erectile-dysfunct%' OR
      slug ILIKE '%impotence%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 3, 'Essential for both testosterone synthesis and NO production required for erectile function')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

END $$;

-- Male hypogonadism
DO $$ DECLARE
  cond_id UUID;
  protocol_uuid UUID;
BEGIN
  -- CJC-1295/Ipamorelin for Male hypogonadism
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'CJC-1295/Ipamorelin';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%hypogonad%' OR
      slug ILIKE '%low-testosterone%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 1, 'GH axis optimization supports Leydig cell function and testosterone production through improved hormonal milieu')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- HCG for Male hypogonadism
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'HCG';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%hypogonad%' OR
      slug ILIKE '%low-testosterone%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Gonadotropin directly stimulating testicular testosterone production; maintains spermatogenesis during TRT')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Tongkat Ali (Eurycoma longifolia) for Male hypogonadism
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Tongkat Ali (Eurycoma longifolia)';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%hypogonad%' OR
      slug ILIKE '%low-testosterone%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Increases free testosterone via SHBG reduction and supports Leydig cell function through eurypeptide mechanisms')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- DHEA for Male hypogonadism
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'DHEA';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%hypogonad%' OR
      slug ILIKE '%low-testosterone%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 3, 'Androgen precursor restoring age-related decline; supports testosterone production through adrenal pathway')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Ashwagandha for Male hypogonadism
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Ashwagandha';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%hypogonad%' OR
      slug ILIKE '%low-testosterone%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 3, 'RCT evidence for 14-40% testosterone increase; reduces cortisol-mediated suppression of gonadal function')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

END $$;

-- Male infertility
DO $$ DECLARE
  cond_id UUID;
  protocol_uuid UUID;
BEGIN
  -- HCG for Male infertility
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'HCG';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%infertil%' OR
      slug ILIKE '%azoosperm%' OR
      slug ILIKE '%oligosperm%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 1, 'Maintains/restores spermatogenesis through direct Leydig and Sertoli cell stimulation; standard fertility treatment')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- HMG for Male infertility
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'HMG';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%infertil%' OR
      slug ILIKE '%azoosperm%' OR
      slug ILIKE '%oligosperm%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 1, 'Combined FSH/LH activity providing comprehensive gonadal stimulation for sperm production and maturation')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Kisspeptin for Male infertility
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Kisspeptin';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%infertil%' OR
      slug ILIKE '%azoosperm%' OR
      slug ILIKE '%oligosperm%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'GnRH stimulator optimizing reproductive hormone axis; emerging evidence for fertility enhancement')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Zinc Bisglycinate for Male infertility
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Zinc Bisglycinate';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%infertil%' OR
      slug ILIKE '%azoosperm%' OR
      slug ILIKE '%oligosperm%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Critical for spermatogenesis; zinc deficiency reduces sperm count, motility, and testosterone synthesis')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- CoQ10 (Ubiquinol) for Male infertility
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'CoQ10 (Ubiquinol)';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%infertil%' OR
      slug ILIKE '%azoosperm%' OR
      slug ILIKE '%oligosperm%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 3, 'Improves sperm quality through mitochondrial energy support and antioxidant protection of sperm membranes')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

END $$;

-- Androgen deficiency / aging male
DO $$ DECLARE
  cond_id UUID;
  protocol_uuid UUID;
BEGIN
  -- CJC-1295/Ipamorelin for Androgen deficiency / aging male
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'CJC-1295/Ipamorelin';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%androgen-deficienc%' OR
      slug ILIKE '%andropause%' OR
      slug ILIKE '%male-aging%' OR
      slug ILIKE '%testosterone-deficiency%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 1, 'GH secretagogue addressing age-related hormonal decline; improves body composition, energy, and testosterone support')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Tongkat Ali (Eurycoma longifolia) for Androgen deficiency / aging male
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Tongkat Ali (Eurycoma longifolia)';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%androgen-deficienc%' OR
      slug ILIKE '%andropause%' OR
      slug ILIKE '%male-aging%' OR
      slug ILIKE '%testosterone-deficiency%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Natural testosterone optimizer for age-related androgen decline; increases free T through SHBG modulation')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- DHEA for Androgen deficiency / aging male
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'DHEA';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%androgen-deficienc%' OR
      slug ILIKE '%andropause%' OR
      slug ILIKE '%male-aging%' OR
      slug ILIKE '%testosterone-deficiency%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Restores declining DHEA-S levels that drop 80% by age 70; supports testosterone and overall hormonal health')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Fenugreek Extract for Androgen deficiency / aging male
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Fenugreek Extract';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%androgen-deficienc%' OR
      slug ILIKE '%andropause%' OR
      slug ILIKE '%male-aging%' OR
      slug ILIKE '%testosterone-deficiency%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 3, 'Furostanolic saponins support free testosterone through aromatase inhibition; improves libido and vitality scores')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

END $$;

-- ------------------------------------------------------------
-- SKIN & OTHER CONDITIONS
-- ------------------------------------------------------------

-- Acne
DO $$ DECLARE
  cond_id UUID;
  protocol_uuid UUID;
BEGIN
  -- DIM (Diindolylmethane) for Acne
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'DIM (Diindolylmethane)';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%acne%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 1, 'Promotes estrogen metabolism balance reducing androgen-driven sebaceous gland activity in hormonal acne')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Zinc Bisglycinate for Acne
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Zinc Bisglycinate';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%acne%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Anti-inflammatory mineral with direct evidence for reducing acne lesion counts; comparable to minocycline in some RCTs')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- NAC for Acne
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'NAC';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%acne%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Reduces oxidative stress and inflammation driving acne pathogenesis; supports liver detoxification of acne-promoting metabolites')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Berberine for Acne
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Berberine';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%acne%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 3, 'Antimicrobial and anti-inflammatory properties address both bacterial and inflammatory components of acne')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

END $$;

-- Alopecia
DO $$ DECLARE
  cond_id UUID;
  protocol_uuid UUID;
BEGIN
  -- CJC-1295/Ipamorelin for Alopecia
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'CJC-1295/Ipamorelin';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%alopecia%' OR
      slug ILIKE '%hair-loss%' OR
      slug ILIKE '%baldness%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 1, 'GH/IGF-1 stimulation promotes hair follicle proliferation and extends anagen growth phase')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Saw Palmetto for Alopecia
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Saw Palmetto';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%alopecia%' OR
      slug ILIKE '%hair-loss%' OR
      slug ILIKE '%baldness%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, '5-alpha reductase inhibitor reducing DHT-driven follicular miniaturization; 60% improvement rate in clinical trials')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Zinc Bisglycinate for Alopecia
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Zinc Bisglycinate';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%alopecia%' OR
      slug ILIKE '%hair-loss%' OR
      slug ILIKE '%baldness%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Addresses zinc deficiency-driven alopecia; essential mineral for hair follicle health and keratin synthesis')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Iron Bisglycinate for Alopecia
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Iron Bisglycinate';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%alopecia%' OR
      slug ILIKE '%hair-loss%' OR
      slug ILIKE '%baldness%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 3, 'Ferritin below 40 ng/mL associated with telogen effluvium; bisglycinate form ensures adequate iron without GI distress')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

END $$;

-- Wound healing
DO $$ DECLARE
  cond_id UUID;
  protocol_uuid UUID;
BEGIN
  -- BPC-157 for Wound healing
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'BPC-157';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%wound%' OR
      slug ILIKE '%wound-healing%' OR
      slug ILIKE '%surgical-wound%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 1, 'Most evidence-supported peptide for wound healing; promotes angiogenesis, collagen deposition, and granulation tissue formation')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- TB-500 for Wound healing
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'TB-500';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%wound%' OR
      slug ILIKE '%wound-healing%' OR
      slug ILIKE '%surgical-wound%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 1, 'Enhances wound healing through cell migration, keratinocyte stimulation, and anti-inflammatory macrophage polarization')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- GHK-Cu for Wound healing
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'GHK-Cu';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%wound%' OR
      slug ILIKE '%wound-healing%' OR
      slug ILIKE '%surgical-wound%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Copper peptide stimulating collagen synthesis, glycosaminoglycan production, and wound remodeling in healing tissue')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Vitamin C (Liposomal) for Wound healing
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Vitamin C (Liposomal)';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%wound%' OR
      slug ILIKE '%wound-healing%' OR
      slug ILIKE '%surgical-wound%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Essential for collagen cross-linking in wound matrix; deficiency delays wound healing significantly')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Zinc Bisglycinate for Wound healing
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Zinc Bisglycinate';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%wound%' OR
      slug ILIKE '%wound-healing%' OR
      slug ILIKE '%surgical-wound%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 3, 'Critical mineral for wound healing; required for cell proliferation, immune defense, and protein synthesis at wound sites')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

END $$;

-- Aging skin
DO $$ DECLARE
  cond_id UUID;
  protocol_uuid UUID;
BEGIN
  -- GHK-Cu for Aging skin
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'GHK-Cu';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%skin-aging%' OR
      slug ILIKE '%wrinkle%' OR
      slug ILIKE '%photoaging%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 1, 'Copper tripeptide that stimulates collagen I/III synthesis, elastin production, and glycosaminoglycan formation in aging skin')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Collagen Peptides for Aging skin
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Collagen Peptides';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%skin-aging%' OR
      slug ILIKE '%wrinkle%' OR
      slug ILIKE '%photoaging%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Oral collagen peptides stimulate dermal fibroblast collagen synthesis; 8-week RCTs show improved skin elasticity and hydration')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Astaxanthin for Aging skin
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Astaxanthin';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%skin-aging%' OR
      slug ILIKE '%wrinkle%' OR
      slug ILIKE '%photoaging%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Most potent natural antioxidant protecting skin from UV photoaging; clinical trials show reduced wrinkles and improved elasticity')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Vitamin C (Liposomal) for Aging skin
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Vitamin C (Liposomal)';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%skin-aging%' OR
      slug ILIKE '%wrinkle%' OR
      slug ILIKE '%photoaging%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 3, 'Essential cofactor for collagen synthesis; also inhibits melanin production and provides photoprotective antioxidant activity')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

END $$;

-- Osteoporosis
DO $$ DECLARE
  cond_id UUID;
  protocol_uuid UUID;
BEGIN
  -- Sermorelin for Osteoporosis
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Sermorelin';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%osteoporo%' OR
      slug ILIKE '%bone-loss%' OR
      slug ILIKE '%bone-density%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 1, 'GH/IGF-1 axis restoration improves bone mineral density through enhanced osteoblast activity and collagen deposition')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Vitamin D3 for Osteoporosis
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Vitamin D3';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%osteoporo%' OR
      slug ILIKE '%bone-loss%' OR
      slug ILIKE '%bone-density%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Critical for calcium absorption and bone mineralization; foundation of all osteoporosis prevention and treatment protocols')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Vitamin K2 (MK-7) for Osteoporosis
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Vitamin K2 (MK-7)';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%osteoporo%' OR
      slug ILIKE '%bone-loss%' OR
      slug ILIKE '%bone-density%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Activates osteocalcin directing calcium into bone matrix; prevents D3-induced vascular calcification')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Collagen Peptides for Osteoporosis
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Collagen Peptides';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%osteoporo%' OR
      slug ILIKE '%bone-loss%' OR
      slug ILIKE '%bone-density%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 3, 'Type I collagen provides the organic matrix of bone; supplementation improves bone mineral density in postmenopausal women')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Boron for Osteoporosis
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Boron';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%osteoporo%' OR
      slug ILIKE '%bone-loss%' OR
      slug ILIKE '%bone-density%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 3, 'Reduces urinary calcium excretion and supports vitamin D metabolism for bone health')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

END $$;

-- Cardiomyopathy
DO $$ DECLARE
  cond_id UUID;
  protocol_uuid UUID;
BEGIN
  -- TB-500 for Cardiomyopathy
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'TB-500';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%cardiomyopathy%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 1, 'Thymosin beta-4 promotes cardiac tissue repair and reduces fibrosis; evidence for myocardial recovery in preclinical models')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- CoQ10 (Ubiquinol) for Cardiomyopathy
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'CoQ10 (Ubiquinol)';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%cardiomyopathy%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 1, 'Mitochondrial support critical for cardiac energy metabolism; RCTs show improved ejection fraction and reduced mortality in CHF')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Omega-3 (EPA/DHA) for Cardiomyopathy
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Omega-3 (EPA/DHA)';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%cardiomyopathy%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Reduces cardiac arrhythmia risk, improves endothelial function, and supports cardiac membrane fluidity')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Taurine for Cardiomyopathy
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Taurine';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%cardiomyopathy%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 3, 'Supports cardiac contractility and reduces oxidative stress in cardiomyocytes; evidence for improved CHF outcomes')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

END $$;

-- Chronic pain
DO $$ DECLARE
  cond_id UUID;
  protocol_uuid UUID;
BEGIN
  -- BPC-157 for Chronic pain
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'BPC-157';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%chronic-pain%' OR
      slug ILIKE '%pain-syndrome%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 1, 'Anti-inflammatory and neuroprotective peptide addressing both inflammatory and neuropathic pain mechanisms')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Curcumin (with Piperine) for Chronic pain
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Curcumin (with Piperine)';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%chronic-pain%' OR
      slug ILIKE '%pain-syndrome%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Multi-target anti-inflammatory comparable to NSAIDs for pain relief; addresses NF-kB and COX-2 driven pain signaling')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Omega-3 (EPA/DHA) for Chronic pain
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Omega-3 (EPA/DHA)';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%chronic-pain%' OR
      slug ILIKE '%pain-syndrome%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Pro-resolving mediators actively resolve chronic inflammation driving pain; reduces analgesic requirements in RCTs')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Magnesium Glycinate for Chronic pain
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Magnesium Glycinate';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%chronic-pain%' OR
      slug ILIKE '%pain-syndrome%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 3, 'Addresses magnesium deficiency contributing to pain sensitization; NMDA receptor modulation reduces central pain processing')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Boswellia Serrata for Chronic pain
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Boswellia Serrata';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%chronic-pain%' OR
      slug ILIKE '%pain-syndrome%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 3, '5-LOX inhibitor reducing leukotriene-mediated pain and inflammation; synergistic with curcumin for chronic pain')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

END $$;

-- Psoriasis
DO $$ DECLARE
  cond_id UUID;
  protocol_uuid UUID;
BEGIN
  -- Thymosin Alpha-1 for Psoriasis
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Thymosin Alpha-1';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%psoriasis%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 1, 'Immune modulator addressing the T-cell-mediated autoimmune inflammation driving psoriatic plaques')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Vitamin D3 for Psoriasis
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Vitamin D3';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%psoriasis%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Immunomodulator and keratinocyte differentiation regulator; vitamin D analogs are first-line topical psoriasis therapy')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Omega-3 (EPA/DHA) for Psoriasis
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Omega-3 (EPA/DHA)';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%psoriasis%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 2, 'Anti-inflammatory omega-3 metabolites reduce psoriatic inflammation; EPA reduces TNF-alpha and IL-6 in psoriatic skin')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  -- Curcumin (with Piperine) for Psoriasis
  SELECT id INTO protocol_uuid FROM peptide_protocols WHERE peptide_name = 'Curcumin (with Piperine)';
  IF protocol_uuid IS NOT NULL THEN
    FOR cond_id IN (
      SELECT id FROM conditions WHERE is_active = true AND (
      slug ILIKE '%psoriasis%'
      )
    ) LOOP
      INSERT INTO condition_protocols (condition_id, protocol_id, priority, rationale)
      VALUES (cond_id, protocol_uuid, 3, 'NF-kB inhibitor reducing keratinocyte hyperproliferation and inflammatory cytokines driving psoriasis flares')
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

END $$;

-- Total conditions mapped: 50
-- Total condition-protocol mappings: 218


-- ============================================================
-- PROTOCOL METADATA UPDATES
-- Populates 7 new columns on all existing peptide_protocols rows:
-- default_phase, timing_notes, food_interaction,
-- injection_site_notes, half_life, onset_weeks, receptor_group
-- ============================================================

-- ------------------------------------------------------------
-- PEPTIDE PROTOCOL METADATA
-- ------------------------------------------------------------

UPDATE peptide_protocols SET
  default_phase = 1,
  timing_notes = 'Subcutaneous injection 250-500mcg 1-2x daily; take on empty stomach for oral capsule form. Inject near injury site for localized healing or abdomen for systemic effects.',
  food_interaction = 'Fasted — take 20-30 minutes before meals or 2 hours after eating',
  injection_site_notes = 'Subcutaneous: abdomen (systemic), or near injury site for localized effect. Rotate injection sites. Can also be taken orally in capsule form for GI-targeted healing.',
  half_life = '4 hours',
  onset_weeks = 2,
  receptor_group = NULL
WHERE peptide_name = 'BPC-157';

UPDATE peptide_protocols SET
  default_phase = 1,
  timing_notes = 'Subcutaneous injection 2-5mg twice weekly during loading phase (4-6 weeks), then 2mg weekly for maintenance. Best administered in the evening for overnight repair.',
  food_interaction = 'No food restriction — can inject regardless of meal timing',
  injection_site_notes = 'Subcutaneous: abdomen or deltoid. Rotate injection sites. Not site-specific — distributes systemically regardless of injection location.',
  half_life = '6-8 hours (but cellular effects last days)',
  onset_weeks = 2,
  receptor_group = NULL
WHERE peptide_name = 'TB-500';

UPDATE peptide_protocols SET
  default_phase = 2,
  timing_notes = 'Subcutaneous injection 200-300mcg before bed on empty stomach. Fasting 2+ hours before injection maximizes GH pulse. Do not eat after injection. Take 5 days on, 2 days off.',
  food_interaction = 'Fasted — minimum 2 hours after last meal; do not eat after injection',
  injection_site_notes = 'Subcutaneous: abdomen. Inject before bed to align with natural nocturnal GH pulsatility. Rotate injection sites within abdominal area.',
  half_life = '10-20 minutes',
  onset_weeks = 4,
  receptor_group = 'GHRHR'
WHERE peptide_name = 'Sermorelin';

UPDATE peptide_protocols SET
  default_phase = 2,
  timing_notes = 'Subcutaneous injection 100-300mcg each peptide before bed on empty stomach. Fasting 2+ hours before injection. Do not eat for 30 min after. 5 days on, 2 days off cycling.',
  food_interaction = 'Fasted — minimum 2 hours after last meal; no food 30 min post-injection',
  injection_site_notes = 'Subcutaneous: abdomen or lower belly fat. Inject before bed for nocturnal GH amplification. Rotate between left and right sides.',
  half_life = 'CJC-1295: 30 min (no DAC) to 8 days (with DAC); Ipamorelin: 2 hours',
  onset_weeks = 4,
  receptor_group = 'GHRHR/GHSR'
WHERE peptide_name = 'CJC-1295/Ipamorelin';

UPDATE peptide_protocols SET
  default_phase = 2,
  timing_notes = 'Subcutaneous injection 1.6mg twice weekly or 900mcg daily. Can be taken any time of day. Standard protocol: Mon/Thu or Tue/Fri dosing.',
  food_interaction = 'No food restriction',
  injection_site_notes = 'Subcutaneous: abdomen or deltoid. Rotate injection sites. Well-tolerated at any injection location.',
  half_life = '2-3 hours (but immune effects last 5-7 days)',
  onset_weeks = 4,
  receptor_group = NULL
WHERE peptide_name = 'Thymosin Alpha-1';

UPDATE peptide_protocols SET
  default_phase = 2,
  timing_notes = 'Subcutaneous injection 2mg daily on empty stomach. Inject before bed or first thing in morning after overnight fast. Consistent daily timing important.',
  food_interaction = 'Fasted — inject after overnight fast or 2+ hours after last meal',
  injection_site_notes = 'Subcutaneous: abdomen, rotating between left and right sides. Avoid injecting into areas of lipodystrophy.',
  half_life = '26-38 minutes',
  onset_weeks = 6,
  receptor_group = 'GHRHR'
WHERE peptide_name = 'Tesamorelin';

UPDATE peptide_protocols SET
  default_phase = 3,
  timing_notes = 'Subcutaneous injection 1.75mg as needed, 45-60 minutes before sexual activity. Maximum once every 72 hours. Do not use more than 8 times per month.',
  food_interaction = 'Light meal or fasted — heavy meal may delay onset. Avoid alcohol.',
  injection_site_notes = 'Subcutaneous: abdomen or thigh. Single-use dosing, not daily. Rotate injection sites between uses.',
  half_life = '2.5 hours',
  onset_weeks = 1,
  receptor_group = 'MC4R'
WHERE peptide_name = 'PT-141';

UPDATE peptide_protocols SET
  default_phase = 2,
  timing_notes = 'Subcutaneous injection 250-500mcg daily on empty stomach, preferably morning before exercise. Fasting 2+ hours before and 30 minutes after injection.',
  food_interaction = 'Fasted — take in morning before breakfast; exercise after injection enhances fat-burning effect',
  injection_site_notes = 'Subcutaneous: abdomen (belly fat area). Inject into fatty tissue. Rotate injection sites daily.',
  half_life = '30-60 minutes',
  onset_weeks = 4,
  receptor_group = NULL
WHERE peptide_name = 'AOD-9604';

UPDATE peptide_protocols SET
  default_phase = 2,
  timing_notes = 'Subcutaneous injection 100-200mcg 2-3x daily or before bed. Short-acting GHRH for precise GH pulse control.',
  food_interaction = 'Fasted — 2 hours after eating; no food 30 min post-injection',
  injection_site_notes = 'Subcutaneous: abdomen. Rotate injection sites.',
  half_life = '30 minutes',
  onset_weeks = 4,
  receptor_group = 'GHRHR'
WHERE peptide_name = 'CJC-1295 (no DAC)';

UPDATE peptide_protocols SET
  default_phase = 2,
  timing_notes = 'Subcutaneous injection 1-2mg once weekly. Long-acting depot form providing sustained GH elevation. Pick a consistent day each week.',
  food_interaction = 'No food restriction for weekly dosing',
  injection_site_notes = 'Subcutaneous: abdomen or thigh. Weekly injection — rotate sites weekly.',
  half_life = '8 days',
  onset_weeks = 4,
  receptor_group = 'GHRHR'
WHERE peptide_name = 'CJC-1295 (with DAC)';

UPDATE peptide_protocols SET
  default_phase = 2,
  timing_notes = 'Subcutaneous injection 200-300mcg 2-3x daily (morning, post-workout, before bed). Fasted dosing maximizes GH response.',
  food_interaction = 'Fasted — 2 hours after meals; no food 30 min post-injection',
  injection_site_notes = 'Subcutaneous: abdomen. Rotate between multiple abdominal sites.',
  half_life = '2 hours',
  onset_weeks = 4,
  receptor_group = 'GHSR'
WHERE peptide_name = 'Ipamorelin';

UPDATE peptide_protocols SET
  default_phase = 3,
  timing_notes = 'Subcutaneous injection 100-300mcg 2-3x daily on empty stomach. Strong hunger stimulation — eat within 20 min of injection for mass-building. Most potent GH release of all secretagogues.',
  food_interaction = 'Fasted — but eat within 20 min of injection (strong appetite stimulation)',
  injection_site_notes = 'Subcutaneous: abdomen. Rotate injection sites. Expect strong hunger within 15-20 minutes.',
  half_life = '15-60 minutes',
  onset_weeks = 2,
  receptor_group = 'GHSR'
WHERE peptide_name = 'GHRP-6';

UPDATE peptide_protocols SET
  default_phase = 3,
  timing_notes = 'Subcutaneous or intramuscular injection 20-50mcg post-workout. Use only on training days. Inject into trained muscle group for localized effect. 4-6 week cycles maximum.',
  food_interaction = 'With post-workout meal — insulin co-release enhances IGF-1 uptake',
  injection_site_notes = 'Intramuscular: inject into trained muscle group for localized growth. Subcutaneous: abdomen for systemic distribution.',
  half_life = '20-30 hours (extended by LR3 modification)',
  onset_weeks = 2,
  receptor_group = 'IGF1R'
WHERE peptide_name = 'IGF-1 LR3';

UPDATE peptide_protocols SET
  default_phase = 3,
  timing_notes = 'Subcutaneous or intramuscular injection 50-100mcg pre-workout into target muscle. Very short-acting and site-specific. Use only on training days.',
  food_interaction = 'Fasted pre-workout for maximum local effect',
  injection_site_notes = 'Intramuscular: inject directly into target muscle group 15-20 min before training that muscle.',
  half_life = '20-30 minutes',
  onset_weeks = 1,
  receptor_group = 'IGF1R'
WHERE peptide_name = 'IGF-DES';

UPDATE peptide_protocols SET
  default_phase = 3,
  timing_notes = 'Intramuscular injection 100-200mcg into trained muscle immediately post-workout. Use on training days only. 4-week cycles.',
  food_interaction = 'With post-workout nutrition for anabolic environment',
  injection_site_notes = 'Intramuscular: inject into the specific muscle group just trained. Bilateral injection for symmetrical development.',
  half_life = '5-7 minutes (local effect)',
  onset_weeks = 2,
  receptor_group = 'IGF1R'
WHERE peptide_name = 'MGF';

UPDATE peptide_protocols SET
  default_phase = 2,
  timing_notes = 'Oral capsule 10-25mg daily before bed. Taken with or without food. Continuous daily dosing — no cycling needed for oral form. Can cause significant hunger in first 2-4 weeks.',
  food_interaction = 'Can be taken with or without food; some prefer with small meal to reduce hunger',
  injection_site_notes = NULL,
  half_life = '24 hours (oral bioavailability)',
  onset_weeks = 4,
  receptor_group = 'GHSR'
WHERE peptide_name = 'MK-677';

UPDATE peptide_protocols SET
  default_phase = 3,
  timing_notes = 'Oral dosing per protocol guidance. Exercise mimetic taken daily. Research compound with limited human data.',
  food_interaction = 'No established food interaction data',
  injection_site_notes = NULL,
  half_life = 'Research compound — limited PK data',
  onset_weeks = 4,
  receptor_group = NULL
WHERE peptide_name = 'SLU-PP-332';

UPDATE peptide_protocols SET
  default_phase = 2,
  timing_notes = 'Subcutaneous injection per specific analog protocol. Start low dose and titrate up weekly to minimize GI side effects. Once-weekly formulations available.',
  food_interaction = 'No food restriction for injection; take before largest meal for maximum satiety effect',
  injection_site_notes = 'Subcutaneous: abdomen, thigh, or upper arm. Rotate injection sites. For weekly formulations, choose consistent day.',
  half_life = 'Varies by analog: 12 hours (liraglutide) to 5 days (semaglutide)',
  onset_weeks = 2,
  receptor_group = 'GLP1R'
WHERE peptide_name = 'GLP-1 Agonist';

UPDATE peptide_protocols SET
  default_phase = 2,
  timing_notes = 'Subcutaneous injection once weekly. Start at lowest dose and titrate up over 4-8 weeks. Take on same day each week.',
  food_interaction = 'No food restriction',
  injection_site_notes = 'Subcutaneous: abdomen, thigh, or upper arm. Rotate sites weekly.',
  half_life = '5 days',
  onset_weeks = 4,
  receptor_group = 'CALCR/RAMP'
WHERE peptide_name = 'Cagrilintide';

UPDATE peptide_protocols SET
  default_phase = 2,
  timing_notes = 'Oral capsule 50-100mg daily. NNMT inhibitor for metabolic enhancement. Take in the morning.',
  food_interaction = 'Can be taken with or without food; morning dosing preferred',
  injection_site_notes = NULL,
  half_life = 'Research compound — limited PK data',
  onset_weeks = 4,
  receptor_group = NULL
WHERE peptide_name = '5-Amino-1MQ';

UPDATE peptide_protocols SET
  default_phase = 3,
  timing_notes = 'Subcutaneous injection 50-500mg per session. AMPK activator mimicking exercise signaling. Use on non-training days or combined with training.',
  food_interaction = 'Fasted for maximum AMPK activation; exercise enhances effects',
  injection_site_notes = 'Subcutaneous: abdomen or thigh. Use on training days for synergy with exercise.',
  half_life = '1-2 hours',
  onset_weeks = 2,
  receptor_group = NULL
WHERE peptide_name = 'AICAR';

UPDATE peptide_protocols SET
  default_phase = 1,
  timing_notes = 'Subcutaneous injection 4mg daily or every other day. Innate repair receptor agonist. Well-tolerated.',
  food_interaction = 'No food restriction',
  injection_site_notes = 'Subcutaneous: abdomen or thigh. Rotate injection sites.',
  half_life = '3-4 hours',
  onset_weeks = 4,
  receptor_group = 'EPOR/CD131'
WHERE peptide_name = 'ARA-290';

UPDATE peptide_protocols SET
  default_phase = 2,
  timing_notes = 'Subcutaneous injection 50-100mcg daily. Antimicrobial peptide for immune defense. Can also be used intranasally for upper respiratory focus.',
  food_interaction = 'No food restriction',
  injection_site_notes = 'Subcutaneous: abdomen. Intranasal: via nasal spray for respiratory immune support. Rotate subcutaneous sites.',
  half_life = '1-2 hours',
  onset_weeks = 2,
  receptor_group = NULL
WHERE peptide_name = 'LL37';

UPDATE peptide_protocols SET
  default_phase = 1,
  timing_notes = 'Subcutaneous injection 200-500mcg daily or oral capsule. Anti-inflammatory tripeptide for gut and mucosal healing. Oral bioavailability is moderate.',
  food_interaction = 'Fasted for oral form; no restriction for injection',
  injection_site_notes = 'Subcutaneous: abdomen for GI-focused effects. Can also be taken orally for direct GI mucosal exposure.',
  half_life = '1-2 hours',
  onset_weeks = 2,
  receptor_group = 'MC1R'
WHERE peptide_name = 'KPV';

UPDATE peptide_protocols SET
  default_phase = 1,
  timing_notes = 'Subcutaneous injection 50-100mcg daily or intranasal. Vasoactive intestinal peptide for immune regulation and gut-brain axis. Start low to assess tolerance.',
  food_interaction = 'Fasted — can cause temporary vasodilation and flushing',
  injection_site_notes = 'Subcutaneous: abdomen. Intranasal: 50mcg per nostril for brain/sinus effects. Monitor blood pressure initially.',
  half_life = '1-2 minutes (but biological effects persist hours)',
  onset_weeks = 4,
  receptor_group = 'VPAC1/VPAC2'
WHERE peptide_name = 'VIP';

UPDATE peptide_protocols SET
  default_phase = 3,
  timing_notes = 'Oral capsule or intranasal 10-20mg daily. Potent neurotrophic peptide. Research compound — start at lowest effective dose.',
  food_interaction = 'Can be taken with or without food',
  injection_site_notes = NULL,
  half_life = 'Research compound — limited PK data',
  onset_weeks = 4,
  receptor_group = NULL
WHERE peptide_name = 'Dihexa';

UPDATE peptide_protocols SET
  default_phase = 3,
  timing_notes = 'Intranasal spray 250-500mcg 2-3x daily. Anxiolytic and nootropic peptide. Effects felt within 15-30 minutes.',
  food_interaction = 'No food restriction for intranasal administration',
  injection_site_notes = 'Intranasal: 1-2 sprays per nostril. Best absorbed through nasal mucosa. Can also be administered subcutaneously.',
  half_life = '30-60 minutes (effects last 3-4 hours)',
  onset_weeks = 1,
  receptor_group = NULL
WHERE peptide_name = 'Selank';

UPDATE peptide_protocols SET
  default_phase = 3,
  timing_notes = 'Intranasal spray 200-600mcg 2-3x daily. Nootropic peptide derived from ACTH fragment. Cognitive effects within 30-60 minutes.',
  food_interaction = 'No food restriction for intranasal administration',
  injection_site_notes = 'Intranasal: 1-2 sprays per nostril 2-3x daily. Morning and early afternoon dosing preferred. Avoid evening dosing to prevent sleep disruption.',
  half_life = '30-60 minutes (effects last 4-6 hours)',
  onset_weeks = 1,
  receptor_group = NULL
WHERE peptide_name = 'Semax';

UPDATE peptide_protocols SET
  default_phase = 1,
  timing_notes = 'Subcutaneous or intranasal 100-300mcg before bed. Delta sleep-inducing peptide for sleep architecture improvement. Take 30-60 minutes before desired sleep.',
  food_interaction = 'Light meal or fasted; avoid heavy meals close to bedtime',
  injection_site_notes = 'Subcutaneous: abdomen. Intranasal: for faster onset. Administer 30-60 min before bed.',
  half_life = '15-25 minutes (but sleep effects last through night)',
  onset_weeks = 1,
  receptor_group = NULL
WHERE peptide_name = 'DSIP';

UPDATE peptide_protocols SET
  default_phase = 1,
  timing_notes = 'Oral or intranasal 10-20mg daily before bed. Pineal gland bioregulator for circadian rhythm normalization. Take consistently at same time nightly.',
  food_interaction = 'No food restriction; evening dosing',
  injection_site_notes = 'Oral capsule or intranasal spray. Evening administration to align with melatonin rhythm.',
  half_life = 'Short-acting peptide — effects are cumulative over weeks',
  onset_weeks = 4,
  receptor_group = NULL
WHERE peptide_name = 'Pinealon';

UPDATE peptide_protocols SET
  default_phase = 3,
  timing_notes = 'Subcutaneous injection 1-2mg daily or topical application. Copper peptide for collagen and skin regeneration. Can be cycled 8 weeks on, 4 weeks off.',
  food_interaction = 'No food restriction for injection; topical application anytime',
  injection_site_notes = 'Subcutaneous: face/neck area for skin effects, or abdomen for systemic. Topical: apply to target skin areas. Can also be used in microneedling protocols.',
  half_life = '1-2 hours (systemic effects cumulative)',
  onset_weeks = 4,
  receptor_group = NULL
WHERE peptide_name = 'GHK-Cu';

UPDATE peptide_protocols SET
  default_phase = 1,
  timing_notes = 'IV infusion 250-500mg over 2-4 hours, or subcutaneous injection 50-100mg daily. Start with lower doses to minimize flushing. Oral NMN/NR are alternative delivery routes.',
  food_interaction = 'Fasted for IV/SubQ — reduces nausea; oral NMN with food',
  injection_site_notes = 'IV: via clinic infusion. Subcutaneous: abdomen, rotating sites. Expect warmth/flushing during IV infusion.',
  half_life = '2-4 hours for NAD+ itself (but NAD+ pool effects last 24h+)',
  onset_weeks = 2,
  receptor_group = NULL
WHERE peptide_name = 'NAD+';

UPDATE peptide_protocols SET
  default_phase = 1,
  timing_notes = 'IV push 200-600mg or subcutaneous injection 200mg daily. Oral liposomal form 500mg daily as alternative. IV provides highest bioavailability.',
  food_interaction = 'Fasted for IV/SubQ; oral liposomal can be taken with or without food',
  injection_site_notes = 'IV: push or drip via clinic. Subcutaneous: abdomen, rotating sites.',
  half_life = '10-15 minutes IV clearance (but cellular glutathione pool persists hours)',
  onset_weeks = 2,
  receptor_group = NULL
WHERE peptide_name = 'Glutathione';

UPDATE peptide_protocols SET
  default_phase = 3,
  timing_notes = 'Oral 0.5-2mg/kg daily in divided doses. Mitochondrial electron carrier. Start at lowest dose. Urine will turn blue-green — this is expected.',
  food_interaction = 'With food to reduce GI irritation; avoid taking with serotonergic supplements',
  injection_site_notes = NULL,
  half_life = '5-7 hours',
  onset_weeks = 2,
  receptor_group = NULL
WHERE peptide_name = 'Methylene Blue';

UPDATE peptide_protocols SET
  default_phase = 3,
  timing_notes = 'Subcutaneous injection 10-40mg daily or per protocol. Mitochondria-targeted antioxidant peptide (elamipretide). Research compound.',
  food_interaction = 'No established food interaction',
  injection_site_notes = 'Subcutaneous: abdomen. Rotate injection sites.',
  half_life = '4 hours (but mitochondrial effects persist 24h+)',
  onset_weeks = 4,
  receptor_group = NULL
WHERE peptide_name = 'SS-31';

UPDATE peptide_protocols SET
  default_phase = 3,
  timing_notes = 'Subcutaneous injection per research protocol. Senolytic peptide targeting p53-FOXO4 interaction. Intermittent dosing (e.g., 3 days on, then 4+ weeks off) — NOT continuous.',
  food_interaction = 'No food restriction',
  injection_site_notes = 'Subcutaneous: abdomen. Intermittent pulsed dosing only — not for continuous use.',
  half_life = 'Research compound — limited PK data',
  onset_weeks = 8,
  receptor_group = NULL
WHERE peptide_name = 'FOXO4-DRI';

UPDATE peptide_protocols SET
  default_phase = 3,
  timing_notes = 'Subcutaneous or intramuscular injection 250-500 IU 2-3x per week. Maintains testicular function during TRT. Can also be used for fertility at higher doses.',
  food_interaction = 'No food restriction',
  injection_site_notes = 'Subcutaneous: abdomen. Intramuscular: deltoid or thigh. Rotate injection sites.',
  half_life = '24-36 hours',
  onset_weeks = 4,
  receptor_group = 'LHCGR'
WHERE peptide_name = 'HCG';

UPDATE peptide_protocols SET
  default_phase = 3,
  timing_notes = 'Intramuscular injection 75-150 IU every other day or per fertility protocol. Combined FSH/LH for comprehensive gonadal stimulation.',
  food_interaction = 'No food restriction',
  injection_site_notes = 'Intramuscular: deltoid or thigh. Follow fertility clinic protocol for timing and monitoring.',
  half_life = 'FSH: 36-72 hours; LH: 24 hours',
  onset_weeks = 4,
  receptor_group = 'FSHR/LHCGR'
WHERE peptide_name = 'HMG';

UPDATE peptide_protocols SET
  default_phase = 3,
  timing_notes = 'Subcutaneous injection 1-10nmol/kg as pulsed dosing. GnRH stimulator for reproductive hormone optimization. Research compound.',
  food_interaction = 'No food restriction',
  injection_site_notes = 'Subcutaneous: abdomen. Pulsed dosing protocol — not continuous.',
  half_life = '30 minutes (but GnRH effects last hours)',
  onset_weeks = 4,
  receptor_group = 'KISS1R'
WHERE peptide_name = 'Kisspeptin';

UPDATE peptide_protocols SET
  default_phase = 3,
  timing_notes = 'Subcutaneous injection per clinic protocol (typically BPC-157 + TB-500 combination). Daily or every other day dosing during recovery phase.',
  food_interaction = 'Fasted for maximum absorption of peptide components',
  injection_site_notes = 'Subcutaneous: near injury site for localized healing, or abdomen for systemic effects.',
  half_life = 'Varies by component (BPC-157: 4h, TB-500: 6-8h)',
  onset_weeks = 2,
  receptor_group = NULL
WHERE peptide_name = 'Wolverine Blend';

UPDATE peptide_protocols SET
  default_phase = 3,
  timing_notes = 'Subcutaneous injection per clinic protocol. Aesthetic peptide combination. Daily or several times per week.',
  food_interaction = 'No food restriction',
  injection_site_notes = 'Subcutaneous: abdomen for systemic, or targeted facial/neck area for localized skin effects.',
  half_life = 'Varies by component',
  onset_weeks = 4,
  receptor_group = NULL
WHERE peptide_name = 'GLOW Blend';

UPDATE peptide_protocols SET
  default_phase = 1,
  timing_notes = 'Subcutaneous injection per clinic protocol. Foundation blend for gut healing and inflammation reduction. Daily dosing during Phase 1.',
  food_interaction = 'Fasted for optimal GI peptide absorption',
  injection_site_notes = 'Subcutaneous: abdomen for GI-targeted effects.',
  half_life = 'Varies by component',
  onset_weeks = 2,
  receptor_group = NULL
WHERE peptide_name = 'KLOW Blend';

UPDATE peptide_protocols SET
  default_phase = 3,
  timing_notes = 'Intranasal spray or subcutaneous injection per clinic protocol. Nootropic peptide combination. Morning and early afternoon dosing.',
  food_interaction = 'No food restriction for intranasal; fasted for subcutaneous',
  injection_site_notes = 'Intranasal: 1-2 sprays per nostril for brain-targeted delivery. Subcutaneous: abdomen as alternative.',
  half_life = 'Varies by component (typically 1-4 hours)',
  onset_weeks = 2,
  receptor_group = NULL
WHERE peptide_name = 'Brain Blend';

UPDATE peptide_protocols SET
  default_phase = 2,
  timing_notes = 'Subcutaneous injection per clinic protocol. Metabolic optimization combination. Morning dosing preferred before exercise.',
  food_interaction = 'Fasted — inject before breakfast or exercise for maximum metabolic effect',
  injection_site_notes = 'Subcutaneous: abdomen. Morning dosing to maximize daytime lipolysis.',
  half_life = 'Varies by component',
  onset_weeks = 4,
  receptor_group = NULL
WHERE peptide_name = 'Weight Loss Blend';

-- ------------------------------------------------------------
-- EXISTING SUPPLEMENT METADATA (from seed 004)
-- ------------------------------------------------------------

UPDATE peptide_protocols SET
  default_phase = 2,
  timing_notes = '300-600mg KSM-66 extract twice daily. Take with meals. Evening dosing preferred for sleep and cortisol benefits. Allow 4-8 weeks for full adaptogenic effects.',
  food_interaction = 'With food — fat-containing meal improves withanolide absorption',
  injection_site_notes = NULL,
  half_life = '1-2 hours (acute); cumulative adaptogenic effects over 4-8 weeks',
  onset_weeks = 4,
  receptor_group = NULL
WHERE peptide_name = 'Ashwagandha';

UPDATE peptide_protocols SET
  default_phase = 2,
  timing_notes = '500mg 2-3x daily with meals. Start with 500mg once daily and increase over 2 weeks to minimize GI effects. Take at beginning of meals for glucose management.',
  food_interaction = 'With meals — reduces GI side effects and maximizes glucose-lowering effect',
  injection_site_notes = NULL,
  half_life = 'Several hours (but metabolic effects are sustained)',
  onset_weeks = 4,
  receptor_group = NULL
WHERE peptide_name = 'Berberine';

UPDATE peptide_protocols SET
  default_phase = 1,
  timing_notes = '2-4g total EPA+DHA daily with meals. Split into 2 doses. Choose high-EPA formulas for mood/inflammation or high-DHA for brain/eye health. Triglyceride form preferred.',
  food_interaction = 'With fat-containing meals — increases absorption 3-5x compared to fasted',
  injection_site_notes = NULL,
  half_life = 'EPA/DHA incorporate into cell membranes over 4-8 weeks',
  onset_weeks = 8,
  receptor_group = NULL
WHERE peptide_name = 'Omega-3 (EPA/DHA)';

UPDATE peptide_protocols SET
  default_phase = 1,
  timing_notes = '5-10g 2-3x daily on empty stomach. Dissolve powder in water. Take 30 min before meals or 2 hours after. Higher doses (20-40g/day) for IBD/gut healing protocols.',
  food_interaction = 'Fasted — take 30 minutes before meals for gut healing; or between meals',
  injection_site_notes = NULL,
  half_life = 'Rapidly absorbed — peak plasma in 30 minutes',
  onset_weeks = 2,
  receptor_group = NULL
WHERE peptide_name = 'L-Glutamine';

UPDATE peptide_protocols SET
  default_phase = 1,
  timing_notes = '500-1000mg curcumin + 5-10mg piperine twice daily with meals. Fat-containing meals increase bioavailability. Phytosome or nano forms have 30x better absorption.',
  food_interaction = 'With fat-containing meals — fat dramatically improves curcumin absorption',
  injection_site_notes = NULL,
  half_life = '6-8 hours (with piperine enhancement)',
  onset_weeks = 4,
  receptor_group = NULL
WHERE peptide_name = 'Curcumin (with Piperine)';

UPDATE peptide_protocols SET
  default_phase = 2,
  timing_notes = '2000-5000 IU daily with largest fat-containing meal. Always pair with vitamin K2 (MK-7). Test serum 25(OH)D quarterly; target 50-70 ng/mL.',
  food_interaction = 'With fat-containing meal — fat-soluble vitamin requires dietary fat for absorption',
  injection_site_notes = NULL,
  half_life = '24-48 hours (but steady-state takes 2-3 months)',
  onset_weeks = 8,
  receptor_group = NULL
WHERE peptide_name = 'Vitamin D3';

UPDATE peptide_protocols SET
  default_phase = 2,
  timing_notes = '15-30mg elemental zinc daily with food. Take separately from iron, calcium, and copper (2 hour gap). Evening dosing may support sleep and testosterone.',
  food_interaction = 'With food to minimize nausea; separate from competing minerals by 2 hours',
  injection_site_notes = NULL,
  half_life = 'Rapidly absorbed (bisglycinate form)',
  onset_weeks = 4,
  receptor_group = NULL
WHERE peptide_name = 'Zinc Bisglycinate';

UPDATE peptide_protocols SET
  default_phase = 3,
  timing_notes = '3-6g daily on empty stomach. Take 30-60 min before exercise for performance. Can split into morning and pre-workout doses. Citrulline malate form also effective.',
  food_interaction = 'Fasted — empty stomach 30-60 minutes before exercise for peak NO production',
  injection_site_notes = NULL,
  half_life = '1 hour to peak plasma citrulline; NO effects within 30-60 min',
  onset_weeks = 2,
  receptor_group = NULL
WHERE peptide_name = 'L-Citrulline';

UPDATE peptide_protocols SET
  default_phase = 1,
  timing_notes = '200-400mg elemental magnesium before bed. Glycinate form is highly bioavailable and least likely to cause GI effects. Split doses if taking 400mg+.',
  food_interaction = 'Can be taken with or without food; bedtime dosing leverages sleep-promoting effects',
  injection_site_notes = NULL,
  half_life = 'Rapid absorption (glycinate chelate form)',
  onset_weeks = 2,
  receptor_group = NULL
WHERE peptide_name = 'Magnesium Glycinate';

UPDATE peptide_protocols SET
  default_phase = 1,
  timing_notes = '600mg 2x daily on empty stomach. Take at least 30 min before meals. Pair with vitamin C to support glutathione recycling. Can cause sulfur-smelling breath initially.',
  food_interaction = 'Fasted — 30 minutes before meals for best absorption; avoid taking with meals',
  injection_site_notes = NULL,
  half_life = '5.6 hours',
  onset_weeks = 2,
  receptor_group = NULL
WHERE peptide_name = 'NAC';

UPDATE peptide_protocols SET
  default_phase = 2,
  timing_notes = '10-20g daily dissolved in liquid. Take with 500mg+ vitamin C for collagen cross-linking. Morning or post-workout timing. Hydrolyzed peptides are best absorbed.',
  food_interaction = 'Can be taken with or without food; pair with vitamin C source for enhanced collagen synthesis',
  injection_site_notes = NULL,
  half_life = 'Rapidly absorbed — peptides detected in blood within 1 hour',
  onset_weeks = 8,
  receptor_group = NULL
WHERE peptide_name = 'Collagen Peptides';

-- Total UPDATE statements: 55


-- ============================================================
-- VERIFICATION QUERIES (run after migration to confirm data)
-- ============================================================

-- Table row counts
-- SELECT 'goal_protocols' as tbl, count(*) as cnt FROM goal_protocols
-- UNION ALL SELECT 'protocol_supplements', count(*) FROM protocol_supplements
-- UNION ALL SELECT 'protocol_phases', count(*) FROM protocol_phases;

-- Coverage of all health goals (should show 25 goals)
-- SELECT goal_id, count(*) as protocol_count
-- FROM goal_protocols GROUP BY goal_id ORDER BY goal_id;

-- Supplement count by type
-- SELECT type, count(*) FROM peptide_protocols GROUP BY type;

-- Phase distribution
-- SELECT phase, phase_label, count(*) as protocol_count
-- FROM protocol_phases GROUP BY phase, phase_label ORDER BY phase;

-- Stacking coverage (protocols with supplements)
-- SELECT pp.peptide_name, count(ps.id) as supplement_count
-- FROM peptide_protocols pp
-- JOIN protocol_supplements ps ON ps.protocol_id = pp.id
-- GROUP BY pp.peptide_name ORDER BY supplement_count DESC;

-- Receptor groups for conflict detection
-- SELECT receptor_group, count(*) as protocol_count
-- FROM peptide_protocols
-- WHERE receptor_group IS NOT NULL
-- GROUP BY receptor_group ORDER BY receptor_group;

-- Protocols missing metadata (should return 0 rows)
-- SELECT peptide_name FROM peptide_protocols
-- WHERE timing_notes IS NULL AND default_phase IS NULL;
