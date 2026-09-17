# 🚀 HAT Project Progress Tracker

Welcome! This document tracks the milestones, completed work, and upcoming roadmap for the **HAT (Hydroponics Automation & Telemetry)** platform in simple, easy-to-understand terms.

---

## 🚦 Phase Summary at a Glance

| Phase | What It Is | Status | Notes |
| :--- | :--- | :--- | :--- |
| **Phase 1: Database Foundation** | PostgreSQL database tables, user security rules, real-time live updates in Supabase. | ✅ **Completed** | Database is fully configured and ready. |
| **Phase 2: FastAPI Backend Service** | Python backend server (`POST /ingest`), security checks, and threshold alert calculations. | ✅ **Completed** | Receives data from ESP32, checks for safety limits. |
| **Phase 3: Automated Tests** | Automated test suite verifying backend API endpoints and safety alerts. | ✅ **Completed** | 6/6 tests passing. |
| **Phase 4: Operations & Watchdog** | Background worker that checks if ESP32 went offline, plus alert acknowledgement API. | ✅ **Completed** | 12/12 tests passing. Alerts created if hardware disconnects. |
| **Phase 5: Telemetry Aggregations** | REST APIs for filtering alerts (`GET /alerts`) and hourly averaged chart data (`GET /telemetry/hourly`). | ✅ **Completed** | 15/15 tests passing. Ready for dashboard charts! |
| **Phase 6: ESP32 Hardware Firmware** | C++ code for ESP32-S3 microchip, reading sensors and sending HTTP POST telemetry to backend. | ✅ **Completed** | **Live & Tested!** ESP32 sends real sensor readings every 30 sec. |
| **Phase 7: Client App (Flutter)** | Mobile & Web Dashboard app for real-time monitoring, push alerts, and remote relay control. | 🟡 **IN PROGRESS** | Steps 1, 2, & 3 complete! Project scaffolded, email auth working, GoRouter 5-tab shell built. |

---

## 📜 Detailed Log of What Has Been Built

### ✅ Phase 1: Database & Supabase Infrastructure
- Created database tables for **Users**, **Hydroponic Systems**, **Devices**, **Sensor Readings**, and **Alerts**.
- Added security policies (RLS) so unauthorized users cannot see or modify other users' hydroponics data.
- Enabled Supabase **Realtime** so sensor updates stream live to user screens instantly.

### ✅ Phase 2: Python Backend Service (`backend/`)
- Built a high-speed Python FastAPI backend server.
- **Security**: ESP32 authenticates using a secret API Key (`dev_secret_key_abc123`), which is safely checked using SHA-256 cryptographic hashing.
- **Alert Engine**: Automatically checks incoming readings. If pH is too high/low ($<5.5$ or $>6.5$) or water temperature is out of safe range ($<16^\circ\text{C}$ or $>26^\circ\text{C}$), it creates an alert in the database.

### ✅ Phase 3 & 4: Automated Testing & Watchdog System
- **15 Automated Tests**: Verified that ingestion, security, alert rules, status queries, and data aggregation work 100% reliably.
- **Watchdog Worker**: Runs every 60 seconds in the background. If the ESP32 stops sending data for over 5 minutes, it creates a "Device Offline" alert automatically.

### ✅ Phase 5: Querying & Hourly Chart Downsampling
- Created `GET /alerts` endpoint with pagination and filtering by system ID, severity, or acknowledged status.
- Created `GET /systems/{id}/telemetry/hourly` endpoint to return hourly average values for temperature, humidity, moisture, EC, and water level — perfect for drawing smooth historical line charts.

### ✅ Phase 6: ESP32-S3 Hardware Firmware (`firmware/`)
- **Firmware Code ([main.cpp](file:///c:/HAT/firmware/src/main.cpp))**: Written in C++ for PlatformIO on ESP32-S3.
- **Active Sensors Connected & Verified**:
  - 🧪 **EC / TDS Sensor** on `GPIO 3` (Safe ADC1 pin)
  - 💧 **Soil/Substrate Moisture Sensor** on `GPIO 1` (Safe ADC1 pin)
  - 🌡️ **DHT22 Air Temp & Humidity** on `GPIO 4`
  - 📏 **Ultrasonic HC-SR04 Water Level** on `GPIO 5` (Trig) & `GPIO 18` (Echo)
  - 🔌 **Relay Control** on `GPIO 2`
- **Smart Features Built Into Firmware**:
  - **Auto Wi-Fi Reconnect**: Keeps trying to connect to Wi-Fi (`UCP`) if disconnected.
  - **Offline Retry Buffer**: If backend is down, saves up to 10 readings in ESP32 memory and sends them automatically once reconnected.
  - **Serial Monitor USB Stability**: Includes a 5-second CDC USB handshake delay and DTR/RTS signal handling to prevent boot freezes.
- **Excluded Probes (Temporarily Held for Future Rev)**:
  - `pH Sensor` on GPIO 14 (ADC2 conflict with Wi-Fi)
  - `Flow Sensor` on GPIO 19 (USB D- pin conflict)

---

## 🔜 Phase 7: What We Are Preparing For Next

Now that the **Hardware (ESP32)**, **Database (Supabase)**, and **Backend API (FastAPI)** are all talking to each other seamlessly, the next step is **Phase 7: The Client App (Flutter)**!

**Goals for Phase 7**:
1. Initialize the Flutter cross-platform mobile & web project.
2. Build a **Real-Time Hydroponic Dashboard**:
   - Live gauge indicators for Temperature, Humidity, Moisture, EC, and Water Level.
   - Status badge showing if ESP32 is `ONLINE` or `OFFLINE`.
3. Build **Historical Charts** using `GET /systems/{id}/telemetry/hourly`.
4. Build **Alerts Drawer** to display critical warnings and allow operators to click "Acknowledge".
5. Build **Remote Relay Control** to turn pumps/lights ON or OFF from the app.
