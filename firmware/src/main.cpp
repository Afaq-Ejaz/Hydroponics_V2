/*
 * ═══════════════════════════════════════════════════════════════════════
 *  HAT — Hydroponics Automation Telemetry
 *  ESP32-S3 Sensor Firmware  (main.cpp)
 * ═══════════════════════════════════════════════════════════════════════
 *
 *  Board  : ESP32-S3 DevKitC-1
 *  Backend: FastAPI /ingest endpoint (HTTP POST with X-API-Key)
 *
 *  Pin Map (revised — all analog sensors moved to ADC1):
 *  ┌────────────────────┬──────────┬──────────────────────────────────┐
 *  │ Sensor             │ GPIO     │ Notes                            │
 *  ├────────────────────┼──────────┼──────────────────────────────────┤
 *  │ pH Sensor (Analog) │ GPIO  6  │ ✅ ADC1 — safe with WiFi active  │
 *  │ TDS / EC (Analog)  │ GPIO  3  │ ✅ ADC1 — safe                   │
 *  │ Moisture (Analog)  │ GPIO  1  │ ✅ ADC1 — safe                   │
 *  │ DHT22   (Digital)  │ GPIO  4  │ ✅ air temp + humidity           │
 *  │ Ultrasonic Trig    │ GPIO  5  │ ✅                               │
 *  │ Ultrasonic Echo    │ GPIO 18  │ ✅                               │
 *  │ Flow Sensor (Dig.) │ GPIO 19  │ ✅ Interrupt — pulse counting    │
 *  │ Relay   (Output)   │ GPIO  2  │ ✅ Remote-controlled from app    │
 *  └────────────────────┴──────────┴──────────────────────────────────┘
 *
 *  GPIO 19 NOTE:
 *    GPIO 19 is the ESP32-S3's USB D- pin. With CDC_ON_BOOT=0 set in
 *    platformio.ini, the native USB peripheral is fully disabled and
 *    GPIO 19 works as a normal digital input. Serial goes through UART.
 *    ⚠ Do NOT plug a USB cable into the native USB port while the flow
 *    sensor is connected — use only the UART/COM USB port.
 *
 *  RELAY NOTE:
 *    The relay is controlled remotely from the Flutter app via the
 *    backend. Each loop cycle, the ESP32 polls GET /relay-command to
 *    check if the user toggled the pump on/off.
 */

#include <Arduino.h>
#include <ArduinoJson.h>
#include <DHT.h>
#include <HTTPClient.h>
#include <WiFi.h>

// ═══════════════════════════════════════════════════════════════════════
//  CONFIGURATION — Edit these values for your setup
// ═══════════════════════════════════════════════════════════════════════

// ── Wi-Fi ──────────────────────────────────────────────────────────────
const char *WIFI_SSID = "UCP";
const char *WIFI_PASSWORD = "Ucp@987987";

// ── Backend API ────────────────────────────────────────────────────────
const char *BACKEND_URL = "http://10.9.26.152:8000/ingest";
const char *API_KEY = "dev_secret_key_abc123";
const char *DEVICE_ID = "ESP32_01";

// ── Timing ─────────────────────────────────────────────────────────────
const unsigned long SEND_INTERVAL_MS = 30000; // 30 seconds between readings

// ── Pin Definitions ────────────────────────────────────────────────────
// Analog sensors — ALL must stay on ADC1 (GPIO 1-10) since WiFi is active
#define PIN_TDS 3      // ✅ ADC1
#define PIN_MOISTURE 1 // ✅ ADC1
#define PIN_PH 6       // ✅ ADC1 (moved from GPIO 14 / ADC2 — see header note)

// ── pH Calibration ─────────────────────────────────────────────────────
// These are PLACEHOLDERS. To calibrate properly:
//   1. Rinse the probe, dip it in pH 7.0 buffer solution, let it settle
//      (~30-60s), read the printed "Probe voltage" from Serial Monitor,
//      and set PH_NEUTRAL_VOLTAGE to that value.
//   2. Repeat in pH 4.0 buffer, note the voltage (V4).
//   3. Slope (pH per volt) = (7.0 - 4.0) / (PH_NEUTRAL_VOLTAGE - V4)
//      Set PH_SLOPE to that computed value (sign should stay positive
//      here since lower voltage = more basic in this probe's wiring).
const float PH_NEUTRAL_VOLTAGE = 2.50; // Voltage at pH 7.0 — CALIBRATE ME
const float PH_SLOPE = 3.50;           // pH per volt — CALIBRATE ME

