# ESP32-S3 Hardware Firmware (Phase 6 / Hardware Guide)

> **Note**: In our project roadmap, Hardware Firmware is formally tracked as **Phase 6**.  
> This file is tailored specifically for the **ESP32-S3** board.

---

## 🛑 HOW TO AVOID JUGGLING: The 1-2-3 Rule

Do **NOT** try to worry about code, Wi-Fi reconnection, JSON payloads, or backend ingestion yet.  
Follow this **linear sequence** — one location and one task at a time:

```
[📍 STEP 1: PC / VS Code] ──► [📍 STEP 2: Physical ESP32-S3] ──► [📍 STEP 3: Browser / Key] ──► [📍 STEP 4: AI Agent Codes] ──► [📍 STEP 5: Flash & Done]
  Install PlatformIO                 Note your GPIO pins                  Get device API key             Agent writes main.cpp            Plug USB & click Upload
```

---

## 📍 STEP 1: At Your PC (VS Code) — Install PlatformIO

* **Where**: On your computer inside VS Code.
* **Estimated Time**: 2 minutes.
* **Goal**: Have the ESP32 flashing tool installed.

### Exactly what to do:
1. Open **VS Code**.
2. Click the **Extensions** icon on the far-left vertical sidebar (or press `Ctrl + Shift + X`).
3. In the search box, type: `PlatformIO IDE`.
4. Click the blue **Install** button on the official extension (by *PlatformIO*).
5. Wait ~1 minute until installation completes. A new **Alien Head icon 👽** will appear on your left sidebar.

> ✅ **You are done with Step 1 when:** You see the Alien Head icon on the left sidebar of VS Code.  
> ⚠️ **Do not configure any boards or code yet!** Move directly to Step 2.

---

## 📍 STEP 2: At Your Desk / Setup — Identify Your Sensor Pins (ESP32-S3)

* **Where**: Looking at your physical ESP32-S3 board and sensor wires.
* **Estimated Time**: 3 minutes.
* **Goal**: Know which wire goes into which pin on your ESP32-S3.

### 💡 Golden Rule for ESP32-S3 Pins (Saves Hours of Debugging):
> **CRITICAL (ESP32-S3 ADC Pinout)**:  
> On the **ESP32-S3**, ADC1 pins are **GPIO 1 through GPIO 10**.  
> Unlike older ESP32 chips (which used GPIO 32–39), the S3 has its safe analog channels on:  
> **GPIO 1, GPIO 2, GPIO 3, GPIO 4, GPIO 5, GPIO 6, GPIO 7, GPIO 8, GPIO 9, GPIO 10**.  
> Always put your analog probes (pH, EC, Water Level, LDR) on these **ADC1** pins so readings remain stable while Wi-Fi is transmitting!  
> *(Also avoid GPIO 19 and 20 for sensors, as they are used by the S3's native USB).*

### Fill In This Cheat Sheet for ESP32-S3:
Check your physical board and write down the GPIO numbers you have plugged in (or plan to plug in):

| Sensor | Sensor Type | Recommended S3 Pins | Your Chosen GPIO Pin |
|---|---|---|---|
| **pH Sensor** | Analog | GPIO 1 or 2 (ADC1) | **GPIO ___** |
| **EC Sensor** (Nutrients) | Analog | GPIO 3 or 4 (ADC1) | **GPIO ___** |
| **Water Temp (DS18B20)** | Digital (OneWire) | GPIO 11 or 12 (with 4.7kΩ pullup) | **GPIO ___** |
| **Water Level** | Analog / Float | GPIO 5 or 6 (ADC1) | **GPIO ___** |
| **Air Temp & Humidity (DHT22)** | Digital | GPIO 13 or 14 | **GPIO ___** |
| **Light Sensor (LDR)** | Analog | GPIO 7 or 8 (ADC1) | **GPIO ___** |

> 📌 **Don't have all sensors wired yet?**  
> No problem! The firmware will safely handle missing sensors (sending `null` so the backend won't fail). Just note down the ones you *do* have connected right now.

---

## 📍 STEP 3: In Your Web Browser — Get Your Device API Key

* **Where**: In your browser on [Supabase Dashboard](https://supabase.com) (or let Agent generate a new one).
* **Estimated Time**: 2 minutes.
* **Goal**: Have the secret string that authenticates `ESP32_01` with the backend.

### Option A: You already have the plaintext key saved
If you saved the key when registering `ESP32_01` (e.g. `hat_live_...` or similar), copy it to your clipboard.

### Option B: You don't have the key / lost it
Because the database stores only the SHA-256 hash (`api_key_hash`), the original key cannot be recovered from the database table.
If you need a new key, just tell the agent:
> *"Agent, generate a new key for ESP32_01 and give me the SQL to update Supabase."*  
The agent will give you a fresh key and the exact 1-line SQL query to run in Supabase SQL Editor.

---

## 📍 STEP 4: In This Chat — Hand Off to the AI Agent

* **Where**: Right here in this chat window.
* **Estimated Time**: 30 seconds.
* **Goal**: Let the Agent write 100% of the C++ code for you.

Simply reply with your details:
```text
Here are my ESP32-S3 pins:
- pH: GPIO 1
- EC: GPIO 3
- Water Temp: GPIO 11
- DHT22: GPIO 13
- Water Level: GPIO 5
- LDR: GPIO 7

My API Key is: [your-key-here]
My Wi-Fi SSID is: [your-wifi-name]
My Wi-Fi Password is: [your-wifi-password]
```

### What the Agent will build immediately:
1. `firmware/platformio.ini` — Pre-configured specifically for **ESP32-S3** (`board = esp32-s3-devkitc-1`, USB CDC on boot enabled so Serial logs work over the S3's Type-C port, and all required sensor libraries).
2. `firmware/src/main.cpp` — Complete, production-ready firmware with Wi-Fi, S3 sensor reads, JSON packaging, HTTPS POST, retry buffer, and serial logs.

---

## 📍 STEP 5: At Your PC — Connect USB & Flash

* **Where**: VS Code.
* **Estimated Time**: 1 minute.
* **Goal**: Upload the compiled firmware onto the ESP32-S3 board.

1. Connect the ESP32-S3 to your PC using a USB-C data cable.
2. In VS Code, open the `firmware/` folder.
3. Look at the bottom blue status bar in VS Code:
   - Click the **Checkmark (✔)** to compile.
   - Click the **Right Arrow (➔)** to upload/flash to ESP32-S3.
4. Click the **Plug icon (🔌)** at the bottom bar to open the **Serial Monitor** (baud rate 115200).

---

## 📍 STEP 6: In Your Browser — Verify Live Data in Supabase

* **Where**: [Supabase Dashboard](https://supabase.com) → Table Editor.
* **Tables to check**:
  1. `sensor_readings`: Watch new rows appear every 30 seconds.
  2. `devices`: Check `last_seen` timestamp for `ESP32_01` updating in real time.

Once rows are appearing in `sensor_readings`, **Hardware Firmware is 100% COMPLETE!** 🎉
