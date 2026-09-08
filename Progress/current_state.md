# Where the Program Stands Right Now (System Understanding & State)

*Last Updated: 2026-09-08*

---

## 1. Executive Summary

The **HAT (Hydroponics Automation & Telemetry)** program has completed its foundational **Database Layer**, its core **Backend Telemetry Ingestion Service**, and its **Automated Test & Verification Suite**. 

The system is able to:
1. Authenticate hardware devices (ESP32) via cryptographically hashed API keys (`X-API-Key`).
2. Ingest multi-sensor hydroponic telemetry safely while tolerating missing or disconnected sensor probes.
3. Automatically update device heartbeat (`last_seen`).
4. Evaluate sensor readings in real time against biochemical thresholds (pH and water temperature) and create alerts.
5. Push persisted readings and alerts to Supabase Realtime for downstream consumers.
6. Verify all API behaviors, security boundaries, and alert pipelines via an automated test suite (`pytest` with 100% pass rate).

---

## 2. What the Program Currently Understands (Implemented Logic)

### 2.1. Telemetry Ingestion Contract
- **Payload Structure**: The program understands the incoming JSON schema defined in [schemas.py](file:///c:/HAT/backend/src/schemas.py):
  - `device_id` (string): Identifies the hardware origin (e.g. `"ESP32_01"`).
  - `timestamp` (ISO datetime): When the reading occurred. If omitted or null, the backend automatically generates a timezone-aware UTC timestamp.
  - `readings` (object): Tolerant dictionary containing any combination of:
    - `ph` (`float | None`)
    - `ec` (`float | None`)
    - `water_temperature` (`float | None`)
    - `water_level` (`float | None`)
    - `air_temperature` (`float | None`)
    - `humidity` (`float | None`)
    - `light_intensity` (`float | None`)
- **Probe Fault Tolerance**: The program understands that hardware probes fail or disconnect. If a probe reports `None`, the backend does not fail validation; it selectively persists only available sensor values.

### 2.2. Hardware Identity & Cryptographic Security
- **Pre-Shared Key (PSK) Scheme**: As implemented in [security.py](file:///c:/HAT/backend/src/security.py), the program receives an `X-API-Key` header from incoming HTTP requests.
- **SHA-256 Digest Matching**: The program understands that API keys must never be stored in plaintext. It calculates `hashlib.sha256(raw_key.encode()).hexdigest()` and checks against `devices.api_key_hash`.
- **Identity Spoofing Protection**: The program cross-verifies that the `payload.device_id` matches the device associated with the API key hash. If an authenticated device tries to push data claiming to be another device, the program rejects it with `400 Bad Request`.
- **Deactivation Control**: The program checks `devices.is_active`. If a device has been flagged as inactive in the database, it rejects requests with `403 Forbidden`.

### 2.3. Multi-Tenant Relational Data Model
- As defined in [20260907102838_initial_schema.sql](file:///c:/HAT/supabase/migrations/20260907102838_initial_schema.sql), the program understands the hierarchical relationship:
  $$\text{Auth User} \longrightarrow \text{Profile} \longrightarrow \text{System Member} \longleftrightarrow \text{Hydroponic System} \longrightarrow \text{Device} \longrightarrow \text{Readings / Alerts}$$
- **Role Permissions**: Understands three member roles: `owner`, `operator`, and `viewer`.
- **Access Guard**: Understands row-level tenant security via `public.has_system_access(system_id)`.
- **Service Worker Privilege**: Understands that sensor telemetry ingestion should bypass client Row-Level Security by using the Supabase `service_role` key in [database.py](file:///c:/HAT/backend/src/database.py).

### 2.4. Environmental Thresholds & Real-time Alerting
- As implemented in [alert_service.py](file:///c:/HAT/backend/src/services/alert_service.py) and configured in [config.py](file:///c:/HAT/backend/src/config.py):
  - **pH Limits**:
    - Nominal Range: $5.5 \le \text{pH} \le 6.5$
    - Trigger: If $\text{pH} < 5.5$ or $\text{pH} > 6.5$, a **`critical`** alert is generated with a detailed diagnosis message.
  - **Water Temperature Limits**:
    - Nominal Range: $16.0^\circ\text{C} \le \text{Temp} \le 26.0^\circ\text{C}$
    - Trigger: If $\text{Temp} > 26.0^\circ\text{C}$ or $\text{Temp} < 16.0^\circ\text{C}$, a **`warning`** alert is generated.
- **Fault Resilience**: Alert evaluation errors are caught and logged without failing the sensor ingestion transaction—ensuring sensor readings are saved even if notification dispatch encounters an issue.

### 2.5. Realtime Streaming
- The program understands that changes to `sensor_readings` and `alerts` must be streamed immediately to clients. Both tables are registered with PostgreSQL's `supabase_realtime` publication.

### 2.6. Automated Behavioral Invariants & Test Guarantees
- As implemented in [test_ingestion.py](file:///c:/HAT/backend/tests/test_ingestion.py) and configured in [pyproject.toml](file:///c:/HAT/backend/pyproject.toml):
  - **Liveness Guarantee**: `GET /health` is guaranteed to return `200 OK` with `{ "status": "ok", "timestamp": ... }`.
  - **Unauthenticated Rejection**: Ingestion requests lacking the `X-API-Key` header are rejected with `401 Unauthorized`.
  - **Forged Key Rejection**: Ingestion requests with mismatched keys are rejected with `401 Unauthorized`.
  - **Device Spoofing Rejection**: Rejects payloads where `payload.device_id` differs from the key's registered identity with `400 Bad Request`.
  - **Graceful Partial Payload Handling**: Payloads containing missing probe fields or `None` values are safely validated and accepted (`201 Created`).
  - **Threshold Breach Alert Enforcement**: When sensor values breach limits (e.g. pH 4.5 and water temp 28.0°C), the engine generates and persists the expected number of alert events (`alerts_generated >= 2`).

---

## 3. Component Responsibility Matrix

| Component | Path | Current Status | What It Does Right Now |
|---|---|---|---|
| **Database Schema** | `supabase/migrations/` | **Complete** | Defines all 6 tables, RLS policies, user trigger, and performance indexes. |
| **Supabase Config** | `supabase/config.toml` | **Complete** | Configures Auth, Realtime, Studio, API, and DB ports for local stack. |
| **Ingestion API** | `backend/src/main.py` | **Complete** | Implements `/health` and `/ingest` endpoints with database connection lifecycle. |
| **App Configuration**| `backend/src/config.py`| **Complete** | Loads environment variables and provides cached threshold settings. |
| **Database Client** | `backend/src/database.py`| **Complete** | Provides cached Supabase client with service-role permissions. |
| **Auth & Security** | `backend/src/security.py`| **Complete** | Validates `X-API-Key` using SHA-256 hashing and checks device active status. |
| **Pydantic Schemas** | `backend/src/schemas.py` | **Complete** | Validates telemetry format and structures JSON responses. |
| **Alert Engine** | `backend/src/services/alert_service.py` | **Complete** | Evaluates pH & water temperature rules and persists alerts. |
| **Automated Test Suite**| `backend/tests/test_ingestion.py` | **Complete** | Full regression test suite covering health, auth, spoofing rejection, partial payloads, and alert generation (6/6 passing). |
| **Packaging & Env** | `backend/pyproject.toml` | **Complete** | Manages dependencies (FastAPI, Supabase, pytest, httpx) and test runner settings with `uv`. |
| **Device Watchdog** | *Pending* | **Not Started** | Background task to detect devices that haven't transmitted within `DEVICE_OFFLINE_THRESHOLD_MINUTES`. |
| **Alert Management API**| *Pending* | **Not Started** | API endpoints for operators to query and acknowledge active alerts (`PATCH /alerts/{id}/ack`). |
| **Edge Firmware** | *Pending* | **Not Started** | ESP32 C++/Arduino firmware to poll sensors and submit HTTP payloads. |
| **Client UI** | *Pending* | **Not Started** | Flutter mobile dashboard for live metrics, controls, and alert acknowledgement. |

---

## 4. What the Program Does NOT Understand Yet (Current Gaps)

1. **Hardware / Edge Code**:
   - The repository contains no ESP32 firmware (no PlatformIO or Arduino sketch). The backend knows how to receive the data, but the physical transmitter code is not yet written.
2. **Offline Device Detection Worker**:
   - Although `DEVICE_OFFLINE_THRESHOLD_MINUTES: int = 5` is defined in `config.py`, there is currently no background worker or cron job checking `devices.last_seen` to emit an alert when an ESP32 drops offline.
3. **Alert Acknowledgement Endpoint**:
   - The database has `is_acknowledged`, `acknowledged_by`, and `acknowledged_at` fields, but the FastAPI backend does not yet provide an API endpoint for an operator to acknowledge an alert.
4. **Historical Telemetry Aggregation**:
   - The database stores raw snapshots. There are no rollup tables or downsampling functions (e.g. hourly/daily averages) for long-term charting.
5. **Hermetic Mock DB Isolation for Tests**:
   - The existing test suite runs against the configured database. Creating a fully mock-isolated fixture set will allow running CI tests completely offline without a live Supabase instance.
6. **Flutter Client Application**:
   - The user-facing application layer has not been scaffolded.
