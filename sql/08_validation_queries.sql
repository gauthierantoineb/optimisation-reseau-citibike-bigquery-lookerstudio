-- ============================================================
-- 08_validation_queries.sql
-- Objectif :
-- - vérifier les tables finales
-- - valider la cohérence du pipeline
-- ============================================================

-- ------------------------------------------------------------
-- Contrôle stg_citibike_trips
-- ------------------------------------------------------------
SELECT
  COUNT(*) AS nb_trips,
  MIN(started_at) AS min_started_at,
  MAX(started_at) AS max_started_at,
  ROUND(AVG(trip_duration_minutes), 2) AS avg_trip_duration_minutes,
  COUNTIF(start_station_id IS NULL) AS missing_start_station_id,
  COUNTIF(end_station_id IS NULL) AS missing_end_station_id,
  COUNTIF(started_at IS NULL) AS missing_started_at,
  COUNTIF(ended_at IS NULL) AS missing_ended_at,
  COUNTIF(trip_duration_minutes IS NULL) AS missing_trip_duration_minutes
FROM `myprojet-485110.projet_bike_ny.stg_citibike_trips`;

-- ------------------------------------------------------------
-- Contrôle stg_citibike_stations
-- ------------------------------------------------------------
SELECT
  COUNT(*) AS nb_stations,
  COUNTIF(station_id IS NULL) AS missing_station_id,
  COUNTIF(station_name IS NULL) AS missing_station_name,
  COUNTIF(latitude IS NULL OR longitude IS NULL) AS missing_coordinates,
  COUNTIF(station_geography IS NULL) AS missing_geography
FROM `myprojet-485110.projet_bike_ny.stg_citibike_stations`;

-- ------------------------------------------------------------
-- Contrôle cohérence trips ↔ stations
-- ------------------------------------------------------------
WITH trip_stations AS (
  SELECT start_station_id AS station_id
  FROM `myprojet-485110.projet_bike_ny.stg_citibike_trips`

  UNION DISTINCT

  SELECT end_station_id AS station_id
  FROM `myprojet-485110.projet_bike_ny.stg_citibike_trips`
)
SELECT
  COUNT(*) AS nb_trip_stations,
  COUNTIF(s.station_id IS NULL) AS nb_missing_in_station_reference
FROM trip_stations t
LEFT JOIN `myprojet-485110.projet_bike_ny.stg_citibike_stations` s
  ON t.station_id = s.station_id;

-- ------------------------------------------------------------
-- Contrôle fct_citibike_trips
-- ------------------------------------------------------------
SELECT
  COUNT(*) AS nb_trips,
  MIN(started_at) AS min_started_at,
  MAX(started_at) AS max_started_at,
  ROUND(AVG(trip_duration_minutes), 2) AS avg_trip_duration_minutes,
  COUNTIF(start_station_geography IS NULL) AS missing_start_station_geography,
  COUNTIF(end_station_geography IS NULL) AS missing_end_station_geography
FROM `myprojet-485110.projet_bike_ny.fct_citibike_trips`;

-- ------------------------------------------------------------
-- Contrôle mart_station_global_priority
-- ------------------------------------------------------------
SELECT
  COUNT(*) AS nb_stations,
  MIN(global_station_priority_score) AS min_score,
  MAX(global_station_priority_score) AS max_score,
  ROUND(AVG(global_station_priority_score), 2) AS avg_score
FROM `myprojet-485110.projet_bike_ny.mart_station_global_priority`;

-- ------------------------------------------------------------
-- Top stations globalement prioritaires
-- ------------------------------------------------------------
SELECT
  station_id,
  station_name,
  total_activity,
  avg_hourly_abs_imbalance,
  imbalance_ratio_pct,
  peak_hour_activity_share_pct,
  global_station_priority_score,
  global_priority_level
FROM `myprojet-485110.projet_bike_ny.mart_station_global_priority`
ORDER BY global_station_priority_score DESC
LIMIT 20;

-- ------------------------------------------------------------
-- Contrôle mart_station_weekday_hour_rebalancing
-- ------------------------------------------------------------
SELECT
  COUNT(*) AS nb_rows,
  COUNT(DISTINCT station_id) AS nb_stations,
  COUNT(DISTINCT day_name) AS nb_days,
  COUNT(DISTINCT trip_hour) AS nb_hours,
  MIN(day_hour_rebalancing_priority_score) AS min_score,
  MAX(day_hour_rebalancing_priority_score) AS max_score
FROM `myprojet-485110.projet_bike_ny.mart_station_weekday_hour_rebalancing`;

-- ------------------------------------------------------------
-- Exemple Monday 08
-- ------------------------------------------------------------
SELECT
  day_name,
  trip_hour,
  station_name,
  avg_hourly_departures,
  avg_hourly_arrivals,
  avg_hourly_net_flow,
  avg_hourly_abs_net_flow,
  direction_consistency_pct,
  signal_to_noise_ratio,
  operational_risk_type,
  recommended_action,
  day_hour_rebalancing_priority_score,
  day_hour_priority_level
FROM `myprojet-485110.projet_bike_ny.mart_station_weekday_hour_rebalancing`
WHERE day_name = 'Monday'
  AND trip_hour = 8
ORDER BY day_hour_rebalancing_priority_score DESC
LIMIT 20;

-- ------------------------------------------------------------
-- Exemple Friday 17
-- ------------------------------------------------------------
SELECT
  day_name,
  trip_hour,
  station_name,
  avg_hourly_departures,
  avg_hourly_arrivals,
  avg_hourly_net_flow,
  avg_hourly_abs_net_flow,
  direction_consistency_pct,
  signal_to_noise_ratio,
  operational_risk_type,
  recommended_action,
  day_hour_rebalancing_priority_score,
  day_hour_priority_level
FROM `myprojet-485110.projet_bike_ny.mart_station_weekday_hour_rebalancing`
WHERE day_name = 'Friday'
  AND trip_hour = 17
ORDER BY day_hour_rebalancing_priority_score DESC
LIMIT 20;

-- ------------------------------------------------------------
-- Contrôle dashboard_rebalancing_decision
-- ------------------------------------------------------------
SELECT
  COUNT(*) AS nb_rows,
  COUNT(DISTINCT station_id) AS nb_stations,
  COUNT(DISTINCT station_label) AS nb_station_labels,
  COUNT(DISTINCT day_name) AS nb_days,
  COUNT(DISTINCT trip_hour) AS nb_hours
FROM `myprojet-485110.projet_bike_ny.dashboard_rebalancing_decision`;

-- ------------------------------------------------------------
-- Noms de station dupliqués
-- ------------------------------------------------------------
SELECT
  station_name,
  COUNT(DISTINCT station_id) AS nb_station_ids
FROM `myprojet-485110.projet_bike_ny.dashboard_rebalancing_decision`
GROUP BY station_name
HAVING COUNT(DISTINCT station_id) > 1
ORDER BY nb_station_ids DESC, station_name;

-- ------------------------------------------------------------
-- Exemple dashboard Monday 08
-- ------------------------------------------------------------
SELECT
  day_name,
  trip_hour,
  station_label,
  operational_risk_label,
  recommended_action,
  avg_hourly_net_flow,
  direction_consistency_pct,
  priority_score,
  priority_level
FROM `myprojet-485110.projet_bike_ny.dashboard_rebalancing_decision`
WHERE day_name = 'Monday'
  AND trip_hour = 8
ORDER BY priority_score DESC
LIMIT 20;
