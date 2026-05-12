-- ============================================================
-- 03_stg_citibike_stations.sql
-- Objectif :
-- - construire un référentiel station fiable et cohérent
-- - partir des stations observées dans les trajets historiques
-- - conserver un seul enregistrement par station_id
-- Type :
-- - vue de staging
-- ============================================================

CREATE OR REPLACE VIEW `myprojet-485110.projet_bike_ny.stg_citibike_stations` AS

WITH station_candidates AS (
  SELECT
    start_station_id AS station_id,
    start_station_name AS station_name,
    start_station_latitude AS latitude,
    start_station_longitude AS longitude,
    COUNT(*) AS nb_events
  FROM `myprojet-485110.projet_bike_ny.stg_citibike_trips`
  GROUP BY
    station_id,
    station_name,
    latitude,
    longitude

  UNION ALL

  SELECT
    end_station_id AS station_id,
    end_station_name AS station_name,
    end_station_latitude AS latitude,
    end_station_longitude AS longitude,
    COUNT(*) AS nb_events
  FROM `myprojet-485110.projet_bike_ny.stg_citibike_trips`
  GROUP BY
    station_id,
    station_name,
    latitude,
    longitude
),

station_ranked AS (
  SELECT
    station_id,
    station_name,
    latitude,
    longitude,
    SUM(nb_events) AS total_events
  FROM station_candidates
  GROUP BY
    station_id,
    station_name,
    latitude,
    longitude
),

deduplicated AS (
  SELECT
    *,
    ROW_NUMBER() OVER (
      PARTITION BY station_id
      ORDER BY total_events DESC, station_name
    ) AS rn
  FROM station_ranked
)

SELECT
  station_id,
  station_name,
  latitude,
  longitude,
  ST_GEOGPOINT(longitude, latitude) AS station_geography
FROM deduplicated
WHERE rn = 1;
