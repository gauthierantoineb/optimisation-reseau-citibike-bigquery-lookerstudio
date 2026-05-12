-- ============================================================
-- 01_raw_checks.sql
-- Objectif :
-- - vérifier rapidement les tables brutes
-- - contrôler la période couverte
-- - contrôler les valeurs manquantes critiques
-- ============================================================

-- ------------------------------------------------------------
-- Contrôle raw_citibike_trips
-- ------------------------------------------------------------
SELECT
  COUNT(*) AS nb_rows,
  MIN(starttime) AS min_starttime,
  MAX(starttime) AS max_starttime,
  MIN(stoptime) AS min_stoptime,
  MAX(stoptime) AS max_stoptime,
  COUNTIF(starttime IS NULL) AS nb_missing_starttime,
  COUNTIF(stoptime IS NULL) AS nb_missing_stoptime,
  COUNTIF(start_station_id IS NULL) AS nb_missing_start_station_id,
  COUNTIF(end_station_id IS NULL) AS nb_missing_end_station_id,
  COUNTIF(tripduration IS NULL) AS nb_missing_tripduration,
  COUNTIF(tripduration <= 0) AS nb_invalid_duration,
  COUNTIF(tripduration > 86400) AS nb_duration_over_24h
FROM `myprojet-485110.projet_bike_ny.raw_citibike_trips`;

-- ------------------------------------------------------------
-- Contrôle raw_citibike_stations
-- ------------------------------------------------------------
SELECT
  COUNT(*) AS nb_rows,
  COUNTIF(station_id IS NULL) AS nb_missing_station_id,
  COUNTIF(name IS NULL) AS nb_missing_station_name,
  COUNTIF(latitude IS NULL OR longitude IS NULL) AS nb_missing_coordinates,
  COUNTIF(capacity IS NULL) AS nb_missing_capacity,
  MIN(last_reported) AS min_last_reported,
  MAX(last_reported) AS max_last_reported
FROM `myprojet-485110.projet_bike_ny.raw_citibike_stations`;
