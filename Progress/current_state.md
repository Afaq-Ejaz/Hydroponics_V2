# 📌 Current System State & Capabilities (Beginner Friendly Guide)

*Last Updated: 2026-09-16*

---

## 1. Executive Summary

The **HAT (Hydroponics Automation & Telemetry)** project has completed **Phases 1 through 6**. 

Our system is a **complete end-to-end IoT system**:
1. **Hardware (ESP32-S3)** collects live physical sensor data.
2. **Backend Server (FastAPI)** receives, authenticates, and validates the data.
3. **Database (Supabase PostgreSQL)** stores readings, runs watchdog checks, and emits real-time updates.

---

## 2. Complete Project File Inventory

Here is every important file in the project and what it does in plain English:

```text
c:\HAT\
├── .env                                                 # Main project environment configuration
├── Progress/
│   ├── architecture.md                                  # Diagram & technical structure of the full system
│   ├── current_state.md                                 # (This file) Current state & capabilities guide
│   ├── dot.md                                           # Milestone progress tracker & roadmap
│   └── phase7_flutter_app.md                            # Step-by-step guide for upcoming Phase 7
├── backend/
│   ├── .env                                             # Backend keys, Supabase URLs, and alert thresholds
│   ├── pyproject.toml                                   # Python project setup and dependency manager
│   ├── src/
│   │   ├── config.py                                    # Loads settings and alert limits safely
│   │   ├── database.py                                  # Connection to Supabase database
│   │   ├── main.py                                      # FastAPI server routes & background watchdog worker
│   │   ├── schemas.py                                   # Data blueprints (Pydantic models for JSON validation)
│   │   ├── security.py                                  # API key verification using SHA-256 security
│   │   └── services/
│   │       ├── alert_service.py                         # Checks if pH or Temp are out of safe range
│   │       └── watchdog_service.py                      # Detects if ESP32 hardware went offline
│   └── tests/                                           # 15 automated test files (100% passing)
├── firmware/
│   ├── platformio.ini                                   # ESP32-S3 board configuration & libraries
│   └── src/
│       └── main.cpp                                     # ESP32-S3 firmware C++ code reading physical sensors
└── supabase/
    └── migrations/                                      # SQL database migrations & view definitions
```

---

## 3. What the System Can Do Right Now

### 📡 A. ESP32-S3 Microcontroller (Hardware Layer)
- **Reads Physical Sensors**:
  - **EC (TDS)** probe on `GPIO 3` (safe ADC1 pin).
  - **Moisture** probe on `GPIO 1` (safe ADC1 pin).
  - **DHT22** Air Temperature & Humidity on `GPIO 4`.
  - **Ultrasonic HC-SR04** Water Level on `GPIO 5` & `GPIO 18`.
- **Relay Actuator**: Relay control line on `GPIO 2`.
- **Wi-Fi Connectivity**: Automatically connects to Wi-Fi (`UCP`) and reconnects if signal drops.
- **Fail-Safe Offline Buffer**: Stores up to 10 readings in internal memory if Wi-Fi or backend is unreachable, then uploads them when connection returns.
- **USB CDC Fix**: Includes DTR/RTS handling and a startup handshake to prevent serial monitor freezing.

### 🛡️ B. Security & Authentication Layer
- Every request from the ESP32 includes an `X-API-Key` header (`dev_secret_key_abc123`).
- The backend hashes this key using **SHA-256** and compares it against stored device keys in Supabase.
- If a key is invalid or a device is deactivated, the request is blocked (`401 Unauthorized` / `403 Forbidden`).

### ⚙️ C. Backend Ingestion & Alert Engine
- Receives JSON payload via `POST /ingest`.
- Saves sensor readings to the `sensor_readings` database table.
- Updates `devices.last_seen` timestamp.
- Evaluates sensor bounds:
  - **pH Limits**: $5.5$ to $6.5$ (Out of bounds triggers a `critical` alert).
  - **Water Temp Limits**: $16.0^\circ\text{C}$ to $26.0^\circ\text{C}$ (Out of bounds triggers a `warning` alert).

### 🐕 D. Device Offline Watchdog
- A background process runs every 60 seconds on the server.
- If an active ESP32 stops sending telemetry for **more than 5 minutes**, the watchdog automatically creates a `critical` "Device Offline" alert in the database.
- Smart deduplication prevents flooding the database with duplicate offline alerts.

### 📊 E. Historical Telemetry & Alert APIs
- `GET /alerts`: Allows filtering alerts by system ID, severity, or acknowledged status.
- `GET /systems/{id}/telemetry/hourly`: Uses a database SQL view (`telemetry_hourly_rollups`) to calculate hourly averages for Temperature, Humidity, Moisture, EC, and Water Level.

---

## 4. Current Hardware Sensor Pinout Table

| Sensor Probe | Function | ESP32-S3 Pin | Operational Status |
| :--- | :--- | :--- | :--- |
| **TDS / EC** | Water Nutrient Level | `GPIO 3` | ✅ **Active & Verified** (ADC1) |
| **Moisture** | Substrate Moisture | `GPIO 1` | ✅ **Active & Verified** (ADC1) |
| **DHT22** | Air Temp & Humidity | `GPIO 4` | ✅ **Active & Verified** |
| **Ultrasonic** | Water Level Height | `GPIO 5` (Trig), `GPIO 18` (Echo) | ✅ **Active & Verified** |
| **Relay** | Pump / Light Control | `GPIO 2` | ✅ **Active & Verified** |
| **pH Sensor** | Water Acidity | `GPIO 14` | ⏸️ Temporarily Excluded (ADC2 Wi-Fi conflict) |
| **Flow Sensor** | Water Flow Rate | `GPIO 19` | ⏸️ Temporarily Excluded (USB D- conflict) |

---

## 5. What Remains for Next Phase (Phase 7)

1. **Flutter Mobile & Web Client App**: Building the user-facing interface for mobile and web.
2. **Realtime Dashboard**: Live telemetry dials and online/offline status indicators.
3. **Control Panel**: Toggle relay switches remotely from the Flutter app.
