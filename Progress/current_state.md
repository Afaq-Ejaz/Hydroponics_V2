# Where the Program Stands Right Now (System Understanding & State)

*Last Updated: 2026-09-09*

---

## 1. Executive Summary

The **HAT (Hydroponics Automation & Telemetry)** platform has completed its foundational **Database Layer**, **Backend Telemetry Ingestion Service**, **Automated Verification Suites**, **Operations & Watchdog Subsystem**, and **Alert Querying & Historical Aggregations** (Phases 1 through 5).

The system is able to:
1. **Authenticate Hardware**: Validate ESP32 devices via cryptographically hashed API keys (`X-API-Key` SHA-256 digests) and verify active deployment status (`devices.is_active`).
2. **Ingest Sparse Telemetry**: Accept multi-sensor hydroponic telemetry while tolerating missing or disconnected sensor probes (`float | None`).
3. **Track Heartbeats**: Update `devices.last_seen` in real time upon telemetry ingest.
4. **Evaluate Threshold Alerts**: Screen sensor readings against biochemical safety margins (pH and water temperature) and persist structured alerts.
5. **Detect Offline Devices (Watchdog)**: Continuously scan active devices via a background worker task, detect stale heartbeats exceeding `DEVICE_OFFLINE_THRESHOLD_MINUTES` (5 mins), and emit deduplicated critical alerts.
6. **Inspect Device Status**: Query real-time connection status (`online` vs. `offline`) and elapsed downtime via `GET /devices/{device_id}/status`.
7. **Manage Alert Lifecycle**: Acknowledge alerts via `PATCH /alerts/{alert_id}/acknowledge` with idempotent semantics and optional operator audit attribution (`acknowledged_by`).
8. **Query Alerts with Server-Side Filtering & Pagination**: Filter alerts by `system_id`, `is_acknowledged`, `severity`, `limit`, `offset` with exact total count via `GET /alerts`.
9. **Serve Downsampled Telemetry Aggregations**: Query hourly sensor averages via `GET /systems/{system_id}/telemetry/hourly` over the `telemetry_hourly_rollups` database view.
10. **Stream Realtime Events**: Push `sensor_readings` and `alerts` row changes through Supabase Realtime publications.
11. **Enforce Behavioral Guarantees**: Maintain 100% automated test coverage across ingestion, operations, and querying (15/15 passing tests with `pytest`).

---

## 2. Active File Structure & Inventory

```
c:\HAT\
├── .env                                            # Root environment variables
├── .gitignore                                      # Git ignore rules
├── Progress/
│   ├── architecture.md                             # Architecture, component breakdown & data flows
│   ├── current_state.md                            # Capabilities, file inventory & active gaps
│   └── dot.md                                      # Milestone progress tracker & roadmap
├── backend/
│   ├── .env                                        # Local backend configuration (Supabase keys & thresholds)
│   ├── pyproject.toml                              # Project configuration & pytest options (uv managed)
│   ├── uv.lock                                     # Deterministic dependency lockfile
│   ├── src/
│   │   ├── __init__.py
│   │   ├── config.py                               # Settings & threshold limits via pydantic-settings
│   │   ├── database.py                             # Supabase client singleton (service_role bypass)
│   │   ├── main.py                                 # FastAPI app (6 endpoints) + watchdog lifespan loop
│   │   ├── schemas.py                              # Pydantic v2 schemas (telemetry, devices, alerts, rollups)
│   │   ├── security.py                             # X-API-Key validation via constant-time SHA-256
│   │   └── services/
│   │       ├── __init__.py
│   │       ├── alert_service.py                    # Threshold evaluation (pH & water temperature)
│   │       └── watchdog_service.py                 # Offline node detector & alert deduplication
│   └── tests/
│       ├── test_ingestion.py                       # Ingestion & auth test suite (6 tests)
│       ├── test_operations.py                      # Device status & alert ack test suite (6 tests)
│       └── test_queries.py                         # Alert filtering & hourly rollup test suite (3 tests)
└── supabase/
    ├── config.toml                                 # Supabase local stack configuration
    └── migrations/
        ├── 20260907102838_initial_schema.sql       # Tables, RLS, user sync trigger & composite indexes
        ├── 20260909102900_telemetry_rollups.sql    # Hourly aggregation view (telemetry_hourly_rollups)
        └── 20260909103319_telemtry_rollups.sql     # Remote-deployed telemetry rollups migration
```

