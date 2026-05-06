-- ============================================================
-- 023: Fix symptom_conditions using name-based lookups
-- ============================================================
-- The original seed (001_peptide_conditions.sql) used hardcoded UUIDs,
-- but production DB has different UUIDs from the HPO import (002).
-- This migration:
--   1. Inserts friendly-named symptoms missing from the HPO import
--   2. Links symptoms to conditions by name (not UUID)
-- ON CONFLICT DO NOTHING prevents duplicates.
-- ============================================================

-- Step 1: Insert missing friendly-named symptoms
INSERT INTO symptoms (name, slug, body_system, synonyms, is_active) VALUES
  ('Brain Fog', 'brain-fog', 'neurological', ARRAY['brain fog','mental fog','difficulty concentrating','cant focus','cloudy thinking'], true),
  ('Cold Intolerance', 'cold-intolerance', 'hormonal', ARRAY['always cold','sensitive to cold','cold hands','cold feet'], true),
  ('Hair Loss', 'hair-loss', 'hormonal', ARRAY['losing hair','thinning hair','alopecia','hair falling out'], true),
  ('Dry Skin / Brittle Nails', 'dry-skin', 'dermatological', ARRAY['dry skin','brittle nails','flaky skin','rough skin'], true),
  ('Low Libido', 'low-libido', 'hormonal', ARRAY['low sex drive','decreased libido','no interest in sex'], true),
  ('Reduced Muscle Mass', 'reduced-muscle-mass', 'musculoskeletal', ARRAY['losing muscle','muscle wasting','muscle atrophy'], true),
  ('Increased Body Fat', 'increased-body-fat', 'metabolic', ARRAY['belly fat','visceral fat','fat gain'], true),
  ('Night Sweats', 'night-sweats', 'hormonal', ARRAY['sweating at night','waking up sweaty','nocturnal sweating'], true),
  ('Mood Swings', 'mood-swings', 'neurological', ARRAY['irritable','irritability','mood changes','emotional'], true),
  ('Erectile Dysfunction', 'erectile-dysfunction', 'hormonal', ARRAY['ED','impotence','sexual dysfunction'], true),
  ('Poor Sleep', 'poor-sleep', 'neurological', ARRAY['insomnia','cant sleep','trouble sleeping','waking up at night'], true),
  ('Poor Recovery', 'poor-recovery', 'musculoskeletal', ARRAY['slow recovery','sore after exercise','DOMS'], true),
  ('Memory Problems', 'memory-problems', 'neurological', ARRAY['forgetful','bad memory','cant remember','memory loss'], true),
  ('Bloating / Digestive Issues', 'bloating', 'gastrointestinal', ARRAY['bloated','bloating','gassy','stomach pain','IBS'], true),
  ('Sugar Cravings', 'sugar-cravings', 'metabolic', ARRAY['craving sugar','carb cravings','sweet tooth'], true),
  ('Post-Exertional Malaise', 'post-exertional-malaise', 'neurological', ARRAY['crash after exercise','PEM','exhausted after exertion'], true),
  ('Slow Wound Healing', 'slow-wound-healing', 'general', ARRAY['wounds not healing','slow healing','chronic wounds'], true),
  ('Depression / Low Mood', 'depression-low-mood', 'neurological', ARRAY['depressed','sad','low mood','feeling down','hopeless'], true),
  ('Anxiety', 'anxiety-general', 'neurological', ARRAY['anxious','worry','nervous','panic','stress','on edge'], true)
ON CONFLICT (slug) DO NOTHING;

-- Step 2: Helper function for name-based symptom→condition linking
CREATE OR REPLACE FUNCTION _link_symptom_condition(
  _symptom_name TEXT,
  _condition_name TEXT,
  _weight NUMERIC,
  _is_primary BOOLEAN
) RETURNS VOID AS $$
DECLARE
  _sid UUID;
  _cid UUID;
BEGIN
  SELECT id INTO _sid FROM symptoms WHERE lower(name) = lower(_symptom_name) AND is_active = true LIMIT 1;
  SELECT id INTO _cid FROM conditions WHERE lower(name) = lower(_condition_name) AND is_active = true LIMIT 1;
  IF _sid IS NOT NULL AND _cid IS NOT NULL THEN
    INSERT INTO symptom_conditions (symptom_id, condition_id, weight, is_primary)
    VALUES (_sid, _cid, _weight, _is_primary)
    ON CONFLICT DO NOTHING;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- Step 3: Link symptoms to all COMMON_CONDITIONS
-- ============================================================

-- HYPOTHYROIDISM
SELECT _link_symptom_condition('Fatigue', 'Hypothyroidism', 1.5, false);
SELECT _link_symptom_condition('Cold Intolerance', 'Hypothyroidism', 2.0, true);
SELECT _link_symptom_condition('Weight Gain', 'Hypothyroidism', 1.5, false);
SELECT _link_symptom_condition('Hair Loss', 'Hypothyroidism', 1.5, false);
SELECT _link_symptom_condition('Brain Fog', 'Hypothyroidism', 1.2, false);
SELECT _link_symptom_condition('Dry Skin / Brittle Nails', 'Hypothyroidism', 1.3, false);
SELECT _link_symptom_condition('Depression / Low Mood', 'Hypothyroidism', 1.0, false);
SELECT _link_symptom_condition('Muscle Weakness', 'Hypothyroidism', 1.2, false);
SELECT _link_symptom_condition('Joint Pain', 'Hypothyroidism', 1.0, false);
SELECT _link_symptom_condition('Poor Sleep', 'Hypothyroidism', 1.0, false);

