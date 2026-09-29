# 🔧 Buck Converter Troubleshooting — Confirmed Diagnosis

**Date:** 2026-09-28  
**Status:** INPUT side reads ~12V ✅ | OUTPUT side reads 0V ❌  
**Verdict:** The LM2596 module itself is the problem. Battery and charge controller are fine.

---

## 🔍 Diagnosis Summary

```
  12V Battery ──→ Charge Controller ──→ Buck Converter ──→ ESP32
       ✅                ✅                  ❌              ⏳
    (working)         (working)         (NO OUTPUT)      (waiting)
```

Power IS reaching the buck converter's input (IN+ / IN- = ~12V).  
But **nothing** comes out of the output (OUT+ / OUT- = 0V).  
This means the issue is **inside the LM2596 module itself**.

---

## 🔧 FIX 1: Turn the Adjustment Potentiometer (TRY THIS FIRST!)

The LM2596 module has a **tiny blue or gold screw** (potentiometer) on the board. This controls the output voltage. If it's turned all the way down, the output will read 0V even though the module is perfectly healthy.

```
          LM2596 MODULE — Top View
    ┌─────────────────────────────────────┐
    │                                     │
    │   [Capacitor]  [IC chip]  [Coil]    │
    │                                     │
    │       ──→  ⚙️ THIS SCREW  ←──       │
    │            (potentiometer)           │
    │                                     │
    ├──────────┐               ┌──────────┤
    │ IN+  IN- │               │ OUT+ OUT-│
    └──────────┘               └──────────┘
```

### What to Do:

1. **Keep the buck converter powered** (leave the 12V connected to IN+ / IN-)
2. **Place your multimeter probes on OUT+ and OUT-** (DC Voltage, 20V range)
3. Get a **small flathead screwdriver** (the tiny ones for glasses/watches work best)
4. Insert it into the potentiometer screw
5. **Turn COUNTER-CLOCKWISE (CCW) slowly**

```
        Turning Direction:
        
        ↺ Counter-Clockwise (CCW) = INCREASE voltage
        ↻ Clockwise (CW) = DECREASE voltage
        
        (NOTE: Some modules are reversed — if CCW doesn't work, try CW)
```

> [!IMPORTANT]
> **Keep turning! These potentiometers can need 15–25 FULL rotations** before the voltage starts changing. Don't give up after 2-3 turns. Keep going while watching the multimeter.

6. **Watch the multimeter** — at some point you should see the voltage start rising from 0V
7. Once voltage appears, **slow down** and carefully adjust until the multimeter reads **5.0V**
8. Stop turning. You're done!

### What If It Worked?

| Multimeter shows | Action |
|:---|:---|
| **4.9V – 5.1V** ✅ | Perfect! Stop turning. Buck converter is fixed. |
| **Rising but not at 5V yet** | Keep turning CCW slowly. |
| **Overshooting past 5V** | Turn CW (clockwise) to bring it back down. |

> [!CAUTION]
> **STOP if you see voltage going above 5.5V!** Turn back CW immediately. Never connect more than 5.5V to the ESP32.

---

## 🔧 FIX 2: Check if the Module is Dead

If you turned the screw **25+ full rotations in both directions** and the output stays at 0V, the module is dead. Verify by checking these signs:

### Dead Module Symptoms:

| Check | How to Check | Dead Sign |
|:---|:---|:---|
| **LED** | Look for a tiny LED on the module | LED does NOT light up even with 12V input |
| **IC Chip Heat** | Touch the big black IC chip briefly after 10 seconds of power | Extremely hot / burning hot = shorted internally |
| **Burn Marks** | Look at the board closely | Black spots, melted plastic, or burnt smell |
| **Capacitors** | Look at the cylindrical components | Swollen top, leaking brown fluid |
| **Solder Joints** | Flip the board over | Cracked or cold solder joints on the screw terminals |

> [!NOTE]
> Cheap LM2596 modules (especially from AliExpress/Daraz) frequently use **counterfeit LM2596 chips** that fail under load or even on first use. This is very common. A dead-on-arrival module is not unusual.

---

## 🔧 FIX 3: Alternative Solutions (If Module is Dead)

### Option A: Buy a Replacement LM2596 Module (Cheapest)

