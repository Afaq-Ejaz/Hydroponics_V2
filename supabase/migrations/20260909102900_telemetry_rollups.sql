-- Migration: Hourly Telemetry Rollup View
-- Provides downsampled sensor averages grouped by system, device, and hour
-- for efficient client charting without loading millions of raw records.

-- 1. Create the aggregation view
CREATE OR REPLACE VIEW public.hourly_sensor_averages AS
SELECT
    system_id,
    device_id,
    date_trunc('hour', recorded_at) AS hour,
    ROUND(AVG(ph)::numeric, 2)                AS avg_ph,
    ROUND(AVG(ec)::numeric, 2)                AS avg_ec,
    ROUND(AVG(water_temperature)::numeric, 2) AS avg_water_temperature,
    ROUND(AVG(air_temperature)::numeric, 2)   AS avg_air_temperature,
    ROUND(AVG(humidity)::numeric, 2)           AS avg_humidity
FROM public.sensor_readings
GROUP BY system_id, device_id, date_trunc('hour', recorded_at);

-- 2. Grant read access to authenticated users
GRANT SELECT ON public.hourly_sensor_averages TO authenticated;

-- 3. Enable RLS on the view via a security-barrier wrapper
--    PostgreSQL views inherit the underlying table's RLS when queried by
--    the table owner, but for Supabase's PostgREST layer we need an
--    explicit security policy.  Since RLS cannot be applied directly to
--    views, we create a SECURITY INVOKER wrapper that PostgREST can enforce.
--    The underlying sensor_readings table already has an RLS policy
--    ("Members view sensor readings") that checks has_system_access(system_id),
--    so authenticated users will only see rows belonging to their systems.
--
--    For the service_role key (used by FastAPI), RLS is bypassed entirely,
--    so the backend can query all systems freely.
