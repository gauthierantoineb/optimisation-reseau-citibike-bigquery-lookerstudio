-- ============================================================
-- 04_fct_citibike_trips.sql
-- Objectif :
-- - créer la table de faits centrale des trajets Citi Bike
-- - enrichir les trajets avec les géographies de départ et d’arrivée
-- - fournir une base unique pour les marts
-- Type :
-- - table de faits
-- ============================================================

CREATE OR REPLACE TABLE `myprojet-485110.projet_bike_ny.fct_citibike_trips` AS

SELECT
  bike_id,

  started_at,
  ended_at,
  trip_date,
  trip_year,
  trip_month,
  EXTRACT(DAY FROM trip_date) AS trip_day,
  day_of_week,
  day_name,
  trip_hour,
  is_weekend,
  is_peak_hour,

  trip_duration_seconds,
  trip_duration_minutes,

  start_station_id,
  start_station_name,
  start_station_latitude,
  start_station_longitude,
  ST_GEOGPOINT(start_station_longitude, start_station_latitude) AS start_station_geography,

  end_station_id,
  end_station_name,
  end_station_latitude,
  end_station_longitude,
  ST_GEOGPOINT(end_station_longitude, end_station_latitude) AS end_station_geography,

  user_type,
  birth_year,
  gender,
  customer_plan,

  same_start_end_station_flag

FROM `myprojet-485110.projet_bike_ny.stg_citibike_trips`;
