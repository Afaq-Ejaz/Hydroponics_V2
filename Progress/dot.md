# Project Progress Tracker

This document tracks the milestones, operational progress, and implementation roadmap for the **HAT (Hydroponics Automation & Telemetry)** platform.

---

## 1. Milestones Overview

| Milestone | Description | Status |
|---|---|---|
| **Phase 1: Database & Persistence Foundation** | PostgreSQL schema, multi-tenancy, RLS policies, Realtime publication, and Supabase config. | **Completed** (Commit `0f53f97`) |
| **Phase 2: FastAPI Telemetry Ingestion Service** | Backend API, device authentication via SHA-256 keys, sensor payload schemas, and alert engine. | **Completed** |
| **Phase 3: Automated Testing & Verification** | Unit & integration tests for API endpoints, payload validation, auth guards, and alert rules. | **Completed** (6/6 Passing) |
| **Phase 4: Operations & Watchdog Subsystem** | Device health inspection (`GET /devices/{id}/status`), alert acknowledgment (`PATCH /alerts/{id}/acknowledge`), background heartbeat watchdog with deduplication, and operations test suite. | **Completed** (12/12 Passing) |
| **Phase 5: Alert Query & Telemetry Aggregations** | REST endpoints for querying active/filtered alerts (`GET /alerts`) and historical downsampled telemetry rollups. | **Next Priority** |
| **Phase 6: ESP32 Hardware Firmware** | C++/Arduino firmware for ESP32 sensor reading and HTTP telemetry dispatch. | **Planned** |
| **Phase 7: Client Application (Flutter)** | Mobile app for real-time sensor dashboards, alert push notifications, and system administration. | **Planned** |

---

## 2. Detailed Progress Log

