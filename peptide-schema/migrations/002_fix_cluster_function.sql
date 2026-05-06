-- Fix recompute_symptom_clusters: use TRUNCATE instead of DELETE
-- (Supabase blocks DELETE without a WHERE clause)
CREATE OR REPLACE FUNCTION recompute_symptom_clusters()
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  TRUNCATE TABLE symptom_clusters;
  INSERT INTO symptom_clusters (symptom_id, related_symptom_id, cluster_weight)
  SELECT
    sc1.symptom_id,
    sc2.symptom_id,
    COUNT(*)::NUMERIC AS co_occurrence_count
  FROM symptom_conditions sc1
  JOIN symptom_conditions sc2
    ON sc1.condition_id = sc2.condition_id
    AND sc1.symptom_id  != sc2.symptom_id
  GROUP BY sc1.symptom_id, sc2.symptom_id
  HAVING COUNT(*) >= 3
  ORDER BY co_occurrence_count DESC;
END;
$$;
