# Where the Program Stands Right Now (System Understanding & State)

*Last Updated: 2026-09-09*

---

## 1. Executive Summary

The **HAT (Hydroponics Automation & Telemetry)** platform has completed its foundational **Database Layer**, **Backend Telemetry Ingestion Service**, **Automated Verification Suites**, and its **Operations & Watchdog Subsystem** (Phases 1 through 4).

The system is able to:
1. **Authenticate Hardware**: Validate ESP32 devices via cryptographically hashed API keys (`X-API-Key` SHA-256 digests) and verify active deployment status (`devices.is_active`).
2. **Ingest Sparse Telemetry**: Accept multi-sensor hydroponic telemetry while tolerating missing or disconnected sensor probes (`float | None`).
3. **Track Heartbeats**: Update `devices.last_seen` in real time upon telemetry ingest.
4. **Evaluate Threshold Alerts**: Screen sensor readings against biochemical safety margins (pH and water temperature) and persist structured alerts.
5. **Detect Offline Devices (Watchdog)**: Continuously scan active devices via a background worker task, detect stale heartbeats exceeding `DEVICE_OFFLINE_THRESHOLD_MINUTES` (5 mins), and emit deduplicated critical alerts.
6. **Inspect Device Status**: Query real-time connection status (`online` vs. `offline`) and elapsed downtime via `GET /devices/{device_id}/status`.
7. **Manage Alert Lifecycle**: Acknowledge alerts via `PATCH /alerts/{alert_id}/acknowledge` with idempotent semantics and optional operator audit attribution (`acknowledged_by`).
8. **Stream Realtime Events**: Push `sensor_readings` and `alerts` row changes through Supabase Realtime publications.
9. **Enforce Behavioral Guarantees**: Maintain 100% automated test coverage across ingestion and operations (12/12 passing tests with `pytest`).

---

## 2. What the Program Currently Understands (Implemented Logic)

### 2.1. Domain Schemas & Contracts
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
- **Error Standard**:
  - `ErrorResponse`: `{ detail: str }`.

