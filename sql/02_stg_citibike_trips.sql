-- ============================================================
-- 02_stg_citibike_trips.sql
-- Objectif :
-- - nettoyer les trajets Citi Bike
-- - standardiser les noms de colonnes
-- - créer les dimensions temporelles
-- - exclure les durées aberrantes et les valeurs nulles critiques
-- Type :
-- - vue de staging
-- ============================================================

CREATE OR REPLACE VIEW `myprojet-485110.projet_bike_ny.stg_citibike_trips` AS

SELECT
  bikeid AS bike_id,

  starttime AS started_at,
  stoptime AS ended_at,

  DATE(starttime) AS trip_date,
  EXTRACT(YEAR FROM starttime) AS trip_year,
  EXTRACT(MONTH FROM starttime) AS trip_month,
  EXTRACT(DAYOFWEEK FROM starttime) AS day_of_week,

  CASE EXTRACT(DAYOFWEEK FROM starttime)
    WHEN 1 THEN 'Sunday'
    WHEN 2 THEN 'Monday'
    WHEN 3 THEN 'Tuesday'
    WHEN 4 THEN 'Wednesday'
    WHEN 5 THEN 'Thursday'
    WHEN 6 THEN 'Friday'
    WHEN 7 THEN 'Saturday'
  END AS day_name,

  EXTRACT(HOUR FROM starttime) AS trip_hour,

  CASE
    WHEN EXTRACT(DAYOFWEEK FROM starttime) IN (1, 7) THEN TRUE
    ELSE FALSE
  END AS is_weekend,

  CASE
    WHEN EXTRACT(HOUR FROM starttime) BETWEEN 7 AND 10
      OR EXTRACT(HOUR FROM starttime) BETWEEN 17 AND 20
    THEN TRUE
    ELSE FALSE
  END AS is_peak_hour,

  tripduration AS trip_duration_seconds,
  ROUND(tripduration / 60.0, 2) AS trip_duration_minutes,

  CAST(start_station_id AS STRING) AS start_station_id,
  start_station_name,
  start_station_latitude,
  start_station_longitude,

  CAST(end_station_id AS STRING) AS end_station_id,
  end_station_name,
  end_station_latitude,
  end_station_longitude,

  usertype AS user_type,
  birth_year,
  gender,
  customer_plan,

  CASE
    WHEN CAST(start_station_id AS STRING) = CAST(end_station_id AS STRING) THEN TRUE
    ELSE FALSE
  END AS same_start_end_station_flag

FROM `myprojet-485110.projet_bike_ny.raw_citibike_trips`

WHERE TRUE
  AND starttime IS NOT NULL
  AND stoptime IS NOT NULL
  AND start_station_id IS NOT NULL
  AND end_station_id IS NOT NULL
  AND start_station_latitude IS NOT NULL
  AND start_station_longitude IS NOT NULL
  AND end_station_latitude IS NOT NULL
  AND end_station_longitude IS NOT NULL
  AND tripduration IS NOT NULL
  AND tripduration > 0
  AND tripduration <= 86400;