- **Where:** Any local electronics shop, Daraz, AliExpress
- **Search for:** "LM2596 DC-DC buck converter module" or "12V to 5V step-down"
- **Cost:** ~PKR 150–350
- **Tip:** Buy 2-3 pieces since they're cheap and some may be DOA (dead on arrival)

### Option B: Use a Car USB Charger (Fastest / Most Reliable)

If you have a **12V car USB charger** (the kind that plugs into a car cigarette lighter socket):

```
    12V Battery ──→ Car USB Charger ──→ USB cable ──→ ESP32
```

1. Cut the car charger's cigarette plug off (or use alligator clips)
2. Connect **RED (+)** wire to battery positive
3. Connect **BLACK (-)** wire to battery negative  
4. Plug a USB cable from the charger's USB port into the ESP32

These are **very reliable** because they use proper voltage regulation ICs and are designed for the 12V→5V job.

### Option C: Use a Phone Charger + Inverter (If You Have One)

If you happen to have a small 12V→220V inverter:

```
    12V Battery ──→ Inverter (220V AC) ──→ Phone Charger ──→ USB ──→ ESP32
```

This is inefficient but works as a temporary solution.

### Option D: Wire Directly to 3.3V (Advanced — NOT Recommended)

> [!CAUTION]
> Only for advanced users. If you have a 3.3V regulator (like AMS1117-3.3), you could step 12V→3.3V and feed it directly to the ESP32's 3.3V pin. But this **bypasses the onboard regulator** and any wiring mistake will instantly kill the chip. **Not recommended unless you know what you're doing.**

---

## 🎯 Recommended Action Plan

```
Step 1: Try the potentiometer screw (25+ turns CCW)
        │
        ├─ Voltage appears → Adjust to 5.0V → DONE ✅
        │
        └─ Still 0V after 25+ turns both ways
            │
            ├─ Check for dead module signs (heat, burns, no LED)
            │
            └─ Module is dead → Pick an alternative:
                │
                ├─ Buy replacement LM2596 (cheapest, PKR 150-350)
                ├─ Use car USB charger (fastest, most reliable)
                └─ Any other 12V→5V solution you can find
```

---

---

## 🔌 USB Cable — Wire Color Guide (RGBW)

You cut open a USB cable and found **4 wires**. Here's what each does:

```
┌─────────────────────────────────────────────────┐
│              USB CABLE WIRES                    │
│                                                 │
│   🔴 RED    = +5V POWER     ← YOU NEED THIS    │
│   ⚫ BLACK  = GND (Ground)  ← YOU NEED THIS    │
│   ⚪ WHITE  = DATA- (D-)    ← TAPE OFF, ignore │
│   🟢 GREEN  = DATA+ (D+)   ← TAPE OFF, ignore │
│                                                 │
└─────────────────────────────────────────────────┘
```

### How to Connect:

| Wire | What It Does | Connect To |
|:---|:---|:---|
| **RED** 🔴 | Carries +5V power | Buck converter **OUT+** |
| **BLACK** ⚫ | Ground return path | Buck converter **OUT-** |
| **WHITE** ⚪ | USB data signal (D-) | **DO NOT USE** — cut short & tape |
| **GREEN** 🟢 | USB data signal (D+) | **DO NOT USE** — cut short & tape |

### Steps:
1. **Strip** RED and BLACK wires (~1cm of insulation off the tips)
2. **Cut** WHITE and GREEN short, wrap each tip individually with **electrical tape**
3. Connect **RED → OUT+** on buck converter
4. Connect **BLACK → OUT-** on buck converter  
5. Plug the **USB-C connector end** into the ESP32-S3

> [!WARNING]
> Make sure WHITE and GREEN wires are taped **individually** so they cannot touch each other or any metal. Shorting data lines can cause erratic behavior.

### Better Alternative: Skip the Cable Entirely

> [!TIP]
> Instead of using the cut USB cable, you can wire the buck converter output **directly to the ESP32's header pins**:
> - Buck converter **OUT+** → ESP32 board's **5V pin**
> - Buck converter **OUT-** → ESP32 board's **GND pin**
> 
> This is cleaner, more reliable, and doesn't need a cable at all.

---

*Last updated: 2026-09-28 — Input confirmed at 12V, output at 0V. Most likely cause: potentiometer turned to minimum.*
