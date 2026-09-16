/*
 * ═══════════════════════════════════════════════════════════════════════
 *  HAT — Hydroponics Automation Telemetry
 *  ESP32-S3 Sensor Firmware  (main.cpp)
 * ═══════════════════════════════════════════════════════════════════════
 *
 *  Board  : ESP32-S3 DevKitC-1
 *  Backend: FastAPI /ingest endpoint (HTTP POST with X-API-Key)
 *
 *  Pin Map (from physical trace):
 *  ┌────────────────────┬──────────┬──────────────────────────────────┐
 *  │ Sensor             │ GPIO     │ Notes                            │
 *  ├────────────────────┼──────────┼──────────────────────────────────┤
 *  │ TDS / EC (Analog)  │ GPIO  3  │ ✅ ADC1 — safe                   │
 *  │ Moisture (Analog)  │ GPIO  1  │ ✅ ADC1 — safe                   │
 *  │ DHT22   (Digital)  │ GPIO  4  │ ✅ air temp + humidity           │
 *  │ Ultrasonic Trig    │ GPIO  5  │ ✅                               │
 *  │ Ultrasonic Echo    │ GPIO 18  │ ✅                               │
 *  │ Relay   (Output)   │ GPIO  2  │ ✅                               │
 *  └────────────────────┴──────────┴──────────────────────────────────┘
 *
 *  EXCLUDED (will be added later):
 *    pH Sensor  (GPIO 14) — ADC2 conflict with Wi-Fi
 *    Flow Sensor (GPIO 19) — USB D- pin conflict
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
// Analog sensors
#define PIN_TDS 3      // ✅ ADC1
#define PIN_MOISTURE 1 // ✅ ADC1

// Digital sensors
#define PIN_DHT 4   // DHT22 data pin
#define PIN_TRIG 5  // Ultrasonic HC-SR04 trigger
#define PIN_ECHO 18 // Ultrasonic HC-SR04 echo

// Actuators
#define PIN_RELAY 2 // Relay control (active HIGH)

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

// ═══════════════════════════════════════════════════════════════════════
//  SENSOR READ FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════

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

String buildPayload(float ec, float moisture, float airTemp, float humidity,
                    float waterLevel) {
  JsonDocument doc;

  doc["device_id"] = DEVICE_ID;
  // Let the backend fill in the timestamp (it defaults to UTC now)

  JsonObject readings = doc["readings"].to<JsonObject>();

  // Only include values that are valid (non-NaN)
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

  String output;
  serializeJson(doc, output);
  return output;
}

// ═══════════════════════════════════════════════════════════════════════
//  SETUP
// ═══════════════════════════════════════════════════════════════════════

void setup() {
  Serial.begin(115200);
  delay(1000); // Give serial monitor time to connect

  Serial.println();
  Serial.println("═══════════════════════════════════════════════════");
  Serial.println("  HAT — Hydroponics Automation Telemetry");
  Serial.println("  ESP32-S3 Sensor Firmware v1.1");
  Serial.println("  Active sensors: EC, Moisture, DHT22, Ultrasonic");
  Serial.println("  Excluded: pH (GPIO 14), Flow (GPIO 19)");
  Serial.println("═══════════════════════════════════════════════════");
  Serial.println();

  // ── Pin Modes ──────────────────────────────────────────────────
  // Analog pins don't need explicit pinMode on ESP32-S3
  pinMode(PIN_DHT, INPUT);
  pinMode(PIN_TRIG, OUTPUT);
  pinMode(PIN_ECHO, INPUT);
  pinMode(PIN_RELAY, OUTPUT);

  // Default relay OFF
  digitalWrite(PIN_RELAY, LOW);

  // ── Initialise DHT ─────────────────────────────────────────────
  dht.begin();
  Serial.println("[Init] DHT22 initialised on GPIO 4");

  // ── Connect Wi-Fi ──────────────────────────────────────────────
  connectWiFi();

  Serial.println();
  Serial.println("[Init] ✅ Setup complete. Entering main loop.");
  Serial.printf("[Init] Sending readings every %lu seconds\n",
                SEND_INTERVAL_MS / 1000);
  Serial.println();
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
  float ec = readEC();
  float moisture = readMoisture();
  float airTemp = dht.readTemperature(); // °C
  float humidity = dht.readHumidity();   // %
  float waterLevel = readWaterLevel();   // cm (-1 if timeout)

  // ── Print to Serial Monitor ────────────────────────────────────
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

  Serial.println();

  // ── Build JSON payload ─────────────────────────────────────────
  String payload = buildPayload(ec, moisture, airTemp, humidity, waterLevel);
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

  Serial.println();
}
