-- ============================================================
-- 05_mart_station_global_priority.sql
-- Objectif :
-- - mesurer l’importance structurelle d’une station dans le réseau
-- - calculer un score global station réutilisable dans le score final
-- Grain :
-- - 1 ligne = 1 station
-- ============================================================

CREATE OR REPLACE TABLE `myprojet-485110.projet_bike_ny.mart_station_global_priority` AS

WITH hourly_station_events AS (
  SELECT
    station_id,
    event_date,
    trip_hour,

    SUM(nb_departures) AS nb_departures,
    SUM(nb_arrivals) AS nb_arrivals,
    SUM(total_activity) AS total_activity,
    SUM(net_flow) AS net_flow,

    ABS(SUM(net_flow)) AS abs_net_flow

  FROM (
    SELECT
      start_station_id AS station_id,
      DATE(started_at) AS event_date,
      EXTRACT(HOUR FROM started_at) AS trip_hour,

      1 AS nb_departures,
      0 AS nb_arrivals,
      1 AS total_activity,
      -1 AS net_flow

    FROM `myprojet-485110.projet_bike_ny.fct_citibike_trips`

    UNION ALL

    SELECT
      end_station_id AS station_id,
      DATE(ended_at) AS event_date,
      EXTRACT(HOUR FROM ended_at) AS trip_hour,

      0 AS nb_departures,
      1 AS nb_arrivals,
      1 AS total_activity,
      1 AS net_flow

    FROM `myprojet-485110.projet_bike_ny.fct_citibike_trips`
  )
  GROUP BY
    station_id,
    event_date,
    trip_hour
),

station_metrics AS (
  SELECT
    s.station_id,
    s.station_name,
    s.latitude,
    s.longitude,

    COUNT(DISTINCT h.event_date) AS nb_active_days,
    COUNT(h.event_date) AS nb_active_station_hours,

    COALESCE(SUM(h.nb_departures), 0) AS nb_departures,
    COALESCE(SUM(h.nb_arrivals), 0) AS nb_arrivals,
    COALESCE(SUM(h.total_activity), 0) AS total_activity,

    COALESCE(SUM(h.abs_net_flow), 0) AS total_abs_hourly_imbalance,

    COALESCE(ROUND(AVG(h.abs_net_flow), 2), 0) AS avg_hourly_abs_imbalance,

    COALESCE(
      ROUND(
        SAFE_DIVIDE(SUM(h.abs_net_flow), NULLIF(SUM(h.total_activity), 0)) * 100,
        2
      ),
      0
    ) AS imbalance_ratio_pct,

    COALESCE(
      SUM(
        CASE
          WHEN h.trip_hour BETWEEN 7 AND 10
            OR h.trip_hour BETWEEN 17 AND 20
          THEN h.total_activity
          ELSE 0
        END
      ),
      0
    ) AS peak_hour_activity,

    COALESCE(
      ROUND(
        SAFE_DIVIDE(
          SUM(
            CASE
              WHEN h.trip_hour BETWEEN 7 AND 10
                OR h.trip_hour BETWEEN 17 AND 20
              THEN h.total_activity
              ELSE 0
            END
          ),
          NULLIF(SUM(h.total_activity), 0)
        ) * 100,
        2
      ),
      0
    ) AS peak_hour_activity_share_pct

  FROM `myprojet-485110.projet_bike_ny.stg_citibike_stations` s
  LEFT JOIN hourly_station_events h
    ON s.station_id = h.station_id

  GROUP BY
    s.station_id,
    s.station_name,
    s.latitude,
    s.longitude
),

normalized AS (
  SELECT
    *,

    PERCENT_RANK() OVER (
      ORDER BY total_activity
    ) AS activity_score,

    PERCENT_RANK() OVER (
      ORDER BY avg_hourly_abs_imbalance
    ) AS imbalance_score,

    PERCENT_RANK() OVER (
      ORDER BY imbalance_ratio_pct
    ) AS relative_imbalance_score,

    PERCENT_RANK() OVER (
      ORDER BY peak_hour_activity_share_pct
    ) AS peak_hour_dependency_score

  FROM station_metrics
)

SELECT
  station_id,
  station_name,
  latitude,
  longitude,
  ST_GEOGPOINT(longitude, latitude) AS station_geography,

  nb_active_days,
  nb_active_station_hours,

  nb_departures,
  nb_arrivals,
  total_activity,

  total_abs_hourly_imbalance,
  avg_hourly_abs_imbalance,
  imbalance_ratio_pct,

  peak_hour_activity,
  peak_hour_activity_share_pct,

  ROUND(activity_score * 100, 2) AS activity_score,
  ROUND(imbalance_score * 100, 2) AS imbalance_score,
  ROUND(relative_imbalance_score * 100, 2) AS relative_imbalance_score,
  ROUND(peak_hour_dependency_score * 100, 2) AS peak_hour_dependency_score,

  ROUND(
      activity_score * 35
    + imbalance_score * 30
    + relative_imbalance_score * 20
    + peak_hour_dependency_score * 15,
    2
  ) AS global_station_priority_score,

  CASE
    WHEN ROUND(
        activity_score * 35
      + imbalance_score * 30
      + relative_imbalance_score * 20
      + peak_hour_dependency_score * 15,
      2
    ) >= 80 THEN 'critical_priority'

    WHEN ROUND(
        activity_score * 35
      + imbalance_score * 30
      + relative_imbalance_score * 20
      + peak_hour_dependency_score * 15,
      2
    ) >= 60 THEN 'high_priority'

    WHEN ROUND(
        activity_score * 35
      + imbalance_score * 30
      + relative_imbalance_score * 20
      + peak_hour_dependency_score * 15,
      2
    ) >= 40 THEN 'medium_priority'

    ELSE 'low_priority'
  END AS global_priority_level

FROM normalized;