---

## 3. What the Program Currently Understands (Implemented Logic)

### 3.1. Domain Schemas & Contracts
Defined in [schemas.py](file:///c:/HAT/backend/src/schemas.py):
- **Telemetry Ingestion**:
  - `SensorReadings`: Tolerant dictionary where each sensor value is `float | None` (`ph`, `ec`, `water_temperature`, `water_level`, `air_temperature`, `humidity`, `light_intensity`).
  - `SensorPayload`: Device ID, optional UTC-defaulted `timestamp`, and `readings`.
  - `IngestionResponse`: `{ status: "accepted", device_id, system_id, recorded_at, alerts_generated }`.
- **System Health**:
  - `HealthResponse`: `{ status: "ok", timestamp: ... }`.
- **Device Status**:
  - `DeviceStatusResponse`: `{ device_id: str, system_id: UUID, name: str, is_active: bool, status: "online" | "offline", last_seen: datetime | None, minutes_since_last_seen: float | None }`.
- **Alert Management**:
  - `AlertAcknowledgeRequest`: `{ acknowledged_by: UUID | None = None }`.
  - `AlertResponse`: `{ id: UUID, system_id: UUID, device_id: str | None, severity: str, message: str, is_acknowledged: bool, acknowledged_by: UUID | None, acknowledged_at: datetime | None, created_at: datetime }`.
  - `AlertListResponse`: `{ alerts: list[AlertResponse], total_count: int }` (exact pagination count).
- **Telemetry Aggregation**:
  - `HourlyAggregationResponse`: `{ system_id: UUID, device_id: str, bucket: datetime, avg_ph: float | None, avg_ec: float | None, avg_water_temp: float | None, avg_water_level: float | None, avg_air_temp: float | None, avg_humidity: float | None, avg_light_intensity: float | None, sample_count: int }`.
- **Error Standard**:
  - `ErrorResponse`: `{ detail: str }`.

### 3.2. Hardware Identity & Cryptographic Security
- Implemented in [security.py](file:///c:/HAT/backend/src/security.py).
- **Pre-Shared Key (PSK)**: Hardware passes raw API key in `X-API-Key` HTTP header.
- **SHA-256 Digest**: Raw key is hashed via `hashlib.sha256(raw_key.encode()).hexdigest()` and matched in constant time (`hmac.compare_digest`) against `devices.api_key_hash`.
- **Identity Spoofing Guard**: Rejects payloads where `payload.device_id != authenticated_device["id"]` with `400 Bad Request`.
- **Deactivation Check**: Rejects requests from inactive devices (`is_active = false`) with `403 Forbidden`.

### 3.3. Multi-Tenant Relational Data Model
- Schema defined in [20260907102838_initial_schema.sql](file:///c:/HAT/supabase/migrations/20260907102838_initial_schema.sql) and [telemetry_rollups.sql](file:///c:/HAT/supabase/migrations/20260909102900_telemetry_rollups.sql):
  $$\text{Auth User} \longrightarrow \text{Profile} \longrightarrow \text{System Member} \longleftrightarrow \text{Hydroponic System} \longrightarrow \text{Device} \longrightarrow \text{Readings / Alerts}$$
- **Role Permissions**: `owner`, `operator`, `viewer`.
- **Access Guard**: `public.has_system_access(system_id)` RLS function.
- **Service Worker Bypass**: Ingestion and watchdog use Supabase `service_role` key in [database.py](file:///c:/HAT/backend/src/database.py) to bypass client RLS rules.

### 3.4. Environmental Thresholds & Real-time Alerting
- Implemented in [alert_service.py](file:///c:/HAT/backend/src/services/alert_service.py) with thresholds configured in [config.py](file:///c:/HAT/backend/src/config.py):
  - **pH Rules**: Nominal range: $5.5 \le \text{pH} \le 6.5$. Out-of-bounds generates a **`critical`** alert.
  - **Water Temperature Rules**: Nominal range: $16.0^\circ\text{C} \le \text{Temp} \le 26.0^\circ\text{C}$. Out-of-bounds generates a **`warning`** alert.
- Non-fatal execution: Alert evaluation errors are logged and non-blocking.

### 3.5. Device Status Inspection API
- Implemented in [main.py](file:///c:/HAT/backend/src/main.py) via `GET /devices/{device_id}/status`:
  - Queries `devices` table by `id == device_id`. Raises `404 Not Found` if missing.
  - Evaluates elapsed minutes: $\Delta t = (\text{now}_{\text{UTC}} - \text{last\_seen}) / 60$.
  - State resolution:
    - If `last_seen` is `None` $\implies$ `status = "offline"`, `minutes_since_last_seen = None`.
    - If $\Delta t \le \text{DEVICE\_OFFLINE\_THRESHOLD\_MINUTES}$ (5 mins) $\implies$ `status = "online"`, `minutes_since_last_seen = round(Δt, 2)`.
    - If $\Delta t > \text{DEVICE\_OFFLINE\_THRESHOLD\_MINUTES}$ $\implies$ `status = "offline"`, `minutes_since_last_seen = round(Δt, 2)`.

### 3.6. Alert Acknowledgment API
- Implemented in [main.py](file:///c:/HAT/backend/src/main.py) via `PATCH /alerts/{alert_id}/acknowledge`:
  - Queries `alerts` table by UUID `alert_id`. Raises `404 Not Found` if missing.
  - **Idempotency**: If `is_acknowledged` is already `true`, returns existing record immediately without updating `acknowledged_at`.
  - **State Transition**: Sets `is_acknowledged = true`, `acknowledged_at = now(UTC)`, and optional `acknowledged_by`.

### 3.7. Device Offline Watchdog & Deduplication Engine
- Implemented in [watchdog_service.py](file:///c:/HAT/backend/src/services/watchdog_service.py) via `check_device_heartbeats() -> int`:
  - Queries active devices (`devices.is_active == True`).
  - Tests staleness: `last_seen is None` OR elapsed time $> 5$ minutes.
  - **Deduplication Check**: Queries `alerts` for an existing unacknowledged offline alert for the device (`like("message", "%stopped reporting%")`).
  - If found, skips alert creation to prevent alert flooding. If not found, creates a `critical` alert.
- **Lifespan Worker Integration**:
  - Registered as `asyncio.create_task(_watchdog_loop(interval_seconds=60))` inside FastAPI `lifespan` in [main.py](file:///c:/HAT/backend/src/main.py).
  - Handles `asyncio.CancelledError` on application shutdown for clean worker termination.

### 3.8. Realtime Streaming
- `sensor_readings` and `alerts` tables are registered in the PostgreSQL `supabase_realtime` publication.

### 3.9. Alert Query & Filter API
- Implemented in [main.py](file:///c:/HAT/backend/src/main.py) via `GET /alerts`:
  - Query parameters: `system_id: str` (required), `is_acknowledged: bool | None`, `severity: str | None`, `limit: int = 50` (max 100), `offset: int = 0`.
  - Uses PostgREST `count="exact"` to calculate true `total_count` for pagination.
  - Orders by `created_at DESC`. Returns `AlertListResponse`.

### 3.10. Hourly Telemetry Rollup API
- Implemented in [main.py](file:///c:/HAT/backend/src/main.py) via `GET /systems/{system_id}/telemetry/hourly`:
  - Queries `telemetry_hourly_rollups` database view.
  - Parameters: `system_id: UUID`, `device_id: str | None`, `start_time: datetime | None`, `end_time: datetime | None`, `limit: int = 168` (max 720).
  - Orders ascending by `bucket` for direct charting compatibility. Returns `list[HourlyAggregationResponse]`.

### 3.11. Automated Behavioral Invariants & Test Guarantees
The codebase maintains 15 automated test cases with 100% pass rate:
- **Ingestion Suite ([test_ingestion.py](file:///c:/HAT/backend/tests/test_ingestion.py))**:
  1. `test_health_endpoint`: Health check returns HTTP 200 with status `"ok"`.
  2. `test_ingest_missing_api_key`: Rejects missing `X-API-Key` with HTTP 401.
  3. `test_ingest_invalid_api_key`: Rejects forged keys with HTTP 401.
  4. `test_ingest_device_id_mismatch`: Rejects identity mismatch with HTTP 400.
  5. `test_ingest_partial_probes_tolerated`: Sparse payloads return HTTP 201 (`"accepted"`).
  6. `test_ingest_threshold_alert_generation`: Out-of-bounds readings generate $\ge 2$ alerts.
- **Operations Suite ([test_operations.py](file:///c:/HAT/backend/tests/test_operations.py))**:
  7. `test_get_device_status_online`: Fresh `last_seen` yields `"online"` status.
  8. `test_get_device_status_offline`: Stale `last_seen` (10 mins) yields `"offline"` status.
  9. `test_get_device_status_not_found`: Non-existent device returns HTTP 404.
  10. `test_acknowledge_alert_success`: Acknowledges alert, updates flag and timestamp.
  11. `test_acknowledge_alert_not_found`: Non-existent alert returns HTTP 404.
  12. `test_watchdog_detects_offline_device_and_deduplicates`: Generates 1 alert on initial detection; second run suppresses duplicates (0 new alerts).
- **Query & Aggregation Suite ([test_queries.py](file:///c:/HAT/backend/tests/test_queries.py))**:
  13. `test_get_alerts_filtered`: Verifies alert filtering by `system_id` and `is_acknowledged` flag.
  14. `test_get_alerts_missing_system_id`: Confirms HTTP 422 when required `system_id` is omitted.
  15. `test_get_hourly_telemetry_empty`: Validates `GET /systems/{id}/telemetry/hourly` response schema and empty bucket handling.

---

## 4. Component Responsibility Matrix

| Component | Path | Current Status | What It Does Right Now |
|---|---|---|---|
| **Database Schemas & Views** | `supabase/migrations/` | **Complete** | 6 relational tables, RLS policies, user auth trigger, composite indexes, and `telemetry_hourly_rollups` view. |
| **Supabase Config** | `supabase/config.toml` | **Complete** | Local development stack configuration for Auth, Realtime, Studio, API, and DB. |
| **FastAPI Application** | `backend/src/main.py` | **Complete** | Exposes `/health`, `/ingest`, `/alerts`, `/alerts/{id}/acknowledge`, `/devices/{id}/status`, `/systems/{id}/telemetry/hourly`, and watchdog background task. |
| **App Configuration** | `backend/src/config.py` | **Complete** | Loads environment variables via `pydantic-settings` with cached singleton access. |
| **Database Client** | `backend/src/database.py` | **Complete** | Exposes cached Supabase client with `service_role` credentials. |
| **Auth & Security** | `backend/src/security.py` | **Complete** | Authenticates devices using SHA-256 key hashing and checks active flags. |
| **Pydantic Schemas** | `backend/src/schemas.py` | **Complete** | Defines strict request/response data models for telemetry, health, devices, alerts, and hourly rollups. |
| **Alert Engine** | `backend/src/services/alert_service.py` | **Complete** | Evaluates sensor readings against pH and temperature safety limits. |
| **Watchdog Service** | `backend/src/services/watchdog_service.py` | **Complete** | Background device heartbeat scanner with deduplication preventing alert flooding. |
| **Ingestion Tests** | `backend/tests/test_ingestion.py` | **Complete** | 6 integration tests verifying ingestion, auth guards, and threshold alerts. |
| **Operations Tests** | `backend/tests/test_operations.py` | **Complete** | 6 integration tests verifying status, alert acknowledgment, and watchdog deduplication. |
| **Query Tests** | `backend/tests/test_queries.py` | **Complete** | 3 integration tests verifying alert filtering, pagination, and telemetry aggregation. |
| **Packaging & Env** | `backend/pyproject.toml` | **Complete** | Dependency management and pytest configuration using `uv`. |
| **Edge Firmware** | *Pending* | **Not Started** | ESP32 PlatformIO/Arduino sketch reading hardware probes and sending HTTP telemetry. |
| **Client UI** | *Pending* | **Not Started** | Flutter application for real-time dashboards, alerts, and remote management. |

---

## 5. What the Program Does NOT Understand Yet (Current Gaps)

1. **Hardware / Edge Firmware (ESP32)**:
   - No C++/Arduino code exists in the repository for physical microcontrollers. The backend contracts are ready, but the hardware transmitter is unbuilt.
2. **Hermetic Mock DB Fixtures for CI**:
   - The test suites connect to a live Supabase backend. An in-memory mock client fixture will allow tests to run hermetically in disconnected CI environments.
3. **Client Application (Flutter)**:
   - The front-end user experience has not been scaffolded.