-- HYPOGONADISM (Low Testosterone)
SELECT _link_symptom_condition('Fatigue', 'Hypogonadism (Low Testosterone)', 1.2, false);
SELECT _link_symptom_condition('Low Libido', 'Hypogonadism (Low Testosterone)', 2.0, true);
SELECT _link_symptom_condition('Muscle Weakness', 'Hypogonadism (Low Testosterone)', 1.5, false);
SELECT _link_symptom_condition('Depression / Low Mood', 'Hypogonadism (Low Testosterone)', 1.2, false);
SELECT _link_symptom_condition('Reduced Muscle Mass', 'Hypogonadism (Low Testosterone)', 1.5, false);
SELECT _link_symptom_condition('Increased Body Fat', 'Hypogonadism (Low Testosterone)', 1.3, false);
SELECT _link_symptom_condition('Night Sweats', 'Hypogonadism (Low Testosterone)', 1.2, false);
SELECT _link_symptom_condition('Mood Swings', 'Hypogonadism (Low Testosterone)', 1.0, false);
SELECT _link_symptom_condition('Erectile Dysfunction', 'Hypogonadism (Low Testosterone)', 2.0, true);
SELECT _link_symptom_condition('Poor Sleep', 'Hypogonadism (Low Testosterone)', 1.0, false);

-- GROWTH HORMONE DEFICIENCY
SELECT _link_symptom_condition('Fatigue', 'Growth Hormone Deficiency', 1.5, false);
SELECT _link_symptom_condition('Reduced Muscle Mass', 'Growth Hormone Deficiency', 2.0, true);
SELECT _link_symptom_condition('Increased Body Fat', 'Growth Hormone Deficiency', 1.8, true);
SELECT _link_symptom_condition('Poor Recovery', 'Growth Hormone Deficiency', 1.5, false);
SELECT _link_symptom_condition('Poor Sleep', 'Growth Hormone Deficiency', 1.2, false);
SELECT _link_symptom_condition('Brain Fog', 'Growth Hormone Deficiency', 1.0, false);
SELECT _link_symptom_condition('Depression / Low Mood', 'Growth Hormone Deficiency', 1.0, false);
SELECT _link_symptom_condition('Muscle Weakness', 'Growth Hormone Deficiency', 1.5, false);
SELECT _link_symptom_condition('Weight Gain', 'Growth Hormone Deficiency', 1.2, false);

-- INSULIN RESISTANCE / METABOLIC SYNDROME
SELECT _link_symptom_condition('Weight Gain', 'Insulin Resistance / Metabolic Syndrome', 2.0, true);
SELECT _link_symptom_condition('Increased Body Fat', 'Insulin Resistance / Metabolic Syndrome', 2.0, true);
SELECT _link_symptom_condition('Sugar Cravings', 'Insulin Resistance / Metabolic Syndrome', 1.8, true);
SELECT _link_symptom_condition('Fatigue', 'Insulin Resistance / Metabolic Syndrome', 1.2, false);
SELECT _link_symptom_condition('Brain Fog', 'Insulin Resistance / Metabolic Syndrome', 1.0, false);
SELECT _link_symptom_condition('Poor Sleep', 'Insulin Resistance / Metabolic Syndrome', 1.0, false);
SELECT _link_symptom_condition('Anxiety', 'Insulin Resistance / Metabolic Syndrome', 0.8, false);

-- CHRONIC FATIGUE SYNDROME
SELECT _link_symptom_condition('Fatigue', 'Chronic Fatigue Syndrome', 2.0, true);
SELECT _link_symptom_condition('Post-Exertional Malaise', 'Chronic Fatigue Syndrome', 2.0, true);
SELECT _link_symptom_condition('Brain Fog', 'Chronic Fatigue Syndrome', 1.5, false);
SELECT _link_symptom_condition('Poor Sleep', 'Chronic Fatigue Syndrome', 1.5, false);
SELECT _link_symptom_condition('Memory Problems', 'Chronic Fatigue Syndrome', 1.2, false);
SELECT _link_symptom_condition('Joint Pain', 'Chronic Fatigue Syndrome', 1.0, false);
SELECT _link_symptom_condition('Depression / Low Mood', 'Chronic Fatigue Syndrome', 1.0, false);

-- GUT DYSBIOSIS / LEAKY GUT
SELECT _link_symptom_condition('Bloating / Digestive Issues', 'Gut Dysbiosis / Leaky Gut', 2.0, true);
SELECT _link_symptom_condition('Fatigue', 'Gut Dysbiosis / Leaky Gut', 1.0, false);
SELECT _link_symptom_condition('Brain Fog', 'Gut Dysbiosis / Leaky Gut', 1.0, false);
SELECT _link_symptom_condition('Anxiety', 'Gut Dysbiosis / Leaky Gut', 1.0, false);
SELECT _link_symptom_condition('Night Sweats', 'Gut Dysbiosis / Leaky Gut', 0.8, false);
SELECT _link_symptom_condition('Weight Gain', 'Gut Dysbiosis / Leaky Gut', 0.8, false);