// Digital sensors
#define PIN_DHT 4   // DHT22 data pin
#define PIN_TRIG 5  // Ultrasonic HC-SR04 trigger
#define PIN_ECHO 18 // Ultrasonic HC-SR04 echo
#define PIN_FLOW 19 // Flow sensor pulse output (YF-S201 or similar)

// Actuators
#define PIN_RELAY 2 // Relay control (active HIGH) — remote via app

// ── Flow Sensor Configuration ──────────────────────────────────────────
// Calibration factor: pulses per litre (YF-S201 = 450 pulses/L,
// which is 7.5 pulses per second per L/min)
const float FLOW_CALIBRATION = 7.5; // pulses per second per L/min

// ISR-safe pulse counter (volatile because modified inside interrupt)
volatile unsigned long flowPulseCount = 0;
unsigned long lastFlowReadTime = 0;

// Interrupt Service Routine — increments on every rising edge
void IRAM_ATTR flowPulseISR() {
  flowPulseCount++;
}

// ── Relay Polling URL ──────────────────────────────────────────────────
// The ESP32 polls this endpoint every cycle to check if the user
// toggled the pump on/off from the Flutter app.
String RELAY_POLL_URL = String("http://10.9.26.152:8000/devices/") + DEVICE_ID + "/relay-command";

// ── Auto-Pump Configuration ────────────────────────────────────────────
// The pump can be triggered automatically by TWO conditions:
//   1. TIMER: Every 120 minutes, pump runs for AUTO_PUMP_DURATION_MS
//   2. MOISTURE: When soil moisture drops below the threshold
// Manual control from the app always takes priority (override).

const unsigned long AUTO_PUMP_INTERVAL_MS  = 120UL * 60UL * 1000UL; // 120 minutes
const unsigned long AUTO_PUMP_DURATION_MS  = 45UL * 1000UL;         // run pump for 45 seconds
const unsigned long AUTO_PUMP_COOLDOWN_MS  = 5UL * 60UL * 1000UL;   // 5-min cooldown between auto runs
const float         MOISTURE_LOW_THRESHOLD = 30.0;                   // below 30% = soil too dry → pump ON

// Auto-pump state
bool          autoPumpActive    = false;   // is an auto-pump cycle currently running?
unsigned long autoPumpStartTime = 0;       // when did the current auto-pump cycle start?
unsigned long lastAutoPumpEnd   = 0;       // when did the last auto-pump cycle finish?
bool          manualOverride    = false;   // true when user manually controls from app
String        autoPumpReason    = "";      // "TIMER" or "MOISTURE" (for Serial logging)

// ── DHT Setup ──────────────────────────────────────────────────────────
#define DHT_TYPE DHT22
DHT dht(PIN_DHT, DHT_TYPE);

// ── Retry Buffer ───────────────────────────────────────────────────────
// If the backend is unreachable, we buffer up to MAX_BUFFER readings and
// retry them on the next successful connection.
#define MAX_BUFFER 10
String retryBuffer[MAX_BUFFER];
int bufferHead = 0;
int bufferCount = 0;

// ── Timing State ───────────────────────────────────────────────────────
unsigned long lastSendTime = 0;
bool currentRelayState = false; // tracks what the relay is currently set to

// ═══════════════════════════════════════════════════════════════════════
//  SENSOR READ FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════

float lastPHVoltage = 0.0;

/**
 * Read pH sensor (analog, ADC1 pin — safe alongside WiFi).
 * Takes 10 samples and averages them for clean noise rejection.
 * Returns pH value constrained to 0.0 - 14.0.
 */
float readPH() {
  long sum = 0;
  for (int i = 0; i < 10; i++) {
    sum += analogRead(PIN_PH);
    delay(10);
  }
  float avgRaw = sum / 10.0;
  float voltage = avgRaw * (3.3 / 4095.0);
  lastPHVoltage = voltage;

  // Standard pH formula: pH = 7.0 + ((V_neutral - V) * slope)
  float ph = 7.0 + ((PH_NEUTRAL_VOLTAGE - voltage) * PH_SLOPE);
  ph = constrain(ph, 0.0, 14.0);
  return ph;
}

/**
 * Read TDS/EC sensor (analog).
 * Returns EC in mS/cm (approximate).
 */