### Phase 1: Database & Supabase Infrastructure (Completed)
- [x] Initialized Supabase project configuration for `HAT` ([config.toml](file:///c:/HAT/supabase/config.toml)).
- [x] Enabled PostgreSQL extensions (`uuid-ossp`).
- [x] Implemented core schema migration ([20260907102838_initial_schema.sql](file:///c:/HAT/supabase/migrations/20260907102838_initial_schema.sql)):
  - [x] `profiles` table synced with Supabase Auth users via trigger `on_auth_user_created`.
  - [x] `hydroponic_systems` table for physical system metadata.
  - [x] `system_members` table with `member_role` enum (`owner`, `operator`, `viewer`) for multi-tenant RBAC.
  - [x] `devices` table with SHA-256 API key hash storage, system association, and `last_seen` timestamp.
  - [x] `sensor_readings` table supporting wide-format telemetry (pH, EC, water temperature, water level, air temperature, humidity, light intensity).
  - [x] `alerts` table with `alert_severity` enum (`info`, `warning`, `critical`) and acknowledgement tracking.
- [x] Added database indexes for high-frequency queries:
  - `idx_sensor_readings_system_time` on `(system_id, recorded_at DESC)`.
  - `idx_system_members_lookup` on `(user_id, system_id)`.
  - `idx_alerts_unacknowledged` partial index on `(system_id) WHERE is_acknowledged = false`.
- [x] Configured Row-Level Security (RLS):
  - Function `public.has_system_access(system_id)` to isolate tenant access.
  - Blocked direct user inserts on `sensor_readings` (`WITH CHECK (false)`) so only the backend service can write data.
- [x] Enabled Realtime replication for `sensor_readings` and `alerts`.

### Phase 2: FastAPI Backend Ingestion Service (Completed)
- [x] Restructured project layout, migrating from placeholder root `src/` to a dedicated `backend/` application package.
- [x] Built 12-factor configuration module ([config.py](file:///c:/HAT/backend/src/config.py)) using `pydantic-settings` to load `.env` settings and alert thresholds.
- [x] Established Supabase database integration ([database.py](file:///c:/HAT/backend/src/database.py)) using `service_role` authorization for high-throughput sensor writing.
- [x] Implemented device authentication layer ([security.py](file:///c:/HAT/backend/src/security.py)):
  - Cryptographic validation of raw `X-API-Key` headers using SHA-256 digests.
  - Active device verification (`devices.is_active`).
- [x] Defined Pydantic v2 telemetry request and response schemas ([schemas.py](file:///c:/HAT/backend/src/schemas.py)):
  - Tolerant `SensorReadings` model handling optional/disconnected sensor probes.
  - Standardized JSON responses for `/health`, `/ingest`, and errors.
- [x] Developed automated alert evaluation service ([alert_service.py](file:///c:/HAT/backend/src/services/alert_service.py)):
  - Real-time pH threshold checks (triggering `critical` alerts if $< 5.5$ or $> 6.5$).
  - Water temperature checks (triggering `warning` alerts if $< 16.0^\circ\text{C}$ or $> 26.0^\circ\text{C}$).
  - Persistent insertion into Supabase `alerts` table.
- [x] Implemented FastAPI endpoints & application lifecycle ([main.py](file:///c:/HAT/backend/src/main.py)):
  - Database connectivity verification on startup `lifespan`.
  - `GET /health` liveness probe.
  - `POST /ingest` pipeline: device auth $\to$ identity cross-check $\to$ database insertion $\to$ `last_seen` update $\to$ alert evaluation $\to$ structured JSON response.

### Phase 3: Automated Testing & Verification Suite (Completed)
- [x] Configured Python package dependencies and test environment via [pyproject.toml](file:///c:/HAT/backend/pyproject.toml) and [uv.lock](file:///c:/HAT/backend/uv.lock).
- [x] Configured `pytest` runner settings (`pythonpath = ["."]`).
- [x] Developed comprehensive API test suite in [test_ingestion.py](file:///c:/HAT/backend/tests/test_ingestion.py) utilizing Starlette / FastAPI `TestClient`:
  - [x] `test_health_endpoint`: Confirmed `/health` liveness probe returns HTTP 200 with `{ "status": "ok" }`.
  - [x] `test_ingest_missing_api_key`: Confirmed requests lacking `X-API-Key` are rejected with HTTP 401.
  - [x] `test_ingest_invalid_api_key`: Confirmed forged/unregistered keys are rejected with HTTP 401.
  - [x] `test_ingest_device_id_mismatch`: Confirmed identity mismatch raises HTTP 400 Bad Request.
  - [x] `test_ingest_partial_probes_tolerated`: Confirmed sparse payloads with missing or null probes return HTTP 201 Created and `status: "accepted"`.
  - [x] `test_ingest_threshold_alert_generation`: Confirmed out-of-range sensor readings trigger real-time alert row creation in the database (`alerts_generated >= 2`).
- [x] Executed full test run via `uv run pytest`: 6/6 tests passed successfully.

### Phase 4: Operations & Watchdog Subsystem (Completed)
- [x] Extended Pydantic v2 domain models in [schemas.py](file:///c:/HAT/backend/src/schemas.py):
  - [x] `AlertAcknowledgeRequest`: Optional `acknowledged_by` (UUID) for user audit attribution.
  - [x] `AlertResponse`: Full alert schema (`id`, `system_id`, `device_id`, `severity`, `message`, `is_acknowledged`, `acknowledged_by`, `acknowledged_at`, `created_at`).
  - [x] `DeviceStatusResponse`: Extended with `name`, `is_active`, `status` (`Literal["online", "offline"]`), `last_seen`, and `minutes_since_last_seen`.
- [x] Implemented Alert Acknowledgment API in [main.py](file:///c:/HAT/backend/src/main.py):
  - [x] `PATCH /alerts/{alert_id}/acknowledge`: Validates alert existence (404 on missing), guarantees idempotency (returns existing alert if already acknowledged without overwriting timestamps), updates `is_acknowledged = True`, `acknowledged_at = UTC now`, and optional `acknowledged_by`.
- [x] Implemented Device Status Inspection API in [main.py](file:///c:/HAT/backend/src/main.py):
  - [x] `GET /devices/{device_id}/status`: Resolves device metadata, evaluates elapsed time against `DEVICE_OFFLINE_THRESHOLD_MINUTES` (5 mins), calculates `minutes_since_last_seen`, and returns strict `"online"` or `"offline"` status.
- [x] Built Device Offline Watchdog Service in [watchdog_service.py](file:///c:/HAT/backend/src/services/watchdog_service.py):
  - [x] `check_device_heartbeats() -> int`: Scans active devices (`is_active = True`), detects stale heartbeats, verifies deduplication against active unacknowledged offline alerts (`like("message", "%stopped reporting%")`), and persists critical alerts.
- [x] Integrated Asynchronous Watchdog Worker into FastAPI `lifespan` ([main.py](file:///c:/HAT/backend/src/main.py)):
  - [x] Background worker task (`asyncio.create_task`) executing every 60 seconds.
  - [x] Graceful shutdown handling on application termination via `asyncio.CancelledError`.
- [x] Developed Operations Test Suite in [test_operations.py](file:///c:/HAT/backend/tests/test_operations.py):
  - [x] `test_get_device_status_online`: Verifies online state for recently active device.
  - [x] `test_get_device_status_offline`: Verifies offline state for stale device (> 5 minutes).
  - [x] `test_get_device_status_not_found`: Confirms HTTP 404 for unknown device IDs.
  - [x] `test_acknowledge_alert_success`: Confirms status update, timestamping, and payload fidelity.
  - [x] `test_acknowledge_alert_not_found`: Confirms HTTP 404 for unknown alert IDs.
  - [x] `test_watchdog_detects_offline_device_and_deduplicates`: Confirms watchdog alert creation and immediate second-run deduplication suppression.
- [x] Executed full test suite via `uv run pytest -v`: 12/12 tests passed successfully.

---

## 3. Current Documentation References

- [architecture.md](file:///c:/HAT/Progress/architecture.md): Complete architecture specification, component breakdown, data flow, watchdog lifecycle, and test subsystem.
- [current_state.md](file:///c:/HAT/Progress/current_state.md): Deep-dive into what the program currently understands, capabilities, boundaries, and active gaps.

---

## 4. Immediate Next Steps

1. **Alert Query & Filter API**: Implement `GET /alerts` with query parameters (`system_id`, `device_id`, `is_acknowledged`, `severity`, `limit`) for client dashboards and operator workflows.
2. **Historical Telemetry Aggregation**: Implement downsampling queries/views (e.g., hourly/daily averages for pH, EC, water temperature) to support client trend graphs without loading millions of raw records.
3. **Hermetic Mock DB Isolation**: Add mock Supabase fixtures for isolated offline CI runs that do not require an active Supabase cloud instance.
4. **ESP32 Hardware Firmware**: Develop PlatformIO/Arduino C++ sketch reading physical sensors (analog pH, DS18B20 water temp, DHT22 ambient, photoresistor) and posting JSON batches with `X-API-Key`.
5. **Flutter Client Application**: Initialize mobile client with Supabase Auth, live telemetry streams via Supabase Realtime, device status badges, and alert notification/acknowledgment trays.
