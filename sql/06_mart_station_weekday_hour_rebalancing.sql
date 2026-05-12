-- ============================================================
-- 06_mart_station_weekday_hour_rebalancing.sql
-- Objectif :
-- - analyser les flux entrants et sortants par station
-- - identifier les stations qui se vident ou se saturent
-- - permettre un dashboard filtrable par jour de semaine et heure
-- - classer les stations avec un score de priorité opérationnelle
-- Grain :
-- - 1 ligne = 1 station × 1 jour de semaine × 1 heure
-- ============================================================

CREATE OR REPLACE TABLE `myprojet-485110.projet_bike_ny.mart_station_weekday_hour_rebalancing` AS

WITH station_activity_period AS (
  SELECT
    station_id,
    MIN(event_date) AS first_active_date,
    MAX(event_date) AS last_active_date
  FROM (
    SELECT
      start_station_id AS station_id,
      DATE(started_at) AS event_date
    FROM `myprojet-485110.projet_bike_ny.fct_citibike_trips`

    UNION ALL

    SELECT
      end_station_id AS station_id,
      DATE(ended_at) AS event_date
    FROM `myprojet-485110.projet_bike_ny.fct_citibike_trips`
  )
  GROUP BY station_id
),

calendar_dates AS (
  SELECT
    calendar_date
  FROM UNNEST(
    GENERATE_DATE_ARRAY(
      (SELECT MIN(trip_date) FROM `myprojet-485110.projet_bike_ny.fct_citibike_trips`),
      (SELECT MAX(trip_date) FROM `myprojet-485110.projet_bike_ny.fct_citibike_trips`)
    )
  ) AS calendar_date
),

hours AS (
  SELECT
    hour AS trip_hour
  FROM UNNEST(GENERATE_ARRAY(0, 23)) AS hour
),

station_calendar AS (
  SELECT
    s.station_id,
    s.station_name,
    s.latitude,
    s.longitude,

    c.calendar_date,
    EXTRACT(DAYOFWEEK FROM c.calendar_date) AS day_of_week,

    CASE EXTRACT(DAYOFWEEK FROM c.calendar_date)
      WHEN 1 THEN 'Sunday'
      WHEN 2 THEN 'Monday'
      WHEN 3 THEN 'Tuesday'
      WHEN 4 THEN 'Wednesday'
      WHEN 5 THEN 'Thursday'
      WHEN 6 THEN 'Friday'
      WHEN 7 THEN 'Saturday'
    END AS day_name,

    CASE
      WHEN EXTRACT(DAYOFWEEK FROM c.calendar_date) IN (1, 7) THEN TRUE
      ELSE FALSE
    END AS is_weekend,

    h.trip_hour

  FROM `myprojet-485110.projet_bike_ny.stg_citibike_stations` s

  INNER JOIN station_activity_period p
    ON s.station_id = p.station_id

  INNER JOIN calendar_dates c
    ON c.calendar_date BETWEEN p.first_active_date AND p.last_active_date

  CROSS JOIN hours h
),

departures AS (
  SELECT
    start_station_id AS station_id,
    DATE(started_at) AS event_date,
    EXTRACT(HOUR FROM started_at) AS trip_hour,
    COUNT(*) AS nb_departures
  FROM `myprojet-485110.projet_bike_ny.fct_citibike_trips`
  GROUP BY
    station_id,
    event_date,
    trip_hour
),

arrivals AS (
  SELECT
    end_station_id AS station_id,
    DATE(ended_at) AS event_date,
    EXTRACT(HOUR FROM ended_at) AS trip_hour,
    COUNT(*) AS nb_arrivals
  FROM `myprojet-485110.projet_bike_ny.fct_citibike_trips`
  GROUP BY
    station_id,
    event_date,
    trip_hour
),

daily_station_balance AS (
  SELECT
    sc.station_id,
    sc.station_name,
    sc.latitude,
    sc.longitude,
    sc.calendar_date,
    sc.day_of_week,
    sc.day_name,
    sc.is_weekend,
    sc.trip_hour,

    COALESCE(d.nb_departures, 0) AS nb_departures,
    COALESCE(a.nb_arrivals, 0) AS nb_arrivals,

    COALESCE(d.nb_departures, 0) + COALESCE(a.nb_arrivals, 0) AS total_activity,

    COALESCE(a.nb_arrivals, 0) - COALESCE(d.nb_departures, 0) AS net_flow,

    ABS(COALESCE(a.nb_arrivals, 0) - COALESCE(d.nb_departures, 0)) AS abs_net_flow

  FROM station_calendar sc

  LEFT JOIN departures d
    ON sc.station_id = d.station_id
    AND sc.calendar_date = d.event_date
    AND sc.trip_hour = d.trip_hour

  LEFT JOIN arrivals a
    ON sc.station_id = a.station_id
    AND sc.calendar_date = a.event_date
    AND sc.trip_hour = a.trip_hour
),