float readEC() {
  int raw = analogRead(PIN_TDS);
  float voltage = raw * (3.3 / 4095.0);
  // TDS module typically outputs 0-2.3V for 0-1000 ppm
  // Convert to approximate EC: EC (mS/cm) ≈ TDS (ppm) / 500
  float tds_ppm = (voltage / 2.3) * 1000.0;
  float ec = tds_ppm / 500.0;
  return ec;
}

/**
 * Read moisture sensor (analog).
 * Returns percentage (0% = dry, 100% = wet).
 * Inverted because most capacitive sensors output HIGH when dry.
 */
float readMoisture() {
  int raw = analogRead(PIN_MOISTURE);
  // Typical capacitive sensor: ~3000 = dry, ~1000 = wet (adjust for yours)
  float pct = map(raw, 3000, 1000, 0, 100);
  pct = constrain(pct, 0.0, 100.0);
  return pct;
}

/**
 * Read ultrasonic HC-SR04 distance (cm).
 * Used as water level measurement.
 */
float readWaterLevel() {
  // Send trigger pulse
  digitalWrite(PIN_TRIG, LOW);
  delayMicroseconds(2);
  digitalWrite(PIN_TRIG, HIGH);
  delayMicroseconds(10);
  digitalWrite(PIN_TRIG, LOW);

  // Measure echo duration (timeout 30ms ≈ ~500cm max)
  long duration = pulseIn(PIN_ECHO, HIGH, 30000);

  if (duration == 0) {
    // Timeout — sensor not responding or out of range
    return -1.0;
  }

  // Speed of sound ≈ 0.034 cm/µs, divide by 2 for round-trip
  float distance_cm = (duration * 0.034) / 2.0;
  return distance_cm;
}

/**
 * Read flow sensor rate (L/min).
 * Uses interrupt-counted pulses since last call.
 * Formula: flowRate = (pulseCount / calibrationFactor) / elapsedSeconds
 */
float readFlowRate() {
  // Atomically read and reset the pulse counter
  noInterrupts();
  unsigned long pulses = flowPulseCount;
  flowPulseCount = 0;
  interrupts();

  unsigned long now = millis();
  float elapsedSec = (now - lastFlowReadTime) / 1000.0;
  lastFlowReadTime = now;

  if (elapsedSec <= 0) return 0.0;

  // flowRate (L/min) = frequency (Hz) / calibration factor
  float frequency = pulses / elapsedSec;
  float flowRate = frequency / FLOW_CALIBRATION;
  return flowRate;
}

/**
 * Poll the backend for the desired relay state (manual control from app).
 * If the user manually toggles ON/OFF from the app, it sets manualOverride
 * which takes priority over auto-pump logic.
 */
void pollRelayCommand() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[Relay] Wi-Fi not connected — keeping current state.");
    return;
  }

  HTTPClient http;
  http.begin(RELAY_POLL_URL);
  http.setTimeout(5000);

  int httpCode = http.GET();

  if (httpCode == 200) {
    String body = http.getString();
    JsonDocument doc;
    DeserializationError err = deserializeJson(doc, body);

    if (!err && doc.containsKey("relay_on")) {
      bool desired = doc["relay_on"].as<bool>();

      if (desired) {
        // User manually turned pump ON from app → override auto-pump
        manualOverride = true;
        if (!currentRelayState) {
          currentRelayState = true;
          digitalWrite(PIN_RELAY, HIGH);
          Serial.println("[Relay] ⚡ MANUAL ON from app");
        } else {
          Serial.println("[Relay] Manual: ON (no change)");
        }
      } else {
        // User turned pump OFF from app
        if (manualOverride) {
          // User explicitly turned off → stop any auto-pump too
          manualOverride = false;
          autoPumpActive = false;
        }
        if (!autoPumpActive && currentRelayState) {
          // Only turn off if no auto-pump is running
          currentRelayState = false;
          digitalWrite(PIN_RELAY, LOW);
          Serial.println("[Relay] ⚡ MANUAL OFF from app");
        } else if (autoPumpActive) {
          Serial.println("[Relay] App says OFF but auto-pump is running — staying ON");
        } else {
          Serial.println("[Relay] Polled: OFF (no change)");
        }
      }
    } else {
      Serial.println("[Relay] ⚠ Failed to parse relay command JSON.");
    }
  } else {
    Serial.printf("[Relay] ⚠ Poll failed (HTTP %d) — keeping %s\n",
                  httpCode, currentRelayState ? "ON" : "OFF");
  }

  http.end();
}

