# HAT Architecture

## Current Structure

- `src/main.py`
  - Application entry point reserved for the backend application.
  - No application logic has been implemented yet.
- `supabase/config.toml`
  - Local Supabase project configuration.
  - Project ID: `HAT`.
  - Database, Auth, Realtime, Studio, Storage, and local SMTP services are configured.
- `supabase/migrations/20260907102838_initial_schema.sql`
  - Initial PostgreSQL schema and access-control migration.

## Data Layer

Supabase PostgreSQL is the primary data store. The schema contains:

- `profiles`: User profile records linked to Supabase Auth users.
- `hydroponic_systems`: Registered hydroponic systems.
- `system_members`: User membership and system-level roles.
- `devices`: ESP32 device registration and status.
- `sensor_readings`: Timestamped hydroponic and environmental measurements.
- `alerts`: System and device alerts with acknowledgement tracking.

## Access and Security

- UUID generation is enabled through `uuid-ossp`.
- Foreign keys enforce relationships between users, systems, members, devices, readings, and alerts.
- Roles are defined as `owner`, `operator`, and `viewer`.
- Row-level security is enabled on all application tables.
- System access is checked through `public.has_system_access(system_id)`.
- Sensor readings cannot be inserted directly by users; the intended writer is the FastAPI backend.
- A database trigger creates a profile when a new Supabase Auth user is registered.

## Data Flow

1. Users authenticate through Supabase Auth.
2. Auth registration creates a corresponding row in `profiles`.
3. Users access hydroponic systems through `system_members`.
4. Registered ESP32 devices belong to a hydroponic system.
5. The planned FastAPI backend accepts device readings and writes to `sensor_readings`.
6. Authorized clients read systems, devices, readings, and alerts through Supabase.
7. Realtime is enabled for `sensor_readings` and `alerts`.

## Performance

- Sensor readings are indexed by `system_id` and descending `recorded_at`.
- Membership lookups are indexed by `user_id` and `system_id`.
- Unacknowledged alerts have a partial index by `system_id`.
