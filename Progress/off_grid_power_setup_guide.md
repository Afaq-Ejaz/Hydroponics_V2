# HAT — Off-Grid Power Setup Guide
## Powering ESP32-S3 Without a Laptop (12V Battery + Solar Charge Controller)

**Date:** 2026-09-28  
**Purpose:** Replace the laptop USB power with a standalone 12V battery supply  

---

## Wiring Diagram

![Wiring Diagram — 12V Battery to ESP32-S3 via Charge Controller and Buck Converter](C:/Users/User/.gemini/antigravity-ide/brain/e2bbec3e-7ed0-4257-9248-0a0739d3aebb/wiring_diagram_1790573356936.jpg)

---

## 🔋 Components You Have

| Component | Role |
|-----------|------|
| 12V Battery (green block) | Main power source |
| PWM Solar Charge Controller | Manages battery charge/discharge, protects battery |
| 12V to 5V Buck Converter | Steps down 12V to the 5V the ESP32 needs |
| ESP32-S3 DevKitC-1 | Microcontroller (needs **5V via USB-C** or **5V pin**) |

---

## ⚡ Understanding Your Solar Charge Controller Terminals

Your PWM charge controller has **3 pairs of screw terminals** (6 holes total).  
Looking at the controller face-on, from LEFT to RIGHT:

```
┌──────────────────────────────────────────────────────────┐
│          SOLAR CHARGE CONTROLLER (PWM)                   │
│                                                          │
│   🔆 PANEL        🔋 BATTERY       💡 LOAD              │
│   [+]   [-]       [+]   [-]       [+]   [-]             │
│                                                          │
│   LEFT pair        CENTER pair      RIGHT pair           │
└──────────────────────────────────────────────────────────┘
```

### What Each Terminal Does:

| Terminal Pair | Icon on box | Purpose |
|---------------|-------------|---------|
| **LEFT — PANEL** (solar panel icon) | ☀️ | Where the solar panel wires connect. **Leave empty for now** since you're not using solar yet. |
| **CENTER — BATTERY** (battery icon) | 🔋 | Where your **12V battery** connects. This is the INPUT/OUTPUT to the battery. |
| **RIGHT — LOAD** (lightbulb icon) | 💡 | Where your **load** (the device you want to power) connects. The controller will provide regulated 12V here from the battery. |

---

## 🔌 Step-by-Step Wiring Instructions

### Step 1: Connect the 12V Battery → Charge Controller (CENTER terminals)

> [!CAUTION]
> Always connect the **battery FIRST** before anything else. This powers up the charge controller so it can protect your other components.

1. Take a **RED wire** from the **battery (+) positive terminal**
2. Screw it into the **BATTERY (+)** terminal on the charge controller (center-left hole)
3. Take a **BLACK wire** from the **battery (-) negative terminal**
4. Screw it into the **BATTERY (-)** terminal on the charge controller (center-right hole)

**Result:** The charge controller should power on and show a battery indicator on its display/LEDs.

---

### Step 2: Connect Charge Controller LOAD → Buck Converter (RIGHT terminals)

> [!IMPORTANT]
> The LOAD terminals (right side, with lightbulb icon) output 12V from the battery. This is where you draw power for your ESP32.

1. Take a **RED wire** from **LOAD (+)** terminal (right-side, positive)
2. Connect it to the **VIN+ (input positive)** of your 12V→5V buck converter
3. Take a **BLACK wire** from **LOAD (-)** terminal (right-side, negative)
4. Connect it to the **VIN- / GND (input negative)** of the buck converter

---

### Step 3: Verify Buck Converter Output is 5V

> [!WARNING]
> **Before connecting the ESP32**, use a multimeter to verify the buck converter output is **5.0V ± 0.2V**. If your buck converter is adjustable (has a small screw/potentiometer), turn it until the multimeter reads **5.0V**.  
> Sending more than 5.5V to the ESP32 will **permanently damage** it.

1. Turn on the LOAD switch on the charge controller (if it has one — some controllers have a button to enable/disable the LOAD output)
2. Measure voltage across the buck converter's **VOUT+ and VOUT-** pins with a multimeter
3. Confirm it reads **5.0V**

---

### Step 4: Connect Buck Converter 5V Output → ESP32-S3

You have **two options** to feed 5V into the ESP32-S3:

#### Option A: Via the 5V and GND Header Pins (Recommended ✅)

1. Connect buck converter **VOUT+ (5V)** → ESP32-S3 board's **5V pin** (labeled "5V" on the board header)
2. Connect buck converter **VOUT- (GND)** → ESP32-S3 board's **GND pin**

