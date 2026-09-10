-- Migration: Hourly Telemetry Rollup View
-- Provides downsampled sensor averages grouped by system, device, and hour
-- for efficient client charting without loading millions of raw records.

-- Drop the old view name if it exists (from a prior migration attempt)
DROP VIEW IF EXISTS public.hourly_sensor_averages;

-- 1. Create the aggregation view
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
    COUNT(*)::int                                AS sample_count
FROM public.sensor_readings
GROUP BY system_id, device_id, date_trunc('hour', recorded_at);

-- 2. Grant read access to authenticated users
GRANT SELECT ON public.telemetry_hourly_rollups TO authenticated;

-- 3. RLS note:
--    The underlying sensor_readings table already has an RLS policy
--    ("Members view sensor readings") that checks has_system_access(system_id),
--    so authenticated users will only see rows belonging to their systems.
--    For the service_role key (used by FastAPI), RLS is bypassed entirely.