/**
 * Check if the pump should auto-start based on:
 *   1. TIMER — every 120 minutes
 *   2. MOISTURE — soil moisture below threshold
 *
 * Auto-pump runs for AUTO_PUMP_DURATION_MS then turns off.
 * Manual app control (manualOverride) always takes priority.
 *
 * @param moisture  Current soil moisture percentage (0-100)
 */
void checkAutoPump(float moisture) {
  unsigned long now = millis();

  // ── If manual override is active, skip all auto logic ──────────
  if (manualOverride) {
    Serial.println("[AutoPump] Skipped — manual override active");
    return;
  }

  // ── If auto-pump is currently running, check if duration elapsed ─
  if (autoPumpActive) {
    if (now - autoPumpStartTime >= AUTO_PUMP_DURATION_MS) {
      // Auto-pump duration finished → turn off
      autoPumpActive = false;
      currentRelayState = false;
      lastAutoPumpEnd = now;
      digitalWrite(PIN_RELAY, LOW);
      Serial.printf("[AutoPump] ✅ Finished (%s cycle) — pump OFF\n",
                    autoPumpReason.c_str());
    } else {
      unsigned long remaining = (AUTO_PUMP_DURATION_MS - (now - autoPumpStartTime)) / 1000;
      Serial.printf("[AutoPump] Running (%s) — %lu seconds remaining\n",
                    autoPumpReason.c_str(), remaining);
    }
    return;
  }

  // ── Cooldown check — don't re-trigger too soon ─────────────────
  if (lastAutoPumpEnd > 0 && (now - lastAutoPumpEnd < AUTO_PUMP_COOLDOWN_MS)) {
    unsigned long cooldownLeft = (AUTO_PUMP_COOLDOWN_MS - (now - lastAutoPumpEnd)) / 1000;
    Serial.printf("[AutoPump] Cooldown — %lu seconds until next auto-pump allowed\n",
                  cooldownLeft);
    return;
  }

  // ── Condition 1: TIMER — every 120 minutes ─────────────────────
  // On first boot, lastAutoPumpEnd == 0, so the timer starts from boot
  bool timerTrigger = false;
  if (lastAutoPumpEnd == 0) {
    // First run: trigger after AUTO_PUMP_INTERVAL_MS from boot
    timerTrigger = (now >= AUTO_PUMP_INTERVAL_MS);
  } else {
    timerTrigger = (now - lastAutoPumpEnd >= AUTO_PUMP_INTERVAL_MS);
  }

  // ── Condition 2: MOISTURE — soil too dry ────────────────────────
  bool moistureTrigger = (!isnan(moisture) && moisture >= 0 && moisture < MOISTURE_LOW_THRESHOLD);

  // ── Activate auto-pump if either condition is true ─────────────
  if (timerTrigger || moistureTrigger) {
    autoPumpActive = true;
    autoPumpStartTime = now;
    currentRelayState = true;
    digitalWrite(PIN_RELAY, HIGH);

    if (moistureTrigger) {
      autoPumpReason = "MOISTURE";
      Serial.printf("[AutoPump] ⚡ TRIGGERED by low moisture (%.1f%% < %.1f%%) — pump ON for %lu sec\n",
                    moisture, MOISTURE_LOW_THRESHOLD, AUTO_PUMP_DURATION_MS / 1000);
    } else {
      autoPumpReason = "TIMER";
      Serial.printf("[AutoPump] ⚡ TRIGGERED by 120-min timer — pump ON for %lu sec\n",
                    AUTO_PUMP_DURATION_MS / 1000);
    }
  } else {
    Serial.println("[AutoPump] Idle — no trigger conditions met");
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  WI-FI
// ═══════════════════════════════════════════════════════════════════════

void connectWiFi() {
  if (WiFi.status() == WL_CONNECTED)
    return;

  Serial.printf("[WiFi] Connecting to '%s'", WIFI_SSID);
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 40) {
    delay(500);
    Serial.print(".");
    attempts++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.printf("\n[WiFi] Connected!  IP: %s\n",
                  WiFi.localIP().toString().c_str());
  } else {
    Serial.println("\n[WiFi] ❌ Connection FAILED. Will retry next cycle.");
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  HTTP POST TO BACKEND
// ═══════════════════════════════════════════════════════════════════════

/**
 * Send a JSON payload string to the backend.
 * Returns true if the server responded with 2xx.
 */
bool sendToBackend(const String &jsonPayload) {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[HTTP] Wi-Fi not connected — skipping POST.");
    return false;
  }

  HTTPClient http;
  http.begin(BACKEND_URL);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("X-API-Key", API_KEY);
  http.setTimeout(10000); // 10 second timeout

  Serial.println("[HTTP] POSTing to backend...");
  int httpCode = http.POST(jsonPayload);

  if (httpCode >= 200 && httpCode < 300) {
    String response = http.getString();
    Serial.printf("[HTTP] ✅ %d — %s\n", httpCode, response.c_str());
    http.end();
    return true;
  } else if (httpCode > 0) {
    String response = http.getString();
    Serial.printf("[HTTP] ❌ %d — %s\n", httpCode, response.c_str());
  } else {
    Serial.printf("[HTTP] ❌ Connection failed: %s\n",
                  http.errorToString(httpCode).c_str());
  }

  http.end();
  return false;
}

// ═══════════════════════════════════════════════════════════════════════
//  RETRY BUFFER MANAGEMENT
// ═══════════════════════════════════════════════════════════════════════

void bufferPayload(const String &payload) {
  if (bufferCount >= MAX_BUFFER) {
    // Buffer full — drop oldest entry
    Serial.println("[Buffer] ⚠ Full — dropping oldest reading.");
    bufferHead = (bufferHead + 1) % MAX_BUFFER;
    bufferCount--;
  }
  int idx = (bufferHead + bufferCount) % MAX_BUFFER;
  retryBuffer[idx] = payload;
  bufferCount++;
  Serial.printf("[Buffer] Queued payload (%d/%d buffered)\n", bufferCount,
                MAX_BUFFER);
}

void flushBuffer() {
  while (bufferCount > 0) {
    String &payload = retryBuffer[bufferHead];
    Serial.printf("[Buffer] Retrying buffered payload (%d remaining)...\n",
                  bufferCount);
    if (sendToBackend(payload)) {
      bufferHead = (bufferHead + 1) % MAX_BUFFER;
      bufferCount--;
    } else {
      // Backend still down — stop flushing, try again later
      Serial.println("[Buffer] Backend still unreachable — will retry later.");
      break;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  BUILD JSON PAYLOAD
// ═══════════════════════════════════════════════════════════════════════

String buildPayload(float ph, float ec, float moisture, float airTemp, float humidity,
                    float waterLevel, float flowRate) {
  JsonDocument doc;

  doc["device_id"] = DEVICE_ID;
  // Let the backend fill in the timestamp (it defaults to UTC now)

  JsonObject readings = doc["readings"].to<JsonObject>();

  // Only include values that are valid (non-NaN)
  if (!isnan(ph) && ph > 0.0)
    readings["ph"] = serialized(String(ph, 2));
  if (!isnan(ec))
    readings["ec"] = serialized(String(ec, 2));
  if (!isnan(moisture))
    readings["moisture"] = serialized(String(moisture, 2));
  if (!isnan(airTemp))
    readings["air_temperature"] = serialized(String(airTemp, 2));
  if (!isnan(humidity))
    readings["humidity"] = serialized(String(humidity, 2));
  if (waterLevel >= 0)
    readings["water_level"] = serialized(String(waterLevel, 2));
  if (!isnan(flowRate) && flowRate >= 0)
    readings["flow_rate"] = serialized(String(flowRate, 2));

  String output;
  serializeJson(doc, output);
  return output;
}

// ═══════════════════════════════════════════════════════════════════════
//  SETUP
// ═══════════════════════════════════════════════════════════════════════

void setup() {
  Serial.begin(115200);

  // ── Wait for Serial connection ──────────────────────────────
  unsigned long start = millis();
  while (!Serial && (millis() - start < 3000)) {
    delay(100);
  }
  delay(500);

  Serial.println();
  Serial.println("═══════════════════════════════════════════════════");
  Serial.println("  HAT — Hydroponics Automation Telemetry");
  Serial.println("  ESP32-S3 Sensor Firmware v2.0");
  Serial.println("  Sensors: pH, EC, Moisture, DHT22, Ultrasonic, Flow");
  Serial.println("  Actuators: Relay (remote pump control from app)");
  Serial.println("═══════════════════════════════════════════════════");
  Serial.println();

  // ── Pin Modes ──────────────────────────────────────────────────
  // Analog pins don't need explicit pinMode on ESP32-S3
  pinMode(PIN_DHT, INPUT);
  pinMode(PIN_TRIG, OUTPUT);
  pinMode(PIN_ECHO, INPUT);
  pinMode(PIN_RELAY, OUTPUT);
  pinMode(PIN_FLOW, INPUT_PULLUP); // Flow sensor open-collector output

  // Default relay OFF
  digitalWrite(PIN_RELAY, LOW);

  // ── Initialise Flow Sensor Interrupt ───────────────────────────
  // Count rising edges from the flow sensor's Hall-effect output
  attachInterrupt(digitalPinToInterrupt(PIN_FLOW), flowPulseISR, RISING);
  lastFlowReadTime = millis();
  Serial.println("[Init] Flow sensor interrupt attached on GPIO 19");

  // ── Initialise DHT ─────────────────────────────────────────────
  dht.begin();
  Serial.println("[Init] DHT22 initialised on GPIO 4");

  // ── Connect Wi-Fi ──────────────────────────────────────────────
  connectWiFi();

  Serial.println();
  Serial.println("[Init] ✅ Setup complete. Entering main loop.");
  Serial.printf("[Init] Sending readings every %lu seconds\n",
                SEND_INTERVAL_MS / 1000);
  Serial.println("[Init] Relay controlled remotely via app poll.\n");
}

// ═══════════════════════════════════════════════════════════════════════
//  MAIN LOOP
// ═══════════════════════════════════════════════════════════════════════

void loop() {
  unsigned long now = millis();

  // Only run every SEND_INTERVAL_MS
  if (now - lastSendTime < SEND_INTERVAL_MS) {
    return;
  }
  lastSendTime = now;

  Serial.println("───────────────────────────────────────────────────");
  Serial.println("[Read] Taking sensor readings...");

  // ── Read all active sensors ─────────────────────────────────────
  float ph = readPH();
  float ec = readEC();
  float moisture = readMoisture();
  float airTemp = dht.readTemperature(); // °C
  float humidity = dht.readHumidity();   // %
  float waterLevel = readWaterLevel();   // cm (-1 if timeout)
  float flowRate = readFlowRate();       // L/min

  // ── Print to Serial Monitor ────────────────────────────────────
  Serial.printf("  pH           : %.2f (Probe voltage: %.3fV)\n", ph, lastPHVoltage);
  Serial.printf("  EC           : %.2f mS/cm\n", ec);
  Serial.printf("  Moisture     : %.2f %%\n", moisture);

  if (isnan(airTemp) || isnan(humidity)) {
    Serial.println("  DHT22        : ❌ Read failed (NaN)");
  } else {
    Serial.printf("  Air Temp     : %.1f °C\n", airTemp);
    Serial.printf("  Humidity     : %.1f %%\n", humidity);
  }

  if (waterLevel < 0) {
    Serial.println("  Water Level  : ❌ Ultrasonic timeout");
  } else {
    Serial.printf("  Water Level  : %.1f cm\n", waterLevel);
  }

  Serial.printf("  Flow Rate    : %.2f L/min\n", flowRate);
  Serial.printf("  Relay        : %s\n", currentRelayState ? "ON" : "OFF");
  Serial.printf("  Auto-Pump    : %s\n", autoPumpActive ? autoPumpReason.c_str() : "IDLE");
  Serial.printf("  Manual Override: %s\n", manualOverride ? "YES" : "NO");

  Serial.println();

  // ── Auto-Pump Logic ────────────────────────────────────────────
  // Check timer (120 min) and moisture threshold BEFORE polling
  // the backend, so auto-pump can activate even if backend is down.
  checkAutoPump(moisture);

  // ── Build JSON payload ─────────────────────────────────────────
  String payload = buildPayload(ph, ec, moisture, airTemp, humidity, waterLevel, flowRate);
  Serial.printf("[JSON] %s\n", payload.c_str());

  // ── Ensure Wi-Fi ───────────────────────────────────────────────
  connectWiFi();

  // ── Flush any buffered payloads first ──────────────────────────
  if (bufferCount > 0) {
    flushBuffer();
  }

  // ── Send current payload ───────────────────────────────────────
  if (!sendToBackend(payload)) {
    bufferPayload(payload);
  }

  // ── Poll backend for relay command (manual app control) ────────
  // Manual ON/OFF from the app overrides auto-pump.
  // If auto-pump is running and user hasn't intervened, it stays on.
  pollRelayCommand();

  Serial.println();
}