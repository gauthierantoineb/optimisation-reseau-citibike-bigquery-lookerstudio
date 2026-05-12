-- ============================================================
-- 07_dashboard_rebalancing_decision.sql
-- Objectif :
-- - fournir une table simple et lisible pour Looker Studio
-- - éviter les ambiguïtés de noms de stations
-- - centraliser les champs utiles au dashboard final
-- Grain :
-- - 1 ligne = 1 station × 1 jour de semaine × 1 heure
-- ============================================================

CREATE OR REPLACE TABLE `myprojet-485110.projet_bike_ny.dashboard_rebalancing_decision` AS

SELECT
  station_id,
  station_name,
  CONCAT(station_name, ' [', station_id, ']') AS station_label,

  latitude,
  longitude,
  station_geography,

  day_of_week,
  day_name,
  is_weekend,
  trip_hour,
  FORMAT('%02d:00', trip_hour) AS hour_label,

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

  CASE
    WHEN operational_risk_type = 'bike_shortage_risk' THEN 'Station qui se vide'
    WHEN operational_risk_type = 'dock_saturation_risk' THEN 'Station qui sature'
    ELSE 'Station équilibrée'
  END AS operational_risk_label,

  recommended_action,
  recommended_intervention_window,

  global_station_priority_score,
  global_priority_level,

  day_hour_rebalancing_priority_score AS priority_score,
  day_hour_priority_level AS priority_level,

  operational_alert_level,

  CASE
    WHEN day_hour_priority_level IN ('critical_priority', 'high_priority') THEN TRUE
    ELSE FALSE
  END AS is_priority_station

FROM `myprojet-485110.projet_bike_ny.mart_station_weekday_hour_rebalancing`;