-- ANXIETY / HPA DYSREGULATION
SELECT _link_symptom_condition('Anxiety', 'Anxiety / HPA Dysregulation', 2.0, true);
SELECT _link_symptom_condition('Poor Sleep', 'Anxiety / HPA Dysregulation', 1.5, false);
SELECT _link_symptom_condition('Mood Swings', 'Anxiety / HPA Dysregulation', 1.5, false);
SELECT _link_symptom_condition('Fatigue', 'Anxiety / HPA Dysregulation', 1.0, false);
SELECT _link_symptom_condition('Night Sweats', 'Anxiety / HPA Dysregulation', 1.2, false);
SELECT _link_symptom_condition('Brain Fog', 'Anxiety / HPA Dysregulation', 1.0, false);

-- DEPRESSION / LOW MOOD
SELECT _link_symptom_condition('Depression / Low Mood', 'Depression / Low Mood', 2.0, true);
SELECT _link_symptom_condition('Fatigue', 'Depression / Low Mood', 1.5, false);
SELECT _link_symptom_condition('Poor Sleep', 'Depression / Low Mood', 1.5, false);
SELECT _link_symptom_condition('Brain Fog', 'Depression / Low Mood', 1.2, false);
SELECT _link_symptom_condition('Memory Problems', 'Depression / Low Mood', 1.2, false);
SELECT _link_symptom_condition('Low Libido', 'Depression / Low Mood', 1.0, false);
SELECT _link_symptom_condition('Weight Gain', 'Depression / Low Mood', 0.8, false);

-- SLEEP DISORDER / DISRUPTED CIRCADIAN RHYTHM
SELECT _link_symptom_condition('Poor Sleep', 'Sleep Disorder / Disrupted Circadian Rhythm', 2.0, true);
SELECT _link_symptom_condition('Fatigue', 'Sleep Disorder / Disrupted Circadian Rhythm', 1.5, false);
SELECT _link_symptom_condition('Brain Fog', 'Sleep Disorder / Disrupted Circadian Rhythm', 1.2, false);
SELECT _link_symptom_condition('Night Sweats', 'Sleep Disorder / Disrupted Circadian Rhythm', 1.5, false);
SELECT _link_symptom_condition('Anxiety', 'Sleep Disorder / Disrupted Circadian Rhythm', 1.0, false);
SELECT _link_symptom_condition('Depression / Low Mood', 'Sleep Disorder / Disrupted Circadian Rhythm', 1.0, false);

-- CHRONIC INFLAMMATION / AUTOIMMUNE REACTIVITY
SELECT _link_symptom_condition('Joint Pain', 'Chronic Inflammation / Autoimmune Reactivity', 1.5, false);
SELECT _link_symptom_condition('Fatigue', 'Chronic Inflammation / Autoimmune Reactivity', 1.2, false);
SELECT _link_symptom_condition('Bloating / Digestive Issues', 'Chronic Inflammation / Autoimmune Reactivity', 1.2, false);
SELECT _link_symptom_condition('Brain Fog', 'Chronic Inflammation / Autoimmune Reactivity', 1.0, false);
SELECT _link_symptom_condition('Poor Recovery', 'Chronic Inflammation / Autoimmune Reactivity', 1.2, false);
SELECT _link_symptom_condition('Slow Wound Healing', 'Chronic Inflammation / Autoimmune Reactivity', 1.5, false);

-- POOR WOUND HEALING / TISSUE REPAIR DEFICIT
SELECT _link_symptom_condition('Slow Wound Healing', 'Poor Wound Healing / Tissue Repair Deficit', 2.0, true);
SELECT _link_symptom_condition('Poor Recovery', 'Poor Wound Healing / Tissue Repair Deficit', 1.5, false);
SELECT _link_symptom_condition('Joint Pain', 'Poor Wound Healing / Tissue Repair Deficit', 1.2, false);
SELECT _link_symptom_condition('Fatigue', 'Poor Wound Healing / Tissue Repair Deficit', 1.0, false);

-- SARCOPENIA (MUSCLE LOSS)
SELECT _link_symptom_condition('Reduced Muscle Mass', 'Sarcopenia (Muscle Loss)', 2.0, true);
SELECT _link_symptom_condition('Muscle Weakness', 'Sarcopenia (Muscle Loss)', 1.8, true);
SELECT _link_symptom_condition('Poor Recovery', 'Sarcopenia (Muscle Loss)', 1.5, false);
SELECT _link_symptom_condition('Fatigue', 'Sarcopenia (Muscle Loss)', 1.0, false);
SELECT _link_symptom_condition('Increased Body Fat', 'Sarcopenia (Muscle Loss)', 1.2, false);

-- Cleanup: drop the helper function
DROP FUNCTION _link_symptom_condition;