weekday_hour_metrics AS (
  SELECT
    station_id,
    station_name,
    latitude,
    longitude,

    day_of_week,
    day_name,
    is_weekend,
    trip_hour,

    COUNT(*) AS nb_observed_days,
    COUNTIF(total_activity > 0) AS nb_active_occurrences,

    ROUND(AVG(nb_departures), 2) AS avg_hourly_departures,
    ROUND(AVG(nb_arrivals), 2) AS avg_hourly_arrivals,
    ROUND(AVG(total_activity), 2) AS avg_hourly_activity,

    ROUND(AVG(net_flow), 2) AS avg_hourly_net_flow,
    ROUND(AVG(abs_net_flow), 2) AS avg_hourly_abs_net_flow,

    ROUND(VARIANCE(net_flow), 2) AS variance_net_flow,
    ROUND(STDDEV(net_flow), 2) AS stddev_net_flow,

    ROUND(
      SAFE_DIVIDE(SUM(abs_net_flow), NULLIF(SUM(total_activity), 0)) * 100,
      2
    ) AS imbalance_ratio_pct,

    ROUND(
      SAFE_DIVIDE(COUNTIF(net_flow < 0), NULLIF(COUNTIF(total_activity > 0), 0)) * 100,
      2
    ) AS shortage_frequency_pct,

    ROUND(
      SAFE_DIVIDE(COUNTIF(net_flow > 0), NULLIF(COUNTIF(total_activity > 0), 0)) * 100,
      2
    ) AS saturation_frequency_pct

  FROM daily_station_balance

  GROUP BY
    station_id,
    station_name,
    latitude,
    longitude,
    day_of_week,
    day_name,
    is_weekend,
    trip_hour
),

enriched AS (
  SELECT
    m.*,

    ST_GEOGPOINT(m.longitude, m.latitude) AS station_geography,

    g.global_station_priority_score,
    g.global_priority_level,

    CASE
      WHEN m.avg_hourly_net_flow < 0 THEN 'bike_shortage_risk'
      WHEN m.avg_hourly_net_flow > 0 THEN 'dock_saturation_risk'
      ELSE 'balanced'
    END AS operational_risk_type,

    CASE
      WHEN m.avg_hourly_net_flow < 0 THEN m.shortage_frequency_pct
      WHEN m.avg_hourly_net_flow > 0 THEN m.saturation_frequency_pct
      ELSE 0
    END AS direction_consistency_pct,

    ROUND(
      SAFE_DIVIDE(ABS(m.avg_hourly_net_flow), COALESCE(m.stddev_net_flow, 0) + 1),
      4
    ) AS signal_to_noise_ratio,

    CASE
      WHEN m.avg_hourly_net_flow < 0 THEN 'Ajouter des vélos'
      WHEN m.avg_hourly_net_flow > 0 THEN 'Retirer des vélos / libérer des docks'
      ELSE 'Surveiller'
    END AS recommended_action,

    CASE
      WHEN m.trip_hour = 0 THEN '23:00-00:00'
      ELSE FORMAT('%02d:00-%02d:00', m.trip_hour - 1, m.trip_hour)
    END AS recommended_intervention_window

  FROM weekday_hour_metrics m

  LEFT JOIN `myprojet-485110.projet_bike_ny.mart_station_global_priority` g
    ON m.station_id = g.station_id
),

normalized AS (
  SELECT
    *,

    PERCENT_RANK() OVER (
      PARTITION BY day_of_week, trip_hour
      ORDER BY avg_hourly_abs_net_flow
    ) AS imbalance_score,

    PERCENT_RANK() OVER (
      PARTITION BY day_of_week, trip_hour
      ORDER BY avg_hourly_activity
    ) AS activity_score,

    PERCENT_RANK() OVER (
      PARTITION BY day_of_week, trip_hour
      ORDER BY imbalance_ratio_pct
    ) AS relative_imbalance_score,

    PERCENT_RANK() OVER (
      PARTITION BY day_of_week, trip_hour
      ORDER BY direction_consistency_pct
    ) AS consistency_score,

    PERCENT_RANK() OVER (
      PARTITION BY day_of_week, trip_hour
      ORDER BY signal_to_noise_ratio
    ) AS reliability_score

  FROM enriched
),

final AS (
  SELECT
    *,

    ROUND(
        imbalance_score * 35
      + activity_score * 20
      + relative_imbalance_score * 15
      + consistency_score * 20
      + reliability_score * 10,
      2
    ) AS day_hour_rebalancing_priority_score

  FROM normalized
)

SELECT
  station_id,
  station_name,
  latitude,
  longitude,
  station_geography,

  day_of_week,
  day_name,
  is_weekend,
  trip_hour,

  nb_observed_days,
  nb_active_occurrences,

  avg_hourly_departures,
  avg_hourly_arrivals,
  avg_hourly_activity,

  avg_hourly_net_flow,
  avg_hourly_abs_net_flow,

  variance_net_flow,
  stddev_net_flow,

  imbalance_ratio_pct,
  shortage_frequency_pct,
  saturation_frequency_pct,
  direction_consistency_pct,
  signal_to_noise_ratio,

  operational_risk_type,
  recommended_action,
  recommended_intervention_window,

  global_station_priority_score,
  global_priority_level,

  ROUND(imbalance_score * 100, 2) AS imbalance_score,
  ROUND(activity_score * 100, 2) AS activity_score,
  ROUND(relative_imbalance_score * 100, 2) AS relative_imbalance_score,
  ROUND(consistency_score * 100, 2) AS consistency_score,
  ROUND(reliability_score * 100, 2) AS reliability_score,

  day_hour_rebalancing_priority_score,

  CASE
    WHEN day_hour_rebalancing_priority_score >= 80 THEN 'critical_priority'
    WHEN day_hour_rebalancing_priority_score >= 60 THEN 'high_priority'
    WHEN day_hour_rebalancing_priority_score >= 40 THEN 'medium_priority'
    ELSE 'low_priority'
  END AS day_hour_priority_level,

  CASE
    WHEN day_hour_rebalancing_priority_score >= 80 THEN 'immediate_action'
    WHEN day_hour_rebalancing_priority_score >= 60 THEN 'high_attention'
    WHEN day_hour_rebalancing_priority_score >= 40 THEN 'moderate_attention'
    ELSE 'normal_monitoring'
  END AS operational_alert_level

FROM final;
