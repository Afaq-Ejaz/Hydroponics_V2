# Project Progress

The project has established its initial backend and database foundation for a hydroponic monitoring system.

- Created the local Supabase project configuration for `HAT`.
- Added Supabase Auth, Realtime, Studio, Storage, and local development service configuration.
- Added the initial PostgreSQL migration.
- Defined user profiles linked to Supabase Auth.
- Defined hydroponic systems, system memberships, and member roles.
- Defined ESP32 device registration with API key hash storage and activity tracking.
- Defined wide-format sensor readings for pH, EC, water conditions, air conditions, humidity, and light intensity.
- Defined alerts with severity and acknowledgement state.
- Added foreign keys, uniqueness constraints, indexes, and timestamp fields.
- Enabled row-level security and system membership access checks.
- Added policies for authorized reads and blocked direct user inserts into sensor readings.
- Enabled Realtime updates for sensor readings and alerts.
- Added automatic profile creation after user registration.
- `src/main.py` is present but has not been implemented yet.
