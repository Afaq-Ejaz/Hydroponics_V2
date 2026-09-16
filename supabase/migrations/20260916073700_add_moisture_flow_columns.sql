-- Migration: Add moisture and flow_rate columns to sensor_readings
-- and update the hourly rollup view to include them.

-- 1. Add new sensor columns
ALTER TABLE public.sensor_readings
    ADD COLUMN IF NOT EXISTS moisture   NUMERIC(5, 2),   -- soil/substrate moisture percentage
    ADD COLUMN IF NOT EXISTS flow_rate  NUMERIC(7, 2);   -- flow sensor reading in L/min

-- 2. Recreate the hourly rollup view with new columns
DROP VIEW IF EXISTS public.telemetry_hourly_rollups CASCADE;

CREATE OR REPLACE VIEW public.telemetry_hourly_rollups AS
SELECT
    system_id,
    device_id,
    date_trunc('hour', recorded_at)             AS bucket,
    ROUND(AVG(ph)::numeric, 2)                  AS avg_ph,
    ROUND(AVG(ec)::numeric, 2)                  AS avg_ec,
    ROUND(AVG(water_temperature)::numeric, 2)   AS avg_water_temp,
    ROUND(AVG(water_level)::numeric, 2)         AS avg_water_level,
    ROUND(AVG(air_temperature)::numeric, 2)     AS avg_air_temp,
    ROUND(AVG(humidity)::numeric, 2)            AS avg_humidity,
    ROUND(AVG(light_intensity)::numeric, 2)     AS avg_light_intensity,
    ROUND(AVG(moisture)::numeric, 2)            AS avg_moisture,
    ROUND(AVG(flow_rate)::numeric, 2)           AS avg_flow_rate,
    COUNT(*)::int                                AS sample_count
FROM public.sensor_readings
GROUP BY system_id, device_id, date_trunc('hour', recorded_at);

-- 3. Grant read access to the authenticated and service roles
GRANT SELECT ON public.telemetry_hourly_rollups TO authenticated;
GRANT SELECT ON public.telemetry_hourly_rollups TO service_role;