### 2.2. Hardware Identity & Cryptographic Security
- Implemented in [security.py](file:///c:/HAT/backend/src/security.py).
- **Pre-Shared Key (PSK)**: Hardware passes raw API key in `X-API-Key` HTTP header.
- **SHA-256 Digest**: Raw key is hashed via `hashlib.sha256(raw_key.encode()).hexdigest()` and matched in constant time (`hmac.compare_digest`) against `devices.api_key_hash`.
- **Identity Spoofing Guard**: Rejects payloads where `payload.device_id != authenticated_device["id"]` with `400 Bad Request`.
- **Deactivation Check**: Rejects requests from inactive devices (`is_active = false`) with `403 Forbidden`.

### 2.3. Multi-Tenant Relational Data Model
- Schema defined in [20260907102838_initial_schema.sql](file:///c:/HAT/supabase/migrations/20260907102838_initial_schema.sql):
  $$\text{Auth User} \longrightarrow \text{Profile} \longrightarrow \text{System Member} \longleftrightarrow \text{Hydroponic System} \longrightarrow \text{Device} \longrightarrow \text{Readings / Alerts}$$
- **Role Permissions**: `owner`, `operator`, `viewer`.
- **Access Guard**: `public.has_system_access(system_id)` RLS function.
- **Service Worker Bypass**: Ingestion and watchdog use Supabase `service_role` key in [database.py](file:///c:/HAT/backend/src/database.py) to bypass client RLS rules.

### 2.4. Environmental Thresholds & Real-time Alerting
- Implemented in [alert_service.py](file:///c:/HAT/backend/src/services/alert_service.py) with thresholds configured in [config.py](file:///c:/HAT/backend/src/config.py):
  - **pH Rules**:
    - Nominal range: $5.5 \le \text{pH} \le 6.5$.
    - Breach: Below 5.5 or above 6.5 generates a **`critical`** alert.
  - **Water Temperature Rules**:
    - Nominal range: $16.0^\circ\text{C} \le \text{Temp} \le 26.0^\circ\text{C}$.
    - Breach: Above 26.0°C or below 16.0°C generates a **`warning`** alert.
- Non-fatal execution: Alert evaluation errors are caught and logged without aborting sensor telemetry storage.

### 2.5. Device Status Inspection API
- Implemented in [main.py](file:///c:/HAT/backend/src/main.py) via `GET /devices/{device_id}/status`:
  - Queries `devices` table by `id == device_id`. Raises `404 Not Found` if missing.
  - Evaluates elapsed minutes: $\Delta t = (\text{now}_{\text{UTC}} - \text{last\_seen}) / 60$.
  - State resolution:
    - If `last_seen` is `None` $\implies$ `status = "offline"`, `minutes_since_last_seen = None`.
    - If $\Delta t \le \text{DEVICE\_OFFLINE\_THRESHOLD\_MINUTES}$ (5 mins) $\implies$ `status = "online"`, `minutes_since_last_seen = round(Δt, 2)`.
    - If $\Delta t > \text{DEVICE\_OFFLINE\_THRESHOLD\_MINUTES}$ $\implies$ `status = "offline"`, `minutes_since_last_seen = round(Δt, 2)`.

### 2.6. Alert Acknowledgment API
- Implemented in [main.py](file:///c:/HAT/backend/src/main.py) via `PATCH /alerts/{alert_id}/acknowledge`:
  - Queries `alerts` table by UUID `alert_id`. Raises `404 Not Found` (`"Alert not found"`) if missing.
  - **Idempotency**: If `is_acknowledged` is already `true`, returns existing record immediately without updating `acknowledged_at`.
  - **State Transition**: Sets `is_acknowledged = true`, `acknowledged_at = datetime.now(timezone.utc).isoformat()`, and optionally sets `acknowledged_by = body.acknowledged_by`.

### 2.7. Device Offline Watchdog & Deduplication Engine
- Implemented in [watchdog_service.py](file:///c:/HAT/backend/src/services/watchdog_service.py) via `check_device_heartbeats() -> int`:
  - Queries all active devices: `devices.is_active == True`.
  - Tests staleness: `last_seen is None` OR elapsed time $> 5$ minutes.
  - **Deduplication Check**: Queries `alerts` for an existing unacknowledged offline alert for the device:
    `eq("device_id", id).eq("is_acknowledged", False).like("message", "%stopped reporting%")`.
  - If found, skips alert creation to prevent alert flooding.
  - If not found, creates a `critical` alert:
    `"Device '{name}' ({id}) has stopped reporting. Last seen: {last_seen or 'never'}."`
  - Returns count of newly created alerts.
- **Lifespan Worker Integration**:
  - Registered as `asyncio.create_task(_watchdog_loop(interval_seconds=60))` inside FastAPI `lifespan` in [main.py](file:///c:/HAT/backend/src/main.py).
  - Handles `asyncio.CancelledError` on application shutdown for clean worker termination.

### 2.8. Realtime Streaming
- `sensor_readings` and `alerts` tables are registered in the PostgreSQL `supabase_realtime` publication.

### 2.9. Automated Behavioral Invariants & Test Guarantees
The codebase maintains 12 automated test cases with 100% pass rate:
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

---

## 3. Component Responsibility Matrix

| Component | Path | Current Status | What It Does Right Now |
|---|---|---|---|
| **Database Schema** | `supabase/migrations/` | **Complete** | Defines 6 relational tables, RLS policies, user auth trigger, and composite indexes. |
| **Supabase Config** | `supabase/config.toml` | **Complete** | Local development stack configuration for Auth, Realtime, Studio, API, and DB. |
| **FastAPI Core & Router** | `backend/src/main.py` | **Complete** | Exposes `/health`, `/ingest`, `/alerts/{id}/acknowledge`, `/devices/{id}/status`, and runs watchdog lifespan worker. |
| **App Configuration** | `backend/src/config.py` | **Complete** | Loads environment variables via `pydantic-settings` with cached singleton access. |
| **Database Client** | `backend/src/database.py` | **Complete** | Exposes cached Supabase client with `service_role` credentials. |
| **Auth & Security** | `backend/src/security.py` | **Complete** | Authenticates devices using SHA-256 key hashing and checks active flags. |
| **Pydantic Schemas** | `backend/src/schemas.py` | **Complete** | Defines strict request/response data models for telemetry, health, devices, and alerts. |
| **Alert Engine** | `backend/src/services/alert_service.py` | **Complete** | Evaluates sensor readings against pH and temperature safety limits. |
| **Watchdog Service** | `backend/src/services/watchdog_service.py` | **Complete** | Background device heartbeat scanner with deduplication preventing alert flooding. |
| **Ingestion Tests** | `backend/tests/test_ingestion.py` | **Complete** | 6 integration tests verifying ingestion, auth guards, and threshold alerts. |
| **Operations Tests** | `backend/tests/test_operations.py` | **Complete** | 6 integration tests verifying status, alert acknowledgment, and watchdog deduplication. |
| **Packaging & Env** | `backend/pyproject.toml` | **Complete** | Dependency management and pytest configuration using `uv`. |
| **Alert Query API** | *Pending* | **Not Started** | REST endpoint to list and filter alerts (`GET /alerts?system_id=...&is_acknowledged=...`). |
| **Historical Aggregations** | *Pending* | **Not Started** | Database views / downsampling functions for long-term telemetry charting. |
| **Edge Firmware** | *Pending* | **Not Started** | ESP32 PlatformIO/Arduino sketch reading hardware probes and sending HTTP telemetry. |
| **Client UI** | *Pending* | **Not Started** | Flutter application for real-time dashboards, alerts, and remote management. |

---

## 4. What the Program Does NOT Understand Yet (Current Gaps)

1. **Alert Listing & Querying Endpoint**:
   - The program can acknowledge specific alerts (`PATCH /alerts/{id}/acknowledge`), but does not yet provide a `GET /alerts` endpoint to list, paginate, or filter active alerts by system, device, or severity.
2. **Historical Telemetry Aggregation & Rollups**:
   - Telemetry is stored as raw snapshots in `sensor_readings`. There are no downsampled aggregation tables (e.g., hourly/daily averages) for efficient client graph rendering.
3. **Hardware / Edge Firmware**:
   - No C++/Arduino code exists in the repository for physical microcontrollers. The backend contracts are ready, but the hardware transmitter is unbuilt.
4. **Hermetic Mock DB Fixtures for CI**:
   - The test suites connect to a live Supabase backend. An in-memory mock client fixture will allow tests to run hermetically in disconnected CI environments.
5. **Client Application (Flutter)**:
   - The front-end user experience has not been scaffolded.
