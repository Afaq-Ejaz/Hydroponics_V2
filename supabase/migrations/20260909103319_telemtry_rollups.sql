-- Hourly rollups view for historical telemetry downsampling
create or replace view public.telemetry_hourly_rollups as
select
    system_id,
    device_id,
    date_trunc('hour', recorded_at) as bucket,
    round(avg(ph)::numeric, 2) as avg_ph,
    round(avg(ec)::numeric, 2) as avg_ec,
    round(avg(water_temperature)::numeric, 2) as avg_water_temp,
    round(avg(water_level)::numeric, 2) as avg_water_level,
    round(avg(air_temperature)::numeric, 2) as avg_air_temp,
    round(avg(humidity)::numeric, 2) as avg_humidity,
    round(avg(light_intensity)::numeric, 2) as avg_light_intensity,
    count(*) as sample_count
from
    public.sensor_readings
group by
    system_id,
    device_id,
    date_trunc('hour', recorded_at);

-- Grant read access to the authenticated and service roles
grant select on public.telemetry_hourly_rollups to authenticated;
grant select on public.telemetry_hourly_rollups to service_role;