> [!TIP]
> This is the cleanest option. No USB cable needed. The 5V pin on the DevKitC-1 feeds directly into the onboard voltage regulator which creates the 3.3V for the chip.

#### Option B: Via a Cut USB-C Cable

1. Cut a spare USB-C cable, expose the **RED (5V)** and **BLACK (GND)** wires inside
2. Connect RED to buck converter **VOUT+**
3. Connect BLACK to buck converter **VOUT-**
4. Plug the USB-C end into the ESP32-S3's **UART/COM USB port**

> [!NOTE]
> Option B works but is less clean. Option A (header pins) is preferred for a permanent setup.

---

### Step 5: LEFT Terminals (PANEL) — Leave Empty For Now

The **left two terminals** (with the solar panel icon) are for connecting a solar panel in the future.  
**For now, leave them completely empty.** The battery alone will power everything.

When you're ready to add solar later:
- Connect solar panel **positive (+)** wire → PANEL (+) terminal
- Connect solar panel **negative (-)** wire → PANEL (-) terminal
- The charge controller will then automatically charge the battery from sunlight

---

## 📊 Complete Wiring Flow Summary

```
                        SOLAR CHARGE CONTROLLER
                   ┌──────────────────────────────────┐
                   │  PANEL       BATTERY      LOAD   │
                   │  [+] [-]     [+] [-]     [+] [-] │
                   └──┬──┬────────┬──┬─────────┬──┬───┘
                      │  │        │  │         │  │
                   EMPTY EMPTY    │  │         │  │
                                  │  │         │  │
          ┌───────────────────────┘  │         │  │
          │  ┌──────────────────────┘         │  │
          │  │                                 │  │
     ┌────┴──┴────┐                           │  │
     │  12V       │                           │  │
     │  BATTERY   │                           │  │
     │  + RED     │                           │  │
     │  - BLACK   │                           │  │
     └────────────┘                           │  │
                                              │  │
                              ┌───────────────┘  │
                              │  ┌───────────────┘
                              │  │
                         ┌────┴──┴────┐
                         │ BUCK       │
                         │ CONVERTER  │
                         │ 12V → 5V   │
                         │ IN+  IN-   │
                         │ OUT+ OUT-  │
                         └──┬────┬────┘
                            │    │
                         5V │    │ GND
                            │    │
                      ┌─────┴────┴─────┐
                      │   ESP32-S3     │
                      │   DevKitC-1    │
                      │   5V    GND    │
                      │   pin   pin    │
                      └────────────────┘
```

---

## ⚠️ Safety Checklist Before Powering On

- [ ] Battery polarity correct (RED = +, BLACK = -)
- [ ] Buck converter verified at **5.0V output** with multimeter
- [ ] No bare wires touching each other
- [ ] LOAD switch/button on charge controller is **ON**
- [ ] ESP32 is connected to **5V pin** (not 3.3V pin — that would bypass the regulator)

---

## 🔄 What Changes in the Firmware?

**Nothing!** The firmware ([main.cpp](file:///c:/HAT/firmware/src/main.cpp)) does not need any code changes. The ESP32-S3 doesn't care where its 5V comes from — laptop USB or battery. It behaves identically.

The only difference:
- ❌ **No Serial Monitor** — Without a laptop connected, you lose the ability to see `Serial.println()` debug output. But the ESP32 still connects to Wi-Fi and sends data to the backend normally.
- ✅ **All sensors, Wi-Fi, relay, and auto-pump** continue working exactly as before.

---

## 🕐 Battery Life Estimate

| Parameter | Value |
|-----------|-------|
| ESP32-S3 typical current draw (Wi-Fi active) | ~150–250 mA |
| Sensors + relay idle | ~50 mA |
| **Total estimated draw** | **~200–300 mA at 5V** |
| At 12V (before buck conversion) | **~100–150 mA at 12V** |
| 12V battery capacity (typical) | 7Ah – 12Ah |
| **Estimated runtime (7Ah battery)** | **~46–70 hours (2–3 days)** |
| **Estimated runtime (12Ah battery)** | **~80–120 hours (3–5 days)** |

> [!NOTE]
> These are rough estimates. Actual runtime depends on your battery's actual capacity, age, and the buck converter's efficiency (~85-90%).

---

## 🌞 Future: Adding Solar Panel

When you're ready to make it truly self-sustaining:

1. Buy a 12V solar panel (20W–50W recommended for this load)
2. Connect panel wires to the **LEFT terminals** (PANEL + and PANEL -)
3. The charge controller will automatically:
   - Charge the battery during sunlight
   - Power the LOAD from solar when available
   - Switch to battery at night
   - Protect the battery from overcharging

**No firmware or wiring changes needed** — just add the panel wires to those two empty terminals.
